import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/party/campaign_membership.dart';
import '../../utils/crypto_utils.dart';
import '../logging_service.dart';

/// Manages local multi-campaign indexing and host passkey persistence
class CampaignRegistryService {
  static const String _kRegistryKey = 'user_campaign_registry';
  static const String _kActiveCampaignKey = 'user_active_campaign_code';

  static final CampaignRegistryService _instance = CampaignRegistryService._internal();
  factory CampaignRegistryService() => _instance;

  CampaignRegistryService._internal() {
    loadMemberships();
  }

  @visibleForTesting
  CampaignRegistryService.newInstance();

  final ValueNotifier<List<CampaignMembership>> membershipsNotifier =
      ValueNotifier<List<CampaignMembership>>([]);

  final ValueNotifier<CampaignMembership?> activeCampaignNotifier =
      ValueNotifier<CampaignMembership?>(null);

  List<CampaignMembership> get memberships => membershipsNotifier.value;
  CampaignMembership? get activeCampaign => activeCampaignNotifier.value;

  /// Loads all indexed campaign memberships from SharedPreferences
  Future<List<CampaignMembership>> loadMemberships() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_kRegistryKey) ?? [];
      final activeCode = prefs.getString(_kActiveCampaignKey);

      final loaded = <CampaignMembership>[];
      for (final itemStr in rawList) {
        try {
          final map = jsonDecode(itemStr) as Map<String, dynamic>;
          loaded.add(CampaignMembership.fromMap(map));
        } catch (e) {
          // Skip corrupted entry
        }
      }

      // Sort by lastPlayed descending
      loaded.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
      membershipsNotifier.value = List.unmodifiable(loaded);

      if (activeCode != null && activeCode.isNotEmpty) {
        final match = loaded.where((m) => m.roomCode == activeCode).firstOrNull;
        if (match != null) {
          activeCampaignNotifier.value = match;
        }
      }

      return loaded;
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to load campaign memberships from registry',
      );
      return [];
    }
  }

  /// Gets a membership by room code
  CampaignMembership? getMembership(String roomCode) {
    final clean = roomCode.trim().toUpperCase();
    return membershipsNotifier.value.where((m) => m.roomCode.toUpperCase() == clean).firstOrNull;
  }

  /// Saves or updates a campaign membership and persists to storage
  Future<void> saveMembership(CampaignMembership membership) async {
    try {
      final cleanCode = membership.roomCode.trim().toUpperCase();
      final currentList = List<CampaignMembership>.from(membershipsNotifier.value);
      final index = currentList.indexWhere((m) => m.roomCode.toUpperCase() == cleanCode);

      final updatedMembership = membership.copyWith(roomCode: cleanCode);

      if (index >= 0) {
        currentList[index] = updatedMembership;
      } else {
        currentList.insert(0, updatedMembership);
      }

      currentList.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
      membershipsNotifier.value = List.unmodifiable(currentList);

      if (activeCampaignNotifier.value?.roomCode.toUpperCase() == cleanCode) {
        activeCampaignNotifier.value = updatedMembership;
      }

      await _persistList(currentList);
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to save campaign membership for ${membership.roomCode}',
      );
    }
  }

  /// Removes a campaign membership from device storage
  Future<void> removeMembership(String roomCode) async {
    try {
      final cleanCode = roomCode.trim().toUpperCase();
      final currentList = List<CampaignMembership>.from(membershipsNotifier.value);
      currentList.removeWhere((m) => m.roomCode.toUpperCase() == cleanCode);

      membershipsNotifier.value = List.unmodifiable(currentList);

      if (activeCampaignNotifier.value?.roomCode.toUpperCase() == cleanCode) {
        activeCampaignNotifier.value = currentList.isNotEmpty ? currentList.first : null;
        final prefs = await SharedPreferences.getInstance();
        if (activeCampaignNotifier.value != null) {
          await prefs.setString(_kActiveCampaignKey, activeCampaignNotifier.value!.roomCode);
        } else {
          await prefs.remove(_kActiveCampaignKey);
        }
      }

      await _persistList(currentList);
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to remove campaign membership $roomCode',
      );
    }
  }

  /// Updates lastPlayed timestamp and sets as active campaign
  Future<void> updateLastPlayed(String roomCode) async {
    final existing = getMembership(roomCode);
    if (existing != null) {
      final updated = existing.copyWith(lastPlayed: DateTime.now());
      await saveMembership(updated);
      await setActiveCampaign(updated);
    }
  }

  /// Sets the currently active campaign
  Future<void> setActiveCampaign(CampaignMembership? membership) async {
    activeCampaignNotifier.value = membership;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (membership != null) {
        await prefs.setString(_kActiveCampaignKey, membership.roomCode);
      } else {
        await prefs.remove(_kActiveCampaignKey);
      }
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(e, stackTrace, reason: 'Failed to persist active campaign code');
    }
  }

  /// Exports the 6-word mnemonic passkey for a DM/Host room
  String? exportPasskeyMnemonic(String roomCode) {
    final membership = getMembership(roomCode);
    if (membership != null && membership.hostKey != null && membership.hostKey!.isNotEmpty) {
      return CryptoUtils.encodeHostKeyToMnemonic(membership.hostKey!);
    }
    return null;
  }

  /// Imports a passkey (raw key or mnemonic) for Co-DM rights
  Future<CampaignMembership> importPasskey({
    required String roomCode,
    required String campaignName,
    required String passkeyOrMnemonic,
    String? playerName,
  }) async {
    final cleanCode = roomCode.trim().toUpperCase();
    final membership = CampaignMembership(
      roomCode: cleanCode,
      campaignName: campaignName.trim().isEmpty ? 'Shared Campaign' : campaignName.trim(),
      role: CampaignRole.coDm,
      hostKey: passkeyOrMnemonic.trim(),
      characterId: playerName,
      lastPlayed: DateTime.now(),
    );

    await saveMembership(membership);
    return membership;
  }

  Future<void> _persistList(List<CampaignMembership> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = list.map((m) => m.toJson()).toList();
    await prefs.setStringList(_kRegistryKey, encoded);
  }
}

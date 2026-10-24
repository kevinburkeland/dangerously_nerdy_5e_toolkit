import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/party/campaign_membership.dart';
import '../logging_service.dart';

/// Manages local multi-campaign indexing and host passkey persistence
class CampaignRegistryService {
  static const String _kRegistryKey = 'user_campaign_registry';
  static const String _kActiveCampaignKey = 'user_active_campaign_code';

  static CampaignRegistryService _instance =
      CampaignRegistryService._internal();
  factory CampaignRegistryService() => _instance;

  CampaignRegistryService._internal() {
    loadMemberships();
  }

  @visibleForTesting
  CampaignRegistryService.newInstance();

  @visibleForTesting
  static set instance(CampaignRegistryService value) => _instance = value;

  @visibleForTesting
  static void resetInstanceForTesting() =>
      _instance = CampaignRegistryService.newInstance();

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
        } catch (e, st) {
          LoggingService().logNonFatal(
            e,
            st,
            reason: 'Failed to parse stored campaign membership entry',
          );
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
    return membershipsNotifier.value
        .where((m) => m.roomCode.toUpperCase() == clean)
        .firstOrNull;
  }

  /// Saves or updates a campaign membership and persists to storage
  Future<void> saveMembership(CampaignMembership membership) async {
    try {
      final cleanCode = membership.roomCode.trim().toUpperCase();
      final currentList =
          List<CampaignMembership>.from(membershipsNotifier.value);
      final index =
          currentList.indexWhere((m) => m.roomCode.toUpperCase() == cleanCode);

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
    final cleanCode = roomCode.trim().toUpperCase();
    final originalList = membershipsNotifier.value;
    final originalActive = activeCampaignNotifier.value;
    try {
      final currentList =
          List<CampaignMembership>.from(originalList);
      currentList.removeWhere((m) => m.roomCode.toUpperCase() == cleanCode);

      await _persistList(currentList);

      membershipsNotifier.value = List.unmodifiable(currentList);

      if (originalActive?.roomCode.toUpperCase() == cleanCode) {
        final nextActive = currentList.isNotEmpty ? currentList.first : null;
        activeCampaignNotifier.value = nextActive;
        final prefs = await SharedPreferences.getInstance();
        if (nextActive != null) {
          await prefs.setString(_kActiveCampaignKey, nextActive.roomCode);
        } else {
          await prefs.remove(_kActiveCampaignKey);
        }
      }
    } catch (e, stackTrace) {
      membershipsNotifier.value = originalList;
      activeCampaignNotifier.value = originalActive;
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to remove campaign membership $roomCode',
      );
      rethrow;
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
      LoggingService().logNonFatal(e, stackTrace,
          reason: 'Failed to persist active campaign code');
    }
  }

  Future<void> _persistList(List<CampaignMembership> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = list.map((m) => m.toJson()).toList();
    await prefs.setStringList(_kRegistryKey, encoded);
  }
}

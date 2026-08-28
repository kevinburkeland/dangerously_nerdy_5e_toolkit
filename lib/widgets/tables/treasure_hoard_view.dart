import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/magic_items/magic_item_library.dart';
import '../../models/party/campaign_membership.dart';
import '../../models/party/party_loot_item.dart';
import '../../models/tables/rollable_table.dart';
import '../../providers/settings_provider.dart';
import '../../services/haptic_service.dart';
import '../../services/party/campaign_registry_service.dart';
import '../../services/party/party_room_service.dart';
import '../../services/rules/treasure_generator_engine.dart';
import '../item_compendium/item_detail_dialog.dart';
import '../party/campaign_dialogs.dart';

/// Interactive UI view for generating Individual Monster Loot and Treasure Hoards
/// with Party Share Calculations and Thematic Gemstone / Art Liquidation.
class TreasureHoardView extends StatefulWidget {
  const TreasureHoardView({super.key});

  @override
  State<TreasureHoardView> createState() => _TreasureHoardViewState();
}

class _TreasureHoardViewState extends State<TreasureHoardView> {
  final TreasureGeneratorEngine _engine = TreasureGeneratorEngine();
  TreasureTier _selectedTier = TreasureTier.cr5To10;
  TreasureDropResult? _currentDrop;
  int _partySize = 4;
  bool _liquidateGemsAndArt = false;

  @override
  void initState() {
    super.initState();
    _currentDrop = _engine.generateTreasureHoard(_selectedTier);
  }

  void _generateHoard() {
    HapticService.mediumImpact(context);
    setState(() {
      _currentDrop = _engine.generateTreasureHoard(_selectedTier);
    });
  }

  void _generateIndividual() {
    HapticService.selectionTick(context);
    setState(() {
      _currentDrop = _engine.generateIndividualTreasure(_selectedTier);
    });
  }

  void _copySummaryToClipboard() {
    if (_currentDrop == null) return;
    HapticService.lightImpact(context);
    final md = _engine.formatMarkdownSummary(
      _currentDrop!,
      partySize: _partySize,
      includeLiquidatedShares: _liquidateGemsAndArt,
    );
    Clipboard.setData(ClipboardData(text: md));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied treasure & party share markdown to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _depositToCampaignVault() async {
    if (_currentDrop == null) return;
    final drop = _currentDrop!;
    final registry = CampaignRegistryService();
    final partyService = PartyRoomService();
    final memberships = registry.memberships;

    if (memberships.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No campaign rooms found. Create or join a campaign room first!'),
          action: SnackBarAction(
            label: 'Create',
            onPressed: () => CreateCampaignDialog.show(context),
          ),
        ),
      );
      return;
    }

    CampaignMembership target;
    if (memberships.length == 1) {
      target = memberships.first;
    } else {
      final chosen = await showDialog<CampaignMembership>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.shield_moon_outlined, color: Colors.amber),
                SizedBox(width: 8),
                Text('Select Campaign Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: memberships.length,
                itemBuilder: (ctx, idx) {
                  final m = memberships[idx];
                  return ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(m.campaignName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${m.roomCode} (${m.role.label})'),
                    onTap: () => Navigator.pop(ctx, m),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ],
          );
        },
      );
      if (chosen == null) return;
      if (!mounted) return;
      target = chosen;
    }

    HapticService.mediumImpact(context);
    final playerName = target.characterId ?? 'DM';

    // Deposit coins
    if (drop.cp > 0 || drop.sp > 0 || drop.ep > 0 || drop.gp > 0 || drop.pp > 0) {
      await partyService.depositCoins(
        roomCode: target.roomCode,
        playerName: playerName,
        cp: drop.cp,
        sp: drop.sp,
        ep: drop.ep,
        gp: drop.gp,
        pp: drop.pp,
        note: 'Treasure Drop (${drop.tierLabel})',
      );
    }

    // Deposit Gems
    for (final gem in drop.gemstones) {
      final item = PartyLootItem(
        id: 'gem_${DateTime.now().millisecondsSinceEpoch}_${gem.name.replaceAll(RegExp(r'\W+'), '_')}',
        name: gem.name,
        category: 'gem',
        count: gem.count,
        gpValue: gem.gpValue.toDouble(),
        sourceTableOrMonster: 'Treasure Drop (${drop.tierLabel})',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      await partyService.addLootItem(
        roomCode: target.roomCode,
        playerName: playerName,
        item: item,
      );
    }

    // Deposit Art
    for (final art in drop.artObjects) {
      final item = PartyLootItem(
        id: 'art_${DateTime.now().millisecondsSinceEpoch}_${art.name.replaceAll(RegExp(r'\W+'), '_')}',
        name: art.name,
        category: 'art',
        count: art.count,
        gpValue: art.gpValue.toDouble(),
        sourceTableOrMonster: 'Treasure Drop (${drop.tierLabel})',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      await partyService.addLootItem(
        roomCode: target.roomCode,
        playerName: playerName,
        item: item,
      );
    }

    // Deposit Magic Items
    for (int i = 0; i < drop.magicItemNames.length; i++) {
      final name = drop.magicItemNames[i];
      final item = PartyLootItem(
        id: 'magic_${DateTime.now().millisecondsSinceEpoch}_$i',
        name: name,
        category: 'magicItem',
        count: 1,
        gpValue: 0.0,
        requiresAttunement: name.toLowerCase().contains('attunement') || name.toLowerCase().contains('ring') || name.toLowerCase().contains('cloak'),
        sourceTableOrMonster: 'Treasure Drop (${drop.tierLabel})',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      await partyService.addLootItem(
        roomCode: target.roomCode,
        playerName: playerName,
        item: item,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deposited treasure into "${target.campaignName}" (${target.roomCode})!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Tier Selector Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Color(0xFFF59E0B), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Challenge Rating (CR) Tier',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: TreasureTier.values.map((tier) {
                    final isSel = _selectedTier == tier;
                    return ChoiceChip(
                      label: Text(tier.shortLabel),
                      selected: isSel,
                      selectedColor: const Color(0xFFF59E0B).withAlpha(50),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedTier = tier);
                          _generateHoard();
                        }
                      },
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? const Color(0xFFF59E0B) : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.shield_moon_outlined, size: 18),
                        label: const Text('Roll Hoard Drop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: _generateHoard,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.person_search_outlined, size: 18),
                        label: const Text('Individual Drop'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF59E0B),
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _generateIndividual,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          if (_currentDrop != null) ...[
            // Result Card
            _buildResultCard(context, _currentDrop!, isDark),
            const SizedBox(height: 14),

            // Party Share Calculator Card
            _buildPartyShareCard(context, _currentDrop!, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, TreasureDropResult drop, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151F) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withAlpha(isDark ? 90 : 70),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withAlpha(isDark ? 30 : 15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Title Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withAlpha(isDark ? 35 : 20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  drop.isHoard ? Icons.all_inbox : Icons.monetization_on,
                  color: const Color(0xFFF59E0B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drop.isHoard ? 'Treasure Hoard (${drop.tierLabel})' : 'Individual Monster Drop (${drop.tierLabel})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        drop.rollSummary,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.shield_moon_outlined, size: 18, color: Color(0xFFF59E0B)),
                  tooltip: 'Deposit into Campaign Vault',
                  visualDensity: VisualDensity.compact,
                  onPressed: _depositToCampaignVault,
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy Markdown',
                  visualDensity: VisualDensity.compact,
                  onPressed: _copySummaryToClipboard,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coins Grid
                _buildCoinsRow(drop, isDark),

                // Total Gold Value Banner
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Text(
                            'Total Cash Equivalent:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${drop.grandTotalGoldValue.toStringAsFixed(1)} GP',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Gemstones Section
                if (drop.gemstones.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gemstones (${drop.gemsGoldValue} GP Total)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        '${drop.gemstones.fold(0, (sum, g) => sum + g.count)} gems',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: drop.gemstones.map((gem) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withAlpha(isDark ? 20 : 15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.cyanAccent.withAlpha(80)),
                        ),
                        child: Text(
                          '${gem.count}x ${gem.name} (${gem.gpValue}gp)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Art Objects Section
                if (drop.artObjects.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Art Objects (${drop.artGoldValue} GP Total)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        '${drop.artObjects.fold(0, (sum, a) => sum + a.count)} items',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: drop.artObjects.map((art) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC084FC).withAlpha(isDark ? 25 : 15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFC084FC).withAlpha(90)),
                        ),
                        child: Text(
                          '${art.count}x ${art.name} (${art.gpValue}gp)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC084FC),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Magic Items Section
                if (drop.magicItemNames.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Magic Items (${drop.magicItemNames.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Column(
                    children: List.generate(drop.magicItemNames.length, (idx) {
                      final itemName = drop.magicItemNames[idx];
                      final itemId = idx < drop.magicItemIds.length ? drop.magicItemIds[idx] : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purpleAccent.withAlpha(60)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 16, color: Colors.purpleAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                itemName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            if (itemId != null)
                              IconButton(
                                icon: const Icon(Icons.info_outline, size: 16, color: Colors.purpleAccent),
                                tooltip: 'View Magic Item Card',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  final item = MagicItemLibrary.findById(itemId) ??
                                      MagicItemLibrary.findByName(itemName);

                                  if (item != null) {
                                    final isPinned = SettingsScope.maybeOf(context)
                                            ?.settings
                                            .pinnedItemIds
                                            .contains(item.id) ??
                                        false;

                                    ItemDetailDialog.show(
                                      context,
                                      item: item,
                                      isPinned: isPinned,
                                      onTogglePin: () {
                                        SettingsScope.maybeOf(context)?.togglePinItem(item.id);
                                      },
                                    );
                                  }
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinsRow(TreasureDropResult drop, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCoinBadge('PP', drop.pp, const Color(0xFFE2E8F0), isDark),
        _buildCoinBadge('GP', drop.gp, const Color(0xFFF59E0B), isDark),
        _buildCoinBadge('EP', drop.ep, const Color(0xFF94A3B8), isDark),
        _buildCoinBadge('SP', drop.sp, const Color(0xFFCBD5E1), isDark),
        _buildCoinBadge('CP', drop.cp, const Color(0xFFB45309), isDark),
      ],
    );
  }

  Widget _buildCoinBadge(String label, int amount, Color color, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 30 : 25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(isDark ? 100 : 80)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildPartyShareCard(BuildContext context, TreasureDropResult drop, bool isDark) {
    final shares = drop.calculateShares(
      _partySize,
      includeLiquidatedGemsAndArt: _liquidateGemsAndArt,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.group, color: Colors.cyanAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Party Share Calculator',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              // Party size stepper
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13151F) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.cyanAccent.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: _partySize > 1 ? () => setState(() => _partySize--) : null,
                    ),
                    Text(
                      '$_partySize Players',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.cyanAccent),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: _partySize < 12 ? () => setState(() => _partySize++) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Option: Liquidate gems and art toggle
          InkWell(
            onTap: () {
              HapticService.selectionTick(context);
              setState(() => _liquidateGemsAndArt = !_liquidateGemsAndArt);
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Checkbox(
                  value: _liquidateGemsAndArt,
                  activeColor: Colors.cyanAccent,
                  checkColor: Colors.black,
                  onChanged: (val) {
                    setState(() => _liquidateGemsAndArt = val ?? false);
                  },
                ),
                Expanded(
                  child: Text(
                    'Liquidate & convert all gemstones and art objects to gold',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 16),

          // Per-Player Share Readout
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withAlpha(isDark ? 20 : 15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.cyanAccent.withAlpha(90)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EACH PLAYER RECEIVES:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.cyanAccent,
                  ),
                ),
                const SizedBox(height: 4),
                if (_liquidateGemsAndArt) ...[
                  Text(
                    '💰 ${shares.gpPerPlayer} GP',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (shares.ppPerPlayer > 0) Text('${shares.ppPerPlayer} PP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if (shares.gpPerPlayer > 0) Text('${shares.gpPerPlayer} GP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF59E0B))),
                      if (shares.epPerPlayer > 0) Text('${shares.epPerPlayer} EP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if (shares.spPerPlayer > 0) Text('${shares.spPerPlayer} SP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if (shares.cpPerPlayer > 0) Text('${shares.cpPerPlayer} CP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if (shares.ppPerPlayer == 0 && shares.gpPerPlayer == 0 && shares.epPerPlayer == 0 && shares.spPerPlayer == 0 && shares.cpPerPlayer == 0)
                        const Text('0 Coins (Only items/gems in hoard)', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Value: ~${shares.totalGpEquivalentPerPlayer.toStringAsFixed(2)} GP per adventurer',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ],

                if (shares.remainderCoins.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Party Fund Remainder: ${shares.remainderCoins.entries.map((e) => '${e.value} ${e.key.toUpperCase()}').join(', ')}',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../models/party/campaign_membership.dart';
import '../../models/party/party_loot_item.dart';
import '../../models/party/party_purse.dart';
import '../../models/party/party_session_state.dart';
import '../../services/dice_room_service.dart';
import '../../services/party/party_room_service.dart';
import '../../theme/app_theme.dart';
import 'party_active_character_banner.dart';
import 'party_loot_item_card.dart';
import 'party_purse_cards.dart';

/// Shared Party Vault tab in the Party Room Screen.
class PartyVaultTab extends StatelessWidget {
  final PartySessionState? session;
  final TabletopColors tabletop;
  final bool isDark;
  final String roomCode;
  final String playerName;
  final bool isDmOrCoDm;
  final CampaignMembership? currentMembership;
  final PartyRoomService partyService;
  final DiceRoomService diceService;
  final String selectedCategoryFilter;
  final ValueChanged<String> onCategoryFilterChanged;
  final int partySplitCount;
  final bool includeLiquidatedInSplit;
  final ValueChanged<int> onSplitCountChanged;
  final ValueChanged<bool> onIncludeLiquidatedChanged;
  final ValueChanged<String> onPlayerNameChanged;
  final VoidCallback onRefresh;

  const PartyVaultTab({
    super.key,
    required this.session,
    required this.tabletop,
    required this.isDark,
    required this.roomCode,
    required this.playerName,
    required this.isDmOrCoDm,
    required this.currentMembership,
    required this.partyService,
    required this.diceService,
    required this.selectedCategoryFilter,
    required this.onCategoryFilterChanged,
    required this.partySplitCount,
    required this.includeLiquidatedInSplit,
    required this.onSplitCountChanged,
    required this.onIncludeLiquidatedChanged,
    required this.onPlayerNameChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final purse = session?.partyPurse ?? const PartyPurse.empty();

    return StreamBuilder<List<PartyLootItem>>(
      stream: partyService.streamLoot(roomCode),
      builder: (context, lootSnap) {
        final allItems = lootSnap.data ?? [];

        // Compute total gem & art gold value
        double gemsAndArtTotal = 0.0;
        for (final item in allItems) {
          if (item.category == 'gem' || item.category == 'art') {
            gemsAndArtTotal += item.totalGpValue;
          }
        }

        // Filter items
        final filteredItems = allItems.where((item) {
          if (selectedCategoryFilter == 'magicItem')
            return item.category == 'magicItem';
          if (selectedCategoryFilter == 'gem_art')
            return item.category == 'gem' || item.category == 'art';
          if (selectedCategoryFilter == 'broken_gear')
            return item.category == 'gear' || item.category == 'currency';
          if (selectedCategoryFilter == 'claimed') return item.isClaimed;
          if (selectedCategoryFilter == 'unclaimed') return !item.isClaimed;
          return true;
        }).toList();

        final split = purse.splitShares(
          partySplitCount,
          includeLiquidatedGemsAndArt: includeLiquidatedInSplit,
          liquidatedGemsAndArtGp: gemsAndArtTotal,
          replicaId: partyService.replicaId,
        );

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // 0. ACTIVE CHARACTER & ROSTER BANNER
            PartyActiveCharacterBanner(
                    session: session,
                    tabletop: tabletop,
                    isDark: isDark,
                    roomCode: roomCode,
                    playerName: playerName,
                    isDmOrCoDm: isDmOrCoDm,
                    currentMembership: currentMembership,
                    partyService: partyService,
                    diceService: diceService,
                    onPlayerNameChanged: onPlayerNameChanged,
                    onRefresh: onRefresh,
                  ),
            const SizedBox(height: 14),

            // 1. COIN PURSE HERO CARD (SHARED PARTY VAULT / RESERVE)
            PartyCoinPurseCard(
                    session: session,
                    purse: purse,
                    gemsAndArtTotal: gemsAndArtTotal,
                    split: split,
                    tabletop: tabletop,
                    isDark: isDark,
                    roomCode: roomCode,
                    playerName: playerName,
                    partySplitCount: partySplitCount,
                    includeLiquidatedInSplit: includeLiquidatedInSplit,
                    onSplitCountChanged: onSplitCountChanged,
                    onIncludeLiquidatedChanged: onIncludeLiquidatedChanged,
                  ),
            const SizedBox(height: 14),

            // 1.5 INDIVIDUAL PARTY MEMBER GOLD STORES
            PartyMemberPursesCard(
                    session: session,
                    tabletop: tabletop,
                    isDark: isDark,
                    roomCode: roomCode,
                    playerName: playerName,
                  ),
            const SizedBox(height: 14),

            // 2. CATEGORY FILTER CHIPS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Items (${allItems.length})', 'all'),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    '✨ Magic (${allItems.where((i) => i.category == 'magicItem').length})',
                    'magicItem',
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    '💎 Gems & Art (${allItems.where((i) => i.category == 'gem' || i.category == 'art').length})',
                    'gem_art',
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    '⚔️ Gear (${allItems.where((i) => i.category == 'gear' || i.category == 'currency').length})',
                    'gear',
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip('🙋 Claimed', 'claimed'),
                  const SizedBox(width: 6),
                  _buildFilterChip('📦 Unclaimed', 'unclaimed'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. LOOT ITEMS LIST
            if (filteredItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 48, color: Colors.grey.shade500),
                      const SizedBox(height: 10),
                      Text(
                        allItems.isEmpty
                            ? 'The party vault is currently empty.\nAdd drops or deposit treasure hoards!'
                            : 'No items match the selected filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filteredItems.map((item) =>
                  PartyLootItemCard(
                    item: item,
                    session: session,
                    tabletop: tabletop,
                    isDark: isDark,
                    roomCode: roomCode,
                    playerName: playerName,
                    currentMembership: currentMembership,
                    partyService: partyService,
                  )),

            const SizedBox(height: 70), // Bottom padding for FAB
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedCategoryFilter == value;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) => onCategoryFilterChanged(value),
    );
  }


}

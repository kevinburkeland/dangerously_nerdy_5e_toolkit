import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';

import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_session_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/party/campaign_dialogs.dart';

import '../../support/dart_directive_reader.dart';
import '../../test_doubles/fake_room_document_port.dart';
import '../../test_doubles/hive_test_harness.dart';
import '../../test_doubles/service_test_configurator.dart';

final _publicWidgetClassRe = RegExp(
  r'\bclass\s+([A-Z][A-Za-z0-9_]*)\s+extends\s+(?:StatefulWidget|StatelessWidget)\b',
);

/// Scans every `.dart` file in [dir] with the shared Dart source reader
/// (comments and strings stripped) and returns every public class extending
/// `StatefulWidget` or `StatelessWidget`.
List<({String className, String filePath})> scanPublicDialogWidgets(
  Directory dir,
) {
  if (!dir.existsSync()) {
    throw StateError('Dialog directory does not exist: ${dir.path}');
  }
  final results = <({String className, String filePath})>[];
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final stripped =
        stripCommentsAndStringsPreservingNewlines(file.readAsStringSync());
    for (final m in _publicWidgetClassRe.allMatches(stripped)) {
      results.add((className: m.group(1)!, filePath: file.path));
    }
  }
  return results;
}

/// Compares the public dialog widgets declared under [dir] against
/// [coveredDialogClasses]. Returns failure lines naming missing/extra classes
/// and their files.
List<String> checkDialogLawCompleteness(
  Directory dir,
  Set<String> coveredDialogClasses,
) {
  final found = scanPublicDialogWidgets(dir);
  final foundNames = <String, String>{
    for (final entry in found) entry.className: entry.filePath,
  };
  final problems = <String>[];
  for (final entry in found) {
    if (!coveredDialogClasses.contains(entry.className)) {
      problems.add(
        'Uncovered dialog class ${entry.className} in ${entry.filePath}',
      );
    }
  }
  for (final listed in coveredDialogClasses) {
    if (!foundNames.containsKey(listed)) {
      problems.add(
        'Listed dialog class $listed not found in ${dir.path}',
      );
    }
  }
  return problems;
}

class _LawPartyRoomService extends PartyRoomService {
  final Map<String, PartySessionState> sessionsByCode =
      <String, PartySessionState>{};
  final List<Map<String, Object?>> dispersalCalls = <Map<String, Object?>>[];

  _LawPartyRoomService({
    required super.replicaId,
    required super.clock,
    required super.registry,
    required super.diceRoomService,
  }) : super.newInstance();

  @override
  PartySessionState? getCachedSession(String roomCode) =>
      sessionsByCode[roomCode.toUpperCase()];

  @override
  Stream<PartySessionState?> streamSession(String roomCode) =>
      Stream<PartySessionState?>.value(sessionsByCode[roomCode.toUpperCase()]);

  @override
  Future<void> disperseCoinsToParty({
    required String roomCode,
    required PartyPurse purseToDisperse,
    required List<String> recipientCharacters,
    required String performedBy,
    bool includePartyReserve = true,
    double liquidatedGemsAndArtGp = 0.0,
    bool includeLiquidatedInSplit = false,
    bool isVaultDispersal = false,
  }) async {
    dispersalCalls.add({
      'roomCode': roomCode,
      'recipientCharacters': List<String>.from(recipientCharacters),
      'performedBy': performedBy,
      'includePartyReserve': includePartyReserve,
      'liquidatedGemsAndArtGp': liquidatedGemsAndArtGp,
      'includeLiquidatedInSplit': includeLiquidatedInSplit,
      'isVaultDispersal': isVaultDispersal,
    });
  }
}

Character _makeLawCharacter(int index) {
  return Character(
    id: EntityId(slug: 'law-char-$index', ruleset: RulesetVersion.v2024),
    name: 'Hero $index',
    speciesRef: const EntityReference<DomainEntity>.empty(
      refType: EntityType.species,
      slug: 'human',
      displayName: 'Human',
    ),
    baseScores: const AbilityScores(
      strength: 14,
      dexterity: 12,
      constitution: 14,
      intelligence: 10,
      wisdom: 10,
      charisma: 10,
    ),
  );
}

List<String> _makeNames(int count) =>
    List<String>.generate(count, (i) => 'Member ${i + 1}');

const List<Size> _screenSizes = <Size>[
  Size(1280, 800),
  Size(360, 640),
];

const List<int> _listSizes = <int>[0, 1, 3, 12];

const Set<String> _coveredDialogClasses = <String>{
  'AddLootItemDialog',
  'AssignLootDialog',
  'ClaimDmPasskeyDialog',
  'CoinTransactionDialog',
  'CreateCampaignDialog',
  'DisperseLootDialog',
  'JoinCampaignDialog',
  'LinkCampaignCharacterDialog',
  'ManagePartyRosterDialog',
  'MemberCoinTransactionDialog',
  'ShareDmPasskeyDialog',
  'SwitchActiveCharacterDialog',
  'TransferCoinDialog',
};

Future<void> _setScreenSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
}

Future<void> _openAndVerifyDialog(
  WidgetTester tester, {
  required String dialogName,
  required Size screenSize,
  required String variantLabel,
  required Widget dialog,
  required Finder titleFinder,
  required List<Finder> actionFinders,
}) async {
  await _setScreenSize(tester, screenSize);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => dialog,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  final dynamic exc = tester.takeException();
  expect(
    exc,
    isNull,
    reason:
        '$dialogName ($variantLabel @ ${screenSize.width.toInt()}x${screenSize.height.toInt()}) threw: $exc',
  );
  expect(
    titleFinder,
    findsOneWidget,
    reason:
        '$dialogName ($variantLabel @ ${screenSize.width.toInt()}x${screenSize.height.toInt()}) title not visible',
  );
  for (final actionFinder in actionFinders) {
    expect(
      actionFinder,
      findsWidgets,
      reason:
          '$dialogName ($variantLabel @ ${screenSize.width.toInt()}x${screenSize.height.toInt()}) missing expected action button ($actionFinder)',
    );
  }

  // Close the dialog cleanly before the next variant.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fix 2.1 completeness bar (control + real folder)', () {
    test('control: extra dialog class in temp folder fails, listed passes', () {
      final tmp = Directory.systemTemp.createTempSync('dialog_law_ctrl_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      File('${tmp.path}/alpha_dialog.dart').writeAsStringSync('''
import 'package:material_ui/material_ui.dart';
// class CommentedOutDialog extends StatelessWidget {}
const ignored = 'class StringDialog extends StatefulWidget {}';
class AlphaDialog extends StatelessWidget {
  const AlphaDialog({super.key});
  @override
  Widget build(BuildContext context) => const AlertDialog();
}
class _PrivateHelper extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''');
      File('${tmp.path}/beta_dialog.dart').writeAsStringSync('''
import 'package:material_ui/material_ui.dart';
class BetaDialog extends StatefulWidget {
  const BetaDialog({super.key});
  @override
  State<BetaDialog> createState() => _BetaState();
}
class _BetaState extends State<BetaDialog> {
  @override
  Widget build(BuildContext context) => const AlertDialog();
}
''');

      final missingProblems = checkDialogLawCompleteness(tmp, {'AlphaDialog'});
      expect(missingProblems, hasLength(1));
      expect(missingProblems.single, contains('BetaDialog'));
      expect(missingProblems.single, contains('beta_dialog.dart'));

      final okProblems =
          checkDialogLawCompleteness(tmp, {'AlphaDialog', 'BetaDialog'});
      expect(okProblems, isEmpty);
    });

    test('real bar: every public dialog in lib/widgets/party/campaign_dialogs/ is covered',
        () {
      final dir = Directory('lib/widgets/party/campaign_dialogs');
      final problems = checkDialogLawCompleteness(dir, _coveredDialogClasses);
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('Fix 2.1 law: every campaign dialog opens cleanly across list and screen sizes',
      () {
    late HiveTestHarness harness;
    late CampaignRegistryService registry;
    late DiceRoomService diceService;
    late _LawPartyRoomService partyService;
    late ReplicaId replica;
    late StatefulHlcClock clock;

    setUp(() async {
      harness = HiveTestHarness();
      await harness.setUpInMemory();
      SharedPreferences.setMockInitialValues({});
      registry = CampaignRegistryService.newInstance();
      diceService = createBoundTestDiceRoomService();
      replica = ReplicaId('campaign_dialogs_law_replica');
      clock = StatefulHlcClock(replicaId: replica);
      final campRepo = LocalCampaignRepository(
        replicaId: replica,
        clock: clock,
        characterRepo: LocalCharacterRepository(),
      );
      sl.registerSingleton<ICampaignRepository>(campRepo);
      sl.registerSingleton<IRoomDocumentPort>(RecordingRoomDocumentPort());
      configureTestServices(
        repository: campRepo,
        replicaId: replica,
        clock: clock,
        registryService: registry,
      );
      partyService = _LawPartyRoomService(
        replicaId: replica,
        clock: clock,
        registry: registry,
        diceRoomService: diceService,
      );
      PartyRoomService.setCustomInstanceForTesting(partyService);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') return null;
        if (call.method == 'Clipboard.getData') return const {'text': ''};
        return null;
      });

      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
        campRepo.dispose();
        PartyRoomService.resetCustomInstanceForTesting();
        sl.reset();
        await harness.tearDown();
      });
    });

    testWidgets('AddLootItemDialog opens at both screen sizes', (tester) async {
      addTearDown(tester.view.reset);
      for (final size in _screenSizes) {
        await _openAndVerifyDialog(
          tester,
          dialogName: 'AddLootItemDialog',
          screenSize: size,
          variantLabel: 'no-list',
          dialog: const AddLootItemDialog(
            roomCode: 'LAW-0001',
            playerName: 'Aldric',
          ),
          titleFinder: find.text('Add Vault Item'),
          actionFinders: [find.text('Cancel'), find.text('Add to Vault')],
        );
      }
    });

    testWidgets('AssignLootDialog opens for roster sizes 0, 1, 3, 12 at both screen sizes',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final count in _listSizes) {
        final names = _makeNames(count);
        for (final size in _screenSizes) {
          await _openAndVerifyDialog(
            tester,
            dialogName: 'AssignLootDialog',
            screenSize: size,
            variantLabel: 'roster=$count',
            dialog: AssignLootDialog(
              itemName: 'Sunblade',
              currentActiveName: count == 0 ? '' : names.first,
              roster: names,
              activePlayers: names,
            ),
            titleFinder: find.text('Assign "Sunblade"'),
            actionFinders: [
              find.text('Cancel'),
              find.text('Return to Vault (Unclaim / Shared)'),
            ],
          );
        }
      }
    });

    testWidgets('ClaimDmPasskeyDialog opens at both screen sizes',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final size in _screenSizes) {
        await _openAndVerifyDialog(
          tester,
          dialogName: 'ClaimDmPasskeyDialog',
          screenSize: size,
          variantLabel: 'no-list',
          dialog: const ClaimDmPasskeyDialog(
            initialRoomCode: 'LAW-0001',
            initialPlayerName: 'Aldric',
          ),
          titleFinder: find.text('Claim DM / Co-DM Status'),
          actionFinders: [find.text('Cancel'), find.text('Claim DM Role')],
        );
      }
    });

    testWidgets('CoinTransactionDialog opens at both screen sizes',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final size in _screenSizes) {
        await _openAndVerifyDialog(
          tester,
          dialogName: 'CoinTransactionDialog',
          screenSize: size,
          variantLabel: 'no-list',
          dialog: const CoinTransactionDialog(
            roomCode: 'LAW-0001',
            playerName: 'Aldric',
            isDeposit: true,
          ),
          titleFinder: find.text('Deposit Coins'),
          actionFinders: [find.text('Cancel'), find.text('Deposit')],
        );
      }
    });

    testWidgets('CreateCampaignDialog opens at both screen sizes',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final size in _screenSizes) {
        await _openAndVerifyDialog(
          tester,
          dialogName: 'CreateCampaignDialog',
          screenSize: size,
          variantLabel: 'no-list',
          dialog: const CreateCampaignDialog(),
          titleFinder: find.text('Create New Campaign'),
          actionFinders: [find.text('Cancel'), find.text('Create Campaign')],
        );
      }
    });

    testWidgets('DisperseLootDialog opens for roster sizes 0, 1, 3, 12 at both screen sizes',
        (tester) async {
      addTearDown(tester.view.reset);
      await registry.saveMembership(
        CampaignMembership(
          roomCode: 'LAW-DISP',
          campaignName: 'Dispersal Test',
          role: CampaignRole.host,
          hostKey: 'host-key',
          lastPlayed: DateTime.utc(2026, 1, 1),
        ),
      );

      for (final size in _screenSizes) {
        for (final count in _listSizes) {
          final names = _makeNames(count);
          partyService.sessionsByCode['LAW-DISP'] = PartySessionState(
            roomCode: 'LAW-DISP',
            campaignName: 'Dispersal Test',
            hostKeyHash: 'hash',
            activePlayers: names,
            characterRoster: names,
            lastUpdated: DateTime.utc(2026, 1, 1),
            expiresAt: DateTime.utc(2026, 2, 1),
          );
          await _openAndVerifyDialog(
            tester,
            dialogName: 'DisperseLootDialog',
            screenSize: size,
            variantLabel: 'roster=$count',
            dialog: DisperseLootDialog(
              initialRoomCode: 'LAW-DISP',
              purse: PartyPurse(gp: 100),
            ),
            titleFinder: find.text('Disperse Loot to Party'),
            actionFinders: [
              find.text('Cancel'),
              find.textContaining('Disperse ('),
            ],
          );
        }
      }
    });

    testWidgets('JoinCampaignDialog opens for saved character counts 0, 1, 3, 12 at both screen sizes',
        (tester) async {
      addTearDown(tester.view.reset);
      final persistence = CharacterPersistenceService();
      for (final count in _listSizes) {
        final chars = List<Character>.generate(count, _makeLawCharacter);
        await persistence.saveRoster(chars);
        for (final size in _screenSizes) {
          await _openAndVerifyDialog(
            tester,
            dialogName: 'JoinCampaignDialog',
            screenSize: size,
            variantLabel: 'characters=$count',
            dialog: const JoinCampaignDialog(),
            titleFinder: find.text('Join Existing Campaign'),
            actionFinders: [find.text('Cancel'), find.text('Join Room')],
          );
        }
      }
    });

    testWidgets('LinkCampaignCharacterDialog opens for character/roster sizes 0, 1, 3, 12 at both screen sizes',
        (tester) async {
      addTearDown(tester.view.reset);
      final persistence = CharacterPersistenceService();
      for (final count in _listSizes) {
        final chars = List<Character>.generate(count, _makeLawCharacter);
        await persistence.saveRoster(chars);
        final roster = _makeNames(count);
        partyService.sessionsByCode['LAW-0001'] = PartySessionState(
          roomCode: 'LAW-0001',
          campaignName: 'Link Test',
          hostKeyHash: 'hash',
          activePlayers: roster,
          characterRoster: roster,
          lastUpdated: DateTime.utc(2026, 1, 1),
          expiresAt: DateTime.utc(2026, 2, 1),
        );
        for (final size in _screenSizes) {
          await _openAndVerifyDialog(
            tester,
            dialogName: 'LinkCampaignCharacterDialog',
            screenSize: size,
            variantLabel: 'characters_and_roster=$count',
            dialog: const LinkCampaignCharacterDialog(
              roomCode: 'LAW-0001',
            ),
            titleFinder: find.text('Link Character to Campaign'),
            actionFinders: [
              find.text('Cancel'),
              if (count > 0) find.text('Link Character'),
            ],
          );
        }
      }
    });

    testWidgets('ManagePartyRosterDialog opens for roster sizes 0, 1, 3, 12 at both screen sizes',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final count in _listSizes) {
        final names = _makeNames(count);
        for (final size in _screenSizes) {
          await _openAndVerifyDialog(
            tester,
            dialogName: 'ManagePartyRosterDialog',
            screenSize: size,
            variantLabel: 'roster=$count',
            dialog: ManagePartyRosterDialog(
              roomCode: 'LAW-0001',
              currentName: count == 0 ? '' : names.first,
              initialRoster: names,
            ),
            titleFinder: find.text('Party Character Roster'),
            actionFinders: [find.text('Add'), find.text('Done')],
          );
        }
      }
    });

    testWidgets('MemberCoinTransactionDialog opens at both screen sizes',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final size in _screenSizes) {
        await _openAndVerifyDialog(
          tester,
          dialogName: 'MemberCoinTransactionDialog',
          screenSize: size,
          variantLabel: 'no-list',
          dialog: const MemberCoinTransactionDialog(
            roomCode: 'LAW-0001',
            characterName: 'Aldric',
            performedBy: 'Aldric',
            isDeposit: true,
          ),
          titleFinder: find.text('Deposit to Aldric'),
          actionFinders: [find.text('Cancel'), find.text('Deposit Coins')],
        );
      }
    });

    testWidgets('ShareDmPasskeyDialog opens at both screen sizes',
        (tester) async {
      addTearDown(tester.view.reset);
      final membership = CampaignMembership(
        roomCode: 'LAW-0001',
        campaignName: 'Law Campaign',
        role: CampaignRole.host,
        hostKey: 'secret-passkey-1234',
        lastPlayed: DateTime.utc(2026, 1, 1),
      );
      for (final size in _screenSizes) {
        await _openAndVerifyDialog(
          tester,
          dialogName: 'ShareDmPasskeyDialog',
          screenSize: size,
          variantLabel: 'no-list',
          dialog: ShareDmPasskeyDialog(membership: membership),
          titleFinder: find.text('DM Passkey Delegation'),
          actionFinders: [find.text('Done')],
        );
      }
    });

    testWidgets('SwitchActiveCharacterDialog opens for roster sizes 0, 1, 3, 12 at both screen sizes',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final count in _listSizes) {
        final names = _makeNames(count);
        for (final size in _screenSizes) {
          await _openAndVerifyDialog(
            tester,
            dialogName: 'SwitchActiveCharacterDialog',
            screenSize: size,
            variantLabel: 'roster=$count',
            dialog: SwitchActiveCharacterDialog(
              roomCode: 'LAW-0001',
              currentName: count == 0 ? 'Aldric' : names.first,
              roster: names,
            ),
            titleFinder: find.text('Select Active Character'),
            actionFinders: [find.text('Cancel'), find.text('Confirm Identity')],
          );
        }
      }
    });

    testWidgets('TransferCoinDialog opens at both screen sizes', (tester) async {
      addTearDown(tester.view.reset);
      for (final size in _screenSizes) {
        await _openAndVerifyDialog(
          tester,
          dialogName: 'TransferCoinDialog',
          screenSize: size,
          variantLabel: 'no-list',
          dialog: const TransferCoinDialog(
            roomCode: 'LAW-0001',
            characterName: 'Aldric',
            performedBy: 'Aldric',
            toReserve: true,
          ),
          titleFinder: find.text('Transfer to Party Reserve'),
          actionFinders: [find.text('Cancel'), find.text('Confirm Transfer')],
        );
      }
    });

    testWidgets(
      'Fix 2.2 DisperseLootDialog characterization with 3-member roster: shows candidates and pops true on confirm',
      (tester) async {
        addTearDown(tester.view.reset);
        await _setScreenSize(tester, const Size(1280, 800));
        await registry.saveMembership(
          CampaignMembership(
            roomCode: 'DISP-3',
            campaignName: 'Three Heroes',
            role: CampaignRole.host,
            hostKey: 'host-key',
            lastPlayed: DateTime.utc(2026, 1, 1),
          ),
        );
        partyService.sessionsByCode['DISP-3'] = PartySessionState(
          roomCode: 'DISP-3',
          campaignName: 'Three Heroes',
          hostKeyHash: 'hash',
          activePlayers: const ['Aldric', 'Lyra', 'Kael'],
          characterRoster: const ['Aldric', 'Lyra', 'Kael'],
          lastUpdated: DateTime.utc(2026, 1, 1),
          expiresAt: DateTime.utc(2026, 2, 1),
        );

        bool? dialogResult;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    dialogResult = await DisperseLootDialog.show(
                      context,
                      initialRoomCode: 'DISP-3',
                      purse: PartyPurse(gp: 120),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Disperse Loot to Party'), findsOneWidget);
        expect(find.text('Aldric'), findsOneWidget);
        expect(find.text('Lyra'), findsOneWidget);
        expect(find.text('Kael'), findsOneWidget);
        expect(find.text('Disperse (4 Shares)'), findsOneWidget);

        await tester.tap(find.text('Disperse (4 Shares)'));
        await tester.pumpAndSettle();

        expect(dialogResult, isTrue);
        expect(partyService.dispersalCalls, hasLength(1));
        expect(
          partyService.dispersalCalls.single['recipientCharacters'],
          containsAll(['Aldric', 'Lyra', 'Kael']),
        );
      },
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mutex/mutex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';

class _FakeCharRepo implements ICharacterRepository {
  @override
  Future<List<Character>> loadCharacters() async => [];
  @override
  Future<List<Character>> saveCharacter(Character c) async => [c];
  @override
  Future<void> saveCharacters(List<Character> c) async {}
  @override
  Future<void> saveRoster(List<Character> r) async {}
  @override
  Future<List<Character>> deleteCharacter(String slug) async => [];
  @override
  Future<Character?> getCharacter(String id) async => null;
  @override
  Future<List<Character>> getCharactersByIds(List<String> ids) async => [];
  @override
  Future<String?> loadActiveCharacterId() async => null;
  @override
  Future<void> saveActiveCharacterId(String slug) async {}
  @override
  Future<void> clearActiveCharacterId() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalCampaignRepository Reactive Streams Tests', () {
    test('broadcasts state updates through watchActiveProfile and watchAllProfiles on save', () async {
      final repo = LocalCampaignRepository(characterRepo: _FakeCharRepo());
      addTearDown(repo.dispose);

      final activeProfileEvents = <CampaignProfile?>[];
      final allProfilesEvents = <List<CampaignProfile>>[];

      final subActive = repo.watchActiveProfile().listen(activeProfileEvents.add);
      final subAll = repo.watchAllProfiles().listen(allProfilesEvents.add);
      addTearDown(() {
        subActive.cancel();
        subAll.cancel();
      });

      final p1 = CampaignProfile.defaultProfile(name: 'Campaign Alpha');
      await repo.saveProfileImmediate(p1);
      await Future<void>.delayed(Duration.zero);

      expect(activeProfileEvents.isNotEmpty, isTrue);
      expect(allProfilesEvents.isNotEmpty, isTrue);
      expect(allProfilesEvents.last.map((p) => p.name), contains('Campaign Alpha'));
    });

    test('setActiveProfileId updates active profile stream', () async {
      final repo = LocalCampaignRepository(characterRepo: _FakeCharRepo());
      addTearDown(repo.dispose);

      final p1 = CampaignProfile.defaultProfile(name: 'Camp 1');
      final p2 = CampaignProfile.defaultProfile(name: 'Camp 2');
      await repo.saveProfileImmediate(p1);
      await repo.saveProfileImmediate(p2);

      final activeIds = <String?>[];
      final sub = repo.watchActiveProfile().listen((p) => activeIds.add(p?.id));
      addTearDown(sub.cancel);

      await repo.setActiveProfileId(p2.id);
      await Future<void>.delayed(Duration.zero);

      expect(activeIds.contains(p2.id), isTrue);
      expect(repo.activeProfileId, equals(p2.id));
    });

    test('saveProfileImmediate emits profile updates asynchronously on microtask queue', () async {
      final repo = LocalCampaignRepository(characterRepo: _FakeCharRepo());
      addTearDown(repo.dispose);

      bool synchronousFlag = false;
      bool eventReceivedDuringCall = false;

      final sub = repo.watchAllProfiles().listen((_) {
        if (synchronousFlag) {
          eventReceivedDuringCall = true;
        }
      });
      addTearDown(sub.cancel);

      synchronousFlag = true;
      final saveFuture = repo.saveProfileImmediate(CampaignProfile.defaultProfile(name: 'Async Test'));
      synchronousFlag = false;

      await saveFuture;
      await Future<void>.delayed(Duration.zero);

      expect(
        eventReceivedDuringCall,
        isFalse,
        reason: 'StreamController must emit asynchronously on the microtask queue, not synchronously in-frame',
      );
    });

    test('rapidly chaining saveProfileImmediate within a Mutex does not deadlock or throw StateError', () async {
      final repo = LocalCampaignRepository(characterRepo: _FakeCharRepo());
      addTearDown(repo.dispose);

      final mutex = Mutex();
      final receivedRosters = <List<CampaignProfile>>[];

      final sub = repo.watchAllProfiles().listen((profiles) {
        receivedRosters.add(profiles);
      });
      addTearDown(sub.cancel);

      final futures = <Future<void>>[];
      for (int i = 0; i < 20; i++) {
        futures.add(mutex.protect(() async {
          final profile = CampaignProfile.defaultProfile(
            id: 'mutex_profile_$i',
            name: 'Mutex Profile $i',
          );
          await repo.saveProfileImmediate(profile);
        }));
      }

      await Future.wait(futures);
      await Future<void>.delayed(Duration.zero);

      expect(receivedRosters.isNotEmpty, isTrue);
      expect(receivedRosters.last.map((p) => p.name), contains('Mutex Profile 19'));
    });
  });
}

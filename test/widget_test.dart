import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/main.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';

class _FakePartyRoomService extends Fake implements PartyRoomService {
  @override
  Future<void> syncAllExistingCampaignsToFirestore() async {}
}

void main() {
  setUp(() {
    PartyRoomService.setCustomInstanceForTesting(_FakePartyRoomService());
  });

  tearDown(() {
    PartyRoomService.setCustomInstanceForTesting(null);
  });

  testWidgets('App launches and displays landing screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DangerouslyNerdy5eToolkitApp());
    expect(find.text('DangerouslyNerdy 5e Toolkit'), findsWidgets);
  });
}

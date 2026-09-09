import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/cascading_transport_router.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_connection_telemetry.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/room_connection_badge.dart';

void main() {
  group('RoomConnectionBadge Widget & a11y Tests', () {
    Widget buildTestWidget({
      required Stream<RoomConnectionTelemetry> stream,
      RoomConnectionTelemetry? initialTelemetry,
      double textScaleFactor = 1.0,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
            child: Center(
              child: RoomConnectionBadge(
                telemetryStream: stream,
                initialTelemetry: initialTelemetry,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a11y: Semantics label properly expands WebRTC P2P with 3 peers', (tester) async {
      final controller = StreamController<RoomConnectionTelemetry>();
      const telemetry = RoomConnectionTelemetry(
        state: TransportState.p2pEstablished,
        peerCount: 3,
        isHost: true,
      );

      await tester.pumpWidget(buildTestWidget(
        stream: controller.stream,
        initialTelemetry: telemetry,
      ));

      expect(
        find.bySemanticsLabel('Network Status: WebRTC P2P, 3 peers connected.'),
        findsOneWidget,
      );
      expect(find.text('WebRTC P2P (3)'), findsOneWidget);
      expect(find.byIcon(Icons.lan), findsOneWidget);

      await controller.close();
    });

    testWidgets('a11y: Semantics label properly expands Offline state with 0 peers', (tester) async {
      final controller = StreamController<RoomConnectionTelemetry>();
      const telemetry = RoomConnectionTelemetry(
        state: TransportState.connecting,
        peerCount: 0,
        isHost: false,
      );

      await tester.pumpWidget(buildTestWidget(
        stream: controller.stream,
        initialTelemetry: telemetry,
      ));

      expect(
        find.bySemanticsLabel('Network Status: Connecting..., 0 peers connected.'),
        findsOneWidget,
      );
      expect(find.text('Connecting... (0)'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);

      await controller.close();
    });

    testWidgets('a11y: Semantics label properly expands Firebase Relay with 2 peers', (tester) async {
      final controller = StreamController<RoomConnectionTelemetry>();
      const telemetry = RoomConnectionTelemetry(
        state: TransportState.fallbackRelay,
        peerCount: 2,
        isHost: false,
      );

      await tester.pumpWidget(buildTestWidget(
        stream: controller.stream,
        initialTelemetry: telemetry,
      ));

      expect(
        find.bySemanticsLabel('Network Status: Firebase Relay, 2 peers connected.'),
        findsOneWidget,
      );
      expect(find.text('Firebase Relay (2)'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_queue), findsOneWidget);

      await controller.close();
    });

    testWidgets('Renders Connecting icon when state is connecting with peers > 0', (tester) async {
      final controller = StreamController<RoomConnectionTelemetry>();
      const telemetry = RoomConnectionTelemetry(
        state: TransportState.connecting,
        peerCount: 1,
        isHost: false,
      );

      await tester.pumpWidget(buildTestWidget(
        stream: controller.stream,
        initialTelemetry: telemetry,
      ));

      expect(
        find.bySemanticsLabel('Network Status: Connecting..., 1 peers connected.'),
        findsOneWidget,
      );
      expect(find.text('Connecting... (1)'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);

      await controller.close();
    });

    testWidgets('Dynamically updates UI as telemetry stream emits new snapshots', (tester) async {
      final controller = StreamController<RoomConnectionTelemetry>.broadcast();

      await tester.pumpWidget(buildTestWidget(
        stream: controller.stream,
        initialTelemetry: const RoomConnectionTelemetry(),
      ));

      expect(find.text('Connecting... (0)'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);

      // Emit transition to WebRTC P2P with 4 peers
      controller.add(const RoomConnectionTelemetry(
        state: TransportState.p2pEstablished,
        peerCount: 4,
        isHost: true,
      ));
      await tester.pump();

      expect(find.text('WebRTC P2P (4)'), findsOneWidget);
      expect(find.byIcon(Icons.lan), findsOneWidget);
      expect(
        find.bySemanticsLabel('Network Status: WebRTC P2P, 4 peers connected.'),
        findsOneWidget,
      );

      // Emit fallback to Firebase Relay
      controller.add(const RoomConnectionTelemetry(
        state: TransportState.fallbackRelay,
        peerCount: 2,
        isHost: false,
      ));
      await tester.pump();

      expect(find.text('Firebase Relay (2)'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_queue), findsOneWidget);
      expect(
        find.bySemanticsLabel('Network Status: Firebase Relay, 2 peers connected.'),
        findsOneWidget,
      );

      await controller.close();
    });

    testWidgets('Renders cleanly at TextScaler 2.0 without overflow errors', (tester) async {
      final controller = StreamController<RoomConnectionTelemetry>();
      const telemetry = RoomConnectionTelemetry(
        state: TransportState.p2pEstablished,
        peerCount: 5,
        isHost: true,
      );

      await tester.pumpWidget(buildTestWidget(
        stream: controller.stream,
        initialTelemetry: telemetry,
        textScaleFactor: 2.0,
      ));

      expect(tester.takeException(), isNull);
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('WebRTC P2P (5)'), findsOneWidget);

      await controller.close();
    });
  });
}

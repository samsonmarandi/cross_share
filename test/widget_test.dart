import 'package:cross_share/app.dart';
import 'package:cross_share/providers/app_providers.dart';
import 'package:cross_share/services/http_server_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Widget tests must not bind sockets, scan the LAN, or invoke device plugins.
class _TestSession extends AppSession {
  _TestSession(super.ref);
  @override
  Future<void> start(OnTransferRequestCallback requestApproval) async {}
}

void main() {
  testWidgets('App loads and switches tabs without starting networking', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => _TestSession(ref))],
        child: const CrossShareApp(),
      ),
    );
    expect(find.text('CrossShare'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    expect(find.text('Device Name'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

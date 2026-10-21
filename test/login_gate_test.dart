import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulia_smart_campus/screens/login_gate.dart';
import 'package:mulia_smart_campus/services/storage_service.dart';

void main() {
      for (final width in [320.0, 360.0]) {
            testWidgets('Setup Admin lokal wajib tanpa Atur Server pada $width',
                    (tester) async {
                      tester.view.physicalSize = Size(width, 1100);
                      tester.view.devicePixelRatio = 1;
                      addTearDown(tester.view.resetPhysicalSize);
                      addTearDown(tester.view.resetDevicePixelRatio);
                      SharedPreferences.setMockInitialValues(<String, Object>{});
                      final storage = await StorageService.buka();
                      await tester.pumpWidget(MaterialApp(home: LoginGate(storage: storage)));
                      await tester.pumpAndSettle();
                      expect(find.text('Atur Server'), findsNothing);
                      expect(find.text('Buat Admin Lokal Pertama'), findsOneWidget);
                      expect(
                          tester
                              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Masuk'))
                              .onPressed,
                          isNull);
                      final setup = find.text('Buat Admin Lokal Pertama');
                      await tester.ensureVisible(setup);
                      await tester.tap(setup);
                      await tester.pumpAndSettle();
                      expect(find.text('Simpan Admin Lokal'), findsOneWidget);
                      expect(find.byKey(const ValueKey('register-role')), findsNothing);
                      final save = find.widgetWithText(FilledButton, 'Simpan Admin Lokal');
                      await tester.ensureVisible(save);
                      await tester.tap(save);
                      await tester.pump();
                      expect(find.text('Username 3–40 karakter tanpa spasi.'), findsOneWidget);
                      expect(tester.takeException(), isNull);
                });
      }
}

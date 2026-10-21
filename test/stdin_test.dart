import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulia_smart_campus/data/compiler_data.dart';
import 'package:mulia_smart_campus/screens/compiler_screen.dart';
import 'package:mulia_smart_campus/screens/web_playground_screen.dart';
import 'package:mulia_smart_campus/services/compiler_service.dart';
import 'package:mulia_smart_campus/services/storage_service.dart';

http.Response selesai() => http.Response(
    jsonEncode({
      'status': {'id': 3, 'description': 'Accepted'},
      'stdout': base64Encode(utf8.encode('Input diterima')),
    }),
    200);
void main() {
  const input = '50\n75\nJonathan ✓ • café 😀\n';
  for (final bahasa in kBahasaKompiler) {
    test('${bahasa.label}: stdin dikirim Base64 UTF-8 tanpa mengubah baris',
        () async {
      final service = CompilerService(client: MockClient((r) async {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(utf8.decode(base64Decode(body['stdin'] as String)), input);
        expect(body['language_id'], CompilerService.idJudge0(bahasa));
        expect(r.url.queryParameters['base64_encoded'], 'true');
        return selesai();
      }));
      addTearDown(service.dispose);
      final hasil =
          await service.jalankan(bahasa: bahasa, kode: 'kode', stdin: input);
      expect(hasil.ok, isTrue);
    });
    testWidgets(
        '${bahasa.label}: stdin dari editor gabungan dikirim pada 320px',
        (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final storage = await StorageService.buka();
      String? terkirim;
      final service = CompilerService(client: MockClient((r) async {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        terkirim = utf8.decode(base64Decode(body['stdin'] as String));
        return selesai();
      }));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: CompilerScreen(
                  storage: storage, bahasaAwal: bahasa, service: service))));
      final field = find.byKey(
        const ValueKey<String>('compiler-editor'),
      );
      expect(field, findsOneWidget);
      await tester.ensureVisible(field);
      await tester.enterText(
        field,
        'kode\n=== INPUT STDIN ===\n$input',
      );
      final tombol = find.widgetWithText(FilledButton, 'Jalankan');
      await tester.ensureVisible(tombol);
      await tester.tap(tombol);
      await tester.pumpAndSettle();
      expect(terkirim, input);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Preview: satu editor dan isi terpisah per tab', (tester) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: WebPlaygroundScreen()));
    await tester.tap(find.widgetWithText(ChoiceChip, 'C++'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    final cpp = find.byKey(const ValueKey<int>(4));
    await tester.enterText(cpp, 'kode C++\n=== INPUT STDIN ===\n50\n75');
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'PHP'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'PHP'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    final php = find.byKey(const ValueKey<int>(3));
    expect(tester.widget<TextField>(php).controller!.text,
        isNot(contains('50\n75')));
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'C++'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'C++'));
    await tester.pump();
    expect(tester.widget<TextField>(cpp).controller!.text,
        'kode C++\n=== INPUT STDIN ===\n50\n75');
    expect(tester.takeException(), isNull);
  });
}

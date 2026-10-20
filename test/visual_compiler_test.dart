import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulia_smart_campus/data/compiler_data.dart';
import 'package:mulia_smart_campus/data/visual_compiler_data.dart';
import 'package:mulia_smart_campus/screens/compiler_screen.dart';
import 'package:mulia_smart_campus/screens/web_playground_screen.dart';
import 'package:mulia_smart_campus/services/compiler_service.dart';
import 'package:mulia_smart_campus/services/storage_service.dart';

String b64(String text) => base64Encode(utf8.encode(text));

void main() {
  test('Teks biasa, offline, dan error tidak menjadi preview', () {
    expect(htmlHasilVisual(berhasil: true, stdout: '123 Halo'), isNull);
    expect(htmlHasilVisual(berhasil: false, stdout: '<b>error</b>'), isNull);
    expect(htmlHasilVisual(berhasil: true, stdout: ''), isNull);
    expect(htmlHasilVisual(berhasil: true, stdout: '<b>123</b>'), '<b>123</b>');
  });
  test('Contoh 4 bahasa mencetak dokumen HTML yang sama', () {
    for (final String id in <String>[
      'cplusplus',
      'php',
      'python',
      'javascript'
    ]) {
      expect(contohKodeVisual(id), contains(kContohHtmlVisual));
    }
  });
  for (final String id in <String>['cplusplus', 'php', 'python']) {
    final bahasa = kBahasaKompiler.firstWhere((b) => b.id == id);
    test('$id memisahkan stdout dari pesan error', () async {
      final service = CompilerService(client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['language_id'], CompilerService.idJudge0(bahasa));
        expect(utf8.decode(base64Decode(body['source_code'] as String)),
            contohKodeVisual(id));
        expect(request.url.queryParameters['base64_encoded'], 'true');
        return http.Response(
            jsonEncode(<String, dynamic>{
              'status': <String, dynamic>{'id': 3, 'description': 'Accepted'},
              'stdout': b64('<h1>Visual</h1>'),
              'stderr': b64('pesan diagnostik'),
            }),
            200);
      }));
      addTearDown(service.dispose);
      final hasil =
      await service.jalankan(bahasa: bahasa, kode: contohKodeVisual(id));
      expect(hasil.ok, isTrue);
      expect(hasil.stdout, '<h1>Visual</h1>');
      expect(hasil.keluaran, contains('pesan diagnostik'));
      expect(htmlHasilVisual(berhasil: hasil.ok, stdout: hasil.stdout),
          '<h1>Visual</h1>');
    });
    testWidgets(
        '$id tersedia di Preview Web dan dieksekusi sesuai tab pada 320px',
            (tester) async {
          tester.view.physicalSize = const Size(320, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          String? kodeTerkirim;
          final service = CompilerService(client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['language_id'], CompilerService.idJudge0(bahasa));
            kodeTerkirim = utf8.decode(base64Decode(body['source_code'] as String));
            expect(utf8.decode(base64Decode(body['stdin'] as String)), '50\n75\n');
            return http.Response(
                jsonEncode({
                  'status': {'id': 3, 'description': 'Accepted'},
                  'stdout': b64('123 teks biasa')
                }),
                200);
          }));
          await tester
              .pumpWidget(MaterialApp(home: WebPlaygroundScreen(service: service)));
          for (final label in [
            'HTML',
            'CSS',
            'JavaScript',
            'PHP',
            'C++',
            'Python'
          ]) {
            expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
          }
          await tester.tap(find.widgetWithText(ChoiceChip, bahasa.label));
          await tester.pump();
          final sumber = 'kode khusus $id';
          await tester.enterText(find.byType(TextField).first, sumber);
          await tester.tap(find.widgetWithText(ChoiceChip, 'HTML'));
          await tester.pump();
          await tester.tap(find.widgetWithText(ChoiceChip, bahasa.label));
          await tester.pump();
          expect(find.text(sumber), findsOneWidget);
          expect(find.byType(TextField), findsOneWidget);
          await tester.enterText(find.byType(TextField),
              '$sumber\n=== INPUT STDIN ===\n50\n75\n');
          final tombol = find.widgetWithText(
              FilledButton, 'Jalankan ${bahasa.label} & Preview');
          await tester.ensureVisible(tombol);
          await tester.tap(tombol);
          await tester.pumpAndSettle();
          expect(kodeTerkirim, '$sumber\n');
          expect(find.byType(SelectableText), findsOneWidget);
          expect(tester.widget<SelectableText>(find.byType(SelectableText)).data,
              contains('123 teks biasa'));
          expect(tester.takeException(), isNull);
        });
  }
  testWidgets(
      'Kompiler tidak lagi memiliki Contoh desain dan Lihat Hasil Visual',
          (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final storage = await StorageService.buka();
        await tester.pumpWidget(
            MaterialApp(home: Scaffold(body: CompilerScreen(storage: storage))));
        expect(find.textContaining('Contoh desain'), findsNothing);
        expect(find.text('Lihat Hasil Visual'), findsNothing);
        expect(find.text('Buka Preview Web'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
  test('Status gagal tidak membuka stdout HTML sebagai preview', () async {
    final service = CompilerService(
        client: MockClient((_) async => http.Response(
            jsonEncode(<String, dynamic>{
              'status': <String, dynamic>{
                'id': 6,
                'description': 'Compilation Error'
              },
              'stdout': b64('<h1>Tidak boleh ditampilkan</h1>'),
              'compile_output': b64('error'),
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    addTearDown(service.dispose);
    final hasil =
    await service.jalankan(bahasa: kBahasaKompiler.first, kode: 'salah');
    expect(htmlHasilVisual(berhasil: hasil.ok, stdout: hasil.stdout), isNull);
  });
}

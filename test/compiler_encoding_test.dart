import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mulia_smart_campus/data/compiler_data.dart';
import 'package:mulia_smart_campus/services/compiler_service.dart';
import 'package:mulia_smart_campus/utils/web_preview_document.dart';

String b64(String s) => base64Encode(utf8.encode(s));
void main() {
  const String unicode = '✓ • — café 日本語 😀';
  for (final bahasa in kBahasaKompiler) {
    test('${bahasa.label}: request dan keluaran Unicode Base64 UTF-8',
            () async {
          final service = CompilerService(
            // Endpoint lama pun dipaksa memakai protokol yang konsisten.
            endpoint:
            'https://example.test/submissions?base64_encoded=false&wait=false&custom=1',
            client: MockClient((r) async {
              expect(r.url.queryParameters['base64_encoded'], 'true');
              expect(r.url.queryParameters['wait'], 'true');
              expect(r.url.queryParameters['custom'], '1');
              final body = jsonDecode(r.body) as Map<String, dynamic>;
              expect(utf8.decode(base64Decode(body['source_code'] as String)),
                  unicode);
              expect(body['language_id'], CompilerService.idJudge0(bahasa));
              expect(body['stdin'], '');
              return http.Response(
                  jsonEncode({
                    'status': {'id': 3, 'description': 'Accepted'},
                    'stdout': b64('<h1>$unicode</h1>'),
                    'stderr': b64('diagnostik $unicode'),
                    'compile_output': null,
                  }),
                  200);
            }),
          );
          addTearDown(service.dispose);
          final hasil = await service.jalankan(bahasa: bahasa, kode: unicode);
          expect(hasil.ok, isTrue);
          expect(hasil.stdout, '<h1>$unicode</h1>');
          expect(hasil.keluaran, contains('diagnostik $unicode'));
          expect(hasil.stdout, isNot(contains('diagnostik')));
        });
  }
  test('Pesan kompilasi Base64 didekode meskipun program gagal', () async {
    final service = CompilerService(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'status': {'id': 6, 'description': 'Compilation Error'},
              'stdout': null,
              'stderr': '',
              'compile_output': b64('Kesalahan: $unicode'),
            }),
            200)));
    addTearDown(service.dispose);
    final hasil =
    await service.jalankan(bahasa: kBahasaKompiler.first, kode: 'salah');
    expect(hasil.ok, isFalse);
    expect(hasil.offline, isFalse);
    expect(hasil.keluaran, 'Kesalahan: $unicode');
  });
  test('Byte output bukan UTF-8 tidak memicu error HTTP 400 di klien',
          () async {
        final service = CompilerService(
            client: MockClient((_) async => http.Response(
                jsonEncode({
                  'status': {'id': 3, 'description': 'Accepted'},
                  'stdout': base64Encode(<int>[65, 255, 66]),
                }),
                200)));
        addTearDown(service.dispose);
        final hasil =
        await service.jalankan(bahasa: kBahasaKompiler.first, kode: 'binary');
        expect(hasil.ok, isTrue);
        expect(hasil.stdout, 'A\uFFFDB');
      });
  test('Base64 rusak dilaporkan sebagai format respons, bukan offline',
          () async {
        final service = CompilerService(
            client: MockClient((_) async => http.Response(
                jsonEncode({
                  'status': {'id': 3, 'description': 'Accepted'},
                  'stdout': '%%%rusak',
                }),
                200)));
        addTearDown(service.dispose);
        final hasil =
        await service.jalankan(bahasa: kBahasaKompiler.first, kode: 'x');
        expect(hasil.ok, isFalse);
        expect(hasil.offline, isFalse);
        expect(hasil.keluaran, contains('JSON/Base64'));
      });
  test('HTML/CSS/JS: UTF-8 eksplisit, Unicode dan CSS tidak hilang', () {
    final doc = buatDokumenPreview(
        '<h1>$unicode</h1>', 'h1::after {content:"✓"}', 'const x = "😀";');
    expect('UTF-8'.allMatches(doc).length, 2);
    expect(doc, contains('café'));
    expect(doc, contains('content:'));
    expect(doc, contains('sandbox="allow-scripts"'));
  });
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mulia_smart_campus/utils/combined_program_input.dart';
import 'package:mulia_smart_campus/services/compiler_service.dart';
import 'package:mulia_smart_campus/screens/web_playground_screen.dart';

void main() {
  test('Tanpa penanda kode utuh dan stdin kosong', () {
    final p = pisahkanProgramInput('print(123)');
    expect(p.kode, 'print(123)');
    expect(p.stdin, '');
  });
  for (final marker in ['=== INPUT STDIN ===', '// === INPUT STDIN ===', '# === INPUT STDIN ===']) {
    test('Pemisah $marker mempertahankan baris dan Unicode', () {
      final p = pisahkanProgramInput('kode\r\n$marker\r\n\r\n café ✓\r\n');
      expect(p.kode, 'kode\r\n');
      expect(p.stdin, '\r\n café ✓\r\n');
    });
  }
  test('Penanda di dalam string bukan pemisah', () {
    const kode = 'print("=== INPUT STDIN ===")';
    expect(pisahkanProgramInput(kode).kode, kode);
  });
  test('Penanda kosong di akhir dan input yang berisi penanda', () {
    expect(pisahkanProgramInput('kode\n=== INPUT STDIN ===').stdin, '');
    expect(pisahkanProgramInput('kode\n=== INPUT STDIN ===\n=== INPUT STDIN ===\n').stdin,
        '=== INPUT STDIN ===\n');
  });
  final cases = <String, String>{
    'C++': '#include <iostream>\nint main(){int x;std::cin>>x;std::cout<<x;}',
    'PHP': '<?php echo trim(fgets(STDIN));',
    'Python': 'print(input())',
  };
  for (final entry in cases.entries) {
    testWidgets('${entry.key}: satu editor mengirim kode dan stdin terpisah', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? sent;
      final service = CompilerService(client: MockClient((r) async {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({
          'status': {'id': 3, 'description': 'Accepted'},
          'stdout': base64Encode(utf8.encode('42')),
        }), 200);
      }));
      await tester.pumpWidget(MaterialApp(home: WebPlaygroundScreen(service: service)));
      await tester.tap(find.widgetWithText(ChoiceChip, entry.key));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '${entry.value}\n=== INPUT STDIN ===\n42\n');
      final run = find.widgetWithText(FilledButton, 'Jalankan ${entry.key} & Preview');
      await tester.ensureVisible(run);
      await tester.tap(run);
      await tester.pumpAndSettle();
      expect(sent, isNotNull);
      expect(utf8.decode(base64Decode(sent!['source_code'] as String)), '${entry.value}\n');
      expect(utf8.decode(base64Decode(sent!['stdin'] as String)), '42\n');
      expect(tester.takeException(), isNull);
    });
  }
}

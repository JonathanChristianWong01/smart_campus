import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mulia_smart_campus/screens/about_screen.dart';
import 'package:mulia_smart_campus/screens/web_playground_screen.dart';
import 'package:mulia_smart_campus/utils/web_preview_document.dart';

void main() {
  test('Preview terisolasi dan isi editor tidak menutup script bootstrap', () {
    final String result = buatDokumenPreview(
        '<h1>Tebal</h1>', 'h1{font-weight:900}', 'const a = "</script>";');
    expect(result, contains('sandbox="allow-scripts"'));
    expect(result, isNot(contains('allow-same-origin')));
    expect(result, contains('font-weight:900'));
    expect(result, contains(r'\u003c/script'));
  });
  testWidgets('Identitas pembuat paling atas pada Info di 320 px',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: AboutScreen())));
    expect(find.text('Jonathan Christian Wong'), findsOneWidget);
    expect(find.text('2411015'), findsOneWidget);
    expect(find.text('IFB5A'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Pembuat Aplikasi')).dy,
        lessThan(tester.getTopLeft(find.text('Ringkasan Kurikulum')).dy));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Tab editor web menyimpan kode saat berpindah pada 320 px',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: WebPlaygroundScreen()));
    await tester.enterText(find.byType(TextField), '<b>Jonathan 123</b>');
    await tester.tap(find.widgetWithText(ChoiceChip, 'CSS'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'HTML'));
    await tester.pump();
    expect(find.text('<b>Jonathan 123</b>'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

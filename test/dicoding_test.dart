import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulia_smart_campus/screens/compiler_screen.dart';
import 'package:mulia_smart_campus/services/storage_service.dart';

void main() {
  for (final double lebar in <double>[320, 360]) {
    testWidgets(
        'Kompiler $lebar px: Dicoding menggantikan progres, tautan browser benar',
            (tester) async {
          tester.view.physicalSize = Size(lebar, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final storage = await StorageService.buka();
          MethodCall? panggilan;
          const channel = MethodChannel('plugins.flutter.io/url_launcher');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
                  (call) async {
                panggilan = call;
                return true;
              });
          addTearDown(() => tester.binding.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null));
          await tester.pumpWidget(
              MaterialApp(home: Scaffold(body: CompilerScreen(storage: storage))));
          final tombol = find.byKey(const ValueKey<String>('buka-dicoding'));
          await tester.ensureVisible(tombol);
          await tester.pumpAndSettle();
          expect(find.text('Progres Sertifikat Praktikum'), findsNothing);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(find.text('Belajar di Dicoding'), findsOneWidget);
          expect(find.text('Web Kompiler'), findsOneWidget);
          await tester.tap(tombol);
          await tester.pumpAndSettle();
          expect(panggilan, isNotNull);
          expect((panggilan!.arguments as Map)['url'], 'https://www.dicoding.com/');
          expect((panggilan!.arguments as Map)['useWebView'], false);
          expect(tester.takeException(), isNull);
        });
  }
  testWidgets('Browser gagal: tampil petunjuk tanpa crash', (tester) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await StorageService.buka();
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompilerScreen(storage: storage))));
    final tombol = find.byKey(const ValueKey<String>('buka-dicoding'));
    await tester.ensureVisible(tombol);
    await tester.tap(tombol);
    await tester.pumpAndSettle();
    expect(find.textContaining('Browser tidak dapat dibuka.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
      'Lima halaman web: tautan Dicoding ada, progres dan callback lama dihapus',
          () {
        for (final nama in <String>[
          'compiler',
          'compiler_cplusplus',
          'compiler_javascript',
          'compiler_php',
          'compiler_python'
        ]) {
          final html = File('assets/web/$nama.html').readAsStringSync();
          expect(html, contains('href="https://www.dicoding.com/"'));
          expect(html, contains('Belajar di Dicoding'));
          for (final token in <String>[
            'Sertifikat Praktikum',
            'refreshProg',
            'cetakSertifikat',
            'mulia_run_ok',
            'id="prog"',
            'id="bar"'
          ]) {
            expect(html, isNot(contains(token)), reason: '$nama: $token');
          }
          expect(html, contains('function run()'));
          expect(html, contains('renderHist'));
        }
      });
}

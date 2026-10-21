import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mulia_smart_campus/screens/account_actions.dart';
import 'package:mulia_smart_campus/services/campus_auth_api.dart';

class AccountsFakeApi extends CampusAuthApi {
  AccountsFakeApi();
  String? method;
  String? path;
  Map<String, dynamic>? body;
  @override
  Future<dynamic> request(String verb, String url,
      [Map<String, dynamic>? data]) async {
    method = verb;
    path = url;
    body = data;
    return <String, dynamic>{'message': 'pending'};
  }
}

void main() {
  for (final role in ['Mahasiswa', 'Dosen']) {
    testWidgets('Pendaftaran $role menunggu Admin pada 320px', (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = AccountsFakeApi();
      addTearDown(api.dispose);
      await tester
          .pumpWidget(MaterialApp(home: RegisterAccountScreen(api: api)));
      await tester.tap(find.byKey(const ValueKey('register-role')));
      await tester.pumpAndSettle();
      expect(find.text('Admin'), findsNothing);
      await tester.tap(find.text(role).last);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('register-username')), 'newuser');
      await tester.enterText(find.byKey(const ValueKey('register-password')),
          'Strong-Password-123');
      await tester.enterText(find.byKey(const ValueKey('register-confirm')),
          'Strong-Password-123');
      final send =
      find.widgetWithText(FilledButton, 'Daftar & Tunggu Persetujuan');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(api.path, '/auth/register');
      expect(api.body!['role'], role);
      expect(api.user, isNull);
      expect(
          find.text(
              'Pendaftaran berhasil. Menunggu persetujuan Admin pada perangkat ini.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Pendaftaran menolak konfirmasi password berbeda',
          (tester) async {
        final api = AccountsFakeApi();
        addTearDown(api.dispose);
        await tester.pumpWidget(MaterialApp(home: RegisterAccountScreen(api: api)));
        await tester.enterText(
            find.byKey(const ValueKey('register-username')), 'newuser');
        await tester.enterText(
            find.byKey(const ValueKey('register-password')), 'Strong-Password-123');
        await tester.enterText(
            find.byKey(const ValueKey('register-confirm')), 'different');
        final send =
        find.widgetWithText(FilledButton, 'Daftar & Tunggu Persetujuan');
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pump();
        expect(find.text('Konfirmasi password tidak sama.'), findsOneWidget);
        expect(api.path, isNull);
      });
  testWidgets('Delete perlu password dan konfirmasi username', (tester) async {
    final api = AccountsFakeApi();
    api.user = {'username': 'student1', 'role': 'Mahasiswa', 'id': 2};
    addTearDown(api.dispose);
    bool? deleted;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      deleted = await confirmDeleteAccount(context, api);
                    },
                    child: const Text('Hapus'))))));
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus Permanen'));
    await tester.pump();
    expect(api.path, isNull);
    expect(
        find.text(
            'Masukkan password Anda dan ketik username akun yang akan dihapus.'),
        findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('delete-password')), 'Strong-Password-123');
    await tester.enterText(
        find.byKey(const ValueKey('delete-confirm')), 'student1');
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus Permanen'));
    await tester.pumpAndSettle();
    expect(api.method, 'DELETE');
    expect(api.path, '/auth/account');
    expect(api.body!['confirm_username'], 'student1');
    expect(deleted, isTrue);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulia_smart_campus/services/campus_auth_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'Strong-Password-123';
  late CampusAuthApi api;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = CampusAuthApi();
    await api.initialize();
  });
  tearDown(() => api.dispose());

  test('Admin setup sekali, hash tersimpan, login dan persist tanpa URL',
          () async {
        expect(api.hasAdmin, isFalse);
        await api.bootstrapAdmin('admin1', password);
        expect(api.hasAdmin, isTrue);
        await expectLater(api.bootstrapAdmin('other', password), throwsException);
        await expectLater(api.login('admin1', 'wrong'), throwsException);
        await api.login('admin1', password);
        expect(api.user!['role'], 'admin');
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(CampusAuthApi.storageKey)!;
        expect(raw.contains(password), isFalse);
        expect((jsonDecode(raw)['users'] as List).first['salt'], isNotEmpty);
        await api.logout();
        expect(api.user, isNull);
        final restored = CampusAuthApi();
        await restored.initialize();
        expect(restored.hasAdmin, isTrue);
        await restored.login('admin1', password);
        expect(restored.user!['username'], 'admin1');
        restored.dispose();
      });
  test('Approval kedua role, izin materi, delete anonim dan Admin dilindungi',
          () async {
        await api.bootstrapAdmin('admin1', password);
        for (final role in ['Mahasiswa', 'Dosen']) {
          await api.request('POST', '/auth/register',
              {'username': role.toLowerCase(), 'password': password, 'role': role});
          await expectLater(
              api.login(role.toLowerCase(), password), throwsException);
        }
        await expectLater(
            api.request('POST', '/auth/register',
                {'username': 'evil', 'password': password, 'role': 'admin'}),
            throwsException);
        await api.login('admin1', password);
        final accounts = await api.request('GET', '/users') as List;
        for (final row in accounts.where((u) => u['role'] != 'admin')) {
          expect(row['approved'], 0);
          await api.request('PATCH', '/users/${row['id']}', {'active': true});
        }
        await api.logout();
        await api.login('mahasiswa', password);
        await expectLater(api.request('GET', '/users'), throwsException);
        await expectLater(
            api.request('POST', '/materials',
                {'course_code': '110100', 'title': 'Test', 'content': 'Isi'}),
            throwsException);
        await api.logout();
        await api.login('dosen', password);
        await api.request('POST', '/materials', {
          'course_code': '110100',
          'title': 'Tetap ada',
          'content': 'Materi lokal'
        });
        await expectLater(
            api.request('DELETE', '/auth/account',
                {'password': 'wrong', 'confirm_username': 'dosen'}),
            throwsException);
        await api.request('DELETE', '/auth/account',
            {'password': password, 'confirm_username': 'dosen'});
        expect(api.user, isNull);
        await expectLater(api.login('dosen', password), throwsException);
        await api.login('admin1', password);
        final materials = await api.request('GET', '/materials') as List;
        expect(materials.single['owner'], 'Akun dihapus');
        expect(materials.single['owner_id'], isNull);
        await expectLater(
            api.request('DELETE', '/auth/account',
                {'password': password, 'confirm_username': 'admin1'}),
            throwsException);
      });
  test(
      'Admin dapat delete pendaftar; password wajib dan Admin tidak dapat dihapus',
          () async {
        await api.bootstrapAdmin('admin1', password);
        await api.request('POST', '/auth/register',
            {'username': 'pending1', 'password': password, 'role': 'Mahasiswa'});
        await api.login('admin1', password);
        final accounts = await api.request('GET', '/users') as List;
        final uid = accounts.firstWhere((u) => u['username'] == 'pending1')['id'];
        await expectLater(
            api.request('DELETE', '/users/$uid',
                {'password': 'wrong', 'confirm_username': 'pending1'}),
            throwsException);
        await api.request('DELETE', '/users/$uid',
            {'password': password, 'confirm_username': 'pending1'});
        expect((await api.request('GET', '/users') as List).length, 1);
        await expectLater(
            api.request('PATCH', '/users/1', {'active': false}), throwsException);
        await expectLater(
            api.request('DELETE', '/users/1',
                {'password': password, 'confirm_username': 'admin1'}),
            throwsException);
      });
  test('Data rusak tidak ditimpa menjadi kosong', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CampusAuthApi.storageKey, 'bad-json');
    final broken = CampusAuthApi();
    await expectLater(broken.initialize(), throwsException);
    expect(prefs.getString(CampusAuthApi.storageKey), 'bad-json');
    broken.dispose();
  });
}

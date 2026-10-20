import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulia_smart_campus/services/github_search_service.dart';
import 'package:mulia_smart_campus/services/storage_service.dart';
import 'package:mulia_smart_campus/screens/repository_screen.dart';

http.Response reply(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code,
        headers: {'content-type': 'application/json; charset=utf-8'});
Map<String, dynamic> user() => {
  'login': 'contoh',
  'name': 'Nama pengguna panjang untuk pengujian tata letak',
  'bio': 'Belajar Flutter dan pemrograman',
  'public_repos': 31,
  'type': 'User'
};
Map<String, dynamic> repo(int n, {String owner = 'contoh'}) => {
  'name': 'smart_campus_repository_nama_panjang_$n',
  'owner': {'login': owner},
  'description':
  'Deskripsi panjang untuk memeriksa tampilan pada layar ponsel sempit.',
  'language': 'Dart',
  'stargazers_count': 7,
  'fork': n == 0
};

void main() {
  test('Validasi username dan @, cegah URL/qualifier', () {
    expect(GithubSearchService.normalizeUsername(' @Contoh-1 '), 'Contoh-1');
    for (final s in [
      '',
      'a b',
      '-a',
      'a-',
      'a--b',
      'https://github.com/a',
      'a:foo',
      'a/b'
    ]) {
      expect(() => GithubSearchService.normalizeUsername(s),
          throwsA(isA<GithubSearchError>()));
    }
  });
  test('Profil nyata dari respons API dipetakan, bukan akun contoh statis',
          () async {
        final service = GithubSearchService(client: MockClient((r) async {
          expect(r.url.host, 'api.github.com');
          expect(r.url.path, '/users/contoh');
          return reply(user());
        }));
        addTearDown(service.dispose);
        final u = await service.account('contoh');
        expect(u.login, 'contoh');
        expect(u.publicRepos, 31);
        expect(u.url, 'https://github.com/contoh');
      });
  test('Daftar owner, pagination dan saring owner lain', () async {
    final service = GithubSearchService(client: MockClient((r) async {
      expect(r.url.path, '/users/contoh/repos');
      expect(r.url.queryParameters['page'], '2');
      return reply(List.generate(
          30, (i) => repo(i, owner: i == 0 ? 'orang-lain' : 'contoh')));
    }));
    addTearDown(service.dispose);
    final result = await service.repositories('contoh', page: 2);
    expect(result.items.length, 29);
    expect(result.hasMore, true);
    expect(result.items.every((e) => e.owner == 'contoh'), true);
  });
  test('Kata kunci memakai API search dibatasi owner dan bukan URL bebas',
          () async {
        final service = GithubSearchService(client: MockClient((r) async {
          expect(r.url.path, '/search/repositories');
          expect(r.url.queryParameters['q'],
              'user:contoh "flutter" in:name,description fork:true');
          return reply({
            'items': [repo(1)],
            'total_count': 1,
            'incomplete_results': false
          });
        }));
        addTearDown(service.dispose);
        final result = await service.repositories('contoh', keyword: 'flutter');
        expect(result.items.single.language, 'Dart');
        expect(result.hasMore, false);
      });
  test('Daftar kosong ditangani', () async {
    final service =
    GithubSearchService(client: MockClient((_) async => reply([])));
    addTearDown(service.dispose);
    final r = await service.repositories('contoh');
    expect(r.items, isEmpty);
    expect(r.hasMore, false);
  });
  for (final code in [404, 403, 429, 500]) {
    test('HTTP $code dilaporkan jelas', () async {
      final service = GithubSearchService(
          client: MockClient((_) async => reply({'message': 'error'}, code)));
      addTearDown(service.dispose);
      await expectLater(
          service.account('contoh'), throwsA(isA<GithubSearchError>()));
    });
  }
  test('Timeout tidak crash', () async {
    final service = GithubSearchService(
        client: MockClient((_) async => throw TimeoutException('timeout')));
    addTearDown(service.dispose);
    await expectLater(
        service.account('contoh'), throwsA(isA<GithubSearchError>()));
  });
  test('Format respons rusak', () async {
    final service = GithubSearchService(
        client: MockClient((_) async => http.Response('invalid', 200)));
    addTearDown(service.dispose);
    await expectLater(
        service.account('contoh'), throwsA(isA<GithubSearchError>()));
  });
  for (final double width in [320.0, 360.0]) {
    testWidgets('Pencarian profil dan repository tanpa overflow $width px',
            (tester) async {
          tester.view.physicalSize = Size(width, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final storage = await StorageService.buka();
          final service = GithubSearchService(
              client: MockClient((r) async =>
                  reply(r.url.path.endsWith('/repos') ? [repo(1)] : user())));
          await tester.pumpWidget(MaterialApp(
              home: Scaffold(
                  body: RepositoryScreen(storage: storage, service: service))));
          await tester.enterText(
              find.byKey(const ValueKey('github-username')), 'contoh');
          await tester.tap(find.byKey(const ValueKey('github-search')));
          await tester.pumpAndSettle();
          expect(find.text('Akun ditemukan'), findsOneWidget);
          expect(find.text('contoh/smart_campus_repository_nama_panjang_1'),
              findsOneWidget);
          expect(find.text('Repositori per Mata Kuliah'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.drag(find.byType(ListView), const Offset(0, -1400));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
  }
  testWidgets('Username salah ditampilkan sebagai pesan, bukan akun palsu',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final storage = await StorageService.buka();
        final service =
        GithubSearchService(client: MockClient((_) async => reply({}, 404)));
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: RepositoryScreen(storage: storage, service: service))));
        await tester.enterText(
            find.byKey(const ValueKey('github-username')), 'tidakada');
        await tester.tap(find.byKey(const ValueKey('github-search')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Akun atau repositori tidak ditemukan.'),
            findsOneWidget);
        expect(find.text('Akun ditemukan'), findsNothing);
        expect(tester.takeException(), isNull);
      });
  test(
      'Panduan push dan upgrade tersedia, tidak menggunakan akun hasil pencarian',
          () {
        expect(githubFirstPushGuide, contains('USERNAME_ANDA/NAMA_REPO.git'));
        expect(githubUpdateGuide, contains('git merge origin/main'));
        expect(githubUpdateGuide, contains('git pull --ff-only origin main'));
        expect(githubUpdateGuide, contains('flutter build apk --release'));
      });
}

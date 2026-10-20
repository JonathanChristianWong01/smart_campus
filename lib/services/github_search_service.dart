import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GithubSearchError implements Exception {
  const GithubSearchError(this.message);
  final String message;
  @override
  String toString() => message;
}

class GithubAccount {
  const GithubAccount(
      {required this.login,
        required this.name,
        required this.bio,
        required this.publicRepos,
        required this.type});
  final String login, name, bio, type;
  final int publicRepos;
  String get url => 'https://github.com/${Uri.encodeComponent(login)}';
  factory GithubAccount.fromJson(Map<String, dynamic> j) => GithubAccount(
    login: j['login'] as String,
    name: j['name'] as String? ?? '',
    bio: j['bio'] as String? ?? '',
    publicRepos: (j['public_repos'] as num?)?.toInt() ?? 0,
    type: j['type'] as String? ?? 'User',
  );
}

class GithubRepository {
  const GithubRepository(
      {required this.name,
        required this.owner,
        required this.description,
        required this.language,
        required this.stars,
        required this.fork});
  final String name, owner, description, language;
  final int stars;
  final bool fork;
  String get fullName => '$owner/$name';
  String get url =>
      'https://github.com/${Uri.encodeComponent(owner)}/${Uri.encodeComponent(name)}';
  factory GithubRepository.fromJson(Map<String, dynamic> j) => GithubRepository(
    name: j['name'] as String,
    owner: (j['owner'] as Map<String, dynamic>)['login'] as String,
    description: j['description'] as String? ?? '',
    language: j['language'] as String? ?? '-',
    stars: (j['stargazers_count'] as num?)?.toInt() ?? 0,
    fork: j['fork'] == true,
  );
}

class GithubRepositoryPage {
  const GithubRepositoryPage(this.items, this.hasMore,
      {this.incomplete = false});
  final List<GithubRepository> items;
  final bool hasMore, incomplete;
}

/// Hanya akses baca API publik GitHub. Tidak ada token/login maupun Git push.
class GithubSearchService {
  GithubSearchService(
      {http.Client? client, this.timeout = const Duration(seconds: 20)})
      : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;

  static String normalizeUsername(String input) {
    String s = input.trim();
    if (s.startsWith('@')) s = s.substring(1);
    // Username tidak boleh mengandung spasi, shell, URL, atau qualifier pencarian.
    if (!RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$')
        .hasMatch(s) ||
        s.contains('--')) {
      throw const GithubSearchError(
          'Username tidak valid. Isi username saja (tanpa https://github.com/), misalnya JonathanChristianWong01.');
    }
    return s;
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    try {
      final r =
      await _client.get(Uri.https('api.github.com', path, query), headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      }).timeout(timeout);
      if (r.statusCode == 404) {
        throw const GithubSearchError(
            'Akun atau repositori tidak ditemukan. Periksa ejaan username.');
      }
      if (r.statusCode == 403 || r.statusCode == 429) {
        throw const GithubSearchError(
            'Akses API GitHub dibatasi atau kuota sementara habis. Tunggu beberapa saat lalu coba lagi. Tidak perlu memasukkan token.');
      }
      if (r.statusCode != 200) {
        throw GithubSearchError(
            'GitHub merespons HTTP ${r.statusCode}. Coba lagi nanti.');
      }
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on GithubSearchError {
      rethrow;
    } on TimeoutException {
      throw const GithubSearchError(
          'Koneksi GitHub timeout. Periksa internet lalu coba lagi.');
    } on FormatException {
      throw const GithubSearchError(
          'Format respons GitHub tidak dapat dibaca. Coba lagi nanti.');
    } catch (_) {
      throw const GithubSearchError(
          'Tidak dapat menghubungi GitHub. Periksa koneksi internet.');
    }
  }

  Future<GithubAccount> account(String username) async {
    final u = normalizeUsername(username);
    final j = await _get('/users/$u');
    if (j is! Map<String, dynamic> || j['login'] is! String) {
      throw const GithubSearchError('Data akun GitHub tidak lengkap.');
    }
    return GithubAccount.fromJson(j);
  }

  Future<GithubRepositoryPage> repositories(String username,
      {String keyword = '', int page = 1}) async {
    final u = normalizeUsername(username);
    if (page < 1) {
      throw const GithubSearchError(
          'Halaman di luar batas pencarian. Persempit kata kunci.');
    }
    final q = keyword.trim();
    if (q.length > 100) {
      throw const GithubSearchError('Kata kunci maksimal 100 karakter.');
    }
    final dynamic data;
    final List<dynamic> raw;
    bool incomplete = false;
    bool more;
    if (q.isEmpty) {
      data = await _get('/users/$u/repos', {
        'type': 'owner',
        'sort': 'updated',
        'per_page': '30',
        'page': '$page'
      });
      if (data is! List) {
        throw const GithubSearchError('Daftar repositori GitHub tidak valid.');
      }
      raw = data;
      more = raw.length == 30;
    } else {
      // Hapus operator/quote: pencarian tetap dibatasi pada pemilik ini.
      final safe = q
          .replaceAll(RegExp(r'[^\p{L}\p{N}\s_.-]', unicode: true), ' ')
          .trim();
      if (safe.isEmpty) {
        throw const GithubSearchError(
            'Masukkan kata kunci berupa huruf atau angka.');
      }
      data = await _get('/search/repositories', {
        'q': 'user:$u "$safe" in:name,description fork:true',
        'sort': 'updated',
        'per_page': '30',
        'page': '$page',
      });
      if (data is! Map<String, dynamic> || data['items'] is! List) {
        throw const GithubSearchError('Hasil pencarian GitHub tidak valid.');
      }
      raw = data['items'] as List;
      incomplete = data['incomplete_results'] == true;
      final total = (data['total_count'] as num?)?.toInt() ?? raw.length;
      more = page * 30 < total.clamp(0, 1000) && raw.isNotEmpty;
    }
    final repos = <GithubRepository>[];
    for (final j in raw) {
      if (j is! Map<String, dynamic> ||
          j['name'] is! String ||
          j['owner'] is! Map ||
          (j['owner'] as Map)['login'] is! String) {
        continue;
      }
      final repo = GithubRepository.fromJson(j);
      if (repo.owner.toLowerCase() == u.toLowerCase()) repos.add(repo);
    }
    return GithubRepositoryPage(repos, more, incomplete: incomplete);
  }

  void dispose() => _client.close();
}

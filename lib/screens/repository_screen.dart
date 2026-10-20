import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/github_search_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Pencarian baca-saja akun dan repositori publik GitHub, bukan klien Git push.
class RepositoryScreen extends StatefulWidget {
  const RepositoryScreen({super.key, required this.storage, this.service});
  // Tetap kompatibel dengan HomeShell; data link MK lama tidak dihapus.
  final StorageService storage;
  final GithubSearchService? service;
  @override
  State<RepositoryScreen> createState() => _RepositoryScreenState();
}

class _RepositoryScreenState extends State<RepositoryScreen> {
  final _username = TextEditingController();
  final _keyword = TextEditingController();
  late final GithubSearchService _service;
  GithubAccount? _account;
  final List<GithubRepository> _repos = [];
  String? _error;
  String _activeKeyword = '';
  bool _loading = false,
      _hasMore = false,
      _searched = false,
      _incomplete = false;
  int _page = 1;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? GithubSearchService();
  }

  @override
  void dispose() {
    _username.dispose();
    _keyword.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _search({bool next = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (!next) {
        _account = null;
        _repos.clear();
        _hasMore = false;
        _searched = false;
        _incomplete = false;
      }
    });
    try {
      final GithubAccount user;
      if (next) {
        if (_account == null) return;
        user = _account!;
      } else {
        GithubSearchService.normalizeUsername(_username.text);
        if (_keyword.text.trim().length > 100) {
          throw const GithubSearchError('Kata kunci maksimal 100 karakter.');
        }
        user = await _service.account(_username.text);
      }
      final query = next ? _activeKeyword : _keyword.text.trim();
      final page = next ? _page + 1 : 1;
      if (mounted && !next) setState(() => _account = user);
      final result =
      await _service.repositories(user.login, keyword: query, page: page);
      if (!mounted) return;
      setState(() {
        _account = user;
        _page = page;
        _activeKeyword = query;
        final names = _repos.map((e) => e.fullName).toSet();
        _repos.addAll(result.items.where((e) => names.add(e.fullName)));
        _hasMore = result.hasMore;
        _incomplete = result.incomplete;
        _searched = true;
      });
    } on GithubSearchError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
        _error = 'Pencarian gagal. Coba lagi setelah memeriksa internet.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _open(String url) async {
    try {
      if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {/* pesan di bawah */}
    _message(
        'Browser tidak dapat dibuka. Salin tautan dan buka secara manual.');
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _message('Disalin ke clipboard');
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ListView(
      key: const ValueKey<String>('repository-list'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(14)),
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Cari Repositori GitHub',
                    style: TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text(
                    'Periksa akun GitHub lalu cari repositori publik miliknya langsung di aplikasi.',
                    style: TextStyle(color: Colors.white, height: 1.5)),
              ]),
        ),
        const JudulBagian('Cari akun & repositori', ikon: Icons.search),
        TextField(
          key: const ValueKey<String>('github-username'),
          controller: _username,
          enabled: !_loading,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
              labelText: 'Username GitHub',
              hintText: 'JonathanChristianWong01',
              prefixIcon: Icon(Icons.alternate_email)),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey<String>('github-keyword'),
          controller: _keyword,
          enabled: !_loading,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
              labelText: 'Kata kunci repositori (opsional)',
              hintText: 'smart_campus, flutter, python…',
              prefixIcon: Icon(Icons.folder_outlined)),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey<String>('github-search'),
          onPressed: _loading ? null : () => _search(),
          icon: _loading
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          label: Text(_loading ? 'Mencari…' : 'Cari di GitHub'),
        ),
        const SizedBox(height: 8),
        const Text(
            'Username diperiksa saat tombol Cari ditekan, bukan login akun. Kosongkan kata kunci untuk melihat repositori publik milik akun tersebut. Akun organisasi juga dapat dicari.'),
        const SizedBox(height: 8),
        const KotakCatatan(
            Text(
                'Butuh internet. API publik tanpa token memiliki batas permintaan. Hanya repositori publik yang ditampilkan; tidak ada akses akun atau repositori privat.'),
            ikon: Icons.info_outline),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          KotakCatatan(
              Text(_error!, key: const ValueKey<String>('github-error')),
              ikon: Icons.error_outline),
        ],
        if (_account != null) ...<Widget>[
          const JudulBagian('Akun ditemukan',
              ikon: Icons.verified_user_outlined),
          KartuPutih(
              aksen: AppColors.gold,
              anak: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                        _account!.name.isEmpty
                            ? _account!.login
                            : _account!.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('@${_account!.login} • ${_account!.type}'),
                    Text('${_account!.publicRepos} repositori publik'),
                    if (_account!.bio.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_account!.bio)),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                        onPressed: () => _open(_account!.url),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Buka profil')),
                  ])),
        ],
        if (_searched) ...<Widget>[
          const JudulBagian('Hasil repositori',
              ikon: Icons.folder_copy_outlined),
          Text(
              'Pemilik: @${_account!.login}${_activeKeyword.isEmpty ? '' : ' • kata kunci: $_activeKeyword'}'),
          Text(
              '${_repos.length} repositori dimuat. Maksimal 30 per halaman.'),
          if (_incomplete)
            const Text(
                'GitHub menandai hasil belum lengkap. Persempit kata kunci atau coba lagi.'),
          if (_repos.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                    'Tidak ada repositori publik yang cocok. Coba kata kunci lain atau kosongkan kata kunci.')),
          for (final repo in _repos)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: KartuPutih(
                  anak: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(repo.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy800,
                                fontSize: 15)),
                        if (repo.description.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(repo.description)),
                        Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                          LabelChip(repo.language, maksLebar: 160),
                          LabelChip.emas('★ ${repo.stars}'),
                          if (repo.fork) const LabelChip('Fork'),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                          FilledButton.icon(
                              onPressed: () => _open(repo.url),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Buka repo')),
                          OutlinedButton.icon(
                              onPressed: () => _copy(repo.url),
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Salin tautan')),
                        ]),
                      ])),
            ),
          if (_hasMore)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  key: const ValueKey<String>('github-more'),
                  onPressed: _loading ? null : () => _search(next: true),
                  child: const Text('Muat lebih banyak'),
                )),
          const SizedBox(height: 8),
          const Text(
              'Pencarian kata kunci mengikuti indeks GitHub dan dibatasi 1.000 hasil. Ini bukan pencarian isi kode. Perubahan repository terbaru mungkin belum terindeks.'),
        ],
        const JudulBagian('Tutorial push & pembaruan',
            ikon: Icons.terminal),
        const KotakCatatan(Text(
            'Tutorial dijalankan di terminal laptop, bukan di kompiler aplikasi. Gunakan akun/repository milik sendiri atau yang memberi izin. Akun yang dicari di atas TIDAK otomatis menjadi tujuan push. Ganti semua placeholder sebelum menjalankan.')),
        const SizedBox(height: 10),
        _GitGuide(
            title: '1. Push proyek pertama kali',
            text: githubFirstPushGuide,
            onCopy: () => _copy(githubFirstPushGuide)),
        const SizedBox(height: 12),
        _GitGuide(
            title: '2. Upgrade / kirim pembaruan repository',
            text: githubUpdateGuide,
            onCopy: () => _copy(githubUpdateGuide)),
        const SizedBox(height: 12),
        const Text(
            'Aplikasi hanya mencari/membuka repositori publik dan menyediakan panduan. Tidak mengunggah kode atau mengubah repository secara otomatis. Tautan MK yang pernah disimpan tetap ada di penyimpanan, tetapi daftar per-MK tidak ditampilkan lagi di menu ini.'),
      ],
    ),
  );
}

class _GitGuide extends StatelessWidget {
  const _GitGuide(
      {required this.title, required this.text, required this.onCopy});
  final String title, text;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: AppColors.navy900, borderRadius: BorderRadius.circular(12)),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: const TextStyle(
                  color: AppColors.gold, fontWeight: FontWeight.w800)),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy,
                      color: AppColors.gold, size: 18),
                  label: const Text('Salin panduan',
                      style: TextStyle(color: AppColors.gold)))),
          SelectableText(text,
              style: const TextStyle(
                  color: Color(0xFF8EF2C4),
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5)),
        ]),
  );
}

const String githubFirstPushGuide = '''PERSIAPAN
1. Pasang Git, Flutter dan login GitHub melalui browser.
2. Buat repository kosong milik sendiri, tanpa README awal.
3. Atur user.name dan user.email Git. Pakai alamat noreply dari Settings > Emails bila ingin email pribadi tetap privat.
4. Pastikan .gitignore mengecualikan build/, .dart_tool/, cadangan_*/, *.bak, .env, android/local.properties, android/key.properties, *.jks, dan *.keystore. Jangan mengunggah token/password.
5. Ganti USERNAME_ANDA dan NAMA_REPO dengan data milik Anda. Contoh folder proyek: D:\\smart_campus.

POWERSHELL — folder proyek
Set-Location "D:\\smart_campus"
git status
# Hanya jika belum ada repository Git:
git init
# Cek identitas sebelum commit:
git config user.name
git config user.email
flutter analyze
flutter test
git add .
git diff --cached --stat
# Periksa isi berkas sebelum lanjut:
git commit -m "Initial commit aplikasi"
git branch -M main
git remote -v
# Hanya jika origin belum ada:
git remote add origin https://github.com/USERNAME_ANDA/NAMA_REPO.git
git push -u origin main

Jika origin sudah ada, jangan add lagi. Periksa URL-nya; ubah hanya bila memang salah dengan git remote set-url origin URL_YANG_BENAR. Login melalui browser jika diminta. Jangan membagikan token/password. Jangan gunakan --force.''';

const String githubUpdateGuide = '''PEMBARUAN SOURCE CODE
1. Jalankan dari proyek yang sudah terhubung ke repository.
2. Periksa git status; jangan menimpa pekerjaan orang lain.
3. Ganti nama-fitur dengan nama branch baru yang belum digunakan.

Set-Location "D:\\smart_campus"
git status
git switch -c pembaruan/nama-fitur
flutter analyze
flutter test
git add .
git diff --cached --stat
git commit -m "Perbarui aplikasi"
git fetch origin
git merge origin/main
# Jika konflik, BERHENTI dan selesaikan; jangan --force.
flutter analyze
flutter test
git push -u origin pembaruan/nama-fitur

DI GITHUB
Buka Compare & pull request. Base: main; compare: pembaruan/nama-fitur. Periksa Files changed, buat PR, lalu merge setelah pemeriksaan berhasil.

SETELAH MERGE
git switch main
git pull --ff-only origin main

APK BARU
flutter build apk --release
Hasil: build/app/outputs/flutter-apk/app-release.apk
Unggah APK lewat Releases, bukan git add folder build.
Push source tidak memperbarui APK yang sudah terpasang di HP. Pasang APK baru. Branch utama mungkin bukan main; sesuaikan nama bila berbeda. Jika muncul error, berhenti dahulu.''';

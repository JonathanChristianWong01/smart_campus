import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/compiler_data.dart';
import '../data/praktikum_data.dart';
import '../data/curriculum_data.dart';
import '../models/mata_kuliah.dart';
import '../services/repo_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/asset_webview.dart';
import '../widgets/common.dart';
import 'compiler_screen.dart';

/// Detail mata kuliah: deskripsi, CPL/CPMK, materi, praktikum kompiler,
/// tautan belajar Dicoding, dan repositori GitHub.
class DetailMataKuliahScreen extends StatelessWidget {
  const DetailMataKuliahScreen({
    super.key,
    required this.mk,
    required this.storage,
  });

  final MataKuliah mk;
  final StorageService storage;

  Future<void> _bukaDicoding(BuildContext context) async {
    bool terbuka = false;
    try {
      terbuka = await launchUrl(
        Uri.parse('https://www.dicoding.com/'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      terbuka = false;
    }
    if (!terbuka && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Browser tidak dapat dibuka. Kunjungi https://www.dicoding.com/ secara manual.',
        )),
      );
    }
  }

  String _labelBahasa(String id) {
    switch (id) {
      case 'cplusplus':
        return 'C++';
      case 'javascript':
        return 'JavaScript';
      case 'php':
        return 'PHP';
      default:
        return 'Python';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String repoAnda = storage.linkRepoUntuk(mk.kode);

    return Scaffold(
      appBar: AppBar(title: Text('${mk.kode} • ${mk.sks} SKS')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  mk.nama,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Semester ${mk.semester} • Program Studi $kProgramStudi • Kurikulum $kKurikulumTahun',
                  style:
                  const TextStyle(color: Color(0xFFA9C0DD), fontSize: 12),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (BuildContext c, BoxConstraints kendala) => Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      LabelChip(mk.kode,
                          latar: AppColors.navy800,
                          teksWarna: AppColors.gold,
                          garis: AppColors.navy600),
                      LabelChip(
                        mk.prasyarat.isEmpty
                            ? 'Tanpa prasyarat'
                            : 'Prasyarat: ${mk.prasyarat}',
                        latar: AppColors.navy800,
                        teksWarna: AppColors.white,
                        garis: AppColors.navy600,
                        maksLebar:
                        (kendala.maxWidth * 0.78).clamp(120.0, 340.0),
                        maksBaris: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const JudulBagian('Deskripsi Mata Kuliah',
                    ikon: Icons.description_outlined),
                Text(
                  mk.deskripsi,
                  style: const TextStyle(
                      fontSize: 12.8, height: 1.55, color: AppColors.ink),
                ),
                if (mk.keterangan.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  KotakCatatan(Text('Syarat khusus: ${mk.keterangan}'),
                      ikon: Icons.rule),
                ],
                const JudulBagian('Identitas Mata Kuliah',
                    ikon: Icons.badge_outlined),
                TabelIdentitas(<List<String>>[
                  <String>['Kode MK', mk.kode],
                  <String>['Nama MK', mk.nama],
                  <String>['Bobot', '${mk.sks} SKS'],
                  <String>['Semester', '${mk.semester}'],
                  <String>[
                    'Prasyarat',
                    mk.prasyarat.isEmpty ? '—' : mk.prasyarat
                  ],
                  <String>[
                    'Perangkat',
                    mk.perangkat.isEmpty ? '—' : mk.perangkat
                  ],
                  <String>['Repo saran', RepoService.namaRepo(mk)],
                ]),
                const JudulBagian('Capaian Pembelajaran Lulusan (CPL)',
                    ikon: Icons.workspace_premium_outlined),
                _DaftarPoin(mk.cpl),
                const JudulBagian('Capaian Pembelajaran Mata Kuliah',
                    ikon: Icons.flag_outlined),
                _DaftarPoin(mk.cpmk),
                const JudulBagian('Materi / Pokok Bahasan',
                    ikon: Icons.list_alt),
                _DaftarPoin(mk.materi, bernomor: true),
                // Praktikum hanya muncul untuk mata kuliah yang memang
                // memakai pemrograman (lihat lib/data/praktikum_data.dart).
                if (bahasaMk(mk.kode).isNotEmpty) ...<Widget>[
                  const JudulBagian('Praktikum di Kompiler Daring',
                      ikon: Icons.terminal),
                  const Text(
                    'Latih materi ini pada kompiler daring Smart Campus. Bahasa yang direkomendasikan untuk mata kuliah ini:',
                    style: TextStyle(
                        fontSize: 12.4, color: AppColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String b in bahasaMk(mk.kode))
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                  title: Text('Praktik ${_labelBahasa(b)}'),
                                ),
                                body: CompilerScreen(
                                  storage: storage,
                                  bahasaAwal: bahasaById(b),
                                  konteksMk: mk,
                                ),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          label: Text('Praktik ${_labelBahasa(b)}'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Video sumber belajar:',
                    style: TextStyle(
                        fontSize: 12.4,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy700),
                  ),
                  const SizedBox(height: 8),
                  _DaftarVideo(bahasa: bahasaMk(mk.kode)),
                ],
                const JudulBagian('Belajar di Dicoding',
                    ikon: Icons.school_outlined),
                const Text(
                  'Akses kelas dan jalur belajar di situs resmi Dicoding. '
                      'Tautan ini membuka browser; tidak menghubungkan akun '
                      'atau menerbitkan sertifikat dari aplikasi.',
                  style: TextStyle(
                      fontSize: 12.4, color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      key: const ValueKey<String>('detail-buka-dicoding'),
                      onPressed: () => _bukaDicoding(context),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Buka Dicoding'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const HalamanWeb(
                            aset: 'assets/web/compiler.html',
                            judul: 'Kompiler Daring',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.code, size: 18),
                      label: const Text('Web Kompiler'),
                    ),
                  ],
                ),
                const JudulBagian('Repositori GitHub',
                    ikon: Icons.hub_outlined),
                KotakCatatan(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                          'Nama repo yang disarankan: ${RepoService.namaRepo(mk)}'),
                      const SizedBox(height: 6),
                      Text(
                        repoAnda.isEmpty
                            ? 'Link repo Anda: belum disimpan.'
                            : 'Link repo Anda: $repoAnda',
                      ),
                    ],
                  ),
                  ikon: Icons.folder_outlined,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(RepoService.urlCari(mk)),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Cari di GitHub'),
                    ),
                    FilledButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(RepoService.urlBuatBaru(mk)),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Buat Repo Baru'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                              text:
                              RepoService.perintahGit(mk, 'username-anda')),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                              Text('Perintah Git disalin ke papan klip'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Salin Perintah Git'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.navy900,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    RepoService.perintahGit(mk, 'username-anda'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.4,
                      color: Color(0xFF8EF2C4),
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _StrukturFolder(mk: mk),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaftarPoin extends StatelessWidget {
  const _DaftarPoin(this.poin, {this.bernomor = false});

  final List<String> poin;
  final bool bernomor;

  @override
  Widget build(BuildContext context) {
    if (poin.isEmpty) {
      return const Text('—', style: TextStyle(color: AppColors.muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < poin.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 24,
                  child: Text(
                    bernomor ? '${i + 1}.' : '•',
                    style: const TextStyle(
                      color: AppColors.navy600,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.6,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    poin[i],
                    style: const TextStyle(fontSize: 12.6, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StrukturFolder extends StatelessWidget {
  const _StrukturFolder({required this.mk});

  final MataKuliah mk;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC8D8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Struktur folder tugas yang disarankan',
            style: TextStyle(
              fontSize: 12.4,
              fontWeight: FontWeight.w800,
              color: AppColors.navy700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            RepoService.strukturFolder(mk).join('\n'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.4,
              color: AppColors.navy800,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Deretan tautan video & dokumentasi untuk bahasa yang dipakai mata kuliah.
class _DaftarVideo extends StatelessWidget {
  const _DaftarVideo({required this.bahasa});

  final List<String> bahasa;

  @override
  Widget build(BuildContext context) {
    final List<SumberVideo> semua = <SumberVideo>[
      for (final String b in bahasa) ...videoUntuk(b),
    ];
    return Column(
      children: <Widget>[
        for (final SumberVideo v in semua)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: KartuPutih(
              onTap: () => launchUrl(
                Uri.parse(v.url),
                mode: LaunchMode.externalApplication,
              ),
              anak: Row(
                children: <Widget>[
                  Icon(
                    v.jenis == 'Video'
                        ? Icons.play_circle_fill
                        : v.jenis == 'Pencarian'
                        ? Icons.search
                        : Icons.menu_book,
                    color: AppColors.navy700,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          v.judul,
                          style: const TextStyle(
                            fontSize: 12.4,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          v.ket,
                          style: const TextStyle(
                            fontSize: 11.4,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 16),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

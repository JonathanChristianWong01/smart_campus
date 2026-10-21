import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/compiler_data.dart';
import '../data/curriculum_data.dart';
import '../models/mata_kuliah.dart';
import '../theme/app_theme.dart';
import '../widgets/asset_webview.dart';
import '../widgets/common.dart';

/// Halaman Info: rincian aplikasi, ringkasan kurikulum, teknologi,
/// dan panduan singkat penggunaan.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final int totalSks =
    kSemuaMataKuliah.fold<int>(0, (int a, MataKuliah m) => a + m.sks);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
      children: <Widget>[
        const JudulBagian('Pembuat Aplikasi', ikon: Icons.person_outline),
        const TabelIdentitas(<List<String>>[
          <String>['Nama', 'Jonathan Christian Wong'],
          <String>['NIM', '2411015'],
          <String>['Kelas', 'IFB5A'],
          <String>['Matkul', 'Teknologi Aplikasi Bergerak'],
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'M',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Smart Campus',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Versi $kAppVersi • Flutter (Dart)',
                          style: TextStyle(
                              color: Color(0xFFA9C0DD), fontSize: 11.8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Aplikasi akademik $kUniversitas yang menghimpun kurikulum $kProgramStudi '
                    '($kKurikulumTahun), tautan belajar di Dicoding, kompiler daring '
                    'C++/JavaScript/PHP/Python, serta repositori GitHub pendukung tugas dan praktikum.',
                style: TextStyle(
                    color: Color(0xFFC8D8EE), fontSize: 12.3, height: 1.6),
              ),
            ],
          ),
        ),
        const JudulBagian('Ringkasan Kurikulum', ikon: Icons.school_outlined),
        TabelIdentitas(<List<String>>[
          <String>['Universitas', kUniversitas],
          <String>['Fakultas', kFakultas],
          <String>['Program Studi', kProgramStudi],
          <String>['Kurikulum', kKurikulumTahun],
          <String>['Jumlah MK', '${kSemuaMataKuliah.length} mata kuliah'],
          <String>['Total SKS', '$totalSks SKS (hasil penjumlahan daftar MK)'],
          <String>['Semester', '${kKurikulum.length} semester'],
          <String>[
            'Belajar daring',
            'Dicoding (situs eksternal, membutuhkan internet)'
          ],
        ]),
        const SizedBox(height: 12),
        const KotakCatatan(
          Text(
            'Catatan data: dokumen kurikulum sumber menulis total 170 SKS, sedangkan penjumlahan '
                'daftar mata kuliah adalah 168 SKS (selisih 2 SKS pada Semester 6). Aplikasi menampilkan '
                'angka hasil hitung daftar agar konsisten dengan tabel mata kuliah.',
          ),
          ikon: Icons.calculate_outlined,
        ),
        const JudulBagian('Rincian SKS per Semester',
            ikon: Icons.table_chart_outlined),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: <Widget>[
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.navy800,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: const Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'SEMESTER',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 11.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        'MK',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 11.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 58,
                      child: Text(
                        'SKS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 11.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final SemesterKurikulum s in kKurikulum)
                Container(
                  decoration: BoxDecoration(
                    border:
                    const Border(bottom: BorderSide(color: AppColors.line)),
                    color: s.nomor.isEven
                        ? const Color(0xFFFAFCFF)
                        : AppColors.white,
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Semester ${s.nomor}'
                              '${s.catatan.isEmpty ? '' : ' • ${s.catatan}'}',
                          style: const TextStyle(fontSize: 12.2, height: 1.4),
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        child: Text(
                          '${s.mataKuliah.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.2,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy700,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 58,
                        child: Text(
                          '${s.totalSks}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.2,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const JudulBagian('Teknologi & Fitur', ikon: Icons.memory),
        TabelIdentitas(<List<String>>[
          <String>['Aplikasi', 'Flutter (Dart) — Android SDK 21+'],
          <String>['Web kampus', 'WebView memuat aset lokal (offline-ready)'],
          <String>[
            'Dicoding',
            'Kelas dan jalur belajar di https://www.dicoding.com/ (browser eksternal)'
          ],
          <String>[
            'Kompiler',
            'Judge0 CE (ce.judge0.com): ${kBahasaKompiler.map((BahasaKompiler b) => b.label).join(', ')}'
          ],
          <String>[
            'Preview Web',
            'HTML/CSS/JavaScript lokal; PHP/C++/Python melalui Judge0 dan preview hasil HTML'
          ],
          <String>[
            'Penyimpanan',
            'SharedPreferences (riwayat eksekusi dan preferensi/link repo)'
          ],
          <String>[
            'Repositori',
            'Pencarian akun/repo publik via GitHub API, serta tautan ke GitHub'
          ],
        ]),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey<String>('info-buka-dicoding'),
          onPressed: () => _bukaDicoding(context),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Buka Dicoding'),
        ),
        const SizedBox(height: 6),
        const Text(
          'Dicoding adalah situs eksternal yang memerlukan internet. '
              'Aplikasi ini tidak menghubungkan akun atau menerbitkan sertifikat Dicoding.',
          style: TextStyle(fontSize: 12.4, color: AppColors.muted, height: 1.5),
        ),
        const JudulBagian('Panduan Singkat', ikon: Icons.help_outline),
        const _Langkah(1,
            'Pilih menu Kurikulum, buka salah satu mata kuliah pada semester yang diinginkan.'),
        const _Langkah(2,
            'Baca deskripsi, CPL/CPMK, dan materi; lalu latih pada menu Praktik (kompiler).'),
        const _Langkah(3,
            'Tekan Buka Dicoding untuk mengakses situs belajar resmi. Tidak ada integrasi akun atau penerbitan sertifikat Dicoding di aplikasi.'),
        const _Langkah(4,
            'Buka menu Repositori untuk mencari akun dan repositori publik GitHub serta membaca panduan push dan update.'),
        const _Langkah(5,
            'Bagikan aplikasi ke teman satu prodi dan unggah proyek ke GitHub Anda.'),
        const JudulBagian('Pranala Cepat', ikon: Icons.link),
        const _Pranala(
          judul: 'Web Biro Akademik (halaman lengkap)',
          aset: 'assets/web/index.html',
        ),
        const _Pranala(
          judul: 'Daftar kurikulum 8 semester',
          aset: 'assets/web/kurikulum.html',
        ),
        const _Pranala(
          judul: 'Kompiler daring (versi web)',
          aset: 'assets/web/compiler.html',
        ),
        const _Pranala(
          judul: 'Repositori & link GitHub',
          aset: 'assets/web/repository.html',
        ),
        const SizedBox(height: 16),
        Text(
          'Smart Campus $kUniversitas — dibangun dengan Flutter. Data kurikulum mengacu pada '
              'dokumen Kurikulum $kProgramStudi Universitas Mulia (8 semester, ${kSemuaMataKuliah.length} mata kuliah).',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11.4, color: AppColors.muted, height: 1.6),
        ),
      ],
    );
  }
}

class _Langkah extends StatelessWidget {
  const _Langkah(this.nomor, this.teks);

  final int nomor;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.navy700,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$nomor',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 11.6,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(fontSize: 12.4, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pranala extends StatelessWidget {
  const _Pranala({required this.judul, required this.aset});

  final String judul;
  final String aset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KartuPutih(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HalamanWeb(aset: aset, judul: judul),
          ),
        ),
        anak: Row(
          children: <Widget>[
            const Icon(Icons.public, color: AppColors.navy700, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                judul,
                style: const TextStyle(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy800,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

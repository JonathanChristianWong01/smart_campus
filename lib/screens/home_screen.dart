import 'package:flutter/material.dart';

import '../data/curriculum_data.dart';
import '../data/praktikum_data.dart';
import '../models/mata_kuliah.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/asset_webview.dart';
import '../widgets/common.dart';
import 'matkul_detail_screen.dart';

/// Beranda Smart Campus — meniru tata letak website Biro Akademik
/// Universitas Mulia: pencarian, statistik, kartu layanan, dan info terbaru.
class HomeScreen extends StatefulWidget {
  const HomeScreen(
      {super.key, required this.storage, required this.onGantiTab});

  final StorageService storage;
  final ValueChanged<int> onGantiTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _cari = TextEditingController();
  List<MataKuliah> _hasil = <MataKuliah>[];

  static const List<List<String>> _info = <List<String>>[
    <String>[
      'Sosialisasi MSIB Batch 7: Kiat Sukses Program Merdeka Belajar Kampus Merdeka',
      'Untuk meningkatkan minat mahasiswa dalam program MBKM Kampus Merdeka, pada tanggal 31 Mei 2024 dilaksanakan sosialisasi program Magang dan Studi Independen Bersertifikat.',
    ],
    <String>[
      'Info Akademik Genap 2023/2024',
      'Dear mahasiswa Universitas Mulia, kalender Akademik Tahun 2023/2024 Genap sudah diterbitkan. Harap diperhatikan hal-hal penting terkait pengisian KRS dan jadwal ujian.',
    ],
    <String>[
      'Pemberitahuan Akademik Genap 2021/2022',
      'Terkait Kalender Akademik Tahun 2021/2022 Genap, mahasiswa diimbau memeriksa jadwal, batas pembayaran, dan tenggat pengisian KRS pada sistem akademik.',
    ],
    <String>[
      'Login Email Mahasiswa',
      'Login email students Universitas Mulia adalah fasilitas yang digunakan mahasiswa untuk mengakses layanan Google for Education, di antaranya Classroom, Drive, dan Meet.',
    ],
    <String>[
      'Panduan KRS Semester Antara',
      'Langkah awal adalah login pada website sistem informasi akademik Universitas Mulia (SIMA). Apabila login tidak berhasil, silakan menghubungi operator prodi.',
    ],
    <String>[
      'Sertifikat Kompetensi Mata Kuliah',
      'Setiap mata kuliah pada Smart Campus memiliki halaman web bertema sertifikat: baca CPL, CPMK, materi praktikum, lalu unduh sertifikat capaian dalam format PDF.',
    ],
  ];

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  void _cariMk(String q) {
    final String kata = q.trim().toLowerCase();
    if (kata.isEmpty) {
      setState(() => _hasil = <MataKuliah>[]);
      return;
    }
    setState(() {
      _hasil = kSemuaMataKuliah
          .where((MataKuliah m) =>
      m.nama.toLowerCase().contains(kata) ||
          m.kode.contains(kata) ||
          m.semester.toString() == kata ||
          (m.prasyarat.toLowerCase().contains(kata)) ||
          bahasaMk(m.kode).any((String b) => b.contains(kata)))
          .take(30)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int totalSks = kSemuaMataKuliah.fold<int>(
      0,
          (int a, MataKuliah m) => a + m.sks,
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        HeroHeader(
          judul: 'Biro Akademik\n$kUniversitas',
          subjudul:
          'Pantau informasi terbaru akademik, kurikulum $kProgramStudi, sertifikat capaian mata kuliah, '
              'kompiler daring (C++, JavaScript, PHP, Python), serta repositori GitHub dalam satu aplikasi.',
          anak: TextField(
            controller: _cari,
            onChanged: _cariMk,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Cari mata kuliah, kode MK, semester, atau bahasa…',
              filled: true,
              fillColor: AppColors.white,
              prefixIcon: const Icon(Icons.search, color: AppColors.navy700),
              suffixIcon: _cari.text.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _cari.clear();
                  _cariMk('');
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _Statistik(
                      angka: '${kSemuaMataKuliah.length}',
                      label: 'Mata Kuliah'),
                  const SizedBox(width: 10),
                  _Statistik(angka: '$totalSks', label: 'Total SKS'),
                  const SizedBox(width: 10),
                  const _Statistik(angka: '8', label: 'Semester'),
                  const SizedBox(width: 10),
                  const _Statistik(angka: '4', label: 'Bahasa Kode'),
                ],
              ),
              if (_cari.text.trim().isNotEmpty) ...<Widget>[
                const JudulBagian('Hasil Pencarian', ikon: Icons.search),
                if (_hasil.isEmpty)
                  const KotakCatatan(
                    Text('Mata kuliah tidak ditemukan. Coba kata kunci lain, '
                        'misalnya "struktur", "web", "110100", atau angka semester.'),
                  )
                else
                  for (final MataKuliah mk in _hasil) ...<Widget>[
                    _KartuMkRingkas(mk: mk, storage: widget.storage),
                    const SizedBox(height: 10),
                  ],
              ] else ...<Widget>[
                const JudulBagian('Layanan Smart Campus', ikon: Icons.apps),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Layanan(
                        ikon: Icons.menu_book,
                        judul: 'Kurikulum',
                        keterangan: '8 semester',
                        onTap: () => widget.onGantiTab(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Layanan(
                        ikon: Icons.terminal,
                        judul: 'Kompiler',
                        keterangan: 'C++, JS, PHP, Python',
                        onTap: () => widget.onGantiTab(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Layanan(
                        ikon: Icons.hub,
                        judul: 'Repositori',
                        keterangan: 'Link GitHub per MK',
                        onTap: () => widget.onGantiTab(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Layanan(
                        ikon: Icons.public,
                        judul: 'Web Akademik',
                        keterangan: 'Halaman BAAK lengkap',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext c) => const HalamanWeb(
                              aset: 'assets/web/index.html',
                              judul: 'Web Biro Akademik',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const JudulBagian('Info Terbaru', ikon: Icons.campaign),
                for (final List<String> n in _info) ...<Widget>[
                  KartuPutih(
                    aksen: AppColors.gold,
                    anak: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const LabelChip.emas('Info Terbaru'),
                        const SizedBox(height: 8),
                        Text(
                          n[0],
                          style: const TextStyle(
                            fontSize: 13.6,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy800,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          n[1],
                          style: const TextStyle(
                            fontSize: 12.3,
                            color: AppColors.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const JudulBagian('Mata Kuliah Unggulan', ikon: Icons.star),
                const Text(
                  'Mata kuliah inti yang dilengkapi halaman sertifikat, praktikum kompiler, dan repositori GitHub.',
                  style: TextStyle(fontSize: 12.3, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                for (final MataKuliah mk in kMataKuliahUnggulan) ...<Widget>[
                  _KartuMkRingkas(mk: mk, storage: widget.storage),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Statistik extends StatelessWidget {
  const _Statistik({required this.angka, required this.label});

  final String angka;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: <Widget>[
            Text(
              angka,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: AppColors.navy700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10.4, color: AppColors.muted, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _Layanan extends StatelessWidget {
  const _Layanan({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    required this.onTap,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KartuPutih(
      onTap: onTap,
      anak: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.navy900,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(ikon, color: AppColors.gold, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            judul,
            style: const TextStyle(
              fontSize: 13.4,
              fontWeight: FontWeight.w800,
              color: AppColors.navy800,
            ),
          ),
          Text(
            keterangan,
            style: const TextStyle(fontSize: 11.4, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Kartu ringkas mata kuliah (dipakai Beranda & hasil pencarian).
class _KartuMkRingkas extends StatelessWidget {
  const _KartuMkRingkas({required this.mk, required this.storage});

  final MataKuliah mk;
  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    return KartuPutih(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext c) => DetailMataKuliahScreen(
            mk: mk,
            storage: storage,
          ),
        ),
      ),
      anak: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              LabelChip(mk.kode),
              LabelChip.emas('Semester ${mk.semester}'),
              LabelChip.hijau('${mk.sks} SKS'),
              if (storage.sertifikatTerisi(mk))
                const LabelChip.hijau('Sertifikat tersimpan'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mk.nama,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.navy800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mk.deskripsi,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12.2, color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              const Icon(Icons.arrow_forward,
                  size: 14, color: AppColors.navy600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Buka web sertifikat ${mk.kode}.html',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.6,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

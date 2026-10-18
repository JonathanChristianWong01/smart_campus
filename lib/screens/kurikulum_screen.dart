import 'package:flutter/material.dart';

import '../data/curriculum_data.dart';
import '../data/praktikum_data.dart';
import '../models/mata_kuliah.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'matkul_detail_screen.dart';

/// Halaman Kurikulum: 8 semester dalam bentuk tab, dapat dicari,
/// tabel ringkas SKS & prasyarat, lalu membuka detail tiap mata kuliah.
class KurikulumScreen extends StatefulWidget {
  const KurikulumScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  State<KurikulumScreen> createState() => _KurikulumScreenState();
}

class _KurikulumScreenState extends State<KurikulumScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final TextEditingController _cari = TextEditingController();
  bool _modeCari = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: kKurikulum.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          color: AppColors.navy900,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _modeCari
                    ? 'Pencarian — ${kSemuaMataKuliah.length} mata kuliah'
                    : 'Kurikulum $kProgramStudi • $kKurikulumTahun',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 13.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _cari,
                      onChanged: (_) =>
                          setState(() => _modeCari = _cari.text.isNotEmpty),
                      style: const TextStyle(fontSize: 13.2),
                      decoration: InputDecoration(
                        hintText: 'Cari mata kuliah / kode MK…',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.white,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _cari.text.isEmpty
                            ? null
                            : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _cari.clear();
                            setState(() => _modeCari = false);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!_modeCari)
          Container(
            color: AppColors.navy900,
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              indicatorColor: AppColors.gold,
              indicatorWeight: 3,
              labelColor: AppColors.gold,
              unselectedLabelColor: const Color(0xFFA9C0DD),
              labelStyle:
              const TextStyle(fontSize: 12.6, fontWeight: FontWeight.w800),
              tabs: <Widget>[
                for (final SemesterKurikulum s in kKurikulum)
                  Tab(text: 'Sem ${s.nomor} • ${s.totalSks} SKS'),
              ],
            ),
          ),
        Expanded(
          child: _modeCari
              ? _HasilCari(
            kata: _cari.text,
            storage: widget.storage,
          )
              : TabBarView(
            controller: _tab,
            children: <Widget>[
              for (final SemesterKurikulum s in kKurikulum)
                _IsiSemester(sem: s, storage: widget.storage),
            ],
          ),
        ),
      ],
    );
  }
}

class _IsiSemester extends StatelessWidget {
  const _IsiSemester({required this.sem, required this.storage});

  final SemesterKurikulum sem;
  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 26),
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                'Semester ${sem.nomor}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            LabelChip.emas('${sem.totalSks} SKS'),
            const Spacer(),
            Text(
              '${sem.mataKuliah.length} MK',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        if (sem.catatan.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: KotakCatatan(Text(sem.catatan)),
          ),
        const SizedBox(height: 10),
        _TabelMk(sem: sem, storage: storage),
        const SizedBox(height: 12),
        KotakCatatan(
          Text(
            'Total SKS pada daftar mata kuliah Semester ${sem.nomor} = '
                '${sem.sksTerhitung} SKS'
                '${sem.sksTerhitung == sem.totalSks ? ' (sesuai dokumen kurikulum).' : ' (dokumen kurikulum menulis ${sem.totalSks} SKS).'}',
          ),
          ikon: Icons.functions,
        ),
      ],
    );
  }
}

class _TabelMk extends StatelessWidget {
  const _TabelMk({required this.sem, required this.storage});

  final SemesterKurikulum sem;
  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: const Row(
              children: <Widget>[
                SizedBox(width: 68, child: Text('KODE', style: _gayaJudul)),
                Expanded(child: Text('NAMA MATA KULIAH', style: _gayaJudul)),
                SizedBox(
                  width: 40,
                  child: Text('SKS',
                      style: _gayaJudul, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
          for (int i = 0; i < sem.mataKuliah.length; i++)
            _BarisMk(
              mk: sem.mataKuliah[i],
              genap: i.isEven,
              storage: storage,
            ),
        ],
      ),
    );
  }
}

const TextStyle _gayaJudul = TextStyle(
  color: AppColors.white,
  fontSize: 11.4,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.4,
);

class _BarisMk extends StatelessWidget {
  const _BarisMk(
      {required this.mk, required this.genap, required this.storage});

  final MataKuliah mk;
  final bool genap;
  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    final bool punyaSertifikat = storage.sertifikatTerisi(mk);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext c) =>
              DetailMataKuliahScreen(mk: mk, storage: storage),
        ),
      ),
      child: Container(
        color: genap ? const Color(0xFFFAFCFF) : AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 68,
                  child: Text(
                    mk.kode,
                    style:
                    const TextStyle(fontSize: 12, color: AppColors.navy600),
                  ),
                ),
                Expanded(
                  child: Text(
                    mk.nama,
                    style: const TextStyle(
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${mk.sks}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.4,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Wrap (bukan Row) supaya chip turun ke baris berikutnya ketika
            // layar sempit. Prasyarat panjang dibatasi & dipotong dengan
            // elipsis agar tidak meluber (penyebab pita kuning-hitam).
            LayoutBuilder(
              builder: (BuildContext c, BoxConstraints kendala) {
                final double batasPrasyarat =
                (kendala.maxWidth * 0.62).clamp(110.0, 300.0);
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (mk.prasyarat.isNotEmpty)
                      LabelChip(
                        'Prasyarat: ${mk.prasyarat}',
                        maksLebar: batasPrasyarat,
                        maksBaris: 2,
                      ),
                    for (final String b in bahasaMk(mk.kode).take(2))
                      LabelChip.hijau(labelBahasaRingkas(b)),
                    if (punyaSertifikat) const LabelChip.emas('✔ Sertifikat'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HasilCari extends StatelessWidget {
  const _HasilCari({required this.kata, required this.storage});

  final String kata;
  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    final String q = kata.trim().toLowerCase();
    final List<MataKuliah> hasil = kSemuaMataKuliah.where((MataKuliah m) {
      return m.nama.toLowerCase().contains(q) ||
          m.kode.contains(q) ||
          m.prasyarat.toLowerCase().contains(q) ||
          m.semester.toString() == q;
    }).toList();

    if (hasil.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: KotakCatatan(
          Text('Tidak ada mata kuliah yang cocok. Contoh kata kunci: '
              '"algoritma", "jaringan", "110100", atau "5".'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
      itemCount: hasil.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext c, int i) {
        final MataKuliah mk = hasil[i];
        return KartuPutih(
          onTap: () => Navigator.of(c).push(
            MaterialPageRoute<void>(
              builder: (_) => DetailMataKuliahScreen(mk: mk, storage: storage),
            ),
          ),
          anak: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        LabelChip(mk.kode),
                        LabelChip.emas('Sem ${mk.semester}'),
                        LabelChip.hijau('${mk.sks} SKS'),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.navy600),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                mk.nama,
                style: const TextStyle(
                  fontSize: 13.6,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

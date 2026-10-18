import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../data/curriculum_data.dart';
import '../models/mata_kuliah.dart';
import '../services/sertifikat_pdf.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/asset_webview.dart';
import '../widgets/common.dart';

/// Halaman Sertifikat (versi aplikasi): isi data mahasiswa, lihat pratinjau
/// sertifikat, lalu cetak / simpan sebagai PDF di perangkat Android.
class SertifikatScreen extends StatefulWidget {
  const SertifikatScreen({super.key, required this.mk, required this.storage});

  final MataKuliah mk;
  final StorageService storage;

  @override
  State<SertifikatScreen> createState() => _SertifikatScreenState();
}

class _SertifikatScreenState extends State<SertifikatScreen> {
  late final TextEditingController _nama;
  late final TextEditingController _nim;
  String _predikat = 'Dengan Pujian (A)';
  bool _sibuk = false;

  static const List<String> _pilihanPredikat = <String>[
    'Dengan Pujian (A)',
    'Sangat Baik (B)',
    'Baik (C)',
    'Cukup (D)',
  ];

  @override
  void initState() {
    super.initState();
    final Map<String, String> data = widget.storage.dataSertifikat(widget.mk);
    _nama = TextEditingController(text: data['nama'] ?? '');
    _nim = TextEditingController(text: data['nim'] ?? '');
    _predikat = _pilihanPredikat.contains(data['predikat'])
        ? data['predikat']!
        : _pilihanPredikat.first;
  }

  @override
  void dispose() {
    _nama.dispose();
    _nim.dispose();
    super.dispose();
  }

  Future<void> _simpan({required bool cetak}) async {
    await widget.storage.simpanSertifikat(widget.mk, <String, String>{
      'nama': _nama.text.trim(),
      'nim': _nim.text.trim(),
      'predikat': _predikat,
      'tanggal': DateTime.now().toIso8601String(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data sertifikat tersimpan di perangkat')),
    );
    if (cetak) await _cetak();
  }

  Future<void> _cetak() async {
    setState(() => _sibuk = true);
    try {
      await Printing.layoutPdf(
        name: 'Sertifikat-${widget.mk.kode}-${_nama.text.trim().isEmpty ? 'mahasiswa' : _nama.text.trim()}.pdf',
        onLayout: (PdfPageFormat format) async {
          final doc = await SertifikatPdf.dokumen(
            mk: widget.mk,
            nama: _nama.text.trim(),
            nim: _nim.text.trim(),
            predikat: _predikat,
          );
          return doc.save();
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _bagikan() async {
    setState(() => _sibuk = true);
    try {
      final doc = await SertifikatPdf.dokumen(
        mk: widget.mk,
        nama: _nama.text.trim(),
        nim: _nim.text.trim(),
        predikat: _predikat,
      );
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'Sertifikat-${widget.mk.kode}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membagikan PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String namaTampil =
    _nama.text.trim().isEmpty ? 'Nama Mahasiswa' : _nama.text.trim();
    final String nimTampil =
    _nim.text.trim().isEmpty ? '—' : _nim.text.trim();

    return Scaffold(
      appBar: AppBar(title: Text('Sertifikat ${widget.mk.kode}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        children: <Widget>[
          KotakCatatan(
            Text(
              'Sertifikat ini diterbitkan oleh Smart Campus $kUniversitas untuk mata kuliah '
                  '${widget.mk.nama} (${widget.mk.kode}) • ${widget.mk.sks} SKS • Semester ${widget.mk.semester}. '
                  'Isi data, simpan, lalu cetak atau simpan sebagai PDF.',
            ),
          ),
          const JudulBagian('Data Mahasiswa', ikon: Icons.person_outline),
          TextField(
            controller: _nama,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nama Lengkap',
              hintText: 'Contoh: Ahmad Fauzan',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nim,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'NIM',
              hintText: 'Contoh: 2026010101',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _predikat,
            decoration: const InputDecoration(labelText: 'Predikat'),
            items: _pilihanPredikat
                .map(
                  (String p) => DropdownMenuItem<String>(value: p, child: Text(p)),
            )
                .toList(),
            onChanged: (String? v) => setState(() => _predikat = v ?? _predikat),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _sibuk ? null : () => _simpan(cetak: false),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Simpan Data'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navy900,
                  ),
                  onPressed: _sibuk ? null : _cetak,
                  icon: _sibuk
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Cetak / PDF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sibuk ? null : _bagikan,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Bagikan PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HalamanWeb(
                        aset: widget.mk.asetWebSertifikat,
                        judul: 'Web Sertifikat ${widget.mk.kode}',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Web Sertifikat'),
                ),
              ),
            ],
          ),
          const JudulBagian('Pratinjau Sertifikat', ikon: Icons.preview),
          _PratinjauSertifikat(
            mk: widget.mk,
            nama: namaTampil,
            nim: nimTampil,
            predikat: _predikat,
          ),
          const SizedBox(height: 12),
          const KotakCatatan(
            Text(
              'Tips Android: tekan "Cetak / PDF" → pilih "Save as PDF" pada dialog cetak '
                  'untuk menyimpan sertifikat ke folder Download tanpa printer.',
            ),
            ikon: Icons.android,
          ),
        ],
      ),
    );
  }
}

/// Pratinjau sertifikat langsung di aplikasi (mirip versi PDF & web).
class _PratinjauSertifikat extends StatelessWidget {
  const _PratinjauSertifikat({
    required this.mk,
    required this.nama,
    required this.nim,
    required this.predikat,
  });

  final MataKuliah mk;
  final String nama;
  final String nim;
  final String predikat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.navy700, width: 4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gold),
        ),
        child: Column(
          children: <Widget>[
            Text(
              '${kFakultas.toUpperCase()} • ${kUniversitas.toUpperCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9.4,
                letterSpacing: 1.2,
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'SERTIFIKAT CAPAIAN\nMATA KULIAH',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: AppColors.navy900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Certificate of Completion',
              style: TextStyle(
                fontSize: 9.6,
                color: AppColors.muted,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            const Text('Diberikan kepada', style: TextStyle(fontSize: 10.6, color: AppColors.muted)),
            const SizedBox(height: 4),
            Text(
              nama,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.navy600,
              ),
            ),
            Container(width: 190, height: 2, color: AppColors.gold),
            const SizedBox(height: 4),
            Text(
              'NIM $nim • $kProgramStudi',
              style: const TextStyle(fontSize: 10.4, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Text(
              'telah menyelesaikan seluruh capaian pembelajaran mata kuliah '
                  '${mk.nama} (${mk.kode}) berbobot ${mk.sks} SKS pada Semester '
                  '${mk.semester} Kurikulum $kKurikulumTahun $kProgramStudi, '
                  '$kFakultas, $kUniversitas.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, height: 1.5),
            ),
            const SizedBox(height: 10),
            Text(
              'Predikat: $predikat',
              style: const TextStyle(
                fontSize: 11.4,
                fontWeight: FontWeight.w800,
                color: AppColors.navy700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _ttd('Ketua Program Studi'),
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFF6DE),
                    border: Border.all(color: AppColors.gold, width: 2.6),
                  ),
                  child: const Text(
                    'CAP\nBIRO\nAKADEMIK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 7.6,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy700,
                      height: 1.2,
                    ),
                  ),
                ),
                _ttd('Kepala Biro Akademik'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'No. ${SertifikatPdf.nomorSertifikat(mk)}',
              style: const TextStyle(fontSize: 8.8, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ttd(String jabatan) {
    return SizedBox(
      width: 92,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 26),
          Container(height: 1.4, color: AppColors.navy700),
          const SizedBox(height: 3),
          Text(
            jabatan,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 8.4, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

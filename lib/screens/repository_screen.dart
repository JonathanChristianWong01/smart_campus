import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/curriculum_data.dart';
import '../models/mata_kuliah.dart';
import '../services/repo_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Halaman Repositori: daftar link GitHub untuk seluruh mata kuliah,
/// penyimpanan link repo milik mahasiswa, dan panduan unggah tugas.
class RepositoryScreen extends StatefulWidget {
  const RepositoryScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  State<RepositoryScreen> createState() => _RepositoryScreenState();
}

class _RepositoryScreenState extends State<RepositoryScreen> {
  final TextEditingController _cari = TextEditingController();
  String _username = 'username-anda';

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  List<MataKuliah> get _daftar {
    final String q = _cari.text.trim().toLowerCase();
    if (q.isEmpty) return kSemuaMataKuliah;
    return kSemuaMataKuliah
        .where((MataKuliah m) =>
    m.nama.toLowerCase().contains(q) ||
        m.kode.contains(q) ||
        RepoService.namaRepo(m).contains(q))
        .toList();
  }

  void _pesan(String teks) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  @override
  Widget build(BuildContext context) {
    final List<MataKuliah> daftar = _daftar;
    final int tersimpan = widget.storage.linkRepo.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Repositori & Link GitHub',
                style: TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Setiap mata kuliah memiliki nama repositori yang disarankan. '
                    'Simpan link repo Anda agar tercatat pada sertifikat dan halaman mata kuliah.',
                style: TextStyle(
                    color: Color(0xFFC8D8EE), fontSize: 12.2, height: 1.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cari,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13.2),
                decoration: const InputDecoration(
                  hintText: 'Cari mata kuliah / nama repo…',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  LabelChip(
                    '$tersimpan link tersimpan',
                    latar: AppColors.navy800,
                    teksWarna: AppColors.gold,
                    garis: AppColors.navy600,
                  ),
                  LabelChip(
                    '${kSemuaMataKuliah.length} repositori disarankan',
                    latar: AppColors.navy800,
                    teksWarna: AppColors.white,
                    garis: AppColors.navy600,
                  ),
                ],
              ),
            ],
          ),
        ),
        const JudulBagian('Username GitHub Anda',
            ikon: Icons.person_pin_outlined),
        TextField(
          onChanged: (String v) => setState(
                  () => _username = v.trim().isEmpty ? 'username-anda' : v.trim()),
          decoration: const InputDecoration(
            labelText: 'Username GitHub',
            hintText: 'contoh: fauzan-mulia',
            prefixIcon: Icon(Icons.alternate_email),
          ),
        ),
        const JudulBagian('Repositori Aplikasi (Template)',
            ikon: Icons.folder_special_outlined),
        _KartuRepoUtama(
          nama: 'mulia_smart_campus',
          keterangan:
          'Aplikasi Flutter (Dart) Smart Campus Universitas Mulia — berisi kurikulum, '
              'web sertifikat tiap mata kuliah, kompiler, dan repositori.',
          url: 'https://github.com/$_username/mulia_smart_campus',
          onBuka: () => launchUrl(
            Uri.parse('https://github.com/$_username/mulia_smart_campus'),
            mode: LaunchMode.externalApplication,
          ),
          onSalin: () async {
            await Clipboard.setData(
              ClipboardData(
                  text: 'https://github.com/$_username/mulia_smart_campus'),
            );
            _pesan('Link repo aplikasi disalin');
          },
        ),
        const SizedBox(height: 10),
        _KotakPerintah(
          judul: 'Perintah pertama kali mengunggah aplikasi',
          isi: <String>[
            'git init',
            'git add .',
            'git commit -m "Smart Campus Universitas Mulia - aplikasi Flutter"',
            'git branch -M main',
            'git remote add origin https://github.com/$_username/mulia_smart_campus.git',
            'git push -u origin main',
          ].join('\n'),
          onSalin: () async {
            await Clipboard.setData(
              ClipboardData(
                text: <String>[
                  'git init',
                  'git add .',
                  'git commit -m "Smart Campus Universitas Mulia - aplikasi Flutter"',
                  'git branch -M main',
                  'git remote add origin https://github.com/$_username/mulia_smart_campus.git',
                  'git push -u origin main',
                ].join('\n'),
              ),
            );
            _pesan('Perintah Git disalin');
          },
        ),
        const JudulBagian('Repositori per Mata Kuliah',
            ikon: Icons.hub_outlined),
        if (daftar.isEmpty)
          const KotakCatatan(Text('Mata kuliah tidak ditemukan.'))
        else
          for (final MataKuliah mk in daftar) ...<Widget>[
            _KartuRepoMk(
              mk: mk,
              storage: widget.storage,
              onPesan: _pesan,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _KartuRepoUtama extends StatelessWidget {
  const _KartuRepoUtama({
    required this.nama,
    required this.keterangan,
    required this.url,
    required this.onBuka,
    required this.onSalin,
  });

  final String nama;
  final String keterangan;
  final String url;
  final VoidCallback onBuka;
  final VoidCallback onSalin;

  @override
  Widget build(BuildContext context) {
    return KartuPutih(
      aksen: AppColors.gold,
      anak: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.code, color: AppColors.navy700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nama,
                  style: const TextStyle(
                    fontSize: 13.6,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy800,
                  ),
                ),
              ),
              const LabelChip.emas('Disarankan'),
            ],
          ),
          const SizedBox(height: 6),
          Text(keterangan,
              style: const TextStyle(
                  fontSize: 12.2, color: AppColors.muted, height: 1.45)),
          const SizedBox(height: 6),
          Text(url,
              style: const TextStyle(fontSize: 11.4, color: AppColors.navy600)),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: onBuka,
                  icon: const Icon(Icons.open_in_new, size: 17),
                  label: const Text('Buka di GitHub'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onSalin,
                icon: const Icon(Icons.copy, size: 17),
                label: const Text('Salin'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KotakPerintah extends StatelessWidget {
  const _KotakPerintah({
    required this.judul,
    required this.isi,
    required this.onSalin,
  });

  final String judul;
  final String isi;
  final VoidCallback onSalin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  judul,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 12.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Salin perintah',
                onPressed: onSalin,
                icon: const Icon(Icons.copy, color: AppColors.gold, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            isi,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.4,
              color: Color(0xFF8EF2C4),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuRepoMk extends StatelessWidget {
  const _KartuRepoMk({
    required this.mk,
    required this.storage,
    required this.onPesan,
  });

  final MataKuliah mk;
  final StorageService storage;
  final ValueChanged<String> onPesan;

  @override
  Widget build(BuildContext context) {
    final String tersimpan = storage.linkRepoUntuk(mk.kode);
    final TextEditingController c = TextEditingController(text: tersimpan);

    return KartuPutih(
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
              if (tersimpan.isNotEmpty) const LabelChip.hijau('Link tersimpan'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mk.nama,
            style: const TextStyle(
              fontSize: 13.4,
              fontWeight: FontWeight.w800,
              color: AppColors.navy800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              const Icon(Icons.folder_outlined,
                  size: 15, color: AppColors.navy600),
              const SizedBox(width: 6),
              Expanded(
                child: SelectableText(
                  RepoService.namaRepo(mk),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.6,
                    color: AppColors.navy700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText:
              'https://github.com/username/${RepoService.namaRepo(mk)}',
              isDense: true,
              suffixIcon: IconButton(
                tooltip: 'Simpan link',
                icon: const Icon(Icons.save_outlined, size: 20),
                onPressed: () async {
                  await storage.simpanLinkRepo(mk.kode, c.text);
                  onPesan('Link repo ${mk.kode} disimpan');
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(RepoService.urlBuatBaru(mk)),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.add_circle_outline, size: 17),
                label: const Text('Buat Repo'),
              ),
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(RepoService.urlCari(mk)),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.search, size: 17),
                label: const Text('Cari di GitHub'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                        text: RepoService.perintahGit(mk, 'username-anda')),
                  );
                  onPesan('Perintah Git ${mk.kode} disalin');
                },
                icon: const Icon(Icons.terminal, size: 17),
                label: const Text('Perintah Git'),
              ),
              if (tersimpan.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(tersimpan),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 17),
                  label: const Text('Buka Repo Saya'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

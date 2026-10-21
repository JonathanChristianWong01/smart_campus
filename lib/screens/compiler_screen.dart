import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../data/compiler_data.dart';
import '../data/praktikum_data.dart';
import '../models/mata_kuliah.dart';
import '../services/compiler_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/asset_webview.dart';
import '../widgets/common.dart';
import '../utils/combined_program_input.dart';
import 'web_playground_screen.dart';

/// Kompiler daring: jalankan kode C++, JavaScript, PHP, dan Python
/// langsung dari aplikasi (API Judge0), dengan riwayat dan tautan belajar Dicoding.
class CompilerScreen extends StatefulWidget {
  const CompilerScreen({
    super.key,
    required this.storage,
    this.bahasaAwal,
    this.konteksMk,
    this.service,
  });

  final StorageService storage;

  /// Opsional untuk pengujian. Layanan ditutup saat layar dilepas.
  final CompilerService? service;
  final BahasaKompiler? bahasaAwal;

  /// Mata kuliah yang sedang dipraktikkan (opsional).
  final MataKuliah? konteksMk;

  @override
  State<CompilerScreen> createState() => _CompilerScreenState();
}

class _CompilerScreenState extends State<CompilerScreen> {
  late final CompilerService _service;
  final TextEditingController _kode = TextEditingController();

  late BahasaKompiler _bahasa;

  /// Bahasa yang boleh dipilih.
  ///
  /// Bila layar dibuka untuk satu mata kuliah (mis. dari tombol "Praktik
  /// Python" pada detail MK), pilihan dibatasi pada bahasa yang relevan
  /// dengan mata kuliah tersebut. Tanpa konteks MK (tab Kompiler), semua
  /// bahasa ditampilkan.
  List<BahasaKompiler> get _pilihanBahasa {
    final MataKuliah? mk = widget.konteksMk;
    if (mk != null) {
      final List<BahasaKompiler> khusus = daftarBahasaMk(mk.kode);
      if (khusus.isNotEmpty) return khusus;
    }
    return kBahasaKompiler;
  }

  String _keluaran =
      'Tekan ▶ Jalankan untuk mengeksekusi kode di kompiler daring.';
  String _meta =
      'Kompiler daring: Judge0 CE (ce.judge0.com) • butuh koneksi internet';
  bool _berjalan = false;
  bool _autoIndent = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CompilerService();
    _bahasa = widget.bahasaAwal ?? kBahasaKompiler.last;
    _kode.text = '${_bahasa.contohKode}\n\n$penandaInputProgram\n';
  }

  @override
  void dispose() {
    _kode.dispose();
    _service.dispose();
    super.dispose();
  }

  void _gantiBahasa(BahasaKompiler b) {
    setState(() {
      _bahasa = b;
      _kode.text = '${b.contohKode}\n\n$penandaInputProgram\n';
      _keluaran = 'Bahasa ${b.label} siap. Tekan ▶ Jalankan.';
    });
  }

  Future<void> _jalankan() async {
    final ProgramDenganInput program = pisahkanProgramInput(_kode.text);
    if (program.kode.trim().isEmpty) {
      setState(() => _keluaran = 'Kode masih kosong.');
      return;
    }
    if (_bahasa.id == 'javascript' &&
        RegExp(r'^\s*<(?:!doctype|html|head|body|h[1-6]|div|p|style|button)\b',
            caseSensitive: false)
            .hasMatch(program.kode)) {
      setState(() => _keluaran =
      'Ini kode HTML, bukan JavaScript Node.js. Gunakan tombol Buka Preview Web di bagian atas, lalu tempel kode di tab HTML.');
      return;
    }
    setState(() {
      _berjalan = true;
      _keluaran = 'Menjalankan…';
    });

    final HasilKompilasi hasil = await _service.jalankan(
      bahasa: _bahasa,
      kode: program.kode,
      stdin: program.stdin,
    );

    await widget.storage.tambahRiwayat(
      RiwayatEksekusi(
        waktu: _formatWaktu(DateTime.now()),
        bahasa: _bahasa.label,
        status: hasil.ok
            ? 'OK'
            : hasil.offline
            ? 'OFFLINE'
            : 'ERROR',
        cuplikanKode: _kode.text.split('\n').first,
      ),
    );

    if (!mounted) return;
    setState(() {
      _berjalan = false;
      _keluaran = hasil.keluaran;
      _meta =
      '${_bahasa.label} ${_bahasa.pistonVersion} • exit code ${hasil.exitCode}'
          '${hasil.durasiMs > 0 ? ' • ${hasil.durasiMs} ms' : ''} • ${hasil.pesanSistem}';
    });
  }

  Future<void> _bukaDicoding() async {
    try {
      final bool terbuka = await launchUrl(
        Uri.parse('https://www.dicoding.com/'),
        mode: LaunchMode.externalApplication,
      );
      if (terbuka) return;
    } catch (_) {
      // Pesan yang sama untuk kegagalan platform dan browser tidak tersedia.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Browser tidak dapat dibuka. Kunjungi https://www.dicoding.com/ secara manual.'),
    ));
  }

  static String _formatWaktu(DateTime t) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${dua(t.day)}/${dua(t.month)}/${t.year} ${dua(t.hour)}:${dua(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final List<RiwayatEksekusi> riwayat = widget.storage.riwayat;

    // ChoiceChip membutuhkan leluhur Material. Tab Kompiler sudah berada di
    // dalam Scaffold, tetapi saat layar ini dibuka sebagai halaman sendiri
    // (dari detail mata kuliah) tidak ada Material di atasnya — itulah yang
    // memicu layar merah "No Material widget found". Pembungkus berikut aman
    // dipakai pada kedua keadaan.
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
        children: <Widget>[
          if (widget.konteksMk != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: KotakCatatan(
                Text(
                  'Praktikum untuk mata kuliah ${widget.konteksMk!.nama} '
                      '(${widget.konteksMk!.kode}) • Semester ${widget.konteksMk!.semester}.',
                ),
                ikon: Icons.school_outlined,
              ),
            ),
          KartuPutih(
            anak: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                    'Ingin hasil berupa desain, warna, atau tulisan tebal?'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const WebPlaygroundScreen(),
                      )),
                  icon: const Icon(Icons.web),
                  label: const Text('Buka Preview Web'),
                ),
                const Text(
                    'HTML, CSS, JavaScript, PHP, C++, dan Python tersedia di halaman Preview Web. Kompiler di bawah tetap untuk keluaran teks.'),
              ],
            ),
          ),
          const JudulBagian('Pilih Bahasa Pemrograman', ikon: Icons.translate),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final BahasaKompiler b in _pilihanBahasa)
                ChoiceChip(
                  label: Text(b.label),
                  selected: b.id == _bahasa.id,
                  onSelected: _berjalan ? null : (_) => _gantiBahasa(b),
                  selectedColor: AppColors.navy700,
                  labelStyle: TextStyle(
                    color: b.id == _bahasa.id
                        ? AppColors.white
                        : AppColors.navy700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
          const JudulBagian('Editor Kode', ikon: Icons.code),
          Container(
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: LabelChip(
                          '${_bahasa.label} ${_bahasa.pistonVersion} • ${_bahasa.namaBerkas}',
                          latar: AppColors.navy900,
                          teksWarna: AppColors.gold,
                          garis: AppColors.navy600,
                          maksLebar: 168,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _autoIndent = !_autoIndent),
                      icon: Icon(
                        _autoIndent
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 16,
                        color: AppColors.gold,
                      ),
                      label: const Text(
                        'Auto-indent',
                        style: TextStyle(fontSize: 11.6, color: AppColors.gold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const ValueKey<String>('compiler-editor'),
                  controller: _kode,
                  readOnly: _berjalan,
                  maxLines: 16,
                  minLines: 10,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.6,
                    color: Color(0xFFE8F0FB),
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: AppColors.navy900,
                    hintText: '// Tulis kode di sini…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    if (_autoIndent) const _AutoIndentFormatter(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
              'Kode dan input dalam satu editor. Tulis kode di atas baris '
                  '=== INPUT STDIN ===, lalu semua input di bawahnya '
                  '(satu jawaban per baris). Tekan Jalankan sekali untuk mengirim '
                  'keduanya. Tanpa input? Biarkan bagian bawah kosong. '
                  'Ini bukan terminal interaktif. Saat bahasa diganti atau contoh '
                  'dimuat ulang, editor kembali ke contoh dan input kosong.'),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _berjalan ? null : _jalankan,
                  icon: _berjalan
                      ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.play_arrow, size: 20),
                  label: Text(_berjalan ? 'Menjalankan…' : 'Jalankan'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Muat contoh kode',
                onPressed: _berjalan ? null : () => _gantiBahasa(_bahasa),
                icon: const Icon(Icons.restore),
              ),
              IconButton.filledTonal(
                tooltip: 'Kosongkan kode',
                onPressed:
                _berjalan ? null : () => setState(() => _kode.text = ''),
                icon: const Icon(Icons.delete_outline),
              ),
              IconButton.filledTonal(
                tooltip: 'Salin kode',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _kode.text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kode disalin')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
          const JudulBagian('Keluaran (stdout / stderr)', ikon: Icons.terminal),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navy900,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              _keluaran,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.2,
                color: Color(0xFF8EF2C4),
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _meta,
            style: const TextStyle(fontSize: 11.2, color: AppColors.muted),
          ),
          const JudulBagian('Belajar di Dicoding', ikon: Icons.school_outlined),
          KartuPutih(
            aksen: AppColors.gold,
            anak: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                    'Lanjutkan belajar pemrograman melalui situs resmi Dicoding.'),
                const SizedBox(height: 8),
                const Text(
                    'Tautan eksternal, bukan integrasi akun. Sertifikat kelas mengikuti ketentuan Dicoding dan tidak terkait jumlah eksekusi di aplikasi ini.'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      key: const ValueKey<String>('buka-dicoding'),
                      onPressed: _bukaDicoding,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Buka Dicoding'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => const HalamanWeb(
                              aset: 'assets/web/compiler.html',
                              judul: 'Web Kompiler Smart Campus',
                            ),
                          )),
                      icon: const Icon(Icons.public, size: 18),
                      label: const Text('Web Kompiler'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const JudulBagian('Riwayat Eksekusi', ikon: Icons.history),
          if (riwayat.isEmpty)
            const KotakCatatan(
              Text(
                  'Belum ada riwayat. Eksekusi kode pertama Anda untuk mencatat riwayat.'),
            )
          else ...<Widget>[
            for (final RiwayatEksekusi r in riwayat)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: <Widget>[
                    LabelChip(r.bahasa, maksLebar: 96),
                    const SizedBox(width: 8),
                    LabelChip(
                      r.status,
                      latar: r.status == 'OK'
                          ? const Color(0xFFE4F7F2)
                          : const Color(0xFFFDECEA),
                      teksWarna: r.status == 'OK'
                          ? const Color(0xFF0F6B58)
                          : const Color(0xFF9B2C22),
                      garis: r.status == 'OK'
                          ? const Color(0xFFB9E9DF)
                          : const Color(0xFFF5C6C0),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            r.cuplikanKode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.2,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            r.waktu,
                            style: const TextStyle(
                                fontSize: 10.6, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  await widget.storage.bersihkanRiwayat();
                  setState(() {});
                },
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('Bersihkan riwayat'),
              ),
            ),
            // ---- Video sumber belajar untuk bahasa yang sedang dipakai ----
            const JudulBagian('Video Sumber Belajar',
                ikon: Icons.ondemand_video),
            for (final SumberVideo v in videoUntuk(_bahasa.id))
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
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

/// Menjaga indentasi otomatis sederhana ketika pengguna menekan Enter.
class _AutoIndentFormatter extends TextInputFormatter {
  const _AutoIndentFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue lama,
      TextEditingValue baru,
      ) {
    if (baru.text.length != lama.text.length + 1) return baru;
    final int pos = baru.selection.baseOffset;
    if (pos <= 0 || baru.text[pos - 1] != '\n') return baru;

    if (baru.text.substring(0, pos).contains(penandaInputProgram)) {
      return baru;
    }

    final List<String> baris = baru.text.substring(0, pos - 1).split('\n');
    final String barisSebelumnya = baris.isEmpty ? '' : baris.last;
    final RegExp pola = RegExp(r'^[ \t]*');
    final String indent = pola.stringMatch(barisSebelumnya) ?? '';
    if (indent.isEmpty) return baru;

    final String teks =
        baru.text.substring(0, pos) + indent + baru.text.substring(pos);
    return TextEditingValue(
      text: teks,
      selection: TextSelection.collapsed(offset: pos + indent.length),
    );
  }
}

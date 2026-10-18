import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../data/compiler_data.dart';
import '../data/visual_compiler_data.dart';
import '../services/compiler_service.dart';
import '../utils/web_preview_document.dart';

const String contohHtmlWeb = '''<h1>Halo Universitas Mulia</h1>
<p>Huruf <b>tebal</b>, <i>miring</i>, dan angka <strong>12345</strong>.</p>
<button id="tombol">Klik Saya</button>
<p id="hasil">Tombol belum diklik.</p>''';
const String contohCssWeb =
'''body { font-family: sans-serif; padding: 20px; background: #f2f5fb; }
h1 { color: #143259; font-weight: 900; }
strong { color: #b57900; font-size: 28px; }
button { background: #ffcf40; color: #0b1729; border: 0;
  padding: 14px 22px; border-radius: 12px; font-weight: bold; }''';
const String contohJsWeb =
'''document.getElementById('tombol').addEventListener('click', function () {
  document.getElementById('hasil').textContent = 'Berhasil! JavaScript berjalan di Android.';
});''';

/// Editor web terpisah dari eksekusi Node.js/Judge0.
class WebPlaygroundScreen extends StatefulWidget {
  const WebPlaygroundScreen({super.key, this.service});

  /// Layanan opsional untuk pengujian, ditutup saat halaman dilepas.
  final CompilerService? service;
  @override
  State<WebPlaygroundScreen> createState() => _WebPlaygroundScreenState();
}

class _WebPlaygroundScreenState extends State<WebPlaygroundScreen> {
  final List<TextEditingController> _editor = <TextEditingController>[
    TextEditingController(text: contohHtmlWeb),
    TextEditingController(text: contohCssWeb),
    TextEditingController(text: contohJsWeb),
    TextEditingController(text: contohKodeVisual('php')),
    TextEditingController(text: contohKodeVisual('cplusplus')),
    TextEditingController(text: contohKodeVisual('python')),
  ];
  static const List<String> _label = <String>[
    'HTML',
    'CSS',
    'JavaScript',
    'PHP',
    'C++',
    'Python'
  ];
  static const List<String> _id = <String>[
    '',
    '',
    '',
    'php',
    'cplusplus',
    'python'
  ];
  late final CompilerService _service;
  int _pilihan = 0;
  bool _berjalan = false;
  String? _keluaran;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CompilerService();
  }

  Future<void> _jalankan() async {
    FocusScope.of(context).unfocus();
    if (_pilihan < 3) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => WebPreviewScreen(
            dokumen: buatDokumenPreview(
                _editor[0].text, _editor[1].text, _editor[2].text)),
      ));
      return;
    }
    final int pilihan = _pilihan;
    final String kode = _editor[pilihan].text;
    if (kode.trim().isEmpty) {
      setState(() => _keluaran = 'Kode ${_label[pilihan]} masih kosong.');
      return;
    }
    setState(() {
      _berjalan = true;
      _keluaran = 'Menjalankan ${_label[pilihan]} di Judge0…';
    });
    final HasilKompilasi hasil = await _service.jalankan(
      bahasa: kBahasaKompiler.firstWhere((b) => b.id == _id[pilihan]),
      kode: kode,
    );
    if (!mounted) return;
    final String? html =
    htmlHasilVisual(berhasil: hasil.ok, stdout: hasil.stdout);
    setState(() {
      _berjalan = false;
      _keluaran = '${hasil.pesanSistem}\n${hasil.keluaran}'
          '${hasil.ok && html == null ? '\nHasil berupa teks biasa. Cetak HTML/CSS untuk menampilkan desain.' : ''}';
    });
    if (html != null) {
      // Dokumen hasil program berdiri sendiri; tidak dicampur tab HTML/CSS/JS.
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            WebPreviewScreen(dokumen: buatDokumenPreview(html, '', '')),
      ));
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _editor) {
      c.dispose();
    }
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Preview Web')),
    body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: <Widget>[
            const Text('Preview Web Android',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy800)),
            const SizedBox(height: 8),
            const Text(
                'Pilih HTML/CSS/JavaScript untuk desain web lokal, atau PHP/C++/Python untuk menjalankan kode yang menghasilkan HTML melalui internet.'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              for (int i = 0; i < _label.length; i++)
                ChoiceChip(
                  label: Text(_label[i]),
                  selected: _pilihan == i,
                  onSelected: _berjalan
                      ? null
                      : (_) => setState(() {
                    _pilihan = i;
                    _keluaran = null;
                  }),
                ),
            ]),
            const SizedBox(height: 10),
            TextField(
              key: ValueKey<int>(_pilihan),
              controller: _editor[_pilihan],
              readOnly: _berjalan,
              onChanged: (_) {
                if (_keluaran != null) setState(() => _keluaran = null);
              },
              minLines: 12,
              maxLines: 18,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 13, color: Colors.white),
              decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppColors.navy900,
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _berjalan ? null : _jalankan,
              icon: const Icon(Icons.play_arrow),
              label: Text(_berjalan
                  ? 'Menjalankan…'
                  : _pilihan < 3
                  ? 'Jalankan Preview Web'
                  : 'Jalankan ${_label[_pilihan]} & Preview'),
            ),
            if (_keluaran != null) ...<Widget>[
              const SizedBox(height: 12),
              const Text('Keluaran / status',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SelectableText(_keluaran!,
                  style:
                  const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ],
            const SizedBox(height: 10),
            Text(_pilihan < 3
                ? 'HTML, CSS, dan JavaScript digabung saat dijalankan. Tidak membutuhkan Judge0.'
                : '${_label[_pilihan]} berjalan di Judge0 (butuh internet). Cetak HTML/CSS dengan echo, cout, atau print. Hasil HTML dibuka sebagai preview; teks biasa dan error tampil di halaman ini. Tab HTML/CSS/JavaScript tidak digabung ke hasil program.'),
            const SizedBox(height: 10),
            const Text(
                'Gunakan tombol kembali untuk mengedit; jalankan lagi untuk memperbarui preview. Kode tetap ada saat kembali dari preview, tetapi belum disimpan permanen ketika halaman editor ditutup.'),
            const SizedBox(height: 8),
            const Text(
                'PHP/C++/Python tidak berjalan langsung di WebView; kode dikirim ke layanan Judge0. Jangan kirim data rahasia. Tidak mendukung GUI Tkinter/Qt atau server web PHP berkelanjutan. Jalankan hanya kode yang dipercaya; pengulangan JavaScript tanpa henti bisa membuat WebView macet.'),
          ],
        )),
  );
}

class WebPreviewScreen extends StatefulWidget {
  const WebPreviewScreen({super.key, required this.dokumen});
  final String dokumen;
  @override
  State<WebPreviewScreen> createState() => _WebPreviewScreenState();
}

class _WebPreviewScreenState extends State<WebPreviewScreen> {
  WebViewController? _controller;
  String? _error;
  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  Future<void> _siapkan() async {
    try {
      final WebViewController controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.white);
      await controller.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (NavigationRequest r) => r.url == 'about:blank' ||
            r.url == 'about:srcdoc' ||
            r.url.startsWith('data:text/html')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ));
      await controller.loadHtmlString(widget.dokumen);
      if (mounted) setState(() => _controller = controller);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
        'Preview tidak dapat dibuka. Perbarui Android System WebView / Chrome lalu coba lagi.\n$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hasil Preview Web')),
    body: SafeArea(
        child: _error != null
            ? Padding(
            padding: const EdgeInsets.all(16), child: Text(_error!))
            : _controller == null
            ? const Center(child: CircularProgressIndicator())
            : WebViewWidget(controller: _controller!)),
  );
}

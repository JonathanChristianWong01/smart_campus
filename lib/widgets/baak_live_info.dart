import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Pembaca DOM publik: tidak bergantung pada API/RSS yang diblokir.
/// Bila struktur website berubah, tampilkan kegagalan, bukan berita buatan.
class BaakLiveInfo extends StatefulWidget {
  const BaakLiveInfo({super.key});
  @override
  State<BaakLiveInfo> createState() => _BaakLiveInfoState();
}

class _BaakLiveInfoState extends State<BaakLiveInfo> {
  static final Uri _sumber = Uri.https('baak.universitasmulia.ac.id', '/');
  WebViewController? _web;
  List<Map<String, String>> _berita = [];
  bool _loading = true;
  String? _error;
  DateTime? _diperiksa;
  int _generasi = 0;

  static const _ekstrak = r'''
(() => {
 const hasil = [], seen = new Set();
 const clean = s => (s || '').replace(/\s+/g, ' ').trim();
 const headings = document.querySelectorAll('h1 a[href],h2 a[href],h3 a[href],h4 a[href],.entry-title a[href],.elementor-post__title a[href]');
 for (const a of headings) {
   let u; try { u = new URL(a.href, location.href); } catch (_) { continue; }
   const title = clean(a.innerText || a.textContent);
   // Entri navigasi bukan artikel Info Terbaru.
   if (['dosen', 'kalender', 'kurikulum'].includes(title.toLowerCase())) continue;
   if (u.protocol !== 'https:' || u.hostname !== 'baak.universitasmulia.ac.id' || u.pathname === '/' || !title || seen.has(u.href)) continue;
   if (/\/(category|tag|author|page)\//.test(u.pathname)) continue;
   const box = a.closest('article,.elementor-post,.post,.type-post') || a.parentElement.parentElement;
   const dateEl = box.querySelector('time,.entry-date,.posted-on,.elementor-post-date,.elementor-post__meta-data');
   const excerpt = box.querySelector('.entry-summary,.entry-content,.elementor-post__excerpt,p');
   const dateText = dateEl ? clean(dateEl.innerText || dateEl.textContent) : '';
   seen.add(u.href);
   hasil.push({judul:title,url:u.href,tanggal:dateText,ringkasan:excerpt ? clean(excerpt.innerText || excerpt.textContent).slice(0,500) : ''});
   if (hasil.length >= 12) break;
 }
 return JSON.stringify(hasil);
})()
''';

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  Future<void> _siapkan() async {
    try {
      final c = WebViewController();
      await c.setJavaScriptMode(JavaScriptMode.unrestricted);
      await c.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (r) {
          final u = Uri.tryParse(r.url);
          return u != null && u.scheme == 'https' && u.host == _sumber.host
              ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
        onPageFinished: (_) => _baca(),
        onWebResourceError: (e) {
          if (mounted && e.isForMainFrame == true) {
            setState(() { _loading = false; _error = 'Tidak dapat mengakses BAAK. Periksa koneksi internet.'; });
          }
        },
      ));
      if (!mounted) return;
      setState(() => _web = c);
      await _muat();
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Pembaca berita gagal disiapkan. Perbarui Android System WebView/Chrome.'; });
    }
  }

  Future<void> _muat() async {
    if (_web == null) { await _siapkan(); return; }
    final generasi = ++_generasi;
    setState(() { _loading = true; _error = null; });
    try {
      await _web!.clearCache();
      await _web!.loadRequest(_sumber);
      Future<void>.delayed(const Duration(seconds: 30), () {
        if (mounted && generasi == _generasi && _loading) {
          setState(() { _loading = false; _error = 'BAAK belum merespons. Coba muat ulang atau buka sumber.'; });
        }
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Gagal meminta pembaruan dari BAAK.'; });
    }
  }

  Future<void> _baca() async {
    try {
      Object? data = await _web!.runJavaScriptReturningResult(_ekstrak);
      // Android/iOS dapat mengembalikan string JSON dengan pembungkus berbeda.
      for (int i = 0; i < 3 && data is String; i++) { data = jsonDecode(data); }
      if (data is! List) throw const FormatException('Bukan daftar berita');
      final list = <Map<String, String>>[];
      for (final row in data) {
        if (row is! Map) continue;
        final judul = (row['judul']?.toString() ?? '').trim().toLowerCase();
        if (const {'dosen', 'kalender', 'kurikulum'}.contains(judul)) continue;
        final url = Uri.tryParse(row['url']?.toString() ?? '');
        if (url == null || url.scheme != 'https' || url.host != _sumber.host) continue;
        list.add({for (final k in ['judul','url','tanggal','ringkasan']) k: row[k]?.toString() ?? ''});
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (list.isEmpty) {
          _error = 'Daftar berita belum dapat dibaca. Website mungkin menolak akses atau strukturnya berubah. Buka sumber untuk melihat informasi resmi.';
        } else {
          _berita = list; _error = null; _diperiksa = DateTime.now();
        }
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Informasi BAAK belum dapat diproses. Coba muat ulang atau buka sumber.'; });
    }
  }

  Future<void> _buka(Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) { /* Tampilkan alamat bila browser tidak tersedia. */ }
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (c) => AlertDialog(
      title: const Text('Browser tidak dapat dibuka'),
      content: SelectableText('Salin dan buka alamat ini:\n$url'),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup'))],
    ));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // WebView tetap terpasang untuk memuat DOM, tanpa panel situs di UI.
      if (_web != null) SizedBox(width: 1, height: 1,
          child: ExcludeSemantics(child: IgnorePointer(child: Opacity(opacity: 0,
              child: WebViewWidget(controller: _web!))))),
      Wrap(spacing: 8, children: [
        TextButton.icon(onPressed: _loading ? null : _muat,
            icon: const Icon(Icons.refresh), label: const Text('Perbarui berita')),
        TextButton.icon(onPressed: () => _buka(_sumber),
            icon: const Icon(Icons.open_in_new), label: const Text('Sumber BAAK')),
      ]),
      if (_loading) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
      if (_error != null && _berita.isNotEmpty) const Text('Menampilkan hasil terakhir pada sesi ini; pembaruan belum berhasil.'),
      for (final berita in _berita) Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(color: Colors.white, borderRadius: BorderRadius.circular(14),
          child: InkWell(borderRadius: BorderRadius.circular(14),
            onTap: () => _buka(Uri.parse(berita['url']!)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: const Border(left: BorderSide(color: Color(0xffffcf40), width: 4)), borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(berita['judul']!, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xff143259), fontSize: 15)),
                if (berita['tanggal']!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(berita['tanggal']!, style: const TextStyle(color: Colors.grey, fontSize: 12))),
                if (berita['ringkasan']!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(berita['ringkasan']!, maxLines: 4, overflow: TextOverflow.ellipsis)),
                const SizedBox(height: 10),
                const Row(children: [Expanded(child: Text('Baca selengkapnya di BAAK', style: TextStyle(color: Color(0xff143259), fontWeight: FontWeight.w600))), Icon(Icons.open_in_new, size: 18)]),
              ]),
            ),
          ),
        ),
      ),
      if (_diperiksa != null) Text('Terakhir diperiksa: ${_diperiksa!.toLocal().toString().substring(0,16)}', style: const TextStyle(fontSize: 11)),
      const Text('Sumber: BAAK Universitas Mulia. Tanggal berita mengikuti website resmi.', style: TextStyle(fontSize: 11)),
    ],
  );
}

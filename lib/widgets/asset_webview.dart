import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

/// Menampilkan halaman web dari aset aplikasi (`assets/web/...`) di dalam
/// WebView, misalnya Beranda Biro Akademik, halaman sertifikat setiap mata
/// kuliah, kompiler, dan halaman repositori.
///
/// Tautan relatif antar halaman aset (mis. `matkul/110100.html`) tetap bekerja:
/// permintaan `file://.../assets/web/xxx.html` dialihkan ke
/// [WebViewController.loadFlutterAsset]. Tautan `http/https` dibuka di
/// peramban luar agar aman (GitHub, situs kampus, dsb.).
class AssetWebView extends StatefulWidget {
  const AssetWebView({
    super.key,
    required this.aset,
    this.judul = 'Smart Campus',
    this.bisaNavigasiAset = true,
  });

  /// Path aset, contoh `assets/web/index.html`.
  final String aset;
  final String judul;

  /// Izinkan perpindahan antar halaman aset di dalam WebView.
  final bool bisaNavigasiAset;

  @override
  State<AssetWebView> createState() => _AssetWebViewState();
}

class _AssetWebViewState extends State<AssetWebView> {
  late final WebViewController _controller;
  String _riwayatAset = '';

  @override
  void initState() {
    super.initState();
    _riwayatAset = widget.aset;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.white)
      ..addJavaScriptChannel(
        'MuliaApp',
        onMessageReceived: (JavaScriptMessage m) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(m.message.replaceAll('"', ''))),
          );
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _tanganiNavigasi,
          onPageFinished: (String url) {
            final String? aset = _asetDariUrl(url);
            if (aset != null && mounted) {
              setState(() => _riwayatAset = aset);
            }
          },
        ),
      )
      ..loadFlutterAsset(widget.aset);
  }

  /// Ubah `file:///.../assets/web/matkul/110100.html` menjadi
  /// `assets/web/matkul/110100.html`.
  String? _asetDariUrl(String url) {
    final int idx = url.indexOf('assets/web/');
    if (idx < 0) return null;
    return Uri.decodeFull(url.substring(idx).split('#').first.split('?').first);
  }

  NavigationDecision _tanganiNavigasi(NavigationRequest req) {
    final String url = req.url;

    if (url.startsWith('http://') || url.startsWith('https://')) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }

    if (url.startsWith('data:') || url.startsWith('blob:') || url.startsWith('about:')) {
      return NavigationDecision.navigate;
    }

    if (url.contains('assets/web/')) {
      final String? aset = _asetDariUrl(url);
      final String bersih = url.split('#').first;
      // Muat ulang halaman yang sama (mis. tautan anchor) atau halaman lain.
      if (aset != null &&
          (widget.bisaNavigasiAset || aset == widget.aset) &&
          !_berkasSama(bersih)) {
        _controller.loadFlutterAsset(aset);
        if (mounted) setState(() => _riwayatAset = aset);
        return NavigationDecision.prevent;
      }
      if (aset == null || !widget.bisaNavigasiAset) {
        return NavigationDecision.prevent;
      }
    }
    return NavigationDecision.navigate;
  }

  bool _berkasSama(String url) {
    final String? aset = _asetDariUrl(url);
    return aset != null && aset == _riwayatAset;
  }

  Future<void> _muatUlang() async {
    await _controller.loadFlutterAsset(_riwayatAset);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.judul),
        actions: <Widget>[
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _muatUlang,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Kembali ke beranda web',
            onPressed: () {
              _controller.loadFlutterAsset('assets/web/index.html');
              setState(() => _riwayatAset = 'assets/web/index.html');
            },
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

/// Pembungkus penuh: halaman WebView dengan judul aplikasi.
class HalamanWeb extends StatelessWidget {
  const HalamanWeb({super.key, required this.aset, required this.judul});

  final String aset;
  final String judul;

  @override
  Widget build(BuildContext context) =>
      AssetWebView(aset: aset, judul: judul);
}

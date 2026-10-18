import 'dart:convert';

/// Kode pengguna diisolasi dalam iframe tanpa akses origin/bridge aplikasi.
String buatDokumenPreview(String html, String css, String javascript) {
  final String dokumen = '''<!doctype html><html><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
</head><body>$html</body></html>''';
  // DOM API menghindari penutupan tag style/script oleh isi editor.
  final String bootstrap = '''<script>
const d = new DOMParser().parseFromString(${jsonEncode(dokumen).replaceAll('<', r'\u003c')}, 'text/html');
const s = d.createElement('style');
s.textContent = ${jsonEncode(css).replaceAll('<', r'\u003c')};
d.head.appendChild(s);
document.open(); document.write('<!doctype html>' + d.documentElement.outerHTML); document.close();
const j = document.createElement('script');
j.textContent = ${jsonEncode(javascript).replaceAll('<', r'\u003c')};
document.body.appendChild(j);
</script>''';
  final String sumber =
  const HtmlEscape(HtmlEscapeMode.attribute).convert(bootstrap);
  return '''<!doctype html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="margin:0"><iframe title="Preview kode" sandbox="allow-scripts" srcdoc="$sumber"
style="border:0;width:100%;height:100vh;display:block"></iframe></body></html>''';
}

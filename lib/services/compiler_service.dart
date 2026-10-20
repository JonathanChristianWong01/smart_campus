import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mata_kuliah.dart';

/// Hasil eksekusi satu program pada kompiler daring.
class HasilKompilasi {
  const HasilKompilasi({
    required this.keluaran,
    required this.ok,
    this.exitCode = 0,
    this.durasiMs = 0,
    this.pesanSistem = '',
    this.offline = false,
    this.stdout = '',
  });

  final String keluaran;

  /// Keluaran standar murni, tanpa stderr / compile_output.
  final String stdout;
  final bool ok;
  final int exitCode;
  final int durasiMs;
  final String pesanSistem;

  /// `true` bila kompiler daring tidak dapat dihubungi (mis. tanpa internet).
  final bool offline;
}

/// Klien kompiler daring.
///
/// Sejak 15 Februari 2026 API publik Piston (emkc.org) **ditutup untuk umum**
/// — setiap permintaan dijawab `401 whitelist only`. Layanan yang dipakai
/// sekarang adalah **Judge0 CE** (`https://ce.judge0.com`): gratis, tanpa
/// API key, dan mendukung C++, JavaScript, PHP, serta Python.
///
/// Antarmuka kelas ini tidak berubah, sehingga [CompilerService] dapat dipakai
/// oleh layar kompiler tanpa penyesuaian lain di sisi pemanggil.
class CompilerService {
  CompilerService({http.Client? client, this.endpoint = _defaultEndpoint})
      : _client = client ?? http.Client();

  /// Judge0 mengeksekusi kode secara sinkron karena `wait=true`.
  static const String _defaultEndpoint =
      'https://ce.judge0.com/submissions?base64_encoded=true&wait=true';

  final http.Client _client;
  final String endpoint;

  /// Nomor bahasa pada Judge0 CE.
  ///
  /// Sumber: `GET https://ce.judge0.com/languages`.
  static int idJudge0(BahasaKompiler bahasa) {
    switch (bahasa.id) {
      case 'cplusplus':
        return 105; // C++ (GCC 14.1.0)
      case 'javascript':
        return 97; // JavaScript (Node.js 20.17.0)
      case 'php':
        return 98; // PHP (8.3.11)
      case 'python':
        return 92; // Python (3.11.2)
    }
    // Cadangan bila id berubah: tebak dari nama bahasa Piston.
    switch (bahasa.pistonLanguage) {
      case 'c++':
        return 105;
      case 'javascript':
        return 97;
      case 'php':
        return 98;
      case 'python':
        return 92;
    }
    return 92;
  }

  Future<HasilKompilasi> jalankan({
    required BahasaKompiler bahasa,
    required String kode,
    String stdin = '',
    Duration timeout = const Duration(seconds: 40),
  }) async {
    final Stopwatch jam = Stopwatch()..start();
    final Map<String, dynamic> body = <String, dynamic>{
      'source_code': base64Encode(utf8.encode(kode)),
      'language_id': idJudge0(bahasa),
      'stdin': base64Encode(utf8.encode(stdin)),
    };

    try {
      final http.Response res = await _client
          .post(
        Uri.parse(endpoint).replace(queryParameters: <String, String>{
          ...Uri.parse(endpoint).queryParameters,
          'base64_encoded': 'true',
          'wait': 'true',
        }),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(timeout);

      jam.stop();

      if (res.statusCode == 429) {
        return HasilKompilasi(
          keluaran: '⚠️ Server kompiler sedang membatasi permintaan '
              '(HTTP 429 — kuota harian layanan gratis tercapai).\n\n'
              'Tunggu beberapa saat lalu tekan ▶ Jalankan lagi, atau '
              'gunakan instance sendiri (lihat panduan di paket perbaikan).',
          ok: false,
          exitCode: 429,
          durasiMs: jam.elapsedMilliseconds,
          pesanSistem: 'Kuota kompiler habis',
        );
      }

      if (res.statusCode != 200) {
        return HasilKompilasi(
          keluaran: 'Server kompiler mengembalikan status ${res.statusCode}.\n'
              '${res.body}',
          ok: false,
          exitCode: res.statusCode,
          durasiMs: jam.elapsedMilliseconds,
          pesanSistem: 'Permintaan gagal',
        );
      }

      final Map<String, dynamic> json =
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final Map<String, dynamic> status =
          (json['status'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final int statusId = (status['id'] as num?)?.toInt() ?? 0;
      final String statusText = (status['description'] as String?) ?? '-';

      // Dengan base64_encoded=true, ketiga field ini berisi Base64,
      // bukan teks biasa. Byte non-UTF8 diganti U+FFFD agar tidak crash.
      String baca(String key) {
        final String encoded = (json[key] as String?) ?? '';
        if (encoded.isEmpty) return '';
        return utf8.decode(base64Decode(encoded), allowMalformed: true);
      }

      final String keluaranStd = baca('stdout');
      final String galatStd = baca('stderr');
      final String galatKompilasi = baca('compile_output');

      final StringBuffer gabung = StringBuffer();
      if (galatKompilasi.isNotEmpty) gabung.write(galatKompilasi);
      if (keluaranStd.isNotEmpty) {
        if (gabung.isNotEmpty && !gabung.toString().endsWith('\n')) {
          gabung.write('\n');
        }
        gabung.write(keluaranStd);
      }
      if (galatStd.isNotEmpty) {
        if (gabung.isNotEmpty && !gabung.toString().endsWith('\n')) {
          gabung.write('\n');
        }
        gabung.write(galatStd);
      }
      final String output = gabung.toString();

      // Judge0: status 3 = Accepted (program selesai tanpa galat).
      final bool ok = statusId == 3;

      return HasilKompilasi(
        keluaran: output.isEmpty ? '(program selesai tanpa keluaran)' : output,
        ok: ok,
        stdout: keluaranStd,
        exitCode: ok ? 0 : 1,
        durasiMs: jam.elapsedMilliseconds,
        pesanSistem: ok
            ? 'Eksekusi berhasil (Judge0 • $statusText)'
            : 'Program keluar dengan galat ($statusText)',
      );
    } on FormatException catch (e) {
      jam.stop();
      return HasilKompilasi(
        keluaran: 'Respons kompiler tidak valid (JSON/Base64): $e',
        ok: false,
        exitCode: -2,
        durasiMs: jam.elapsedMilliseconds,
        pesanSistem: 'Format respons kompiler tidak valid',
      );
    } on TimeoutException {
      jam.stop();
      return _fallback(
          bahasa, 'Waktu koneksi ke kompiler habis (timeout).', jam);
    } catch (e) {
      jam.stop();
      return _fallback(
          bahasa, 'Tidak dapat menghubungi kompiler daring: $e', jam);
    }
  }

  /// Menutup koneksi HTTP yang dipakai layanan ini.
  ///
  /// Dipanggil dari `dispose()` layar kompiler.
  void dispose() => _client.close();

  HasilKompilasi _fallback(BahasaKompiler b, String sebab, Stopwatch jam) {
    return HasilKompilasi(
      keluaran: '⚠️ Mode offline — $sebab\n\n'
          'Pelajari contoh keluaran yang diharapkan untuk ${b.label}:\n'
          '────────────────────────────\n'
          '${b.contohKeluaran}\n\n'
          'Pastikan perangkat terhubung internet, lalu tekan ▶ Jalankan lagi.',
      ok: false,
      exitCode: -1,
      durasiMs: jam.elapsedMilliseconds,
      pesanSistem: 'Offline (mode demo)',
      offline: true,
    );
  }
}

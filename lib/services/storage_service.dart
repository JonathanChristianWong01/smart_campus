import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mata_kuliah.dart';

/// Riwayat satu kali eksekusi pada kompiler daring.
class RiwayatEksekusi {
  const RiwayatEksekusi({
    required this.waktu,
    required this.bahasa,
    required this.status,
    required this.cuplikanKode,
  });

  final String waktu;
  final String bahasa;
  final String status;
  final String cuplikanKode;

  factory RiwayatEksekusi.fromJson(Map<String, dynamic> j) => RiwayatEksekusi(
    waktu: '${j['waktu'] ?? ''}',
    bahasa: '${j['bahasa'] ?? ''}',
    status: '${j['status'] ?? ''}',
    cuplikanKode: '${j['kode'] ?? ''}',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'waktu': waktu,
    'bahasa': bahasa,
    'status': status,
    'kode': cuplikanKode,
  };
}

/// Penyimpanan lokal (SharedPreferences) untuk:
/// data sertifikat, link repositori GitHub, riwayat eksekusi, dan progres.
class StorageService {
  StorageService._(this._prefs);

  final SharedPreferences _prefs;

  static const String _kSertifikat = 'mulia_cert_';
  static const String _kRepo = 'mulia_repos';
  static const String _kRiwayat = 'mulia_hist';
  static const String _kRunOk = 'mulia_run_ok';
  static const String _kOnboarding = 'mulia_onboarding_selesai';
  static const String _kNama = 'mulia_nama_mahasiswa';
  static const String _kNim = 'mulia_nim_mahasiswa';

  static Future<StorageService> buka() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return StorageService._(p);
  }

  // ---------- Identitas mahasiswa ----------
  String get namaMahasiswa => _prefs.getString(_kNama) ?? '';
  set namaMahasiswa(String v) => _prefs.setString(_kNama, v);

  String get nimMahasiswa => _prefs.getString(_kNim) ?? '';
  set nimMahasiswa(String v) => _prefs.setString(_kNim, v);

  // ---------- Onboarding ----------
  bool get onboardingSelesai => _prefs.getBool(_kOnboarding) ?? false;
  Future<void> tandaiOnboarding() => _prefs.setBool(_kOnboarding, true);

  // ---------- Sertifikat ----------
  Map<String, String> dataSertifikat(MataKuliah mk) {
    final String? raw = _prefs.getString('$_kSertifikat${mk.kode}');
    if (raw == null) {
      return <String, String>{
        'nama': namaMahasiswa,
        'nim': nimMahasiswa,
        'predikat': 'Dengan Pujian (A)',
        'tanggal': '',
      };
    }
    return Map<String, String>.from(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> simpanSertifikat(MataKuliah mk, Map<String, String> data) async {
    await _prefs.setString('$_kSertifikat${mk.kode}', jsonEncode(data));
    if ((data['nama'] ?? '').isNotEmpty) namaMahasiswa = data['nama']!;
    if ((data['nim'] ?? '').isNotEmpty) nimMahasiswa = data['nim']!;
  }

  bool sertifikatTerisi(MataKuliah mk) =>
      (dataSertifikat(mk)['nama'] ?? '').trim().isNotEmpty;

  Future<void> hapusSertifikat(MataKuliah mk) =>
      _prefs.remove('$_kSertifikat${mk.kode}');

  // ---------- Repositori GitHub ----------
  Map<String, String> get linkRepo {
    final String? raw = _prefs.getString(_kRepo);
    if (raw == null) return <String, String>{};
    return Map<String, String>.from(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> simpanLinkRepo(String kode, String url) async {
    final Map<String, String> data = linkRepo;
    if (url.trim().isEmpty) {
      data.remove(kode);
    } else {
      data[kode] = url.trim();
    }
    await _prefs.setString(_kRepo, jsonEncode(data));
  }

  String linkRepoUntuk(String kode) => linkRepo[kode] ?? '';

  // ---------- Kompiler ----------
  int get jumlahEksekusiBerhasil => _prefs.getInt(_kRunOk) ?? 0;

  Future<void> tambahEksekusiBerhasil() =>
      _prefs.setInt(_kRunOk, jumlahEksekusiBerhasil + 1);

  List<RiwayatEksekusi> get riwayat {
    final String? raw = _prefs.getString(_kRiwayat);
    if (raw == null) return <RiwayatEksekusi>[];
    return (jsonDecode(raw) as List<dynamic>)
        .map((dynamic e) =>
        RiwayatEksekusi.fromJson(Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
        .toList();
  }

  Future<void> tambahRiwayat(RiwayatEksekusi r) async {
    final List<RiwayatEksekusi> semua = <RiwayatEksekusi>[r, ...riwayat];
    final List<RiwayatEksekusi> dibatasi = semua.take(15).toList();
    await _prefs.setString(
      _kRiwayat,
      jsonEncode(dibatasi.map((RiwayatEksekusi e) => e.toJson()).toList()),
    );
  }

  Future<void> bersihkanRiwayat() => _prefs.remove(_kRiwayat);
}

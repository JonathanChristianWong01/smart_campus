/// Model data kurikulum Smart Campus Universitas Mulia.
///
/// Dipakai oleh `lib/data/curriculum_data.dart` (berkas yang dihasilkan otomatis
/// dari `tools/curriculum.json` oleh `tools/gen_web.py`).
library;

/// Satu mata kuliah pada kurikulum S1 Informatika Universitas Mulia.
class MataKuliah {
  const MataKuliah({
    required this.kode,
    required this.nama,
    required this.sks,
    required this.semester,
    this.prasyarat = '',
    this.keterangan = '',
    this.deskripsi = '',
    this.cpl = const <String>[],
    this.cpmk = const <String>[],
    this.materi = const <String>[],
    this.perangkat = '',
    this.bahasaKompiler = const <String>[],
  });

  /// Kode mata kuliah, contoh `110100`.
  final String kode;

  /// Nama mata kuliah, contoh `Algoritma dan Pemrograman`.
  final String nama;

  /// Bobot SKS.
  final int sks;

  /// Semester penawaran (1 - 8).
  final int semester;

  /// Mata kuliah prasyarat (opsional).
  final String prasyarat;

  /// Keterangan tambahan (mis. syarat KKN/Skripsi).
  final String keterangan;

  /// Deskripsi singkat mata kuliah.
  final String deskripsi;

  /// Capaian Pembelajaran Lulusan.
  final List<String> cpl;

  /// Capaian Pembelajaran Mata Kuliah.
  final List<String> cpmk;

  /// Pokok bahasan / materi per pertemuan.
  final List<String> materi;

  /// Perangkat lunak & alat praktikum.
  final String perangkat;

  /// Kode bahasa untuk praktikum di kompiler daring
  /// (`cplusplus`, `javascript`, `php`, `python`).
  final List<String> bahasaKompiler;

  /// Nama folder/berkas web sertifikat mata kuliah ini.
  String get berkasWeb => '$kode.html';

  /// URL relatif halaman web sertifikat pada aset aplikasi.
  String get asetWebSertifikat => 'assets/web/matkul/$kode.html';

  /// Link pencarian repositori GitHub untuk mata kuliah ini.
  String get linkGithub =>
      'https://github.com/search?q=${Uri.encodeComponent('$kode $nama')}&type=repositories';
}

/// Kumpulan mata kuliah dalam satu semester.
class SemesterKurikulum {
  const SemesterKurikulum({
    required this.nomor,
    required this.totalSks,
    this.catatan = '',
    this.mataKuliah = const <MataKuliah>[],
  });

  final int nomor;
  final int totalSks;
  final String catatan;
  final List<MataKuliah> mataKuliah;

  /// Jumlah SKS hasil penjumlahan mata kuliah (bisa berbeda dengan dokumen resmi).
  int get sksTerhitung =>
      mataKuliah.fold<int>(0, (int a, MataKuliah m) => a + m.sks);
}

/// Pilihan bahasa pada kompiler daring.
class BahasaKompiler {
  const BahasaKompiler({
    required this.id,
    required this.label,
    required this.pistonLanguage,
    required this.pistonVersion,
    required this.namaBerkas,
    required this.contohKode,
    required this.contohKeluaran,
  });

  final String id;
  final String label;

  /// Nama bahasa pada API Piston (mis. `c++`, `javascript`).
  final String pistonLanguage;
  final String pistonVersion;
  final String namaBerkas;
  final String contohKode;
  final String contohKeluaran;
}

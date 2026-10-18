import '../models/mata_kuliah.dart';
import 'compiler_data.dart';

/// Mata kuliah yang **benar-benar memakai praktik menulis kode**, beserta
/// bahasa yang relevan.
///
/// Sebelumnya seluruh 58 mata kuliah diberi label bahasa (JavaScript, Python,
/// PHP) — termasuk Pancasila, Bahasa Indonesia, dan Pendidikan Agama — karena
/// generator web memberi nilai bawaan ketika data tidak tersedia. Daftar ini
/// menggantikannya: hanya mata kuliah yang materinya berisi pemrograman yang
/// menampilkan praktikum kompiler.
///
/// Ingin menambah/mengurangi? Cukup ubah peta di bawah — tidak ada bagian lain
/// yang perlu disesuaikan.
///
/// Nilai yang sah: `cplusplus`, `javascript`, `php`, `python`.
const Map<String, List<String>> kPraktikumPerMk = <String, List<String>>{
  // ---------- Semester 1 ----------
  '001000': <String>['python'], // Teknologi Informasi
  '110100': <String>['cplusplus', 'python'], // Algoritma dan Pemrograman
  '110800': <String>['python'], // Logika Informatika

  // ---------- Semester 2 ----------
  '113100': <String>['cplusplus', 'javascript'], // Pemrograman Java
  '113200': <String>['cplusplus', 'javascript'], // Pemrograman Visual
  '113700': <String>['cplusplus'], // Sistem Digital
  '114100': <String>['cplusplus', 'python'], // Struktur Data
  '112400': <String>['python'], // Komunikasi Data

  // ---------- Semester 3 ----------
  '010100': <String>['python'], // Jaringan Komputer
  '010500': <String>['php', 'javascript'], // Pemrograman Web
  '010600': <String>['php', 'python'], // Sistem Basis Data
  '010700': <String>['python'], // Sistem Operasi
  '110200': <String>[
    'cplusplus',
    'javascript'
  ], // Analisis Desain Berorientasi Objek

  // ---------- Semester 4 ----------
  '010800': <String>['python'], // Statistika dan Probabilitas
  '111800': <String>['cplusplus'], // Arsitektur dan Organisasi Komputer
  '111900': <String>['cplusplus', 'javascript'], // Grafika Komputer
  '112700': <String>['python', 'cplusplus'], // Metode Numerik
  '112800': <String>['cplusplus', 'python'], // Mikrokontroller
  '112000': <String>['cplusplus', 'python'], // Internet of Things
  '113600': <String>['javascript', 'python'], // Rekayasa Perangkat Lunak
  '112200': <String>['python'], // Kecerdasan Buatan
  '113800': <String>['javascript'], // Sistem Multimedia

  // ---------- Semester 5 ----------
  '110700': <String>['python'], // Kriptografi
  '110600': <String>['python'], // Jaringan Nirkabel
  '111300': <String>['cplusplus', 'python'], // Robotika
  '111400': <String>['javascript', 'cplusplus'], // Simulasi dan Game Komputer
  '111000': <String>['javascript'], // Pemrograman Aplikasi Bergerak
  '111600': <String>['javascript', 'php'], // Teknologi Aplikasi Bergerak
  '111500': <String>['php', 'python'], // Sistem Manajemen Basis Data
  '111100': <String>['python'], // Penalaran Komputer

  // ---------- Semester 6 ----------
  '116200': <String>['python'], // Pembelajaran Mesin
  '112100': <String>['python'], // Jaringan Syaraf Tiruan
  '112500': <String>['python'], // Logika Fuzzy
  '113300': <String>['python', 'cplusplus'], // Pengolahan Citra Digital
  '116000': <String>['python'], // Sistem Pendukung Keputusan
  '112300': <String>['python'], // Komputasi Awan
  '112900': <String>[
    'javascript',
    'python'
  ], // Pemrograman Aplikasi Bergerak Lanjut
  '113000': <String>['php', 'javascript'], // Pemrograman Framework
  '113500': <String>['javascript'], // Rekayasa Aplikasi Bergerak
};

/// Kode bahasa untuk satu mata kuliah (`<String>[]` bila tidak ada praktikum).
List<String> bahasaMk(String kodeMk) =>
    kPraktikumPerMk[kodeMk] ?? const <String>[];

/// `true` bila mata kuliah ini punya praktikum di kompiler daring.
bool mkPunyaPraktikum(String kodeMk) => bahasaMk(kodeMk).isNotEmpty;

/// Daftar [BahasaKompiler] untuk satu mata kuliah.
List<BahasaKompiler> daftarBahasaMk(String kodeMk) =>
    bahasaMk(kodeMk).map(bahasaById).toList();

/// Label ringkas sebuah bahasa untuk chip: `cplusplus` → `C++`.
String labelBahasaRingkas(String id) {
  switch (id) {
    case 'cplusplus':
      return 'C++';
    case 'javascript':
      return 'JavaScript';
    case 'php':
      return 'PHP';
    case 'python':
      return 'Python';
  }
  return id;
}

/// Satu sumber belajar tambahan (video / dokumentasi / pencarian).
class SumberVideo {
  const SumberVideo({
    required this.judul,
    required this.url,
    required this.ket,
    required this.jenis,
  });

  final String judul;
  final String url;
  final String ket;

  /// `Video`, `Pencarian`, atau `Dokumentasi`.
  final String jenis;
}

/// Sumber video & dokumentasi per bahasa.
///
/// Video kursus lengkap memakai kanal **freeCodeCamp.org** (YouTube) yang stabil
/// dan gratis; tautan pencarian dipakai agar selalu tersedia video berbahasa
/// Indonesia tanpa risiko tautan mati.
const Map<String, List<SumberVideo>> kSumberVideo = <String, List<SumberVideo>>{
  'cplusplus': <SumberVideo>[
    SumberVideo(
      judul: 'C++ Tutorial for Beginners — Full Course',
      url: 'https://www.youtube.com/watch?v=vLnPwxZdW4Y',
      ket: 'freeCodeCamp.org • kursus lengkap dari nol',
      jenis: 'Video',
    ),
    SumberVideo(
      judul: 'Video C++ berbahasa Indonesia',
      url:
      'https://www.youtube.com/results?search_query=belajar+c%2B%2B+bahasa+indonesia',
      ket: 'Pencarian YouTube • pilih playlist terbaru',
      jenis: 'Pencarian',
    ),
    SumberVideo(
      judul: 'Referensi pustaka C++',
      url: 'https://cplusplus.com/doc/tutorial/',
      ket: 'cplusplus.com • tutorial & referensi',
      jenis: 'Dokumentasi',
    ),
  ],
  'javascript': <SumberVideo>[
    SumberVideo(
      judul: 'Learn JavaScript — Full Course for Beginners',
      url: 'https://www.youtube.com/watch?v=PkZNo7MFNFg',
      ket: 'freeCodeCamp.org • kursus lengkap',
      jenis: 'Video',
    ),
    SumberVideo(
      judul: 'Video JavaScript berbahasa Indonesia',
      url:
      'https://www.youtube.com/results?search_query=belajar+javascript+bahasa+indonesia',
      ket: 'Pencarian YouTube • pilih playlist terbaru',
      jenis: 'Pencarian',
    ),
    SumberVideo(
      judul: 'MDN — JavaScript Guide',
      url: 'https://developer.mozilla.org/en-US/docs/Web/JavaScript',
      ket: 'developer.mozilla.org • dokumentasi resmi',
      jenis: 'Dokumentasi',
    ),
  ],
  'php': <SumberVideo>[
    SumberVideo(
      judul: 'PHP Programming Language Tutorial — Full Course',
      url: 'https://www.youtube.com/watch?v=OK_JCtrrv-c',
      ket: 'freeCodeCamp.org • kursus lengkap',
      jenis: 'Video',
    ),
    SumberVideo(
      judul: 'Video PHP berbahasa Indonesia',
      url:
      'https://www.youtube.com/results?search_query=belajar+php+bahasa+indonesia',
      ket: 'Pencarian YouTube • pilih playlist terbaru',
      jenis: 'Pencarian',
    ),
    SumberVideo(
      judul: 'PHP Manual',
      url: 'https://www.php.net/manual/en/index.php',
      ket: 'php.net • dokumentasi resmi',
      jenis: 'Dokumentasi',
    ),
  ],
  'python': <SumberVideo>[
    SumberVideo(
      judul: 'Learn Python — Full Course for Beginners',
      url: 'https://www.youtube.com/watch?v=rfscVS0vtbw',
      ket: 'freeCodeCamp.org • kursus lengkap',
      jenis: 'Video',
    ),
    SumberVideo(
      judul: 'Video Python berbahasa Indonesia',
      url:
      'https://www.youtube.com/results?search_query=belajar+python+bahasa+indonesia',
      ket: 'Pencarian YouTube • pilih playlist terbaru',
      jenis: 'Pencarian',
    ),
    SumberVideo(
      judul: 'Python Tutorial (resmi)',
      url: 'https://docs.python.org/3/tutorial/',
      ket: 'docs.python.org • dokumentasi resmi',
      jenis: 'Dokumentasi',
    ),
  ],
};

/// Sumber video untuk satu bahasa (`<SumberVideo>[]` bila tidak dikenal).
List<SumberVideo> videoUntuk(String idBahasa) =>
    kSumberVideo[idBahasa] ?? const <SumberVideo>[];

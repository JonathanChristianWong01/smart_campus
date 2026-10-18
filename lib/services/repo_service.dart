import '../models/mata_kuliah.dart';

/// Membangun URL GitHub untuk setiap mata kuliah:
/// pencarian repositori, pembuatan repositori baru, dan tautan profil.
class RepoService {
  const RepoService._();

  /// Slug nama repositori yang disarankan, contoh:
  /// `110100-algoritma-dan-pemrograman`.
  static String namaRepo(MataKuliah mk) {
    final String slug = mk.nama
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${mk.kode}-$slug';
  }

  /// URL pencarian repositori GitHub untuk mata kuliah.
  static String urlCari(MataKuliah mk) =>
      'https://github.com/search?q=${Uri.encodeComponent('${mk.kode} ${mk.nama}')}&type=repositories';

  /// URL pembuatan repositori baru dengan nama yang sudah disarankan.
  static String urlBuatBaru(MataKuliah mk) {
    final String nama = namaRepo(mk);
    final String deskripsi = 'Tugas dan praktikum ${mk.nama} - S1 Informatika Universitas Mulia';
    return 'https://github.com/new?name=${Uri.encodeComponent(nama)}'
        '&description=${Uri.encodeComponent(deskripsi)}';
  }

  /// URL topik/pencarian tugas kuliah di GitHub.
  static String urlTopik(String topik) =>
      'https://github.com/topics/${Uri.encodeComponent(topik)}';

  /// Perintah Git untuk mengunggah tugas mata kuliah.
  static String perintahGit(MataKuliah mk, String username) {
    final String nama = namaRepo(mk);
    return <String>[
      '# 1) Siapkan repositori lokal',
      'git init',
      'git add .',
      'git commit -m "Tugas ${mk.kode} ${mk.nama} - $username"',
      '',
      '# 2) Sambungkan ke GitHub',
      'git branch -M main',
      'git remote add origin https://github.com/$username/$nama.git',
      '',
      '# 3) Kirim tugas',
      'git push -u origin main',
    ].join('\n');
  }

  /// Struktur folder tugas yang disarankan.
  static List<String> strukturFolder(MataKuliah mk) => <String>[
    '${namaRepo(mk)}/',
    '├── README.md          # ringkasan tugas & identitas mahasiswa',
    '├── docs/              # laporan, screenshot, dan jurnal praktikum',
    '├── src/               # kode sumber program',
    '└── assets/            # gambar, dataset, dan media pendukung',
  ];
}

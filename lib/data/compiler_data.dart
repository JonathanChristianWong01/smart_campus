import '../models/mata_kuliah.dart';

/// Data 4 bahasa pemrograman pada kompiler daring Smart Campus.
///
/// Versi mengikuti runtime yang tersedia pada API kompiler Piston.
const List<BahasaKompiler> kBahasaKompiler = <BahasaKompiler>[
  BahasaKompiler(
    id: 'cplusplus',
    label: 'C++',
    pistonLanguage: 'c++',
    pistonVersion: '10.2.0',
    namaBerkas: 'main.cpp',
    contohKode: '''// Kompiler C++ — Smart Campus Universitas Mulia
#include <iostream>
using namespace std;

int main() {
    cout << "Halo, Smart Campus Universitas Mulia!" << endl;
    int total = 0;
    for (int i = 1; i <= 5; i++) total += i;
    cout << "Total SKS 5 matkul pertama: " << total << endl;
    return 0;
}
''',
    contohKeluaran: 'Halo, Smart Campus Universitas Mulia!\n'
        'Total SKS 5 matkul pertama: 15',
  ),
  BahasaKompiler(
    id: 'javascript',
    label: 'JavaScript',
    pistonLanguage: 'javascript',
    pistonVersion: '18.15.0',
    namaBerkas: 'main.js',
    contohKode: '''// Kompiler JavaScript (Node.js) — Smart Campus Universitas Mulia
const mk = [
  { kode: '110100', nama: 'Algoritma dan Pemrograman', sks: 3 },
  { kode: '114100', nama: 'Struktur Data', sks: 3 },
  { kode: '010500', nama: 'Pemrograman Web', sks: 3 },
];
let total = 0;
mk.forEach(m => {
  total += m.sks;
  console.log(m.kode + ' - ' + m.nama + ' (' + m.sks + ' SKS)');
});
console.log('Total SKS: ' + total);
''',
    contohKeluaran: '110100 - Algoritma dan Pemrograman (3 SKS)\n'
        '114100 - Struktur Data (3 SKS)\n'
        '010500 - Pemrograman Web (3 SKS)\n'
        'Total SKS: 9',
  ),
  BahasaKompiler(
    id: 'php',
    label: 'PHP',
    pistonLanguage: 'php',
    pistonVersion: '8.2.3',
    namaBerkas: 'main.php',
    contohKode: '''<?php
// Kompiler PHP — Smart Campus Universitas Mulia
\$nilai = [85, 90, 78, 92, 88];
\$total = array_sum(\$nilai);
\$rata = \$total / count(\$nilai);
echo "Nilai: " . implode(', ', \$nilai) . PHP_EOL;
echo "Total: \$total | Rata-rata: \$rata" . PHP_EOL;
''',
    contohKeluaran: 'Nilai: 85, 90, 78, 92, 88\nTotal: 433  |  Rata-rata: 86.6',
  ),
  BahasaKompiler(
    id: 'python',
    label: 'Python',
    pistonLanguage: 'python',
    pistonVersion: '3.10.0',
    namaBerkas: 'main.py',
    contohKode: '''# Kompiler Python — Smart Campus Universitas Mulia
def ipk(sks_nilai):
    total_sks = sum(s for s, _ in sks_nilai)
    total_mutu = sum(s * n for s, n in sks_nilai)
    return total_mutu / total_sks

data = [(3, 4.0), (3, 3.5), (2, 3.0), (3, 4.0)]
print('IPK mahasiswa:', round(ipk(data), 2))
print('Total SKS:', sum(s for s, _ in data))
''',
    contohKeluaran: 'IPK mahasiswa: 3.73\nTotal SKS: 11',
  ),
];

/// Cari bahasa berdasarkan id (`cplusplus`, `javascript`, `php`, `python`).
BahasaKompiler bahasaById(String id) {
  return kBahasaKompiler.firstWhere(
        (BahasaKompiler b) => b.id == id,
    orElse: () => kBahasaKompiler.last,
  );
}

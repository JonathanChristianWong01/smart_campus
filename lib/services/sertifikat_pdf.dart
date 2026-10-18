import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/curriculum_data.dart';
import '../models/mata_kuliah.dart';

/// Membuat berkas PDF "Sertifikat Capaian Mata Kuliah" (A4 lanskap) yang
/// dapat langsung dicetak atau dibagikan dari perangkat Android.
///
/// Dipakai oleh `SertifikatScreen` melalui paket `printing`
/// (`Printing.layoutPdf` / `Printing.sharePdf`).
class SertifikatPdf {
  const SertifikatPdf._();

  static const PdfColor _navy = PdfColor.fromInt(0xFF07101F);
  static const PdfColor _navy2 = PdfColor.fromInt(0xFF123059);
  static const PdfColor _gold = PdfColor.fromInt(0xFFFFC93C);
  static const PdfColor _muted = PdfColor.fromInt(0xFF5B6B80);

  static String nomorSertifikat(MataKuliah mk) {
    final int tahun = DateTime.now().year;
    final String s = mk.semester.toString().padLeft(2, '0');
    return 'MU/${mk.kode}/$tahun/SC-$s';
  }

  static Future<pw.Document> dokumen({
    required MataKuliah mk,
    required String nama,
    required String nim,
    required String predikat,
  }) async {
    final pw.Document doc = pw.Document(
      title: 'Sertifikat ${mk.nama} - $nama',
      author: kUniversitas,
      subject: 'Sertifikat capaian mata kuliah ${mk.kode}',
      creator: 'Smart Campus $kUniversitas',
      // Fonta standar PDF (helvetica) agar berkas tetap kecil dan tidak
      // membutuhkan aset fonta tambahan pada perangkat Android.
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      ),
    );

    final pw.Widget pembatas = pw.Container(height: 1.4, color: _gold);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context ctx) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _navy, width: 3),
              color: PdfColors.white,
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _gold, width: 1),
              ),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 22,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: <pw.Widget>[
                  pw.Text(
                    '${kFakultas.toUpperCase()} • ${kUniversitas.toUpperCase()}',
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.6,
                      color: _muted,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'SERTIFIKAT CAPAIAN MATA KULIAH',
                    style: const pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                      color: _navy,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Certificate of Completion — Kurikulum $kKurikulumTahun',
                    style: const pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Text(
                    'Diberikan kepada',
                    style: const pw.TextStyle(fontSize: 10.5, color: _muted),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    nama.isEmpty ? 'Nama Mahasiswa' : nama,
                    style: const pw.TextStyle(
                      fontSize: 25,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy2,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pembatas,
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'NIM ${nim.isEmpty ? '—' : nim}  •  Program Studi $kProgramStudi',
                    style: const pw.TextStyle(fontSize: 10, color: _muted),
                  ),
                  pw.SizedBox(height: 14),
                  pw.ConstrainedBox(
                    constraints: const pw.BoxConstraints(maxWidth: 640),
                    child: pw.Text(
                      'telah menyelesaikan seluruh capaian pembelajaran mata kuliah '
                          '${mk.nama} (${mk.kode}) berbobot ${mk.sks} SKS pada Semester '
                          '${mk.semester} Kurikulum $kKurikulumTahun Program Studi '
                          '$kProgramStudi, $kFakultas, $kUniversitas, meliputi materi '
                          'teori, tugas terstruktur, dan praktikum'
                          '${mk.perangkat.isEmpty ? '' : ' menggunakan ${mk.perangkat}'}.',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 10.5),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Predikat: $predikat',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy2,
                    ),
                  ),
                  pw.Spacer(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: <pw.Widget>[
                      _ttd('Ketua Program Studi', kProgramStudi),
                      _seal(),
                      _ttd('Kepala Biro Akademik', kUniversitas),
                      _ttd('Dosen Pengampu', mk.nama),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'No. Sertifikat: ${nomorSertifikat(mk)}  •  Diterbitkan '
                        '${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}  •  '
                        'Smart Campus $kUniversitas v$kAppVersi',
                    style: const pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return doc;
  }

  static pw.Widget _ttd(String jabatan, String nama) {
    return pw.SizedBox(
      width: 150,
      child: pw.Column(
        children: <pw.Widget>[
          pw.Container(height: 34),
          pw.Container(height: 1, color: _navy2),
          pw.SizedBox(height: 3),
          pw.Text(
            jabatan,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            nama,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _seal() {
    return pw.Container(
      width: 62,
      height: 62,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: _gold, width: 2.6),
        color: const PdfColor.fromInt(0xFFFFF6DE),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: <pw.Widget>[
          pw.Text(
            'CAP',
            style: const pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _navy2,
            ),
          ),
          pw.Text(
            'BIRO\nAKADEMIK',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
              fontSize: 6,
              fontWeight: pw.FontWeight.bold,
              color: _navy2,
            ),
          ),
        ],
      ),
    );
  }
}

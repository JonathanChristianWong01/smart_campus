/// Penanda ini diproses aplikasi, bukan dikirim ke kompiler.
const String penandaInputProgram = '=== INPUT STDIN ===';

class ProgramDenganInput {
  const ProgramDenganInput(this.kode, this.stdin);
  final String kode;
  final String stdin;
}

/// Penanda harus menempati satu baris utuh. Komentar // dan # juga diterima.
/// Pertama kali ditemukan memisahkan kode dari seluruh sisa input.
ProgramDenganInput pisahkanProgramInput(String teks) {
  final pemisah = RegExp(
    r'^[ \t]*(?:(?://|#)[ \t]*)?=== INPUT STDIN ===[ \t]*(?:\r?\n|$)',
    multiLine: true,
  ).firstMatch(teks);
  if (pemisah == null) return ProgramDenganInput(teks, '');
  return ProgramDenganInput(
    teks.substring(0, pemisah.start),
    teks.substring(pemisah.end),
  );
}

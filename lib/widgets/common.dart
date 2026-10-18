import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Judul bagian dengan garis gradien (mengikuti gaya halaman web kampus).
class JudulBagian extends StatelessWidget {
  const JudulBagian(this.teks, {super.key, this.ikon});

  final String teks;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: <Widget>[
          if (ikon != null) ...<Widget>[
            Icon(ikon, size: 18, color: AppColors.navy700),
            const SizedBox(width: 8),
          ],
          // Judul dibatasi agar tidak meluber pada layar sempit.
          Flexible(
            flex: 8,
            child: Text(
              teks,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.navy800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            flex: 2,
            child: Divider(color: AppColors.line, thickness: 2, height: 2),
          ),
        ],
      ),
    );
  }
}

/// Header bergradien biru tua kehitaman (dipakai di Beranda).
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.judul,
    required this.subjudul,
    this.anak,
  });

  final String judul;
  final String subjudul;
  final Widget? anak;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            judul,
            style: const TextStyle(
              color: AppColors.goldLight,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subjudul,
            style: const TextStyle(
              color: Color(0xFFC8D8EE),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          if (anak != null) ...<Widget>[const SizedBox(height: 16), anak!],
        ],
      ),
    );
  }
}

/// Label kecil (chip) bergaya kampus.
class LabelChip extends StatelessWidget {
  const LabelChip(
      this.teks, {
        super.key,
        this.latar = const Color(0xFFEEF3FB),
        this.teksWarna = AppColors.navy700,
        this.garis = const Color(0xFFD5E0F2),
        this.maksLebar,
        this.maksBaris = 1,
      });

  final String teks;
  final Color latar;
  final Color teksWarna;
  final Color garis;

  /// Batas lebar chip. Bila teks lebih panjang, teks dipotong dengan elipsis
  /// sehingga baris chip tidak pernah meluber keluar layar.
  final double? maksLebar;

  /// Jumlah baris teks maksimum di dalam chip.
  final int maksBaris;

  /// Varian chip emas (mis. untuk bobot SKS / semester).
  const LabelChip.emas(
      this.teks, {
        super.key,
        this.maksLebar,
        this.maksBaris = 1,
      })  : latar = const Color(0xFFFFF5D9),
        teksWarna = const Color(0xFF8A6100),
        garis = const Color(0xFFF5DE9A);

  /// Varian chip hijau (mis. status berhasil).
  const LabelChip.hijau(
      this.teks, {
        super.key,
        this.maksLebar,
        this.maksBaris = 1,
      })  : latar = const Color(0xFFE4F7F2),
        teksWarna = const Color(0xFF0F6B58),
        garis = const Color(0xFFB9E9DF);

  @override
  Widget build(BuildContext context) {
    final Widget label = Text(
      teks,
      maxLines: maksBaris,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: teksWarna,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: latar,
        border: Border.all(color: garis),
        borderRadius: BorderRadius.circular(999),
      ),
      child: maksLebar == null
          ? label
          : ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maksLebar!),
        child: label,
      ),
    );
  }
}

/// Kartu putih standar dengan sudut membulat dan garis aksen kiri.
class KartuPutih extends StatelessWidget {
  const KartuPutih({
    super.key,
    required this.anak,
    this.aksen = AppColors.navy700,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  final Widget anak;
  final Color aksen;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: aksen, width: 4)),
            ),
            child: anak,
          ),
        ),
      ),
    );
  }
}

/// Kotak catatan (info penting) bergaya biru muda.
class KotakCatatan extends StatelessWidget {
  const KotakCatatan(this.anak, {super.key, this.ikon = Icons.info_outline});

  final Widget anak;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC8D8EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(ikon, size: 18, color: AppColors.navy700),
          const SizedBox(width: 9),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(
                  fontSize: 12.4, color: AppColors.navy700, height: 1.5),
              child: anak,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tabel sederhana untuk identitas mata kuliah.
class TabelIdentitas extends StatelessWidget {
  const TabelIdentitas(this.baris, {super.key});

  final List<List<String>> baris;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < baris.length; i++)
            Container(
              decoration: BoxDecoration(
                border: i == baris.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: AppColors.line)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 118,
                    child: Text(
                      baris[i][0],
                      style: const TextStyle(
                        fontSize: 12.3,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      baris[i][1],
                      style:
                      const TextStyle(fontSize: 12.6, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

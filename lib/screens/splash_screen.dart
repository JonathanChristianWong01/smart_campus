import 'package:flutter/material.dart';

import '../data/curriculum_data.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart';

/// Layar pembuka: logo, identitas kampus, lalu lanjut ke [HomeShell].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _lanjut();
  }

  Future<void> _lanjut() async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext c) => HomeShell(storage: widget.storage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const Spacer(),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x55FFC93C),
                      blurRadius: 26,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'M',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy900,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'SMART CAMPUS',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                kUniversitas.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '$kFakultas • $kProgramStudi\nKurikulum $kKurikulumTahun',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFA9C0DD),
                  fontSize: 12.4,
                  height: 1.6,
                ),
              ),
              const Spacer(),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Menyiapkan kurikulum, sertifikat, kompiler & repositori…',
                style: TextStyle(color: Color(0xFF7E96B8), fontSize: 11.6),
              ),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }
}

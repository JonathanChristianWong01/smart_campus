import 'package:flutter/material.dart';

import 'data/curriculum_data.dart';
import 'screens/login_gate.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

/// Aplikasi Smart Campus Universitas Mulia.
class SmartCampusApp extends StatelessWidget {
  const SmartCampusApp({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Campus $kUniversitas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: SplashScreen(storage: storage),
      routes: <String, WidgetBuilder>{
        '/beranda': (BuildContext c) => LoginGate(storage: storage),
      },
    );
  }
}

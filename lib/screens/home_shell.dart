import 'package:flutter/material.dart';

import '../data/curriculum_data.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'compiler_screen.dart';
import 'home_screen.dart';
import 'kurikulum_screen.dart';
import 'repository_screen.dart';

/// Kerangka utama aplikasi dengan 5 menu bawah:
/// Beranda, Kurikulum, Kompiler, Repositori, dan Info.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.storage});

  final StorageService storage;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> halaman = <Widget>[
      HomeScreen(storage: widget.storage, onGantiTab: (int i) => setState(() => _tab = i)),
      KurikulumScreen(storage: widget.storage),
      CompilerScreen(storage: widget.storage),
      RepositoryScreen(storage: widget.storage),
      const AboutScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                'M',
                style: TextStyle(
                  color: AppColors.navy900,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('SMART CAMPUS', style: TextStyle(fontSize: 14, height: 1.1)),
                Text(
                  kUniversitas,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    color: Color(0xFFA9C0DD),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Web Biro Akademik (halaman lengkap)',
            icon: const Icon(Icons.public),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Buka tab Beranda → Layanan → Web Biro Akademik'),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: halaman),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        height: 66,
        onDestinationSelected: (int i) => setState(() => _tab = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Kurikulum',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: 'Kompiler',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: 'Repositori',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Info',
          ),
        ],
      ),
    );
  }
}

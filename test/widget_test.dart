// Uji dasar aplikasi Smart Campus Universitas Mulia:
// memastikan data kurikulum utuh, model benar, dan Beranda tampil setelah splash.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mulia_smart_campus/app.dart';
import 'package:mulia_smart_campus/data/curriculum_data.dart';
import 'package:mulia_smart_campus/models/mata_kuliah.dart';
import 'package:mulia_smart_campus/services/repo_service.dart';
import 'package:mulia_smart_campus/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Kurikulum berisi 8 semester, 58 mata kuliah, dan tiap MK punya data lengkap',
          () {
        expect(kKurikulum.length, 8);
        expect(kSemuaMataKuliah.length, 58);
        for (final MataKuliah mk in kSemuaMataKuliah) {
          expect(mk.kode.length, 6, reason: 'Kode MK harus 6 digit: ${mk.kode}');
          expect(mk.sks, greaterThan(0));
          expect(mk.deskripsi.isNotEmpty, isTrue);
          expect(mk.materi.isNotEmpty, isTrue);
          expect(mk.cpl.isNotEmpty, isTrue);
          expect(mk.semester, inInclusiveRange(1, 8));
          expect(mk.asetWebSertifikat, 'assets/web/matkul/${mk.kode}.html');
        }
        expect(totalSksKurikulum, 168);
      });

  test('Pencarian kode mata kuliah & nama repo GitHub', () {
    final MataKuliah? mk = mataKuliahByKode('110100');
    expect(mk, isNotNull);
    expect(mk!.nama, 'Algoritma dan Pemrograman');
    expect(RepoService.namaRepo(mk), '110100-algoritma-dan-pemrograman');
    expect(RepoService.urlCari(mk), contains('github.com/search'));
  });

  testWidgets('Splash tampil lalu Beranda tampil', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final StorageService storage = await StorageService.buka();

    await tester.pumpWidget(SmartCampusApp(storage: storage));
    expect(find.text('SMART CAMPUS'), findsOneWidget);

    // Lewati splash (1,6 detik) tanpa pumpAndSettle (ada animasi berulang).
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Biro Akademik'), findsWidgets);
    expect(find.text('Beranda'), findsWidgets);
  });
}

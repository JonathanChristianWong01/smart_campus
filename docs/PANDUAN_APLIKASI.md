# Panduan Smart Campus

## Pembuat
- Nama: Jonathan Christian Wong
- NIM: 2411015
- Kelas: IFB5A

## Fitur
- Informasi kurikulum dan detail mata kuliah.
- Sertifikat mata kuliah dan ekspor PDF.
- Kompiler C++, Python, PHP, dan JavaScript.
- Preview Web.
- Penyimpanan tautan repositori tugas.

## Menjalankan proyek
1. Pasang Flutter SDK dan Android Studio.
2. Jalankan `flutter pub get`.
3. Hubungkan perangkat Android.
4. Jalankan `flutter run`.

## Koneksi internet
Eksekusi kode melalui Judge0 memerlukan internet.
Preview HTML/CSS/JavaScript lokal tidak memakai Judge0.

## Membuat APK Android

Jalankan perintah berikut dari folder proyek:

    flutter pub get
    flutter analyze
    flutter test
    flutter build apk --release

APK hasil build berada di:

    build/app/outputs/flutter-apk/app-release.apk

Jangan mengunggah keystore, password signing,
atau android/key.properties ke repository.

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'campus_auth_api.dart';
import 'local_academic_store.dart';
import '../data/curriculum_data.dart';

/// Demo satu perangkat. JSON dan lampiran tidak dienkripsi.
class LocalTaskFiles {
  LocalTaskFiles(this.api, {this.documentsDirectory, this.clock});
  final DateTime Function()? clock;
  DateTime get _now => (clock ?? DateTime.now)();
  final Future<Directory> Function()? documentsDirectory;
  final CampusAuthApi api;
  static const key = 'smart_campus_tasks_files_v1';
  static Future<void> _tail = Future<void>.value();

  Future<Map<String, dynamic>> _actor() async {
    await api.request('GET', '/materials'); // Memvalidasi sesi/akun aktif.
    final actor = api.user;
    if (actor == null) throw Exception('Silakan login kembali.');
    return Map<String, dynamic>.from(actor);
  }

  Future<List<Map<String, dynamic>>> _all() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null) return [];
    final data = jsonDecode(raw);
    if (data is! List) throw Exception('Data tugas rusak; jangan hapus data aplikasi.');
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  bool _visible(Map r, Map actor, List<Map<String, dynamic>> all) {
    if (r['kind'] != 'submission') return true;
    if (actor['role'] == 'admin' || r['owner'] == actor['id']) return true;
    return actor['role'] == 'Dosen' && all.any((t) => t['id'] == r['parent'] && t['owner'] == actor['id']);
  }

  Future<List<Map<String, dynamic>>> list() async {
    final a = await _actor();
    final all = await _all();
    return all.where((r) => _visible(r, a, all)).toList().reversed.toList();
  }

  Future<String> author(Map row) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(CampusAuthApi.storageKey);
    if (raw == null) return 'Akun dihapus';
    final users = (jsonDecode(raw) as Map)['users'] as List;
    for (final u in users) {
      if (u['id'] == row['owner']) return u['username'] as String;
    }
    return 'Akun dihapus';
  }

  Future<void> save({required String kind, required String code,
    required String title, required String text, String? parent, DateTime? deadline,
    String? editId, String? expectedVersion, List<String> keepPaths = const [],
    required List<Map<String, String>> files}) {
    final future = _tail.then((_) async {
      final a = await _actor();
      final all = await _all();
      Map<String, dynamic>? previous;
      if (editId != null) {
        final matches = all.where((r) => r['id'] == editId);
        if (matches.isEmpty) throw Exception('Data sudah dihapus. Muat ulang daftar.');
        previous = matches.first;
        if (previous['kind'] != kind || previous['parent'] != parent) throw Exception('Jenis/induk data tidak boleh diubah.');
        final allowed = kind == 'submission'
            ? a['role'] == 'Mahasiswa' && previous['owner'] == a['id']
            : a['role'] == 'admin' || (a['role'] == 'Dosen' && previous['owner'] == a['id']);
        if (!allowed) throw Exception('Tidak berhak mengedit data ini.');
        if (expectedVersion != null && (previous['updated'] ?? previous['created']) != expectedVersion) {
          throw Exception('Data sudah berubah. Buka ulang sebelum mengedit.');
        }
        if (kind == 'task' && previous['code'] != code && all.any((r) => r['parent'] == editId)) {
          throw Exception('MK tugas yang sudah memiliki pengumpulan tidak boleh dipindah.');
        }
      }
      final oldDeadline = previous?['deadline'];
      final deadlineChanged = deadline?.toUtc().toIso8601String() != oldDeadline;
      if (kind != 'submission' && deadline != null && !deadline.isAfter(_now) && (previous == null || deadlineChanged)) {
        throw Exception('Deadline baru harus setelah waktu sekarang.');
      }
      final retained = <Map<String, dynamic>>[];
      final oldFiles = previous == null ? <dynamic>[] : previous['files'] as List;
      for (final path in keepPaths.toSet()) {
        final found = oldFiles.where((f) => f['path'] == path);
        if (found.isEmpty) throw Exception('Lampiran lama tidak cocok dengan data ini.');
        retained.add(Map<String, dynamic>.from(found.first as Map));
      }
      void checkDeadline() {
        if (kind != 'submission') return;
        final task = all.firstWhere((r) => r['id'] == parent && r['kind'] == 'task');
        final raw = task['deadline'];
        if (raw == null) return;
        final limit = DateTime.tryParse(raw.toString());
        if (limit == null) throw Exception('Deadline tugas tidak valid. Hubungi pembuat tugas.');
        if (!_now.isBefore(limit)) throw Exception('Deadline telah berakhir. Pengumpulan ditutup.');
      }
      if (kind == 'submission') {
        if (a['role'] != 'Mahasiswa') throw Exception('Hanya Mahasiswa mengumpulkan tugas.');
        if (!all.any((r) => r['id'] == parent && r['kind'] == 'task' && r['code'] == code)) {
          throw Exception('Tugas sudah tidak tersedia.');
        }
        checkDeadline();
        if (all.any((r) => r['parent'] == parent && r['owner'] == a['id'] && r['id'] != editId)) {
          throw Exception('Anda sudah mengumpulkan. Gunakan Edit pada jawaban sendiri sebelum deadline.');
        }
      } else if (!['material', 'task'].contains(kind) || !['admin', 'Dosen'].contains(a['role'])) {
        throw Exception('Hanya Dosen/Admin membuat materi dan tugas.');
      }
      if (code.isEmpty || title.trim().isEmpty || (text.trim().isEmpty && files.isEmpty && retained.isEmpty)) {
        throw Exception('Pilih MK, isi judul, dan tambahkan teks atau lampiran.');
      }
      if (!kSemuaMataKuliah.any((m) => m.kode == code) || title.length > 160 || text.length > 20000) {
        throw Exception('MK tidak valid atau isian melebihi batas.');
      }
      if (files.length + retained.length > 10) throw Exception('Maksimal 10 lampiran.');
      final id = editId ?? DateTime.now().microsecondsSinceEpoch.toString();
      final root = await (documentsDirectory?.call() ?? getApplicationDocumentsDirectory());
      final folder = Directory('${root.path}/smart_campus_files/$id/rev_${DateTime.now().microsecondsSinceEpoch}');
      final saved = <Map<String, dynamic>>[...retained];
      try {
        await folder.create(recursive: true);
        int total = 0;
        for (final retainedFile in retained) {
          final kept = File(retainedFile['path'] as String);
          if (!await kept.exists()) throw Exception('Lampiran lama hilang. Lepas lampiran yang hilang lalu simpan ulang.');
          final length = await kept.length();
          if (length > 50 * 1024 * 1024) throw Exception('Lampiran melebihi batas 50 MB.');
          total += length;
        }
        if (total > 200 * 1024 * 1024) throw Exception('Total lampiran melebihi 200 MB.');
        for (int i = 0; i < files.length; i++) {
          final f = files[i];
          final source = File(f['path']!);
          final size = await source.length();
          total += size;
          if (size > 50 * 1024 * 1024 || total > 200 * 1024 * 1024) {
            throw Exception('Maksimal 50 MB per file dan 200 MB per pengiriman.');
          }
          final name = f['name']!.replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_');
          final dest = '${folder.path}/${i}_$name';
          await source.copy(dest);
          saved.add({'name': f['name'], 'path': dest, 'type': f['type'], 'bytes': size});
        }
        checkDeadline(); // Cek ulang setelah proses salin lampiran.
        final updated = <String, dynamic>{'id': id, 'kind': kind, 'code': code, 'title': title.trim(),
          'text': text, 'parent': parent, 'owner': previous?['owner'] ?? a['id'],
          'deadline': kind == 'submission' ? null : deadline?.toUtc().toIso8601String(),
          'created': previous?['created'] ?? _now.toIso8601String(),
          'updated': _now.toIso8601String(), 'files': saved,
          if(kind=='submission'&&previous!=null&&previous['assessment']!=null) 'assessment':{...Map<String,dynamic>.from(previous['assessment'] as Map),'needsReview':true}};
        if (previous == null) { all.add(updated); }
        else { all[all.indexOf(previous)] = updated; }
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(key, jsonEncode(all))) throw Exception('Penyimpanan gagal.');
        // Metadata sudah berhasil disimpan. Cleanup tidak boleh membatalkan edit.
        for (final old in oldFiles) {
          if (retained.any((f) => f['path'] == old['path'])) continue;
          try {
            final oldFile = File(old['path'] as String);
            if (oldFile.path.startsWith('${root.path}/smart_campus_files/$id/') && await oldFile.exists()) {
              await oldFile.delete();
            }
          } catch (_) { /* Salinan yatim dapat dibersihkan saat seluruh data dihapus. */ }
        }
      } catch (_) {
        if (await folder.exists()) await folder.delete(recursive: true);
        rethrow;
      }
    });
    _tail = future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return future;
  }

  Future<Map<String,dynamic>> _gradingContext(String id) async {
    final actor=await _actor();final all=await _all();
    final submission=all.firstWhere((r)=>r['id']==id&&r['kind']=='submission',orElse:()=>throw Exception('Pengumpulan tidak ditemukan.'));
    final task=all.firstWhere((r)=>r['id']==submission['parent']&&r['kind']=='task',orElse:()=>throw Exception('Tugas tidak tersedia.'));
    if(!_visible(submission,actor,all)||!['Dosen','admin'].contains(actor['role'])) throw Exception('Tidak berhak menilai pengumpulan.');
    if(task['code']!=submission['code']) throw Exception('MK pengumpulan tidak sesuai tugas.');
    final prefs=await SharedPreferences.getInstance();final raw=prefs.getString(CampusAuthApi.storageKey);
    final users=raw==null?<dynamic>[]:(jsonDecode(raw) as Map)['users'] as List;
    if(!users.any((u)=>u['id']==submission['owner']&&u['role']=='Mahasiswa'&&u['active']==1&&u['approved']==1)) throw Exception('Akun Mahasiswa tidak aktif.');
    return {'actor':actor,'all':all,'submission':submission,'task':task};
  }
  Future<void> assessSubmission(String id,String score,String note,{required String expectedVersion,String? expectedAssessment,String? letter}) {
    final future=_tail.then((_)async{
      final context=await _gradingContext(id);final actor=context['actor'] as Map;final task=context['task'] as Map;
      if(actor['role']!='Dosen'||task['owner']!=actor['id']) throw Exception('Nilai tugas hanya diisi Dosen pembuat tugas. Admin hanya memantau nilai tugas.');
      final r=context['submission'] as Map;
      if((r['updated']??r['created'])!=expectedVersion||(r['assessment'] as Map?)?['graded']!=expectedAssessment) throw Exception('Jawaban/nilai sudah berubah. Muat ulang sebelum menilai.');
      final value=double.tryParse(score.replaceAll(',','.'));
      if(value==null||!value.isFinite||value<0||value>100||note.length>1000) throw Exception('Nilai tugas harus 0–100, catatan maksimal 1000 karakter.');
      final oldAssessment=r['assessment'] as Map?;
      final taskLetter=(letter??oldAssessment?['letter']?.toString()??'').trim().toUpperCase();
      if(taskLetter.length>4) throw Exception('Nilai huruf tugas maksimal 4 karakter, misalnya A, A- atau B+.');
      r['assessment']={'letter':taskLetter,'score':value,'note':note.trim(),'by':actor['id'],'graded':DateTime.now().toIso8601String(),'submissionVersion':r['updated']??r['created'],'needsReview':false};
      final prefs=await SharedPreferences.getInstance();
      if(!await prefs.setString(key,jsonEncode(context['all']))) throw Exception('Gagal menyimpan nilai tugas.');
    });
    _tail=future.then<void>((_) {},onError:(Object _,StackTrace __){});return future;
  }
  Future<List<Map<String,dynamic>>> finalGradeOptions(String id) async {
    final context=await _gradingContext(id);final submission=context['submission'] as Map;
    final academic=await LocalAcademicStore(api).view();final actor=academic['actor'] as Map;
    final grades=academic['grades'] as List;
    return (academic['classes'] as List).where((c)=>c['code']==submission['code']&&
        (actor['role']=='admin'||c['teacher']==actor['id'])&&
        ((academic['rosters'][c['id']] as List?)??[]).contains(submission['owner'])).map((c){
      final previous=grades.where((r)=>r['class']==c['id']&&r['student']==submission['owner']);
      return <String,dynamic>{...Map<String,dynamic>.from(c as Map),'currentGrade':previous.isEmpty?null:previous.first};
    }).toList();
  }
  Future<void> saveFinalGradeFromSubmission(String id,String classId,String score,String letter,String note,{required String expectedVersion}) {
    final future=_tail.then((_)async{
      final context=await _gradingContext(id);final submission=context['submission'] as Map;
      if((submission['updated']??submission['created'])!=expectedVersion) throw Exception('Jawaban sudah berubah. Muat ulang pengumpulan.');
      final choices=await finalGradeOptions(id);
      if(!choices.any((c)=>c['id']==classId)) throw Exception('Kelas harus sesuai MK, kewenangan pengampu/Admin, dan KRS disetujui Mahasiswa.');
      await LocalAcademicStore(api).grade(classId,submission['owner'] as int,score,letter,note);
    });
    _tail=future.then<void>((_) {},onError:(Object _,StackTrace __){});return future;
  }

  Future<void> remove(String id) {
    final future = _tail.then((_) => _remove(id));
    _tail = future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return future;
  }

  Future<void> _remove(String id) async {
    final a = await _actor();
    final all = await _all();
    final row = all.firstWhere((r) => r['id'] == id);
    if (a['role'] != 'admin' && row['owner'] != a['id']) throw Exception('Tidak berhak menghapus.');
    // Pertahankan jawaban agar tidak terhapus tanpa sengaja.
    if (row['kind'] == 'task' && all.any((r) => r['parent'] == id)) {
      throw Exception('Tugas memiliki pengumpulan; hapus pengumpulan dahulu bila memang diperlukan.');
    }
    all.remove(row);
    final p = await SharedPreferences.getInstance();
    if (!await p.setString(key, jsonEncode(all))) throw Exception('Gagal menghapus.');
    final root = await (documentsDirectory?.call() ?? getApplicationDocumentsDirectory());
    final folder = Directory('${root.path}/smart_campus_files/$id');
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  Future<void> openAttachment(Map row, Map file) async {
    final a = await _actor();
    final all = await _all();
    final current = all.firstWhere((r) => r['id'] == row['id']);
    if (!_visible(current, a, all)) throw Exception('Akses ditolak.');
    if (!(current['files'] as List).any((f) => f['path'] == file['path'])) throw Exception('Lampiran tidak dikenal.');
    if (!await File(file['path'] as String).exists()) throw Exception('Berkas tidak ditemukan.');
  }
}

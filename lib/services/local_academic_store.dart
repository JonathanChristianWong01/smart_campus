import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/curriculum_data.dart';
import 'campus_auth_api.dart';

/// Demo lokal; bukan pengganti SIAM atau sistem akademik resmi.
class LocalAcademicStore {
  LocalAcademicStore(this.api, {this.documentsDirectory});
  final CampusAuthApi api;
  final Future<Directory> Function()? documentsDirectory;
  static const key = 'smart_campus_academic_v1';
  static Future<void> _tail = Future<void>.value();
  Map<String,dynamic> _empty() => {'profiles':<String,dynamic>{},'pa':<String,dynamic>{},'classes':[],'krs':[],'attendance':[],'grades':[],'guidance':[]};
  Future<Map<String,dynamic>> _data() async {
    final p = await SharedPreferences.getInstance(); final raw = p.getString(key);
    if (raw == null) return _empty();
    final d = Map<String,dynamic>.from(jsonDecode(raw) as Map);
    if (d['profiles'] is! Map || d['pa'] is! Map || ['classes','krs','attendance','grades','guidance'].any((k) => d[k] is! List)) {
      throw Exception('Data akademik tidak valid. Jangan hapus data aplikasi.');
    }
    return d;
  }
  Future<Map<String,dynamic>> _actor() async => Map<String,dynamic>.from(await api.request('GET','/auth/me') as Map);
  Future<List<Map<String,dynamic>>> _users() async {
    final p = await SharedPreferences.getInstance(); final raw = p.getString(CampusAuthApi.storageKey);
    if (raw == null) throw Exception('Data akun tidak ditemukan.');
    return ((jsonDecode(raw) as Map)['users'] as List).where((u) => u['active']==1 && u['approved']==1).map((u) => <String,dynamic>{'id':u['id'],'username':u['username'],'role':u['role']}).toList();
  }
  bool _admin(Map a) => a['role']=='admin';
  bool _pa(Map d, Map a, int student) => a['role']=='Dosen' && d['pa']['$student']==a['id'];
  List<Map<String,dynamic>> _rows(Map d,String key) => (d[key] as List).map((r)=>Map<String,dynamic>.from(r as Map)).toList();
  Map<String,dynamic> _class(Map d,String id) => _rows(d,'classes').firstWhere((c)=>c['id']==id,orElse:()=>throw Exception('Kelas tidak ditemukan.'));
  bool _teacher(Map d,Map a,String classId) => a['role']=='Dosen' && _class(d,classId)['teacher']==a['id'];
  bool _enrolled(Map d,int student,String classId) => _rows(d,'krs').any((r)=>r['student']==student && r['status']=='approved' && (r['classes'] as List).contains(classId));
  dynamic _recipient(Map d,Map r)=>r['requestedTeacher']??d['pa']['${r['student']}'];
  bool _canReview(Map d,Map a,Map r)=>a['role']=='Dosen'&&_recipient(d,r)==a['id'];
  bool _selectedAttendance(Map d,Map a,int student,String classId)=>a['role']=='Dosen'&&_rows(d,'krs').any((r)=>
  r['student']==student&&r['status']=='approved'&&r['requestedTeacher']==a['id']&&r['reviewer']==a['id']&&(r['classes'] as List).contains(classId));
  bool _canAttend(Map d,Map a,int student,String classId)=>(_teacher(d,a,classId)&&_enrolled(d,student,classId))||_selectedAttendance(d,a,student,classId);
  static int _lastGeneratedId=0;
  String _id() {
    final now=DateTime.now().microsecondsSinceEpoch;
    _lastGeneratedId=now>_lastGeneratedId?now:_lastGeneratedId+1;
    return _lastGeneratedId.toString();
  }
  Future<void> _write(Future<void> Function(Map<String,dynamic>,Map<String,dynamic>,List<Map<String,dynamic>>) op) {
    final f = _tail.then((_) async {
      final a = await _actor(); final users = await _users(); final d = await _data();
      // Prevent collisions on platforms with coarse clock resolution and after restart.
      for(final name in ['classes','krs','guidance']){
        for(final row in d[name] as List){
          final id=int.tryParse('${row['id']}');
          if(id!=null&&id>_lastGeneratedId)_lastGeneratedId=id;
        }
      }
      await op(d,a,users);
      final p = await SharedPreferences.getInstance();
      if (!await p.setString(key,jsonEncode(d))) throw Exception('Gagal menyimpan data akademik.');
    });
    _tail = f.then<void>((_) {},onError:(Object _,StackTrace __){}); return f;
  }
  String _text(dynamic v,int max,{bool required=false}) {
    final s = (v?.toString()??'').trim();
    if ((required && s.isEmpty)||s.length>max) throw Exception('Isian wajib kosong atau terlalu panjang (maksimal $max).');
    return s;
  }
  Future<Map<String,dynamic>> view() async {
    final a = await _actor(); final users = await _users(); final d = await _data();
    final advisedClasses = _rows(d,'krs').where((r)=>_pa(d,a,r['student'] as int)||_canReview(d,a,r)).expand((r)=>(r['classes'] as List).cast<String>()).toSet();
    final classes = _rows(d,'classes').where((c)=>_admin(a)||a['role']=='Mahasiswa'||c['teacher']==a['id']||advisedClasses.contains(c['id'])).toList();
    final rosters = <String,List<int>>{};
    for (final c in classes) {
      if (!_admin(a) && c['teacher']!=a['id']) continue;
      rosters[c['id'] as String] = users.where((u)=>u['role']=='Mahasiswa' && _enrolled(d,u['id'] as int,c['id'] as String)).map((u)=>u['id'] as int).toList();
    }
    final attendanceRosters=<String,List<int>>{};
    for(final c in classes){
      attendanceRosters[c['id'] as String]=users.where((u)=>u['role']=='Mahasiswa'&&(_admin(a)?_enrolled(d,u['id'] as int,c['id'] as String):_canAttend(d,a,u['id'] as int,c['id'] as String))).map((u)=>u['id'] as int).toList();
    }
    final visibleIds = <int>{a['id'] as int};
    for(final c in classes){visibleIds.add(c['teacher'] as int);}
    if (_admin(a)) { visibleIds.addAll(users.map((u)=>u['id'] as int)); }
    if (a['role']=='Dosen') {
      visibleIds.addAll(users.where((u)=>_pa(d,a,u['id'] as int)).map((u)=>u['id'] as int));
      for (final ids in [...rosters.values,...attendanceRosters.values]) { visibleIds.addAll(ids); }
      visibleIds.addAll(_rows(d,'krs').where((r)=>_canReview(d,a,r)).map((r)=>r['student'] as int));
    }
    if (a['role']=='Mahasiswa') {
      for (final c in classes) { visibleIds.add(c['teacher'] as int); }
      visibleIds.addAll(users.where((u)=>u['role']=='Dosen').map((u)=>u['id'] as int));
      final pa = d['pa']['${a['id']}']; if (pa is int) visibleIds.add(pa);
    }
    final krs = _rows(d,'krs').where((r)=>_admin(a)||r['student']==a['id']||_pa(d,a,r['student'] as int)||_canReview(d,a,r)).toList();
    for(final r in krs){final target=_recipient(d,r);if(target is int)visibleIds.add(target);}
    bool recordVisible(Map r) => _admin(a)||r['student']==a['id']||_teacher(d,a,r['class'] as String);
    return {'paCandidates':<Map<String,dynamic>>[],
      'actor':a,'users':users.where((u)=>visibleIds.contains(u['id'])).toList(),
      'profiles':{for(final entry in (d['profiles'] as Map).entries) if(visibleIds.contains(int.tryParse(entry.key.toString()))) entry.key:entry.value},
      'pa':{for(final entry in (d['pa'] as Map).entries) if(_admin(a)||visibleIds.contains(int.tryParse(entry.key.toString()))) entry.key:entry.value},
      'classes':classes,'rosters':rosters,'attendanceRosters':attendanceRosters,'krs':krs,
      'reviewTargets':{for(final r in krs) r['id']:_recipient(d,r)},
      'attendance':_rows(d,'attendance').where((r)=>recordVisible(r)||_selectedAttendance(d,a,r['student'] as int,r['class'] as String)).toList(),
      'grades':_rows(d,'grades').where(recordVisible).toList(),
      'guidance':_rows(d,'guidance').where((r)=>_admin(a)||r['student']==a['id']||_pa(d,a,r['student'] as int)).toList()};
  }
  Future<void> profile(int id,Map<String,dynamic> input,{String? photoPath,bool removePhoto=false}) async {
    String? copied;
    try {
      await _write((d,a,users) async {
        final target = users.firstWhere((u)=>u['id']==id,orElse:()=>throw Exception('Akun tidak aktif.'));
        final own = id==a['id']; final academic = _admin(a)||_pa(d,a,id);
        if (!own && !academic) throw Exception('Tidak berhak mengubah profil.');
        final old = Map<String,dynamic>.from(d['profiles']['$id'] as Map? ?? {});
        final row = Map<String,dynamic>.from(old);
        if (own || _admin(a)) {
          for (final k in ['name','skills','bio','email','phone','faculty','lecturerId','position','nim']) {
            row[k]=_text(input[k], k=='bio'?2000:k=='skills'?1000:160);
          }
          if ((row['name'] as String).isEmpty) throw Exception('Nama wajib diisi.');
          if (target['role']=='Mahasiswa') {
            if ((row['nim'] as String).isEmpty || (row['skills'] as String).isEmpty || (row['bio'] as String).isEmpty) throw Exception('NIM, skill, dan deskripsi Mahasiswa wajib diisi.');
            final sem = int.tryParse('${input['semester']}');
            if (sem==null||sem<1||sem>14) throw Exception('Semester harus 1–14.');
            row['semester']=sem;
            for (final entry in (d['profiles'] as Map).entries) {
              if (entry.key!='$id' && (entry.value as Map)['nim']==row['nim']) throw Exception('NIM sudah dipakai akun lain.');
            }
          }
          if (removePhoto) row.remove('photo');
          if (photoPath!=null) {
            final f=File(photoPath); if(await f.length()>10*1024*1024) throw Exception('Foto maksimal 10 MB.');
            final root=await (documentsDirectory?.call()??getApplicationDocumentsDirectory());
            final dir=Directory('${root.path}/academic_profiles'); await dir.create(recursive:true);
            copied='${dir.path}/${id}_${_id()}.jpg'; await f.copy(copied!); row['photo']=copied;
          }
        }
        if (target['role']=='Mahasiswa' && input.containsKey('gpa') && '${input['gpa']}'.trim().isNotEmpty) {
          if (!academic) {
            if ('${old['gpa']??''}'!='${input['gpa']}') throw Exception('IPK hanya diisi Admin/Dosen PA.');
          } else {
            final gpa=double.tryParse('${input['gpa']}'.replaceAll(',','.'));
            if(gpa==null||!gpa.isFinite||gpa<0||gpa>4) throw Exception('IPK manual harus 0–4.');
            row['gpa']=gpa; row['gpaBy']=a['id'];
          }
        }
        row['updated']=DateTime.now().toIso8601String(); d['profiles']['$id']=row;
      });
    } catch (_) { if(copied!=null && await File(copied!).exists()) await File(copied!).delete(); rethrow; }
    // Foto lama tidak dihapus otomatis agar operasi edit gagal tidak merusak referensi lama.
  }
  Future<void> assignPa(int student,int teacher) => _write((d,a,users) async {
    if(!_admin(a)) throw Exception('Hanya Admin menetapkan PA.');
    if(!users.any((u)=>u['id']==student&&u['role']=='Mahasiswa')||!users.any((u)=>u['id']==teacher&&u['role']=='Dosen')) throw Exception('Pilih Mahasiswa dan Dosen aktif.');
    d['pa']['$student']=teacher;
  });
  Future<void> takeStudent(int student) async {
    await _actor();
    throw Exception('Penetapan Dosen PA hanya melalui Admin.');
  }
  Future<void> saveClass(Map<String,dynamic> input) => _write((d,a,users) async {
    final id=input['id'] as String?; final old=id==null?null:_class(d,id);
    if(!_admin(a)) throw Exception('Hanya Admin membuat atau mengubah jadwal/kelas.');
    final code=_text(input['code'],30,required:true);
    if(!kSemuaMataKuliah.any((m)=>m.kode==code)) throw Exception('MK tidak valid.');
    final teacher=int.tryParse('${input['teacher']}');
    if(!users.any((u)=>u['id']==teacher&&u['role']=='Dosen')) throw Exception('Pilih Dosen aktif.');
    if(old!=null&&_rows(d,'krs').any((r)=>(r['classes'] as List).contains(id)) && (code!=old['code']||input['term']!=old['term'])) throw Exception('MK/periode kelas yang sudah dipilih KRS tidak dapat diganti.');
    final day=int.tryParse('${input['day']}'); final start=_text(input['start'],5,required:true); final end=_text(input['end'],5,required:true);
    final time=RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if(day==null||day<1||day>7||!time.hasMatch(start)||!time.hasMatch(end)||start.compareTo(end)>=0) throw Exception('Hari 1–7 dan jam HH:mm; jam selesai setelah mulai.');
    final term=_text(input['term'],80,required:true);
    for(final c in _rows(d,'classes')) {
      if(c['id']==id||c['term']!=term||c['day']!=day)continue;
      if(c['teacher']==teacher && start.compareTo(c['end'] as String)<0 && (c['start'] as String).compareTo(end)<0) throw Exception('Jadwal Dosen bertabrakan di periode yang sama.');
    }
    final row={'id':id??_id(),'code':code,'teacher':teacher,'term':_text(input['term'],80,required:true),'label':_text(input['label'],80,required:true),'day':day,'start':start,'end':end,'room':_text(input['room'],120)};
    final list=d['classes'] as List;
    if(old==null) { list.add(row); } else { list[list.indexWhere((c)=>c['id']==id)]=row; }
  });
  Future<void> submitKrs(String term,List<String> ids,{int? reviewer}) => _write((d,a,users) async {
    if(a['role']!='Mahasiswa') throw Exception('Hanya Mahasiswa mengajukan KRS.');
    final p=d['profiles']['${a['id']}'] as Map?;
    if(p==null||'${p['nim']??''}'.trim().isEmpty||p['semester']==null||'${p['skills']??''}'.trim().isEmpty||'${p['bio']??''}'.trim().isEmpty) throw Exception('Lengkapi NIM, semester, skill dan deskripsi terlebih dahulu.');
    final semester=int.tryParse('${p['semester']}');
    if(semester==null||semester<1||semester>14) throw Exception('Semester harus 1–14.');
    final target=reviewer??d['pa']['${a['id']}'];
    if(!users.any((u)=>u['id']==target&&u['role']=='Dosen')) throw Exception('Pilih Dosen tujuan ACC yang aktif.');
    if(ids.isEmpty||ids.toSet().length!=ids.length) throw Exception('Pilih minimal satu kelas, tanpa duplikat.');
    final classes=ids.map((id)=>_class(d,id)).toList();
    if(classes.any((c)=>!kSemuaMataKuliah.any((m)=>m.kode==c['code']&&m.semester==semester))) throw Exception('KRS hanya boleh memilih MK semester $semester sesuai profil Mahasiswa.');
    if(classes.any((c)=>c['term']!=term)||classes.map((c)=>c['code']).toSet().length!=classes.length) throw Exception('Pilih satu periode dan satu kelas per MK.');
    for(int i=0;i<classes.length;i++) { for(int j=i+1;j<classes.length;j++) {
      final x=classes[i],y=classes[j];
      if(x['day']==y['day']&&(x['start'] as String).compareTo(y['end'] as String)<0&&(y['start'] as String).compareTo(x['end'] as String)<0) throw Exception('Jadwal kelas bertabrakan.');
    }}
    final rows=d['krs'] as List; final index=rows.indexWhere((r)=>r['student']==a['id']&&r['term']==term);
    if(index>=0&&rows[index]['status']!='revision') throw Exception('KRS sudah diajukan/disetujui. Minta revisi ke Dosen tujuan ACC.');
    final row={'id':index<0?_id():rows[index]['id'],'student':a['id'],if(reviewer!=null)'requestedTeacher':reviewer,'term':term,'semester':semester,'classes':ids,'status':'pending','note':'','submitted':DateTime.now().toIso8601String()};
    if(index<0) { rows.add(row); } else { rows[index]=row; }
  });
  Future<void> redirectKrs(String id,int reviewer)=>_write((d,a,users)async{
    final r=(d['krs'] as List).firstWhere((r)=>r['id']==id);
    if(a['role']!='Mahasiswa'||r['student']!=a['id']||r['status']!='pending') throw Exception('Hanya pemilik dapat mengganti tujuan KRS yang masih menunggu.');
    if(!users.any((u)=>u['id']==reviewer&&u['role']=='Dosen')) throw Exception('Pilih Dosen aktif.');
    r['requestedTeacher']=reviewer;r.remove('reviewer');r.remove('reviewed');
  });
  Future<void> reviewKrs(String id,bool approve,String note) => _write((d,a,users) async {
    final rows=d['krs'] as List; final r=rows.firstWhere((r)=>r['id']==id);
    if(!_canReview(d,a,r)) throw Exception('Hanya Dosen tujuan permintaan ACC yang dapat menyetujui/revisi KRS.');
    if(!approve&&note.trim().isEmpty) throw Exception('Alasan revisi wajib diisi.');
    if(approve&&r['status']!='pending') throw Exception('Hanya KRS menunggu yang dapat disetujui.');
    if(!users.any((u)=>u['id']==r['student'])) throw Exception('Akun Mahasiswa tidak aktif.');
    if(approve){
      final semester=int.tryParse('${r['semester']??d['profiles']['${r['student']}']?['semester']}');
      if(semester==null||semester<1||semester>14) throw Exception('Semester pengajuan belum valid. Minta Mahasiswa melengkapi profil dan mengajukan ulang.');
      for(final classId in r['classes'] as List){
        final c=_class(d,classId as String);
        if(!kSemuaMataKuliah.any((m)=>m.kode==c['code']&&m.semester==semester)) throw Exception('MK tidak sesuai semester pengajuan. Minta revisi agar Mahasiswa memilih kelas semester yang sesuai.');
        if(c['term']!=r['term']||!users.any((u)=>u['id']==c['teacher']&&u['role']=='Dosen')) throw Exception('Kelas/pengampu tidak aktif atau periode berubah. Minta revisi KRS terlebih dahulu.');
      }
    }
    r['status']=approve?'approved':'revision'; r['note']=_text(note,2000); r['reviewer']=a['id']; r['reviewed']=DateTime.now().toIso8601String();
  });
  Future<void> attendance(String classId,int student,String date,String status) => _write((d,a,users) async {
    if(!_canAttend(d,a,student,classId)) throw Exception('Absensi hanya oleh pengampu atau Dosen pilihan yang telah ACC Mahasiswa pada kelas ini.');
    if(!_enrolled(d,student,classId)) throw Exception('Mahasiswa belum memiliki KRS disetujui untuk kelas ini.');
    if(!users.any((u)=>u['id']==student&&u['role']=='Mahasiswa')) throw Exception('Akun Mahasiswa tidak aktif.');
    final parsed=DateTime.tryParse(date);
    if(parsed==null||parsed.toIso8601String().substring(0,10)!=date||!['Hadir','Izin','Sakit','Alpa'].contains(status)) throw Exception('Tanggal/status tidak valid.');
    final rows=d['attendance'] as List; rows.removeWhere((r)=>r['class']==classId&&r['student']==student&&r['date']==date);
    rows.add({'class':classId,'student':student,'date':date,'status':status,'by':a['id']});
  });
  Future<void> grade(String classId,int student,String score,String letter,String note) => _write((d,a,users) async {
    if((!_admin(a)&&!_teacher(d,a,classId))||!_enrolled(d,student,classId)) throw Exception('Hanya Admin atau Dosen pengampu mengisi nilai untuk KRS disetujui.');
    if(!(d['classes'] as List).any((c)=>c['id']==classId)) throw Exception('Kelas tidak ditemukan.');
    if(!users.any((u)=>u['id']==student&&u['role']=='Mahasiswa')) throw Exception('Akun Mahasiswa tidak aktif.');
    final value=double.tryParse(score.replaceAll(',','.'));
    if(value==null||!value.isFinite||value<0||value>100) throw Exception('Nilai angka harus 0–100.');
    final rows=d['grades'] as List; rows.removeWhere((r)=>r['class']==classId&&r['student']==student);
    rows.add({'class':classId,'student':student,'score':value,'letter':_text(letter,4),'note':_text(note,1000),'by':a['id'],'updated':DateTime.now().toIso8601String()});
  });
  Future<void> guidance(int student,String topic,String note) => _write((d,a,users) async {
    if(!_pa(d,a,student)) throw Exception('Hanya Dosen PA menulis bimbingan.');
    (d['guidance'] as List).add({'id':_id(),'student':student,'teacher':a['id'],'topic':_text(topic,160,required:true),'note':_text(note,4000,required:true),'date':DateTime.now().toIso8601String()});
  });
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import '../data/curriculum_data.dart';
import '../services/campus_auth_api.dart';
import '../services/local_academic_store.dart';

class ProfileAcademicScreen extends StatefulWidget {
  const ProfileAcademicScreen({super.key, required this.api, this.initialSection, this.store});
  final CampusAuthApi api;
  final String? initialSection;
  /// Optional test dependency; normal screens use the local account service.
  final LocalAcademicStore? store;
  @override
  State<ProfileAcademicScreen> createState()=>_ProfileAcademicScreenState();
}
class _ProfileAcademicScreenState extends State<ProfileAcademicScreen> {
  late final LocalAcademicStore store;
  Map<String,dynamic>? data;
  String section='Dashboard';
  bool busy=false;
  String? error;
  Map get actor=>data!['actor'] as Map;
  bool get admin=>actor['role']=='admin';
  bool get teacher=>actor['role']=='Dosen';
  List<Map<String,dynamic>> rows(String key)=>(data![key] as List).map((r)=>Map<String,dynamic>.from(r as Map)).toList();
  String user(dynamic id) {
    final users=rows('users').where((u)=>u['id']==id);
    if(users.isEmpty)return 'Akun dihapus/nonaktif';
    final p=data!['profiles']['$id'] as Map?;
    return '${p?['name']??users.first['username']} (${users.first['username']})';
  }
  String studentLabel(int id) {
    final profile=data!['profiles']['$id'] as Map?;
    return '${user(id)} • NIM ${profile?['nim']??'belum diisi'}';
  }
  int rosterCount(Map c)=>rosterIds(c,section=='Absensi').length;
  List<int> rosterIds(Map c,bool attendance)=>((attendance?(data!['attendanceRosters']??data!['rosters']):data!['rosters'])[c['id']] as List? ?? []).cast<int>();
  List<Map<String,dynamic>> actionableClasses(bool attendance)=>rows('classes').where((c)=>admin||c['teacher']==actor['id']||(attendance&&rosterIds(c,true).isNotEmpty)).toList();
  dynamic targetOf(Map r)=>(data!['reviewTargets'] as Map?)?[r['id']]??r['requestedTeacher']??data!['pa']['${r['student']}'];
  bool canReview(Map r)=>teacher&&targetOf(r)==actor['id'];
  Future<int?> chooseReviewer()async{
    final id=await choose('Pilih Dosen tujuan ACC',{for(final u in rows('users').where((u)=>u['role']=='Dosen')) '${u['id']}':user(u['id'])});
    return id==null?null:int.parse(id);
  }
  Future<void> redirect(Map r)async{
    final id=await chooseReviewer();if(id!=null&&mounted)await act(()=>store.redirectKrs(r['id'] as String,id));
  }
  String course(dynamic code) {
    final mk=kSemuaMataKuliah.where((m)=>m.kode==code);
    return mk.isEmpty?'$code':'$code — ${mk.first.nama} (${mk.first.sks} SKS)';
  }
  String classLabel(Map c)=>'${course(c['code'])} • ${c['label']} • ${c['term']}';
  String schedule(Map c)=>'${const ['','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'][c['day'] as int]} ${c['start']}–${c['end']} • ${c['room']}';
  @override
  void initState(){super.initState();section=widget.initialSection??'Dashboard';store=widget.store??LocalAcademicStore(widget.api);load();}
  Future<void> load() async {
    if(!mounted)return;setState(()=>busy=true);
    try{final d=await store.view();if(mounted)setState((){data=d;error=null;});}
    catch(e){if(mounted)setState(()=>error='$e');}
    if(mounted)setState(()=>busy=false);
  }
  Future<void> act(Future<void> Function() fn) async {
    if(busy)return;setState(()=>busy=true);
    try{await fn();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Data tersimpan lokal.')));}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
    if(mounted){setState(()=>busy=false);await load();}
  }
  Future<Map<String,String>?> form(String title,List<AcademicField> fields) async {
    return Navigator.push<Map<String,String>>(context,MaterialPageRoute(builder:(_)=>AcademicForm(title:title,fields:fields)));
  }
  Future<String?> choose(String title,Map<String,String> options) async {
    if(options.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Belum ada pilihan yang tersedia.')));return null;}
    return showModalBottomSheet<String>(context:context,isScrollControlled:true,builder:(c)=>SafeArea(child:SizedBox(height:MediaQuery.sizeOf(c).height*.65,
        child:Column(children:[Padding(padding:const EdgeInsets.all(16),child:Text(title,style:Theme.of(c).textTheme.titleLarge)),Expanded(child:ListView(children:[for(final e in options.entries)ListTile(title:Text(e.value),onTap:()=>Navigator.pop(c,e.key))]))]))));
  }
  Future<void> editProfile(Map u) async {
    final id=u['id'] as int; final p=Map<String,dynamic>.from(data!['profiles']['$id'] as Map? ?? {});
    final own=id==actor['id']; final pa=teacher&&data!['pa']['$id']==actor['id'];
    final personal=own||admin;
    final fields=<AcademicField>[
      if(personal)...[
        AcademicField('name',u['role']=='Dosen'?'Nama lengkap & gelar':'Nama lengkap',initial:p['name']??''),
        if(u['role']=='Mahasiswa')...[
          AcademicField('nim','NIM (wajib)',initial:p['nim']??''),
          AcademicField('semester','Semester (1–14)',initial:'${p['semester']??1}',numeric:true),
          AcademicField('position','Jabatan kelas/organisasi (bukan hak akses)',initial:p['position']??'Mahasiswa',choices:const {'Mahasiswa':'Mahasiswa','Ketua kelas':'Ketua kelas','Ketua organisasi':'Ketua organisasi','Pengurus organisasi':'Pengurus organisasi','Anggota organisasi':'Anggota organisasi','Lainnya':'Lainnya'}),
        ],
        if(u['role']=='Dosen')AcademicField('lecturerId','NIDN/NIP/identitas Dosen',initial:p['lecturerId']??''),
        AcademicField('faculty','Prodi / fakultas',initial:p['faculty']??'S1 Informatika'),
        AcademicField('skills','Skill / keahlian',initial:p['skills']??'',lines:3),
        AcademicField('bio','Deskripsi / profil singkat',initial:p['bio']??'',lines:4),
        AcademicField('email','Email',initial:p['email']??''),AcademicField('phone','Telepon (opsional)',initial:p['phone']??''),
      ],
      if(u['role']=='Mahasiswa'&&(admin||pa))AcademicField('gpa','IPK manual 0–4 (opsional semua semester)',initial:'${p['gpa']??''}',numeric:true),
    ];
    final values=await form(personal?'Edit profil':'Isi IPK Mahasiswa bimbingan',fields);
    if(values!=null&&mounted)await act(()=>store.profile(id,values));
  }
  Future<void> photo(Map u,bool camera) async {
    try{
      final f=await ImagePicker().pickImage(source:camera?ImageSource.camera:ImageSource.gallery,imageQuality:85,maxWidth:1200);
      if(f==null||!mounted)return;
      final old=Map<String,dynamic>.from(data!['profiles']['${u['id']}'] as Map? ?? {});
      if('${old['name']??''}'.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Lengkapi profil terlebih dahulu.')));return;}
      await act(()=>store.profile(u['id'] as int,old,photoPath:f.path));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  }
  Future<void> assignPa() async {
    final student=await choose('Mahasiswa',{for(final u in rows('users').where((u)=>u['role']=='Mahasiswa')) '${u['id']}':user(u['id'])});
    if(student==null||!mounted)return;
    final lecturer=await choose('Dosen PA',{for(final u in rows('users').where((u)=>u['role']=='Dosen')) '${u['id']}':user(u['id'])});
    if(lecturer!=null&&mounted)await act(()=>store.assignPa(int.parse(student),int.parse(lecturer)));
  }
  Future<void> editClass([Map<String,dynamic>? c]) async {
    if(!admin)return;
    final editable=admin;
    final values=await form(c==null?'Buat kelas mengajar':'Edit kelas / jadwal',[
      if(editable)...[
        AcademicField('code','Mata kuliah kurikulum',initial:c?['code']??kSemuaMataKuliah.first.kode,choices:{for(final m in kSemuaMataKuliah)m.kode:'Semester ${m.semester} • ${m.kode} — ${m.nama}'}),
        if(admin)AcademicField('teacher','Dosen pengampu',initial:'${c?['teacher']??''}',choices:{for(final u in rows('users').where((u)=>u['role']=='Dosen')) '${u['id']}':user(u['id'])}),
        AcademicField('term','Periode (contoh 2026/2027 Ganjil)',initial:c?['term']??'2026/2027 Ganjil'),
      ],
      AcademicField('label','Nama kelas',initial:c?['label']??'A'),
      AcademicField('day','Hari',initial:'${c?['day']??1}',choices:const {'1':'Senin','2':'Selasa','3':'Rabu','4':'Kamis','5':'Jumat','6':'Sabtu','7':'Minggu'}),
      AcademicField('start','Jam mulai HH:mm',initial:c?['start']??'08:00'),AcademicField('end','Jam selesai HH:mm',initial:c?['end']??'09:40'),AcademicField('room','Ruang / lokasi',initial:c?['room']??''),
    ]);
    if(values==null||!mounted)return;
    await act(()=>store.saveClass({...?c,...values,if(c!=null)'id':c['id']}));
  }
  Future<void> submitKrs() async {
    final profile=data!['profiles']['${actor['id']}'] as Map? ?? {};
    final semester=int.tryParse('${profile['semester']}');
    if(semester==null||semester<1||semester>14){
      await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Lengkapi semester profil'),content:const Text('Isi semester yang benar pada Profil sebelum memilih KRS.'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Mengerti'))]));return;
    }
    final classes=rows('classes').where((c)=>kSemuaMataKuliah.any((m)=>m.kode==c['code']&&m.semester==semester)).toList();
    if(classes.isEmpty){
      await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:Text('Belum ada kelas semester $semester'),content:Text('Admin perlu membuat kelas untuk mata kuliah semester $semester terlebih dahulu. Kelas dari semester lain tidak dapat dipilih. IPK tidak wajib untuk mengajukan KRS.'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Mengerti'))]));return;
    }
    final term=await choose('Pilih periode',{for(final c in classes)c['term'] as String:c['term'] as String});
    if(term==null||!mounted)return;
    final reviewer=await chooseReviewer();if(reviewer==null||!mounted)return;
    final candidates=classes.where((c)=>c['term']==term).toList();
    final selected=<String>{};
    final yes=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,update)=>AlertDialog(
        title:Text('KRS semester $semester • $term'),content:SizedBox(width:500,height:400,child:Column(children:[
      Text('Hanya MK semester $semester sesuai profil Anda. Pilih satu kelas per MK. IPK boleh kosong; pengajuan tetap ditinjau Dosen tujuan ACC.'),
      Expanded(child:ListView(children:[for(final k in candidates)CheckboxListTile(value:selected.contains(k['id']),onChanged:(v)=>update((){if(v==true){selected.add(k['id'] as String);}else{selected.remove(k['id']);}}),title:Text(classLabel(k)),subtitle:Text('${schedule(k)}\n${user(k['teacher'])}'))])),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Batal')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Kirim permintaan ACC'))])));
    if(yes==true&&mounted)await act(()=>store.submitKrs(term,selected.toList(),reviewer:reviewer));
  }
  Future<void> review(Map r,bool approve) async {
    final result=await form(approve?'Setujui KRS':'Minta revisi KRS',[AcademicField('note',approve?'Catatan (opsional)':'Alasan revisi (wajib)',lines:4)]);
    if(result!=null&&mounted)await act(()=>store.reviewKrs(r['id'] as String,approve,result['note']!));
  }
  Future<void> classRoster(Map c,bool attendance) async {
    final ids=rosterIds(c,attendance);
    if(ids.isEmpty){
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
          title:const Text('Belum ada peserta dengan KRS disetujui'),
          content:const Text('Mahasiswa harus mengajukan KRS untuk kelas ini, memilih Dosen tujuan ACC, lalu Dosen itu menyetujuinya. Setelah itu tekan muat ulang. Admin tidak melakukan ACC KRS. Dosen pilihan hanya dapat mengabsen peserta yang disetujuinya pada kelas tersebut.'),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Mengerti'))]));
      return;
    }
    final selected=await choose(attendance?'Pilih Mahasiswa untuk absensi':'Pilih Mahasiswa untuk nilai',{for(final id in ids)'$id':studentLabel(id)});
    if(selected==null||!mounted)return;final student=int.parse(selected);
    if(attendance){
      final date=await showDatePicker(context:context,initialDate:DateTime.now(),firstDate:DateTime(2020),lastDate:DateTime(DateTime.now().year+2));
      if(date==null||!mounted)return;
      final status=await choose('Status kehadiran',const {'Hadir':'Hadir','Izin':'Izin','Sakit':'Sakit','Alpa':'Alpa'});
      if(status!=null&&mounted)await act(()=>store.attendance(c['id'] as String,student,date.toIso8601String().substring(0,10),status));
    }else{
      final old=rows('grades').where((r)=>r['class']==c['id']&&r['student']==student);
      final grade=old.isEmpty?<String,dynamic>{}:old.first;
      final v=await form('Nilai ${user(student)}',[
        AcademicField('score','Nilai angka 0–100',initial:'${grade['score']??''}',numeric:true),
        AcademicField('letter','Nilai huruf (manual, opsional)',initial:grade['letter']??''),AcademicField('note',admin?'Sumber nilai / catatan dari Dosen':'Catatan',initial:grade['note']??'',lines:3)]);
      if(v!=null&&mounted)await act(()=>store.grade(c['id'] as String,student,v['score']!,v['letter']!,v['note']!));
    }
  }
  Future<void> addGuidance() async {
    final student=await choose('Mahasiswa bimbingan PA',{for(final u in rows('users').where((u)=>u['role']=='Mahasiswa'&&data!['pa']['${u['id']}']==actor['id']))'${u['id']}':user(u['id'])});
    if(student==null||!mounted)return;
    final v=await form('Catatan bimbingan (dibaca Mahasiswa)',[AcademicField('topic','Topik'),AcademicField('note','Catatan bimbingan',lines:6)]);
    if(v!=null&&mounted)await act(()=>store.guidance(int.parse(student),v['topic']!,v['note']!));
  }
  Future<void> openSection(String name) async {
    await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>ProfileAcademicScreen(api:widget.api,initialSection:name,store:widget.store)));
    if(mounted)await load();
  }
  String displayName(Map u) {
    final p=data!['profiles']['${u['id']}'] as Map?;
    final n=p?['name']?.toString().trim()??'';
    return n.isEmpty?u['username'] as String:n;
  }
  Widget avatar(Map u,{double radius=34}) {
    final p=data!['profiles']['${u['id']}'] as Map?;
    final path=p?['photo'] as String?;
    return Container(padding:const EdgeInsets.all(3),decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0xffffcf40),width:2)),
        child:ClipOval(child:path!=null?Image.file(File(path),width:radius*2,height:radius*2,fit:BoxFit.cover,
            errorBuilder:(_,e,stack)=>_avatarFallback(u,radius)):_avatarFallback(u,radius)));
  }
  Widget _avatarFallback(Map u,double radius)=>Container(width:radius*2,height:radius*2,color:const Color(0xffe7edf7),alignment:Alignment.center,
      child:Text(displayName(u).isEmpty?'?':displayName(u).substring(0,1).toUpperCase(),style:TextStyle(fontSize:radius*.8,fontWeight:FontWeight.w800,color:const Color(0xff143259))));
  Widget pill(String text,{Color color=const Color(0xff143259),Color background=const Color(0xffeaf0fa)})=>Container(
      padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:background,borderRadius:BorderRadius.circular(30)),
      child:Text(text,style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:color)));
  Widget panelTitle(String title,String subtitle)=>Padding(padding:const EdgeInsets.fromLTRB(0,12,0,16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:Color(0xff0b1b32))),const SizedBox(height:6),
    Text(subtitle,style:const TextStyle(fontSize:13,color:Color(0xff64748b),height:1.5)),
  ]));
  Widget infoRow(IconData icon,String label,dynamic value) {
    final text=value?.toString().trim()??'';
    return Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:const Color(0xfff0f4fa),borderRadius:BorderRadius.circular(12)),child:Icon(icon,size:18,color:const Color(0xff143259))),
      const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:11,color:Color(0xff64748b))),const SizedBox(height:3),Text(text.isEmpty?'Belum diisi':text,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600,color:Color(0xff172d4c),height:1.4))])),
    ]));
  }
  Widget metric(String value,String label,IconData icon)=>Expanded(child:Container(
      padding:const EdgeInsets.symmetric(horizontal:8,vertical:14),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xffe2e8f0)),borderRadius:BorderRadius.circular(18)),
      child:Column(children:[Icon(icon,size:19,color:const Color(0xff607da6)),const SizedBox(height:8),Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:Color(0xff143259))),const SizedBox(height:4),Text(label,textAlign:TextAlign.center,style:const TextStyle(fontSize:11,color:Color(0xff64748b)))])));
  Widget dashboard() {
    final profile=data!['profiles']['${actor['id']}'] as Map? ?? {};
    final student=actor['role']=='Mahasiswa';
    final ownClasses=teacher?rows('classes').where((c)=>c['teacher']==actor['id']).length:rows('classes').length;
    final pending=rows('krs').where((r)=>r['status']=='pending'&&(!teacher||canReview(r))).length;
    final menu=<Map<String,dynamic>>[
      {'name':'Profil','icon':Icons.person_outline,'sub':'Biodata, foto & keahlian','color':const Color(0xff2563eb)},
      {'name':'Jadwal','icon':Icons.calendar_month_outlined,'sub':student?'Penawaran kelas & waktu kuliah':'Kelas & jadwal mengajar','color':const Color(0xff7c3aed)},
      {'name':'KRS','icon':Icons.assignment_outlined,'sub':student?'Ajukan & pantau persetujuan':teacher?'Permintaan ACC untuk Anda':'Pantau pengajuan KRS','color':const Color(0xffd49a09)},
      {'name':'Absensi','icon':Icons.fact_check_outlined,'sub':teacher?'Catat kehadiran kelas':'Rekap kehadiran','color':const Color(0xff08916f)},
      {'name':'Nilai','icon':Icons.insights_outlined,'sub':admin?'Masukkan nilai dari Dosen':teacher?'Input & tinjau nilai':'Hasil akademik manual','color':const Color(0xffe06c35)},
      {'name':'Bimbingan','icon':Icons.forum_outlined,'sub':teacher?'Catatan Mahasiswa PA':'Riwayat bimbingan akademik','color':const Color(0xff087ea4)},
      if(admin){'name':'Pengelolaan','icon':Icons.admin_panel_settings_outlined,'sub':'Profil, Dosen PA & kelas','color':const Color(0xff143259)},
    ];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff0b1729),Color(0xff1b3c68)],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(24)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[avatar(actor,radius:30),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('SMART CAMPUS',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,letterSpacing:1.5,color:Color(0xffffd35b))),const SizedBox(height:6),Text(displayName(actor),style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(student?'NIM ${profile['nim']??'belum diisi'}':'Universitas Mulia',style:const TextStyle(color:Color(0xffc3d1e8),fontSize:12))]))]),
        const SizedBox(height:18),Wrap(spacing:8,runSpacing:6,children:[pill(actor['role'] as String,color:const Color(0xffffd35b),background:const Color(0xff29476b)),pill('Lokal • satu HP',color:Colors.white,background:const Color(0xff29476b)),if(student&&profile['semester']!=null)pill('Semester ${profile['semester']}',color:Colors.white,background:const Color(0xff29476b))]),
        const SizedBox(height:8),TextButton.icon(onPressed:()=>openSection('Profil'),icon:const Icon(Icons.edit_outlined,size:16,color:Color(0xffffd35b)),label:const Text('Lihat & lengkapi profil',style:TextStyle(color:Color(0xffffd35b),fontSize:12))),
      ])),
      const SizedBox(height:16),Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        metric(student?(profile['gpa'] is num?(profile['gpa'] as num).toStringAsFixed(2):'—'):'$ownClasses',student?'IPK manual':teacher?'Kelas mengajar':'Kelas tersedia',student?Icons.school_outlined:Icons.menu_book_outlined),const SizedBox(width:8),
        metric('$pending','KRS menunggu',Icons.pending_actions_outlined),const SizedBox(width:8),
        metric(admin?'${rows('users').length}':'${rows('guidance').length}',admin?'Akun aktif':'Catatan PA',admin?Icons.people_outline:Icons.forum_outlined),
      ]),
      panelTitle('Ruang akademik Anda',student?'Akses perkuliahan dan perkembangan studi dalam satu tempat.':teacher?'Kelola kegiatan mengajar dan bimbingan sesuai kewenangan Anda.':'Pantau aktivitas akademik dan kelola penetapan kelas serta PA.'),
      LayoutBuilder(builder:(context,constraints){final columns=constraints.maxWidth>=700?3:constraints.maxWidth<300?1:2;
      return Wrap(spacing:12,runSpacing:12,children:[for(final m in menu)SizedBox(width:(constraints.maxWidth-12*(columns-1))/columns,
          child:Material(color:Colors.white,borderRadius:BorderRadius.circular(20),child:InkWell(borderRadius:BorderRadius.circular(20),onTap:busy?null:()=>openSection(m['name'] as String),
              child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(border:Border.all(color:const Color(0xffe2e8f0)),borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:(m['color'] as Color).withAlpha(22),borderRadius:BorderRadius.circular(13)),child:Icon(m['icon'] as IconData,color:m['color'] as Color,size:23)),const Spacer(),const Icon(Icons.arrow_outward,size:15,color:Color(0xff94a3b8))]),
                const SizedBox(height:16),Text(m['name'] as String,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:Color(0xff143259))),const SizedBox(height:6),Text(m['sub'] as String,style:const TextStyle(fontSize:12,height:1.45,color:Color(0xff64748b))),
              ]))),
          ))]);}),
      const SizedBox(height:20),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xfffff7db),borderRadius:BorderRadius.circular(16)),child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.info_outline,size:18,color:Color(0xff8a6500)),SizedBox(width:10),Expanded(child:Text('Data tersimpan di HP ini. Nilai/IPK manual dan tidak tersinkron ke SIAM resmi.',style:TextStyle(fontSize:12,height:1.5,color:Color(0xff785900))))])),
    ]);
  }
  Widget profileCard(Map u) {
    final p=data!['profiles']['${u['id']}'] as Map? ?? {};
    final student=u['role']=='Mahasiswa';final own=u['id']==actor['id'];final pa=teacher&&data!['pa']['${u['id']}']==actor['id'];
    final skills=(p['skills']?.toString()??'').split(RegExp(r'[,;\n]')).map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList();
    return Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Center(child:avatar(u,radius:43)),const SizedBox(height:14),Text(displayName(u),textAlign:TextAlign.center,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:Color(0xff143259))),
      const SizedBox(height:6),Text('@${u['username']}',textAlign:TextAlign.center,style:const TextStyle(color:Color(0xff64748b),fontSize:12)),const SizedBox(height:12),Center(child:pill(u['role'] as String)),
      const SizedBox(height:20),const Divider(),
      if(student)...[infoRow(Icons.badge_outlined,'NIM',p['nim']),infoRow(Icons.layers_outlined,'Semester',p['semester']),infoRow(Icons.school_outlined,'IPK • diisi manual oleh Admin/PA',p['gpa']??'Belum diisi • opsional untuk pengajuan KRS'),infoRow(Icons.workspace_premium_outlined,'Jabatan kelas / organisasi',p['position']??'Mahasiswa'),infoRow(Icons.supervisor_account_outlined,'Dosen pembimbing akademik',data!['pa']['${u['id']}']==null?null:user(data!['pa']['${u['id']}']))],
      if(u['role']=='Dosen')infoRow(Icons.badge_outlined,'NIDN / NIP',p['lecturerId']),infoRow(Icons.apartment_outlined,'Prodi / fakultas',p['faculty']),
      const Divider(),const SizedBox(height:12),const Text('Keahlian',style:TextStyle(fontSize:15,fontWeight:FontWeight.w800,color:Color(0xff143259))),const SizedBox(height:10),
      if(skills.isEmpty)const Text('Belum ada skill yang ditambahkan.',style:TextStyle(color:Color(0xff64748b),fontSize:13))else Wrap(spacing:7,runSpacing:7,children:[for(final skill in skills)pill(skill)]),
      const SizedBox(height:20),const Text('Tentang saya',style:TextStyle(fontSize:15,fontWeight:FontWeight.w800,color:Color(0xff143259))),const SizedBox(height:8),Text('${p['bio']??'Lengkapi deskripsi singkat Anda.'}',style:const TextStyle(height:1.6,fontSize:13,color:Color(0xff52647e))),
      const SizedBox(height:12),infoRow(Icons.mail_outline,'Email',p['email']),infoRow(Icons.phone_outlined,'Telepon',p['phone']),
      if(student&&(p['nim']==null||p['semester']==null||'${p['nim']??''}'.trim().isEmpty||'${p['skills']??''}'.trim().isEmpty||'${p['bio']??''}'.trim().isEmpty))Padding(padding:const EdgeInsets.symmetric(vertical:12),child:pill('Profil belum lengkap',color:const Color(0xff9a6700),background:const Color(0xfffff5d6))),
      if(own||admin||pa)FilledButton.icon(onPressed:busy?null:()=>editProfile(u),icon:const Icon(Icons.edit_outlined,size:18),label:Text(!own&&!admin?'Isi / ubah IPK':'Edit profil')),
      if(own||admin)Padding(padding:const EdgeInsets.only(top:10),child:Wrap(alignment:WrapAlignment.center,spacing:6,children:[OutlinedButton.icon(onPressed:busy?null:()=>photo(u,false),icon:const Icon(Icons.photo_library_outlined,size:18),label:const Text('Galeri')),OutlinedButton.icon(onPressed:busy?null:()=>photo(u,true),icon:const Icon(Icons.camera_alt_outlined,size:18),label:const Text('Kamera'))])),
    ])));
  }
  @override
  Widget build(BuildContext context) => Theme(data:academicUiTheme(context),child:Scaffold(
    appBar:AppBar(title:Text(section=='Dashboard'?'Profil & akademik':section),actions:[IconButton(onPressed:busy?null:load,icon:const Icon(Icons.refresh))]),
    body:data==null?Center(child:error!=null?Text(error!):const CircularProgressIndicator()):RefreshIndicator(onRefresh:load,child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(18,12,18,28),children:[
      if(section=='Dashboard')dashboard()else panelTitle(section,section=='Profil'?'Identitas, keahlian, dan informasi akademik Anda.':section=='Pengelolaan'?'Administrasi profil, penetapan PA, dan penawaran kelas.':section=='KRS'?'Mahasiswa memilih Dosen tujuan untuk menyetujui KRS.':section=='Jadwal'?'Penawaran kelas dan jadwal yang ditetapkan Admin.':section=='Absensi'?'Rekap kehadiran berdasarkan kelas dan Mahasiswa.':section=='Nilai'?(admin?'Masukkan nilai berdasarkan hasil penilaian Dosen pengampu.':'Nilai manual yang dicatat Dosen pengampu.'):'Catatan pendampingan akademik bersama Dosen PA.'),
      if(busy)const LinearProgressIndicator(),if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
      if(section=='Profil')profileCard(actor),
      if(section=='Pengelolaan'&&admin)...[
        const SizedBox(height:8),
        Card(margin:EdgeInsets.zero,child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Row(children:[Icon(Icons.admin_panel_settings_outlined,color:Color(0xff143259)),SizedBox(width:10),Expanded(child:Text('Tindakan Admin',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:Color(0xff143259))))]),
          const SizedBox(height:8),const Text('Atur pembimbing akademik dan siapkan kelas perkuliahan.',style:TextStyle(fontSize:13,height:1.5,color:Color(0xff64748b))),
          const SizedBox(height:20),
          FilledButton.icon(style:FilledButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:16,vertical:18)),onPressed:busy?null:assignPa,icon:const Icon(Icons.supervisor_account_outlined,size:21),label:const Align(alignment:Alignment.centerLeft,child:Text('Tetapkan / ganti Dosen PA',style:TextStyle(height:1.4)))),
          const SizedBox(height:14),
          FilledButton.icon(style:FilledButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:16,vertical:18)),onPressed:busy?null:()=>editClass(),icon:const Icon(Icons.calendar_month_outlined,size:21),label:const Align(alignment:Alignment.centerLeft,child:Text('Buat kelas & jadwal mengajar',style:TextStyle(height:1.4)))),
        ]))),
        const SizedBox(height:28),
        Row(crossAxisAlignment:CrossAxisAlignment.center,children:[const Expanded(child:Text('Daftar profil',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:Color(0xff143259)))),const SizedBox(width:10),pill('${rows('users').where((u)=>u['id']!=actor['id']).length} akun')]),
        const SizedBox(height:8),const Text('Ketuk kartu untuk melihat profil dan tindakan yang tersedia.',style:TextStyle(fontSize:13,height:1.5,color:Color(0xff64748b))),
        const SizedBox(height:16),
        if(!rows('users').any((u)=>u['id']!=actor['id']))const AcademicEmpty(icon:Icons.people_outline,title:'Belum ada profil lain',message:'Profil akun aktif akan ditampilkan di sini.'),
        for(final u in rows('users').where((u)=>u['id']!=actor['id']))Padding(padding:const EdgeInsets.only(bottom:14),child:Card(margin:EdgeInsets.zero,clipBehavior:Clip.antiAlias,child:ExpansionTile(
          tilePadding:const EdgeInsets.symmetric(horizontal:16,vertical:12),childrenPadding:const EdgeInsets.fromLTRB(8,0,8,12),shape:const Border(),collapsedShape:const Border(),
          leading:avatar(u,radius:19),title:Text(displayName(u),style:const TextStyle(fontWeight:FontWeight.w700,fontSize:15,color:Color(0xff143259))),
          subtitle:Padding(padding:const EdgeInsets.only(top:6),child:Text('@${u['username']} • ${u['role']}',style:const TextStyle(fontSize:12,height:1.5,color:Color(0xff64748b)))),children:[profileCard(u)],
        ))),
        const SizedBox(height:12),
      ],
      if(section=='Jadwal')...[
        if(rows('classes').isEmpty)const AcademicEmpty(icon:Icons.calendar_month_outlined,title:'Belum ada jadwal',message:'Kelas akan tampil setelah dibuat dan ditetapkan oleh Admin.'),
        if(admin)FilledButton(onPressed:busy?null:()=>editClass(),child:const Text('Buat kelas & jadwal mengajar')),
        const Text('Jadwal dan kelas dibuat serta diubah hanya oleh Admin. Dosen melihat jadwal yang ditetapkan.'),
        for(final c in rows('classes'))Card(child:ListTile(title:Text(classLabel(c)),subtitle:Text('${schedule(c)}\nPengampu: ${user(c['teacher'])}'),
            trailing:admin?IconButton(onPressed:busy?null:()=>editClass(c),icon:const Icon(Icons.edit)):null)),
      ],
      if(section=='KRS')...[
        if(actor['role']=='Mahasiswa')Padding(padding:const EdgeInsets.only(bottom:12),child:pill('Semester profil: ${data!['profiles']['${actor['id']}']?['semester']??'belum diisi'}')),
        if(actor['role']=='Mahasiswa')const Padding(padding:EdgeInsets.only(bottom:12),child:Text('IPK opsional untuk semua semester. Pilihan kelas KRS mengikuti semester pada profil Mahasiswa.')),
        if(teacher)Text('Permintaan ACC untuk Anda: ${rows('krs').where((r)=>r['status']=='pending'&&canReview(r)).length} pengajuan.'),
        if(teacher&&!rows('krs').any((r)=>canReview(r)))const Padding(padding:EdgeInsets.all(12),child:Text('Belum ada permintaan ACC untuk Anda. Mahasiswa harus memilih nama Anda sebagai Dosen tujuan saat mengajukan KRS. Setelah ACC, peserta tersedia pada menu Absensi.')),
        if(actor['role']=='Mahasiswa'&&rows('krs').isEmpty)const Text('Belum ada pengajuan KRS. Lengkapi profil, lalu pilih Dosen tujuan ACC saat mengajukan KRS.'),
        if(actor['role']=='Mahasiswa')FilledButton(onPressed:busy?null:submitKrs,child:const Text('Ajukan / ajukan ulang KRS revisi')),
        if(admin)const Text('Admin memantau KRS; persetujuan hanya oleh Dosen tujuan yang dipilih Mahasiswa.'),
        for(final r in rows('krs'))Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Wrap(spacing:8,runSpacing:8,children:[pill('${const {'pending':'Menunggu Dosen','approved':'Disetujui','revision':'Perlu revisi'}[r['status']]??r['status']}',color:r['status']=='approved'?const Color(0xff087e60):const Color(0xff986300),background:r['status']=='approved'?const Color(0xffe0f5ec):const Color(0xfffff3d4)),pill(r['term'] as String)]),
          const SizedBox(height:12),Text(user(r['student']),style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:Color(0xff143259))),const SizedBox(height:8),
          for(final id in r['classes'] as List)Text(rows('classes').where((c)=>c['id']==id).isEmpty?'Kelas $id':classLabel(rows('classes').firstWhere((c)=>c['id']==id))),
          if(r['semester']!=null)Text('Semester pengajuan: ${r['semester']}'),
          Text('Dosen tujuan ACC: ${targetOf(r)==null?'Belum dipilih':user(targetOf(r))}'),
          Text('Catatan: ${r['note']}'),
          if(teacher&&!canReview(r))const Text('Pemantauan PA • ACC ditujukan kepada Dosen lain.',style:TextStyle(fontSize:12,color:Color(0xff64748b))),
          if(actor['role']=='Mahasiswa'&&r['status']=='pending')TextButton.icon(onPressed:busy?null:()=>redirect(r),icon:const Icon(Icons.swap_horiz),label:const Text('Pilih / ganti Dosen tujuan')),
          if(canReview(r))Wrap(children:[
            if(r['status']=='pending')TextButton(onPressed:busy?null:()=>review(r,true),child:const Text('ACC KRS')),
            TextButton(onPressed:busy?null:()=>review(r,false),child:const Text('Minta revisi'))]),
        ]))),
      ],
      if(section=='Absensi'||section=='Nilai')...[
        if(rows(section=='Absensi'?'attendance':'grades').isEmpty)AcademicEmpty(icon:section=='Absensi'?Icons.fact_check_outlined:Icons.insights_outlined,title:section=='Absensi'?'Belum ada catatan kehadiran':'Belum ada nilai',message:(teacher||(admin&&section=='Nilai'))?'Pilih kelas di bawah untuk mulai mencatat.':'Data tampil setelah dicatat oleh Dosen pengampu.'),
        if(teacher)const Text('Absensi tersedia bagi pengampu, serta bagi Dosen pilihan setelah ACC peserta pada kelas terkait. Input nilai tetap khusus pengampu atau Admin.'),
        if(teacher&&actionableClasses(section=='Absensi').isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('Belum ada kelas yang dapat dicatat di menu ini. Untuk absensi, ACC permintaan Mahasiswa terlebih dahulu. Untuk nilai, Anda harus pengampu kelas.')),
        if(admin)Text(section=='Nilai'?'Admin memasukkan nilai berdasarkan penilaian dari Dosen. Pilih kelas dan Mahasiswa dengan KRS disetujui. Catat sumber nilai pada kolom catatan.':'Admin hanya memantau presensi. Kehadiran dicatat pengampu atau Dosen pilihan yang telah ACC peserta terkait.'),
        if(teacher||(admin&&section=='Nilai'))for(final c in actionableClasses(section=='Absensi'))Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(classLabel(c),style:const TextStyle(fontWeight:FontWeight.bold)),
          Text('${rosterCount(c)} Mahasiswa dapat dipilih pada menu ini'),
          if(teacher&&c['teacher']!=actor['id'])const Text('Akses absensi dari ACC Anda • bukan pengampu kelas',style:TextStyle(fontSize:12,color:Color(0xff64748b))),
          FilledButton.icon(onPressed:busy?null:()=>classRoster(c,section=='Absensi'),icon:Icon(section=='Absensi'?Icons.fact_check:Icons.grading),label:Text(section=='Absensi'?'Catat absensi':admin?'Masukkan nilai dari Dosen':'Input / ubah nilai')),
        ]))),
        for(final r in rows(section=='Absensi'?'attendance':'grades'))Card(child:ListTile(title:Text(user(r['student'])),subtitle:Text('${rows('classes').where((c)=>c['id']==r['class']).map((c)=>classLabel(c)).join()}\n${section=='Absensi'?'${r['date']} • ${r['status']}':'Nilai ${r['score']} ${r['letter']} • ${r['note']}'}'))),
        if(section=='Nilai')const Text('Nilai manual, tidak menghitung IPK otomatis. IPK diisi Admin/PA melalui profil.'),
      ],
      if(section=='Bimbingan')...[
        if(rows('guidance').isEmpty)const AcademicEmpty(icon:Icons.forum_outlined,title:'Belum ada catatan bimbingan',message:'Catatan pendampingan dari Dosen PA akan tampil di sini.'),
        if(teacher)FilledButton(onPressed:busy?null:addGuidance,child:const Text('Tambah catatan bimbingan')),
        for(final r in rows('guidance'))Card(child:ListTile(title:Text('${user(r['student'])} • ${r['topic']}'),subtitle:Text('${r['date']} • PA: ${user(r['teacher'])}\n${r['note']}'))),
      ],
    ])),
  ));
}

class AcademicField {
  AcademicField(this.key,this.label,{this.initial='',this.lines=1,this.numeric=false,this.choices});
  final String key,label,initial;final int lines;final bool numeric;final Map<String,String>? choices;
}
class AcademicForm extends StatefulWidget {
  const AcademicForm({super.key,required this.title,required this.fields});
  final String title;final List<AcademicField> fields;
  @override
  State<AcademicForm> createState()=>_AcademicFormState();
}
class _AcademicFormState extends State<AcademicForm> {
  late final Map<String,TextEditingController> controllers;
  @override
  void initState(){super.initState();controllers={for(final f in widget.fields)f.key:TextEditingController(text:f.initial)};}
  @override
  void dispose(){for(final c in controllers.values){c.dispose();}super.dispose();}
  @override
  Widget build(BuildContext context)=>Theme(data:academicUiTheme(context),child:Scaffold(appBar:AppBar(title:Text(widget.title)),body:ListView(padding:const EdgeInsets.all(20),children:[
    const Padding(padding:EdgeInsets.only(bottom:20),child:Text('Lengkapi informasi di bawah. Perubahan tersimpan lokal pada perangkat ini.',style:TextStyle(color:Color(0xff64748b),fontSize:13,height:1.5))),
    for(final f in widget.fields)Padding(padding:const EdgeInsets.only(bottom:12),child:f.choices!=null?
    DropdownButtonFormField<String>(isExpanded:true,initialValue:f.choices!.containsKey(controllers[f.key]!.text)?controllers[f.key]!.text:null,
        decoration:InputDecoration(labelText:f.label),items:[for(final e in f.choices!.entries)DropdownMenuItem(value:e.key,child:Text(e.value,maxLines:2,overflow:TextOverflow.ellipsis))],onChanged:(v)=>controllers[f.key]!.text=v??''):
    TextField(controller:controllers[f.key],minLines:f.lines,maxLines:f.lines,maxLength:f.key=='bio'?2000:f.key=='note'?4000:f.key=='skills'?1000:160,
        keyboardType:f.numeric?const TextInputType.numberWithOptions(decimal:true):f.lines>1?TextInputType.multiline:TextInputType.text,decoration:InputDecoration(labelText:f.label))),
    FilledButton(onPressed:()=>Navigator.pop(context,{for(final e in controllers.entries)e.key:e.value.text}),child:const Text('Simpan / lanjutkan')),
  ])));
}

ThemeData academicUiTheme(BuildContext context) => Theme.of(context).copyWith(
  scaffoldBackgroundColor:const Color(0xfff3f6fb),
  colorScheme:Theme.of(context).colorScheme.copyWith(primary:const Color(0xff143259),secondary:const Color(0xffffcf40),surface:Colors.white),
  appBarTheme:const AppBarTheme(backgroundColor:Color(0xff0b1729),foregroundColor:Colors.white,elevation:0,centerTitle:false,titleTextStyle:TextStyle(fontSize:18,fontWeight:FontWeight.w700)),
  cardTheme:CardThemeData(color:Colors.white,elevation:0,margin:const EdgeInsets.symmetric(vertical:8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),side:const BorderSide(color:Color(0xffe2e8f0)))),
  inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:18),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:const BorderSide(color:Color(0xffd9e2ef))),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:const BorderSide(color:Color(0xffd9e2ef)))),
  filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:const Color(0xff143259),foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(horizontal:18,vertical:15),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))),
  outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(foregroundColor:const Color(0xff143259),side:const BorderSide(color:Color(0xffd4deed)),padding:const EdgeInsets.symmetric(horizontal:16,vertical:13),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))),
);

class AcademicEmpty extends StatelessWidget {
  const AcademicEmpty({super.key,required this.icon,required this.title,required this.message});
  final IconData icon;final String title,message;
  @override
  Widget build(BuildContext context)=>Container(margin:const EdgeInsets.symmetric(vertical:12),padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xffe2e8f0))),child:Column(children:[
    Container(padding:const EdgeInsets.all(14),decoration:const BoxDecoration(color:Color(0xffedf2fa),shape:BoxShape.circle),child:Icon(icon,size:26,color:const Color(0xff7890b3))),const SizedBox(height:14),
    Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800,color:Color(0xff143259))),const SizedBox(height:8),Text(message,textAlign:TextAlign.center,style:const TextStyle(fontSize:12,color:Color(0xff64748b),height:1.5)),
  ]));
}

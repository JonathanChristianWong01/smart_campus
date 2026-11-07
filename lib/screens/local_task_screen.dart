import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType, PlatformFile;
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:open_filex/open_filex.dart' show OpenFilex, ResultType;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' show AudioRecorder, RecordConfig;
import '../data/curriculum_data.dart';
import '../services/campus_auth_api.dart';
import '../services/local_task_files.dart';
import 'profile_academic_screen.dart' show AcademicForm, AcademicField;

String deadlineLabel(Map row) {
  final raw = row['deadline'];
  if (raw == null) return 'Tanpa deadline';
  final d = DateTime.tryParse(raw.toString())?.toLocal();
  if (d == null) return 'Deadline tidak valid';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

bool taskClosed(Map row) {
  final raw = row['deadline'];
  if (raw == null) return false;
  final d = DateTime.tryParse(raw.toString());
  return d == null || !DateTime.now().isBefore(d);
}

class LocalTaskScreen extends StatefulWidget {
  const LocalTaskScreen({super.key, required this.api, required this.legacyBuilder});
  final CampusAuthApi api;
  final WidgetBuilder legacyBuilder;
  @override
  State<LocalTaskScreen> createState() => _LocalTaskScreenState();
}

class _LocalTaskScreenState extends State<LocalTaskScreen> {
  late final LocalTaskFiles store;
  List<Map<String, dynamic>> rows = [];
  String? error;
  bool busy = false;
  String kind = 'material';
  bool get writer => ['admin', 'Dosen'].contains(widget.api.user?['role']);
  @override
  void initState() { super.initState(); store = LocalTaskFiles(widget.api); load(); }
  Future<void> load() async {
    setState(() { busy = true; error = null; });
    try {
      final data = await store.list();
      if (mounted) setState(() => rows = data);
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    if (mounted) setState(() => busy = false);
  }
  void message(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
  Future<void> compose({Map<String, dynamic>? task, Map<String, dynamic>? editing}) async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => TaskCompose(
        store: store, kind: editing?['kind'] as String? ?? (task == null ? kind : 'submission'), task: task, editing: editing)));
    if (mounted) await load();
  }
  bool canAssess(Map row)=>widget.api.user?['role']=='Dosen'&&rows.any((r)=>r['id']==row['parent']&&r['kind']=='task'&&r['owner']==widget.api.user?['id']);
  String assessmentSummary(Map row){
    final a=row['assessment'] as Map?;
    return a==null?'Belum dinilai':'Nilai tugas: ${a['score']}/100${(a['letter']?.toString().trim()??'').isEmpty?'':' • ${a['letter']}'}${a['needsReview']==true?' • perlu dinilai ulang':''}';
  }
  Future<void> assess(Map<String,dynamic> row)async{
    final old=row['assessment'] as Map?;
    final author=await store.author(row);if(!mounted)return;
    final value=await Navigator.push<Map<String,String>>(context,MaterialPageRoute(builder:(_)=>AcademicForm(title:'Nilai tugas • $author',fields:[
      AcademicField('score','Nilai tugas 0–100',initial:'${old?['score']??''}',numeric:true),AcademicField('letter','Nilai huruf tugas (opsional, maks. 4)',initial:'${old?['letter']??''}'),AcademicField('note','Catatan untuk Mahasiswa (maks. 1000)',initial:'${old?['note']??''}',lines:4),
    ])));
    if(value==null||!mounted)return;
    try{await store.assessSubmission(row['id'] as String,value['score']!,value['note']!,expectedVersion:(row['updated']??row['created']) as String,expectedAssessment:old?['graded'] as String?,letter:value['letter']??'');message('Nilai tugas tersimpan. Nilai akhir MK tidak diubah.');await load();}
    catch(e){message(e);}
  }
  Future<void> finalGrade(Map<String,dynamic> row)async{
    try{
      final author=await store.author(row);
      final classes=await store.finalGradeOptions(row['id'] as String);if(!mounted)return;
      if(classes.isEmpty){message('Belum ada kelas yang sesuai MK, hak pengampu/Admin dan KRS disetujui Mahasiswa. Nilai tugas tetap dapat diisi Dosen pembuat tugas.');return;}
      final selected=await showModalBottomSheet<Map<String,dynamic>>(context:context,isScrollControlled:true,builder:(c)=>SafeArea(child:SizedBox(height:MediaQuery.sizeOf(c).height*.6,child:ListView(padding:const EdgeInsets.all(20),children:[
        const Text('Pilih kelas untuk nilai akhir MK',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const Text('Nilai tugas tidak otomatis dihitung menjadi nilai akhir. Pastikan periode dan kelas benar.'),
        for(final item in classes)ListTile(title:Text('${item['code']} • ${item['label']}'),subtitle:Text('${item['term']} • nilai akhir saat ini: ${item['currentGrade']?['score']??'belum diisi'}'),onTap:()=>Navigator.pop(c,item)),
      ]))));
      if(selected==null||!mounted)return;final old=selected['currentGrade'] as Map?;
      final value=await Navigator.push<Map<String,String>>(context,MaterialPageRoute(builder:(_)=>AcademicForm(title:'Nilai akhir • $author',fields:[
        AcademicField('score','Nilai akhir MK 0–100',initial:'${old?['score']??''}',numeric:true),AcademicField('letter','Huruf (opsional, maks. 4)',initial:'${old?['letter']??''}'),AcademicField('note','Catatan nilai akhir (maks. 1000)',initial:'${old?['note']??''}',lines:4),
      ])));
      if(value==null||!mounted)return;
      final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Simpan nilai akhir MK?'),content:Text('Nilai ${value['score']} untuk $author mengganti nilai akhir pada kelas ${selected['label']} • ${selected['term']}. Ini terpisah dari nilai tugas.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Batal')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Simpan nilai akhir'))]));
      if(yes!=true||!mounted)return;
      await store.saveFinalGradeFromSubmission(row['id'] as String,selected['id'] as String,value['score']!,value['letter']!,value['note']!,expectedVersion:(row['updated']??row['created']) as String);
      message('Nilai akhir MK tersimpan. Buka menu Nilai lalu muat ulang.');await load();
    }catch(e){message(e);}
  }
  Future<void> detail(Map<String, dynamic> row) async {
    final author = await store.author(row);
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
        builder: (c) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(c).height * .8,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text(row['title'] as String, style: Theme.of(c).textTheme.titleLarge),
            Text('${row['code']} • $author\n${row['created']}'),
            if (row['updated'] != null) Text('Terakhir diedit: ${row['updated']}'),
            if (row['kind'] != 'submission') Text('Deadline: ${deadlineLabel(row)}${row['kind'] == 'task' && taskClosed(row) ? ' — Pengumpulan ditutup' : ''}'),
            const SizedBox(height: 12), SelectableText(row['text'] as String),
            for (final raw in row['files'] as List) ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(raw['name'] as String),
              subtitle: Text('${((raw['bytes'] as num) / 1024).toStringAsFixed(1)} KB'),
              onTap: () async {
                try {
                  await store.openAttachment(row, raw as Map);
                  final result = await OpenFilex.open(raw['path'] as String);
                  if (result.type != ResultType.done) message(result.message);
                } catch (e) { message(e); }
              },
            ),
            if(row['kind']=='submission')...[
              const Divider(),Text(assessmentSummary(row),style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
              if(row['assessment']!=null)Text('Catatan Dosen: ${row['assessment']['note']}'),
              if(row['assessment']?['needsReview']==true)const Text('Jawaban diedit setelah dinilai. Nilai sebelumnya perlu ditinjau ulang Dosen.',style:TextStyle(color:Colors.deepOrange)),
              const Text('Nilai tugas terpisah dari nilai akhir MK.'),
              if(canAssess(row))FilledButton.icon(onPressed:(){Navigator.pop(c);assess(row);},icon:const Icon(Icons.rate_review_outlined),label:const Text('Nilai / ubah nilai tugas')),
              if(canAssess(row)||widget.api.user?['role']=='admin')OutlinedButton.icon(onPressed:(){Navigator.pop(c);finalGrade(row);},icon:const Icon(Icons.school_outlined),label:const Text('Input / ubah nilai akhir MK')),
            ],
            if (row['kind'] == 'task' && widget.api.user?['role'] == 'Mahasiswa') FilledButton.icon(
                icon: const Icon(Icons.upload_file), label: Text(taskClosed(row) ? 'Pengumpulan ditutup' : 'Kumpulkan jawaban'),
                onPressed: taskClosed(row) ? null : () { Navigator.pop(c); compose(task: row); }),
            if (row['kind'] == 'task' && writer) ...[
              const Divider(), const Text('Pengumpulan yang dapat Anda lihat'),
              for (final submission in rows.where((r) => r['parent'] == row['id'])) ListTile(
                title: FutureBuilder<String>(future: store.author(submission), builder: (_, s) => Text(s.data ?? 'Memuat…')),
                subtitle: Text('${submission['created']} • ${assessmentSummary(submission)}'),
                onTap: () { Navigator.pop(c); detail(submission); },
              ),
              if (!rows.any((r) => r['parent'] == row['id'])) const Text('Belum ada pengumpulan.'),
            ],
            if ((row['kind'] == 'submission' && row['owner'] == widget.api.user?['id'] && widget.api.user?['role'] == 'Mahasiswa') ||
                (row['kind'] != 'submission' && (widget.api.user?['role'] == 'admin' || (widget.api.user?['role'] == 'Dosen' && row['owner'] == widget.api.user?['id']))))
              TextButton.icon(icon: const Icon(Icons.edit_outlined), label: const Text('Edit'), onPressed: () {
                Map<String, dynamic>? parentTask;
                if (row['kind'] == 'submission') {
                  final parents = rows.where((r) => r['id'] == row['parent'] && r['kind'] == 'task');
                  if (parents.isEmpty || taskClosed(parents.first)) { message('Tugas tidak tersedia atau deadline sudah lewat.'); return; }
                  parentTask = parents.first;
                }
                Navigator.pop(c);
                compose(task: parentTask, editing: row);
              }),
            if (row['owner'] == widget.api.user?['id'] || widget.api.user?['role'] == 'admin') TextButton.icon(
              icon: const Icon(Icons.delete_outline), label: const Text('Hapus'),
              onPressed: () async {
                final yes = await showDialog<bool>(context: c, builder: (d) => AlertDialog(
                    title: const Text('Hapus data dan lampirannya?'), content: const Text('Tindakan ini tidak dapat dibatalkan.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
                      FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Hapus'))]));
                if (yes != true) return;
                try { await store.remove(row['id'] as String); if (c.mounted) Navigator.pop(c); await load(); }
                catch (e) { message(e); }
              },
            ),
          ]),
        )));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Materi & tugas lokal'), actions: [
      IconButton(tooltip: 'Materi lama', icon: const Icon(Icons.history), onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: widget.legacyBuilder))),
      IconButton(tooltip: 'Muat ulang', onPressed: busy ? null : load, icon: const Icon(Icons.refresh)),
    ]),
    floatingActionButton: writer && kind != 'submission' ? FloatingActionButton(
        onPressed: busy ? null : () => compose(), child: const Icon(Icons.add)) : null,
    body: ListView(padding: const EdgeInsets.fromLTRB(16,16,16,90), children: [
      const Text('Lokal satu HP. Bergantian login untuk membuat tugas dan mengumpulkan jawaban. Tidak dikirim ke perangkat lain.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        for (final item in const {'material':'Materi','task':'Tugas','submission':'Pengumpulan'}.entries)
          ChoiceChip(label: Text(item.value), selected: kind == item.key,
              onSelected: (_) => setState(() => kind = item.key)),
      ]),
      if (busy) const LinearProgressIndicator(),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      if (!busy && !rows.any((r) => r['kind'] == kind)) const Padding(padding: EdgeInsets.all(24), child: Text('Belum ada data. Materi sebelumnya tersedia melalui ikon riwayat di atas.')),
      for (final row in rows.where((r) => r['kind'] == kind)) Card(child: ListTile(
          title: Text(row['title'] as String),
          subtitle: Text('${row['code']} • ${(row['files'] as List).length} lampiran${row['kind'] == 'submission' ? '' : '\nDeadline: ${deadlineLabel(row)}'}${row['kind'] == 'task' && taskClosed(row) ? ' — Ditutup' : ''}${row['kind']=='submission'?'\n${assessmentSummary(row)}':''}'),
          trailing: const Icon(Icons.chevron_right), onTap: () => detail(row))),
    ]),
  );
}

class TaskCompose extends StatefulWidget {
  const TaskCompose({super.key, required this.store, required this.kind, this.task, this.editing});
  final LocalTaskFiles store;
  final String kind;
  final Map<String, dynamic>? task;
  final Map<String, dynamic>? editing;
  @override
  State<TaskCompose> createState() => _TaskComposeState();
}
class _TaskComposeState extends State<TaskCompose> with WidgetsBindingObserver {
  final title = TextEditingController();
  final text = TextEditingController();
  final recorder = AudioRecorder();
  final files = <Map<String, String>>[];
  final temps = <String>[];
  final retained = <Map<String, dynamic>>[];
  String? code;
  bool busy = false;
  bool recording = false;
  DateTime? deadline;
  String? error;
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    final original = widget.editing;
    code = original?['code'] as String? ?? widget.task?['code'] as String?;
    if (original != null) {
      title.text = original['title'] as String;
      text.text = original['text'] as String;
      deadline = DateTime.tryParse(original['deadline']?.toString() ?? '')?.toLocal();
      retained.addAll((original['files'] as List).map((f) => Map<String, dynamic>.from(f as Map)));
    } else if (widget.task != null) { title.text = 'Jawaban: ${widget.task!['title']}'; }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    title.dispose(); text.dispose(); recorder.dispose();
    // Hanya rekaman sementara buatan aplikasi; file galeri tidak dihapus.
    for (final path in temps) { File(path).delete().catchError((Object _) => File(path)); }
    super.dispose();
  }
  void fail(Object e) { if (mounted) setState(() => error = '$e'); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (recording && state == AppLifecycleState.paused) { stopRecording(); }
  }

  Future<void> pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context,
        initialDate: deadline != null && deadline!.isAfter(now) ? deadline! : now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 10, 12, 31));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context,
        initialTime: TimeOfDay.fromDateTime(deadline ?? now.add(const Duration(hours: 1))));
    if (time == null || !mounted) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!value.isAfter(DateTime.now())) { fail('Pilih tanggal dan jam setelah waktu sekarang.'); return; }
    setState(() { deadline = value; error = null; });
  }

  Future<void> selectMk() async {
    final selected = await showDialog<String>(context: context, builder: (_) => const CoursePicker());
    if (mounted && selected != null) setState(() => code = selected);
  }
  Future<void> attachments() async {
    final action = await showModalBottomSheet<String>(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      for (final item in const {'doc':'Dokumen','media':'Foto & Video','camera':'Kamera','audio':'Audio'}.entries)
        ListTile(leading: Icon({'doc':Icons.description,'media':Icons.photo_library,'camera':Icons.camera_alt,'audio':Icons.headphones}[item.key]),
            title: Text(item.value), onTap: () => Navigator.pop(c, item.key)),
    ])));
    if (action == null || !mounted) return;
    setState(() { busy = true; error = null; });
    try {
      if (action == 'camera') {
        final mode = await showDialog<String>(context: context, builder: (c) => SimpleDialog(title: const Text('Kamera'), children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(c,'photo'), child: const Text('Ambil foto')),
          SimpleDialogOption(onPressed: () => Navigator.pop(c,'video'), child: const Text('Rekam video (maks. 2 menit)'))]));
        final picker = ImagePicker();
        final f = mode == 'photo' ? await picker.pickImage(source: ImageSource.camera, imageQuality: 85)
            : mode == 'video' ? await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 2)) : null;
        if (f != null) await add(f.path, f.name, mode == 'photo' ? 'image' : 'video');
      } else if (action == 'audio') {
        if (!mounted) return;
        final mode = await showDialog<String>(context: context, builder: (c) => SimpleDialog(title: const Text('Audio'), children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(c,'file'), child: const Text('Pilih file audio')),
          SimpleDialogOption(onPressed: () => Navigator.pop(c,'record'), child: const Text('Rekam suara'))]));
        if (mode == 'record') {
          if (!await recorder.hasPermission()) throw Exception('Izin mikrofon diperlukan untuk merekam.');
          final dir = await getTemporaryDirectory();
          final path = '${dir.path}/suara_${DateTime.now().microsecondsSinceEpoch}.m4a';
          temps.add(path);
          await recorder.start(const RecordConfig(), path: path);
          if (mounted) setState(() => recording = true);
        } else if (mode == 'file') { await pick(FileType.audio); }
      } else { await pick(action == 'media' ? FileType.media : FileType.any); }
    } catch (e) { fail(e); }
    if (mounted) setState(() => busy = false);
  }
  Future<void> pick(FileType type) async {
    final result = await FilePicker.platform.pickFiles(type: type, allowMultiple: true);
    for (final f in result?.files ?? <PlatformFile>[]) {
      if (f.path == null) throw Exception('File tidak dapat diakses. Pilih file lokal yang sudah diunduh.');
      await add(f.path!, f.name, type == FileType.audio ? 'audio' : 'file');
    }
  }
  Future<void> add(String path, String name, String type) async {
    if (files.length + retained.length >= 10) throw Exception('Maksimal 10 lampiran.');
    if (await File(path).length() > 50 * 1024 * 1024) throw Exception('$name melebihi 50 MB.');
    if (mounted) setState(() => files.add({'path':path,'name':name,'type':type}));
  }
  Future<void> stopRecording() async {
    try {
      final path = await recorder.stop();
      if (mounted) setState(() => recording = false);
      if (path != null) await add(path, path.split('/').last, 'audio');
    } catch (e) { fail(e); if (mounted) setState(() => recording = false); }
  }
  Future<void> save() async {
    setState(() { busy = true; error = null; });
    try {
      if (!kSemuaMataKuliah.any((m) => m.kode == code)) throw Exception('Pilih MK dari kurikulum.');
      await widget.store.save(kind: widget.kind, code: code!, title: title.text,
          text: text.text, parent: widget.editing?['parent'] as String? ?? widget.task?['id'] as String?, deadline: deadline,
          editId: widget.editing?['id'] as String?, expectedVersion: (widget.editing?['updated'] ?? widget.editing?['created']) as String?,
          keepPaths: retained.map((f) => f['path'] as String).toList(), files: List.of(files));
      if (mounted) Navigator.pop(context);
    } catch (e) { fail(e); if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final matches = kSemuaMataKuliah.where((m) => m.kode == code);
    final mkLabel = matches.isEmpty ? 'Pilih kode dan nama MK' : '${matches.first.kode} — ${matches.first.nama}';
    return PopScope(canPop: !busy && !recording, child: Scaffold(
      appBar: AppBar(title: Text(widget.editing != null ? 'Edit ${widget.kind == 'submission' ? 'jawaban' : widget.kind == 'task' ? 'tugas' : 'materi'}' : widget.kind == 'submission' ? 'Kumpulkan tugas' : widget.kind == 'task' ? 'Buat tugas' : 'Tambah materi')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        OutlinedButton.icon(onPressed: busy || recording || widget.task != null ? null : selectMk,
            icon: const Icon(Icons.menu_book), label: Text(mkLabel)),
        TextField(controller: title, enabled: !busy && !recording, maxLength: 160, decoration: const InputDecoration(labelText: 'Judul')),
        TextField(controller: text, enabled: !busy && !recording, maxLength: 20000, minLines: 4, maxLines: 10,
            decoration: InputDecoration(labelText: widget.kind == 'submission' ? 'Jawaban / keterangan' : 'Isi materi / instruksi tugas')),
        if (widget.kind != 'submission') ...[
          OutlinedButton.icon(onPressed: busy || recording ? null : pickDeadline,
              icon: const Icon(Icons.event), label: Text(deadline == null ? 'Pilih tanggal & jam deadline (opsional)' : 'Deadline: ${deadlineLabel({'deadline': deadline!.toIso8601String()})}')),
          if (deadline != null) TextButton(onPressed: busy || recording ? null : () => setState(() => deadline = null), child: const Text('Hapus deadline')),
          Text(widget.kind == 'task' ? 'Setelah deadline, pengumpulan ditutup. Mengikuti jam HP ini.' : 'Deadline materi hanya informasi; penutupan pengumpulan berlaku pada Tugas.'),
        ],
        if (widget.task != null) Text('Deadline tugas: ${deadlineLabel(widget.task!)}'),
        const Text('Isi teks atau lampiran. Maksimal 10 file, 50 MB/file, total 200 MB. Lokal satu HP.'),
        OutlinedButton.icon(onPressed: busy || recording ? null : attachments,
            icon: const Icon(Icons.attach_file), label: const Text('Tambah lampiran')),
        if (recording) FilledButton.icon(onPressed: stopRecording, icon: const Icon(Icons.stop), label: const Text('Hentikan & lampirkan rekaman')),
        if (recording) const Text('Sedang merekam. Hentikan rekaman sebelum menyimpan atau kembali.'),
        for (int i = 0; i < retained.length; i++) ListTile(
            leading: const Icon(Icons.attach_file), title: Text(retained[i]['name'] as String), subtitle: const Text('Lampiran tersimpan — dipertahankan'),
            trailing: IconButton(tooltip: 'Lepas lampiran saat simpan', icon: const Icon(Icons.close), onPressed: busy || recording ? null : () => setState(() => retained.removeAt(i)))),
        for (int i = 0; i < files.length; i++) ListTile(
            leading: const Icon(Icons.insert_drive_file), title: Text(files[i]['name']!),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: busy || recording ? null : () => setState(() => files.removeAt(i)))),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        FilledButton(onPressed: busy || recording ? null : save, child: Text(busy ? 'Memproses…' : widget.editing != null ? 'Simpan perubahan' : widget.kind == 'submission' ? 'Kumpulkan' : 'Simpan')),
      ]),
    ));
  }
}

class CoursePicker extends StatefulWidget {
  const CoursePicker({super.key});
  @override
  State<CoursePicker> createState() => _CoursePickerState();
}
class _CoursePickerState extends State<CoursePicker> {
  String query = '';
  int? semester;
  @override
  Widget build(BuildContext context) {
    final items = kSemuaMataKuliah.where((m) => (semester == null || m.semester == semester) && '${m.kode} ${m.nama} ${m.semester}'.toLowerCase().contains(query.toLowerCase())).toList()..sort((a,b) { final c = a.semester.compareTo(b.semester); return c == 0 ? a.kode.compareTo(b.kode) : c; });
    return AlertDialog(title: const Text('MK S1 Informatika'), content: SizedBox(width: 460, height: MediaQuery.sizeOf(context).height * .6,
        child: Column(children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            ChoiceChip(label: const Text('Semua'), selected: semester == null, onSelected: (_) => setState(() => semester = null)),
            for (int n = 1; n <= 8; n++) Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(label: Text('Semester $n'), selected: semester == n, onSelected: (_) => setState(() => semester = n))),
          ])),
          TextField(autofocus: false, decoration: const InputDecoration(labelText: 'Cari kode, nama, atau semester'), onChanged: (v) => setState(() => query = v)),
          Expanded(child: ListView.builder(itemCount: items.length, itemBuilder: (_, i) => ListTile(
              title: Text('${items[i].kode} — ${items[i].nama}'), subtitle: Text('Semester ${items[i].semester} • ${items[i].sks} SKS'),
              onTap: () => Navigator.pop(context, items[i].kode)))),
        ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal'))]);
  }
}

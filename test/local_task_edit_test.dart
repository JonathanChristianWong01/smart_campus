import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulia_smart_campus/data/curriculum_data.dart';
import 'package:mulia_smart_campus/services/campus_auth_api.dart';
import 'package:mulia_smart_campus/services/local_task_files.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CampusAuthApi api;
  late LocalTaskFiles store;
  late Directory root;
  late DateTime now;
  const pw = 'Strong-Password-123';
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    root = await Directory.systemTemp.createTemp('campus_edit');
    now = DateTime.utc(2030, 1, 1, 8);
    api = CampusAuthApi(); await api.initialize();
    await api.bootstrapAdmin('admin1', pw); await api.login('admin1', pw);
    store = LocalTaskFiles(api, documentsDirectory: () async => root, clock: () => now);
  });
  tearDown(() async { api.dispose(); await root.delete(recursive: true); });
  Future<Map<String, dynamic>> create() async {
    final f = File('${root.path}/asli.txt'); await f.writeAsString('lampiran lama');
    await store.save(kind:'task',code:kSemuaMataKuliah.first.kode,title:'Judul',text:'Instruksi',deadline:now.add(const Duration(hours:1)),
        files:[{'path':f.path,'name':'asli.txt','type':'file'}]);
    return (await store.list()).first;
  }
  Future<void> edit(Map<String,dynamic> r, {List<String>? keep, List<Map<String,String>> files = const [], DateTime? deadline}) => store.save(
      kind:r['kind'] as String,code:r['code'] as String,title:'Judul diubah',text:'Isi diubah',parent:r['parent'] as String?,
      editId:r['id'] as String,expectedVersion:(r['updated'] ?? r['created']) as String,
      deadline:deadline ?? DateTime.tryParse(r['deadline']?.toString() ?? ''),
      keepPaths:keep ?? (r['files'] as List).map((f) => f['path'] as String).toList(),files:files);
  test('Edit mempertahankan ID, pembuat, waktu dibuat, lampiran, dan memperpanjang deadline', () async {
    final old = await create(); now = now.add(const Duration(minutes:1));
    final limit = now.add(const Duration(hours:2));
    await edit(old,deadline:limit);
    final row = (await store.list()).single;
    expect(row['id'],old['id']); expect(row['owner'],old['owner']); expect(row['created'],old['created']);
    expect(row['title'],'Judul diubah'); expect(row['deadline'],limit.toIso8601String());
    final file = (row['files'] as List).single;
    expect(await File(file['path'] as String).readAsString(),'lampiran lama');
    await expectLater(edit(old),throwsException); // Snapshot lama ditolak.
  });
  test('Lepas lampiran hanya membersihkan salinan setelah simpan sukses', () async {
    final old = await create(); final path = ((old['files'] as List).single as Map)['path'] as String;
    await edit(old,keep:[]);
    expect((await store.list()).single['files'],isEmpty);
    expect(await File(path).exists(),isFalse);
    expect(await File('${root.path}/asli.txt').exists(),isTrue);
  });
  test('Edit gagal tidak merusak metadata atau lampiran lama', () async {
    final old = await create(); final path = ((old['files'] as List).single as Map)['path'] as String;
    await expectLater(edit(old,files:[{'path':'${root.path}/tidak_ada','name':'hilang.txt','type':'file'}]),throwsException);
    expect((await store.list()).single['title'],'Judul'); expect(await File(path).exists(),isTrue);
  });
  test('Mahasiswa revisi sendiri sebelum deadline; sesudah deadline ditolak', () async {
    final task = await create();
    await api.request('POST','/auth/register',{'username':'student1','password':pw,'role':'Mahasiswa'});
    final users = await api.request('GET','/users') as List;
    final student = users.firstWhere((u) => u['username'] == 'student1');
    await api.request('PATCH','/users/${student['id']}',{'active':true});
    await api.logout(); await api.login('student1',pw);
    await expectLater(edit(task),throwsException);
    await store.save(kind:'submission',code:task['code'] as String,title:'Jawaban',text:'Isi',parent:task['id'] as String,files:[]);
    final answer = (await store.list()).firstWhere((r) => r['kind']=='submission');
    now = now.add(const Duration(minutes:1)); await edit(answer);
    final latest = (await store.list()).firstWhere((r) => r['kind']=='submission');
    now = now.add(const Duration(hours:2));
    await expectLater(edit(latest),throwsException);
  });
}

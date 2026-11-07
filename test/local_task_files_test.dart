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
  late Directory temp;
  const pw = 'Strong-Password-123';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('campus_task_test');
    api = CampusAuthApi();
    await api.initialize();
    await api.bootstrapAdmin('admin1', pw);
    await api.login('admin1', pw);
    store = LocalTaskFiles(api, documentsDirectory: () async => temp);
  });
  tearDown(() async { api.dispose(); await temp.delete(recursive: true); });
  test('Salinan lampiran bertahan setelah file sumber dihapus', () async {
    final f = File('${temp.path}/asli.txt'); await f.writeAsString('Jawaban');
    await store.save(kind: 'task', code: kSemuaMataKuliah.first.kode,
        title: 'Tugas 1', text: '', files: [{'path':f.path,'name':'jawaban.txt','type':'file'}]);
    await f.delete();
    final row = (await store.list()).single;
    final attachment = (row['files'] as List).single as Map;
    expect(await File(attachment['path'] as String).readAsString(), 'Jawaban');
    await store.openAttachment(row, attachment);
    await store.remove(row['id'] as String);
    expect(await store.list(), isEmpty);
    expect(await File(attachment['path'] as String).exists(), isFalse);
  });
  test('MK tidak dikenal ditolak dan sesi logout tidak bisa membaca', () async {
    await expectLater(store.save(kind:'task',code:'INVALID',title:'Tugas',text:'Isi',files:[]), throwsException);
    await api.logout();
    await expectLater(store.list(), throwsException);
  });
  test('Mahasiswa mengumpulkan sekali dan tidak boleh membuat tugas', () async {
    final code = kSemuaMataKuliah.first.kode;
    await store.save(kind:'task',code:code,title:'Tugas',text:'Instruksi',files:[]);
    final task = (await store.list()).single;
    await api.request('POST','/auth/register',{'username':'mhs1','password':pw,'role':'Mahasiswa'});
    final users = await api.request('GET','/users') as List;
    final user = users.firstWhere((u) => u['username'] == 'mhs1');
    await api.request('PATCH','/users/${user['id']}',{'active':true});
    await api.logout(); await api.login('mhs1',pw);
    await expectLater(store.save(kind:'task',code:code,title:'Tidak boleh',text:'Isi',files:[]), throwsException);
    await store.save(kind:'submission',code:code,title:'Jawaban',text:'Isi',parent:task['id'] as String,files:[]);
    await expectLater(store.save(kind:'submission',code:code,title:'Duplikat',text:'Isi',parent:task['id'] as String,files:[]), throwsException);
    final submission = (await store.list()).firstWhere((r) => r['kind'] == 'submission');
    expect(await store.author(submission), 'mhs1');
    await api.logout(); await api.login('admin1',pw);
    await expectLater(store.remove(task['id'] as String), throwsException);
    await api.request('DELETE','/users/${user['id']}',{'password':pw,'confirm_username':'mhs1'});
    expect(await store.author(submission), 'Akun dihapus');
  });
}

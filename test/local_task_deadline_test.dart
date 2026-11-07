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
  late Directory directory;
  late DateTime now;
  const password = 'Strong-Password-123';
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    directory = await Directory.systemTemp.createTemp('deadline_test');
    now = DateTime.utc(2030, 1, 1, 8);
    api = CampusAuthApi();
    await api.initialize();
    await api.bootstrapAdmin('admin1', password);
    await api.login('admin1', password);
    store = LocalTaskFiles(api, documentsDirectory: () async => directory, clock: () => now);
    await api.request('POST', '/auth/register', {'username':'student1', 'password':password,'role':'Mahasiswa'});
    final users = await api.request('GET','/users') as List;
    final student = users.firstWhere((u) => u['username'] == 'student1');
    await api.request('PATCH','/users/${student['id']}', {'active':true});
  });
  tearDown(() async { api.dispose(); await directory.delete(recursive: true); });

  Future<Map<String, dynamic>> task(DateTime? deadline) async {
    await store.save(kind:'task',code:kSemuaMataKuliah.first.kode,title:'Tugas deadline',text:'Isi',deadline:deadline,files:[]);
    return (await store.list()).firstWhere((r) => r['kind'] == 'task');
  }
  Future<void> loginStudent() async { await api.logout(); await api.login('student1',password); }
  Future<void> submit(Map<String,dynamic> t) => store.save(kind:'submission',code:t['code'] as String,title:'Jawaban',text:'Isi',parent:t['id'] as String,files:[]);

  test('Sebelum deadline diterima dan deadline disimpan UTC', () async {
    final t = await task(now.add(const Duration(hours:1)));
    expect((t['deadline'] as String).endsWith('Z'), isTrue);
    await loginStudent();
    await submit(t);
    expect((await store.list()).where((r) => r['kind'] == 'submission').length,1);
  });
  test('Tepat pada deadline ditolak di service', () async {
    final t = await task(now.add(const Duration(hours:1)));
    now = now.add(const Duration(hours:1));
    await loginStudent();
    await expectLater(submit(t),throwsException);
    expect((await store.list()).where((r) => r['kind'] == 'submission'),isEmpty);
  });
  test('Lewat deadline ditolak dan tugas tanpa deadline tetap bisa', () async {
    final closed = await task(now.add(const Duration(minutes:1)));
    final open = await task(null);
    now = now.add(const Duration(days:2));
    await loginStudent();
    await expectLater(submit(closed),throwsException);
    await submit(open);
  });
  test('Deadline pembuatan yang sudah lewat ditolak', () async {
    await expectLater(task(now.subtract(const Duration(minutes:1))),throwsException);
  });
}

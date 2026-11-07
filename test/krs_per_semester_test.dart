import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulia_smart_campus/data/curriculum_data.dart';
import 'package:mulia_smart_campus/services/campus_auth_api.dart';
import 'package:mulia_smart_campus/services/local_academic_store.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  late CampusAuthApi api;late LocalAcademicStore store;late int student,reviewer;
  final classes=<int,String>{};const password='Strong-Password-123';
  Future<void> login(String name)async{await api.logout();await api.login(name,password);}
  Future<void> profile(int semester)async{
    await store.profile(student,{'name':'Mahasiswa','nim':'2411015','skills':'Dart','bio':'Belajar','semester':'$semester'});
  }
  setUp(()async{
    SharedPreferences.setMockInitialValues(<String,Object>{});classes.clear();
    api=CampusAuthApi();await api.initialize();await api.bootstrapAdmin('admin1',password);await api.login('admin1',password);store=LocalAcademicStore(api);
    for(final e in {'student1':'Mahasiswa','dosen1':'Dosen','tujuan1':'Dosen'}.entries){await api.request('POST','/auth/register',{'username':e.key,'password':password,'role':e.value});}
    final users=await api.request('GET','/users') as List;
    for(final u in users.where((u)=>u['role']!='admin')){await api.request('PATCH','/users/${u['id']}',{'active':true});}
    student=users.firstWhere((u)=>u['username']=='student1')['id'] as int;
    final teacher=users.firstWhere((u)=>u['username']=='dosen1')['id'] as int;
    reviewer=users.firstWhere((u)=>u['username']=='tujuan1')['id'] as int;
    for(final semester in kSemuaMataKuliah.map((m)=>m.semester).toSet()){
      final mk=kSemuaMataKuliah.firstWhere((m)=>m.semester==semester);
      await store.saveClass({'teacher':teacher,'code':mk.kode,'term':'2026/2027','label':'Semester $semester','day':1,'start':'${(7+semester).toString().padLeft(2,'0')}:00','end':'${(8+semester).toString().padLeft(2,'0')}:00','room':'R1'});
      classes[semester]=((await store.view())['classes'] as List).firstWhere((c)=>c['label']=='Semester $semester')['id'] as String;
    }
    final created=(await store.view())['classes'] as List;
    expect(created.map((c)=>c['id']).toSet().length,created.length,reason:'ID kelas tidak boleh duplikat walau dibuat cepat.');
    for(final entry in classes.entries){
      final row=created.singleWhere((c)=>c['id']==entry.value);
      expect(kSemuaMataKuliah.any((m)=>m.kode==row['code']&&m.semester==entry.key),isTrue);
    }
  });
  tearDown(()=>api.dispose());
  for(final semester in kSemuaMataKuliah.map((m)=>m.semester).toSet()){
    test('Semester $semester tanpa IPK dapat memilih MK sendiri, ACC dan absensi',()async{
      await profile(semester);await login('student1');await store.submitKrs('2026/2027',[classes[semester]!],reviewer:reviewer);
      final v=await store.view();expect(v['profiles']['$student']['gpa'],isNull);expect(v['krs'].single['semester'],semester);
      final id=v['krs'].single['id'] as String;await login('tujuan1');await store.reviewKrs(id,true,'');
      await store.attendance(classes[semester]!,student,'2026-11-08','Hadir');
    });
  }
  test('Semester 1 ditolak memilih MK semester 2 atau mencampur semester',()async{
    await profile(1);await login('student1');
    await expectLater(store.submitKrs('2026/2027',[classes[2]!],reviewer:reviewer),throwsException);
    await expectLater(store.submitKrs('2026/2027',[classes[1]!,classes[2]!],reviewer:reviewer),throwsException);
    expect((await store.view())['krs'],isEmpty);
  });
  test('Semester 9 tanpa penawaran yang sesuai tidak boleh memilih kelas semester 1',()async{
    await profile(9);await login('student1');
    await expectLater(store.submitKrs('2026/2027',[classes[1]!],reviewer:reviewer),throwsException);
  });
}

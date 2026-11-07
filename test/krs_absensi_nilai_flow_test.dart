import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulia_smart_campus/data/curriculum_data.dart';
import 'package:mulia_smart_campus/services/campus_auth_api.dart';
import 'package:mulia_smart_campus/services/local_academic_store.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  late CampusAuthApi api;late LocalAcademicStore store;
  late int student,pa,pengampu;late String classId,krsId;
  const pw='Strong-Password-123';
  Future<void> login(String name)async{await api.logout();await api.login(name,pw);}
  setUp(()async{
    SharedPreferences.setMockInitialValues(<String,Object>{});
    api=CampusAuthApi();await api.initialize();await api.bootstrapAdmin('admin1',pw);await api.login('admin1',pw);store=LocalAcademicStore(api);
    for(final item in {'student1':'Mahasiswa','pa1':'Dosen','pengampu1':'Dosen'}.entries){await api.request('POST','/auth/register',{'username':item.key,'password':pw,'role':item.value});}
    final users=await api.request('GET','/users') as List;
    for(final u in users.where((u)=>u['role']!='admin')){await api.request('PATCH','/users/${u['id']}',{'active':true});}
    student=users.firstWhere((u)=>u['username']=='student1')['id'] as int;
    pa=users.firstWhere((u)=>u['username']=='pa1')['id'] as int;
    pengampu=users.firstWhere((u)=>u['username']=='pengampu1')['id'] as int;
    await store.assignPa(student,pa);
    await store.profile(student,{'name':'Mahasiswa','nim':'2411015','skills':'Dart','bio':'Belajar','semester':'1','gpa':'3.5'});
    await store.saveClass({'teacher':pengampu,'code':kSemuaMataKuliah.first.kode,'term':'2026/2027 Ganjil','label':'A','day':1,'start':'08:00','end':'09:40','room':'R1'});
    classId=((await store.view())['classes'] as List).single['id'] as String;
    await login('student1');await store.submitKrs('2026/2027 Ganjil',[classId]);
    krsId=((await store.view())['krs'] as List).single['id'] as String;
  });
  tearDown(()=>api.dispose());
  Future<void> approve()async{await login('pa1');await store.reviewKrs(krsId,true,'ACC PA');}
  test('PA menyetujui, bukan Admin atau pengampu yang bukan PA',()async{
    await login('admin1');await expectLater(store.reviewKrs(krsId,true,''),throwsException);
    await login('pengampu1');await expectLater(store.reviewKrs(krsId,true,''),throwsException);
    await approve();await login('pengampu1');
    expect((await store.view())['rosters'][classId],[student]);
  });
  test('Sebelum ACC belum ada roster dan pengampu belum boleh mencatat',()async{
    await login('pengampu1');expect((await store.view())['rosters'][classId],isEmpty);
    await expectLater(store.attendance(classId,student,'2026-11-04','Hadir'),throwsException);
    await expectLater(store.grade(classId,student,'85','A',''),throwsException);
  });
  test('Pengampu mencatat empat status dan memperbarui nilai tanpa duplikat',()async{
    await approve();await login('pengampu1');
    const statuses=['Hadir','Izin','Sakit','Alpa'];
    for(int i=0;i<statuses.length;i++){await store.attendance(classId,student,'2026-11-0${i+1}',statuses[i]);}
    await store.grade(classId,student,'80','B','Awal');await store.grade(classId,student,'90','A','Revisi');
    await login('student1');final v=await store.view();
    expect((v['attendance'] as List).map((r)=>r['status']).toSet(),statuses.toSet());
    expect((v['grades'] as List).single['score'],90.0);
    expect(v['profiles']['$student']['gpa'],3.5);
  });
  test('PA yang bukan pengampu dan Mahasiswa tidak dapat mengisi nilai/absensi',()async{
    await approve();
    await expectLater(store.grade(classId,student,'100','A',''),throwsException);
    await expectLater(store.attendance(classId,student,'2026-11-04','Hadir'),throwsException);
    await login('student1');await expectLater(store.grade(classId,student,'100','A',''),throwsException);
  });
}

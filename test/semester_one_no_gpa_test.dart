import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulia_smart_campus/data/curriculum_data.dart';
import 'package:mulia_smart_campus/services/campus_auth_api.dart';
import 'package:mulia_smart_campus/services/local_academic_store.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  late CampusAuthApi api;late LocalAcademicStore store;
  late int student,pa,pengampu,selectedTeacher,secondStudent;late String classId,krsId;
  const pw='Strong-Password-123';
  Future<void> login(String name)async{await api.logout();await api.login(name,pw);}
  setUp(()async{
    SharedPreferences.setMockInitialValues(<String,Object>{});
    api=CampusAuthApi();await api.initialize();await api.bootstrapAdmin('admin1',pw);await api.login('admin1',pw);store=LocalAcademicStore(api);
    for(final item in {'student1':'Mahasiswa','pa1':'Dosen','pengampu1':'Dosen','pilihan1':'Dosen','student2':'Mahasiswa'}.entries){await api.request('POST','/auth/register',{'username':item.key,'password':pw,'role':item.value});}
    final users=await api.request('GET','/users') as List;
    for(final u in users.where((u)=>u['role']!='admin')){await api.request('PATCH','/users/${u['id']}',{'active':true});}
    student=users.firstWhere((u)=>u['username']=='student1')['id'] as int;
    pa=users.firstWhere((u)=>u['username']=='pa1')['id'] as int;
    pengampu=users.firstWhere((u)=>u['username']=='pengampu1')['id'] as int;
    selectedTeacher=users.firstWhere((u)=>u['username']=='pilihan1')['id'] as int;
    secondStudent=users.firstWhere((u)=>u['username']=='student2')['id'] as int;
    await store.profile(secondStudent,{'name':'Mahasiswa Dua','nim':'2411016','skills':'Dart','bio':'Belajar','semester':'1'});
    await store.assignPa(student,pa);
    await store.profile(student,{'name':'Mahasiswa','nim':'2411015','skills':'Dart','bio':'Belajar','semester':'1'});
    await store.saveClass({'teacher':pengampu,'code':kSemuaMataKuliah.first.kode,'term':'2026/2027 Ganjil','label':'A','day':1,'start':'08:00','end':'09:40','room':'R1'});
    classId=((await store.view())['classes'] as List).single['id'] as String;
    await login('student1');await store.submitKrs('2026/2027 Ganjil',[classId]);
    krsId=((await store.view())['krs'] as List).single['id'] as String;
  });
  tearDown(()=>api.dispose());
  test('Semester 1 tanpa IPK dapat diajukan, ACC Dosen pilihan, lalu absensi',()async{
    expect((await store.view())['profiles']['$student']['gpa'],isNull);
    await store.redirectKrs(krsId,selectedTeacher);
    await login('pilihan1');await store.reviewKrs(krsId,true,'ACC semester 1');
    await store.attendance(classId,student,'2026-11-04','Hadir');
    await login('student1');final v=await store.view();
    expect(v['krs'].single['status'],'approved');expect(v['attendance'].single['status'],'Hadir');
    expect(v['profiles']['$student']['gpa'],isNull);
  });
  test('IPK kosong tetap diperbolehkan tanpa mengubahnya menjadi nol',()async{
    expect((await store.view())['profiles']['$student']['gpa'],isNull);
    expect((await store.view())['krs'].single['status'],'pending');
  });
  test('Semester 1 tanpa PA juga dapat memilih Dosen dan ACC tanpa IPK',()async{
    await login('student2');await store.submitKrs('2026/2027 Ganjil',[classId],reviewer:selectedTeacher);
    final id=(await store.view())['krs'].single['id'] as String;
    await login('pilihan1');await store.reviewKrs(id,true,'');
    await login('student2');expect((await store.view())['profiles']['$secondStudent']['gpa'],isNull);
    expect((await store.view())['krs'].single['status'],'approved');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulia_smart_campus/data/curriculum_data.dart';
import 'package:mulia_smart_campus/services/campus_auth_api.dart';
import 'package:mulia_smart_campus/services/local_academic_store.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  late CampusAuthApi api;late LocalAcademicStore store;
  late int student,teacher,other,secondStudent;
  const pw='Strong-Password-123';
  Future<void> login(String name)async{await api.logout();await api.login(name,pw);}
  setUp(()async{
    SharedPreferences.setMockInitialValues(<String,Object>{});
    api=CampusAuthApi();await api.initialize();await api.bootstrapAdmin('admin1',pw);await api.login('admin1',pw);
    store=LocalAcademicStore(api);
    for(final item in {'student1':'Mahasiswa','student2':'Mahasiswa','teacher1':'Dosen','teacher2':'Dosen'}.entries){
      await api.request('POST','/auth/register',{'username':item.key,'password':pw,'role':item.value});
    }
    final users=await api.request('GET','/users') as List;
    for(final u in users.where((u)=>u['role']!='admin')){await api.request('PATCH','/users/${u['id']}',{'active':true});}
    student=users.firstWhere((u)=>u['username']=='student1')['id'] as int;
    secondStudent=users.firstWhere((u)=>u['username']=='student2')['id'] as int;
    teacher=users.firstWhere((u)=>u['username']=='teacher1')['id'] as int;
    other=users.firstWhere((u)=>u['username']=='teacher2')['id'] as int;
    await store.assignPa(student,teacher);
    await store.profile(student,{'name':'Mahasiswa Satu','nim':'2411015','semester':'1','skills':'Dart','bio':'Belajar informatika','gpa':'3.5'});
    await store.saveClass({'code':kSemuaMataKuliah.first.kode,'teacher':teacher,'term':'2026/2027 Ganjil','label':'A','day':1,'start':'08:00','end':'09:40','room':'R1'});
  });
  tearDown(()=>api.dispose());
  Future<String> classId()async=>(((await store.view())['classes'] as List).first as Map)['id'] as String;
  Future<String> submit()async{
    await login('student1');final c=await classId();await store.submitKrs('2026/2027 Ganjil',[c]);
    return (((await store.view())['krs'] as List).first as Map)['id'] as String;
  }
  test('Mahasiswa tidak mengubah IPK atau menetapkan PA dan tidak melihat mahasiswa lain',()async{
    await login('student1');
    await expectLater(store.profile(student,{'name':'Satu','nim':'2411015','semester':'1','skills':'Dart','bio':'Isi','gpa':'4.0'}),throwsException);
    await expectLater(store.assignPa(student,other),throwsException);
    final view=await store.view();expect((view['users'] as List).any((u)=>u['id']==secondStudent),isFalse);
    expect(view['profiles']['$student']['gpa'],3.5);
  });
  test('Hanya PA yang ditetapkan menyetujui KRS; pengampu mencatat nilai dan absensi',()async{
    final krs=await submit();
    await login('teacher2');await expectLater(store.reviewKrs(krs,true,''),throwsException);
    await login('teacher1');await store.reviewKrs(krs,true,'Disetujui');final c=await classId();
    await store.attendance(c,student,'2026-11-04','Hadir');await store.grade(c,student,'85','A','Manual');
    await login('student1');final own=await store.view();
    expect((own['attendance'] as List).single['status'],'Hadir');expect((own['grades'] as List).single['score'],85.0);
    await expectLater(store.grade(c,student,'100','A',''),throwsException);
    expect(own['profiles']['$student']['gpa'],3.5);
  });
  test('Revisi KRS dan bimbingan oleh PA',()async{
    final krs=await submit();await login('teacher1');await store.reviewKrs(krs,false,'Periksa pilihan');
    await store.guidance(student,'Rencana studi','Pilih sesuai kurikulum');
    await login('student1');final d=await store.view();expect((d['guidance'] as List).single['topic'],'Rencana studi');
    await store.submitKrs('2026/2027 Ganjil',[await classId()]);expect(((await store.view())['krs'] as List).single['status'],'pending');
  });
  test('NIM unik dan persetujuan diperlukan sebelum nilai/absensi',()async{
    await expectLater(store.profile(secondStudent,{'name':'Dua','nim':'2411015','semester':'1','skills':'JS','bio':'Isi'}),throwsException);
    final c=await classId();await login('teacher1');
    await expectLater(store.grade(c,student,'80','B',''),throwsException);
    await expectLater(store.attendance(c,student,'2026-11-04','Hadir'),throwsException);
  });
  test('Profil ketua kelas tidak mengubah role login',()async{
    await login('student1');await store.profile(student,{'name':'Mahasiswa','nim':'2411015','semester':'1','skills':'Dart','bio':'Isi','position':'Ketua kelas'});
    expect(api.user!['role'],'Mahasiswa');
    expect((await store.view())['profiles']['$student']['position'],'Ketua kelas');
  });
}

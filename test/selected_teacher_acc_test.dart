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
    await store.profile(secondStudent,{'name':'Mahasiswa Dua','nim':'2411016','skills':'Dart','bio':'Belajar','semester':'1','gpa':'3.5'});
    await store.assignPa(student,pa);
    await store.profile(student,{'name':'Mahasiswa','nim':'2411015','skills':'Dart','bio':'Belajar','semester':'1','gpa':'3.5'});
    await store.saveClass({'teacher':pengampu,'code':kSemuaMataKuliah.first.kode,'term':'2026/2027 Ganjil','label':'A','day':1,'start':'08:00','end':'09:40','room':'R1'});
    classId=((await store.view())['classes'] as List).single['id'] as String;
    await login('student1');await store.submitKrs('2026/2027 Ganjil',[classId]);
    krsId=((await store.view())['krs'] as List).single['id'] as String;
  });
  tearDown(()=>api.dispose());
  Future<void> approve()async{await login('pa1');await store.reviewKrs(krsId,true,'ACC PA');}
  test('Admin mengisi nilai Dosen, tetap dilarang ACC dan mencatat presensi',()async{
    await login('admin1');
    await expectLater(store.grade(classId,student,'85','A','Dari Dosen'),throwsException);
    await expectLater(store.reviewKrs(krsId,true,''),throwsException);
    await approve();await login('admin1');
    await expectLater(store.attendance(classId,student,'2026-11-04','Hadir'),throwsException);
    await store.grade(classId,student,'85','A','Sumber: penilaian Dosen pengampu');
    await login('student1');expect((await store.view())['grades'].single['score'],85.0);
    await login('pengampu1');await store.grade(classId,student,'90','A','Koreksi Dosen');
    expect((await store.view())['grades'].single['score'],90.0);
  });
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
  test('Dosen pilihan bukan PA/pengampu menerima ACC, lalu hanya absensi',()async{
    await login('student1');await store.redirectKrs(krsId,selectedTeacher);
    await login('pa1');await expectLater(store.reviewKrs(krsId,true,''),throwsException);
    await login('pengampu1');await expectLater(store.reviewKrs(krsId,true,''),throwsException);
    await login('pilihan1');
    expect((await store.view())['krs'].single['id'],krsId);
    await expectLater(store.attendance(classId,student,'2026-11-04','Hadir'),throwsException);
    await store.reviewKrs(krsId,true,'ACC pilihan');
    final v=await store.view();expect(v['attendanceRosters'][classId],[student]);
    expect(v['rosters'][classId],isNull);
    await store.attendance(classId,student,'2026-11-04','Hadir');
    expect((await store.view())['attendance'].single['status'],'Hadir');
    await expectLater(store.grade(classId,student,'95','A',''),throwsException);
    await login('student1');expect((await store.view())['attendance'].single['status'],'Hadir');
    await expectLater(store.redirectKrs(krsId,pa),throwsException);
    await login('admin1');await expectLater(store.reviewKrs(krsId,true,''),throwsException);
  });
  test('Batas peserta: tidak dapat mengabsen Mahasiswa yang disetujui Dosen lain',()async{
    await login('student1');await store.redirectKrs(krsId,selectedTeacher);
    await login('pilihan1');await store.reviewKrs(krsId,true,'');
    await login('student2');await store.submitKrs('2026/2027 Ganjil',[classId],reviewer:pa);
    final other=((await store.view())['krs'] as List).single['id'] as String;
    await login('pa1');await store.reviewKrs(other,true,'');
    await login('pilihan1');
    expect((await store.view())['attendanceRosters'][classId],[student]);
    await expectLater(store.attendance(classId,secondStudent,'2026-11-04','Alpa'),throwsException);
    await login('pengampu1');expect(((await store.view())['attendanceRosters'][classId] as List).toSet(),{student,secondStudent});
  });
  test('Tanpa PA bisa memilih Dosen, revisi mencabut akses sampai ACC ulang',()async{
    await login('student2');await store.submitKrs('2026/2027 Ganjil',[classId],reviewer:selectedTeacher);
    final id=((await store.view())['krs'] as List).single['id'] as String;
    await login('pilihan1');await store.reviewKrs(id,true,'');
    await store.attendance(classId,secondStudent,'2026-11-04','Izin');
    await store.reviewKrs(id,false,'Perbaiki pengajuan');
    await expectLater(store.attendance(classId,secondStudent,'2026-11-05','Hadir'),throwsException);
    await login('student2');await store.submitKrs('2026/2027 Ganjil',[classId],reviewer:pa);
    await login('pilihan1');await expectLater(store.reviewKrs(id,true,''),throwsException);
    await login('pa1');await store.reviewKrs(id,true,'');await store.attendance(classId,secondStudent,'2026-11-05','Sakit');
  });

}

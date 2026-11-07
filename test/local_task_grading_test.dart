import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mulia_smart_campus/data/curriculum_data.dart';
import 'package:mulia_smart_campus/services/campus_auth_api.dart';
import 'package:mulia_smart_campus/services/local_task_files.dart';
import 'package:mulia_smart_campus/services/local_academic_store.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  late CampusAuthApi api;late LocalTaskFiles tasks;late LocalAcademicStore academic;
  late Directory root;late DateTime now;late int student,teacher,other;
  late String taskId,submissionId,classId;
  const password='Strong-Password-123';
  String getVersion(Map r)=>(r['updated']??r['created']) as String;
  Future<void> login(String name)async{await api.logout();await api.login(name,password);}
  Future<Map<String,dynamic>> submission()async=>(await tasks.list()).firstWhere((r)=>r['id']==submissionId);
  Future<void> approve()async{
    await login('student1');await academic.submitKrs('2026/2027',[classId],reviewer:other);
    final id=(await academic.view())['krs'].single['id'] as String;
    await login('other1');await academic.reviewKrs(id,true,'');
  }
  setUp(()async{
    SharedPreferences.setMockInitialValues(<String,Object>{});
    root=await Directory.systemTemp.createTemp('task_grading');now=DateTime.utc(2030,1,1,8);
    api=CampusAuthApi();await api.initialize();await api.bootstrapAdmin('admin1',password);await api.login('admin1',password);
    tasks=LocalTaskFiles(api,documentsDirectory:()async=>root,clock:()=>now);academic=LocalAcademicStore(api);
    for(final e in {'student1':'Mahasiswa','student2':'Mahasiswa','teacher1':'Dosen','other1':'Dosen'}.entries){await api.request('POST','/auth/register',{'username':e.key,'password':password,'role':e.value});}
    final users=await api.request('GET','/users') as List;
    for(final u in users.where((u)=>u['role']!='admin')){await api.request('PATCH','/users/${u['id']}',{'active':true});}
    student=users.firstWhere((u)=>u['username']=='student1')['id'] as int;
    teacher=users.firstWhere((u)=>u['username']=='teacher1')['id'] as int;
    other=users.firstWhere((u)=>u['username']=='other1')['id'] as int;
    await academic.profile(student,{'name':'Mahasiswa','nim':'2411015','semester':'1','skills':'Dart','bio':'Belajar'});
    await academic.saveClass({'teacher':teacher,'code':kSemuaMataKuliah.first.kode,'term':'2026/2027','label':'A','day':1,'start':'08:00','end':'09:00','room':'R1'});
    classId=(await academic.view())['classes'].single['id'] as String;
    await login('teacher1');await tasks.save(kind:'task',code:kSemuaMataKuliah.first.kode,title:'Tugas',text:'Instruksi',deadline:now.add(const Duration(hours:1)),files:[]);
    taskId=(await tasks.list()).single['id'] as String;
    await login('student1');await tasks.save(kind:'submission',code:kSemuaMataKuliah.first.kode,title:'Jawaban',text:'Isi jawaban',parent:taskId,files:[]);
    submissionId=(await tasks.list()).firstWhere((r)=>r['kind']=='submission')['id'] as String;
  });
  tearDown(()async{api.dispose();await root.delete(recursive:true);});
  test('Dosen pembuat menilai setelah deadline, Mahasiswa melihat; nilai akhir tetap kosong',()async{
    now=now.add(const Duration(hours:2));await login('teacher1');final r=await submission();
    await tasks.assessSubmission(submissionId,'85','Bagus',expectedVersion:getVersion(r));
    await login('student1');expect((await submission())['assessment']['score'],85.0);
    expect((await academic.view())['grades'],isEmpty);
    await login('student2');expect((await tasks.list()).where((r)=>r['id']==submissionId),isEmpty);
  });
  test('Mahasiswa, Dosen lain dan Admin tidak dapat mengisi nilai per tugas',()async{
    final version=getVersion(await submission());
    for(final name in ['student1','other1','admin1']){
      await login(name);await expectLater(tasks.assessSubmission(submissionId,'100','',expectedVersion:version),throwsException);
    }
    await login('teacher1');await expectLater(tasks.assessSubmission(submissionId,'101','',expectedVersion:version),throwsException);
  });
  test('Edit jawaban mempertahankan nilai lama dan menandainya perlu tinjau ulang',()async{
    await login('teacher1');final r=await submission();
    await tasks.assessSubmission(submissionId,'80','Awal',expectedVersion:getVersion(r));
    await login('student1');final old=await submission();now=now.add(const Duration(minutes:5));
    await tasks.save(kind:'submission',code:old['code'] as String,title:'Jawaban diperbaiki',text:'Isi baru',parent:taskId,editId:submissionId,expectedVersion:getVersion(old),files:[]);
    final edited=await submission();expect(edited['assessment']['score'],80.0);expect(edited['assessment']['needsReview'],true);
    await login('teacher1');await expectLater(tasks.assessSubmission(submissionId,'90','Snapshot lama',expectedVersion:getVersion(old),expectedAssessment:old['assessment']['graded'] as String),throwsException);
    await tasks.assessSubmission(submissionId,'90','Ditinjau ulang',expectedVersion:getVersion(edited),expectedAssessment:edited['assessment']['graded'] as String);
    expect((await submission())['assessment']['needsReview'],false);
  });
  test('Nilai akhir dari pengumpulan wajib KRS disetujui dan terpisah dari nilai tugas',()async{
    await login('teacher1');expect(await tasks.finalGradeOptions(submissionId),isEmpty);
    final r=await submission();await expectLater(tasks.saveFinalGradeFromSubmission(submissionId,classId,'90','A','',expectedVersion:getVersion(r)),throwsException);
    await approve();await login('teacher1');expect((await tasks.finalGradeOptions(submissionId)).single['id'],classId);
    await tasks.assessSubmission(submissionId,'75','Nilai tugas',expectedVersion:getVersion(r));
    await tasks.saveFinalGradeFromSubmission(submissionId,classId,'90','A','Nilai akhir manual',expectedVersion:getVersion(r));
    await login('student1');expect((await submission())['assessment']['score'],75.0);
    expect((await academic.view())['grades'].single['score'],90.0);
    await login('admin1');await tasks.saveFinalGradeFromSubmission(submissionId,classId,'88','A','Dari Dosen',expectedVersion:getVersion(r));
    expect((await academic.view())['grades'].single['score'],88.0);
    await login('other1');await expectLater(tasks.finalGradeOptions(submissionId),throwsException);
  });
  test('Huruf tugas opsional, tersimpan, terlihat Mahasiswa dan terpisah dari nilai akhir',()async{
    await login('teacher1');final r=await submission();
    await tasks.assessSubmission(submissionId,'87','Bagus',expectedVersion:getVersion(r),letter:' a- ');
    await login('student1');final first=await submission();
    expect(first['assessment']['letter'],'A-');expect(first['assessment']['score'],87.0);
    expect((await academic.view())['grades'],isEmpty);
    await login('teacher1');
    await expectLater(tasks.assessSubmission(submissionId,'88','',expectedVersion:getVersion(first),expectedAssessment:first['assessment']['graded'] as String,letter:'ABCDE'),throwsException);
    await tasks.assessSubmission(submissionId,'88','Koreksi',expectedVersion:getVersion(first),expectedAssessment:first['assessment']['graded'] as String);
    final second=await submission();expect(second['assessment']['letter'],'A-');
    await tasks.assessSubmission(submissionId,'88','Tanpa huruf',expectedVersion:getVersion(second),expectedAssessment:second['assessment']['graded'] as String,letter:'');
    expect((await submission())['assessment']['letter'],'');
  });

}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mulia_smart_campus/screens/profile_academic_screen.dart';
import 'package:mulia_smart_campus/services/local_academic_store.dart';
import 'package:mulia_smart_campus/services/campus_auth_api.dart';

class DashboardFixture extends LocalAcademicStore {
  DashboardFixture(super.api,this.role);
  final String role;
  @override
  Future<Map<String,dynamic>> view() async => {
    'actor':{'id':1,'username':'akun_demo','role':role},
    'users':[{'id':1,'username':'akun_demo','role':role}],
    'profiles':{'1':{'name':'Nama Pengguna Lengkap','nim':'2411015','semester':3,'gpa':3.5,'skills':'Dart, Flutter','bio':'Belajar informatika'}},
    'pa':<String,dynamic>{},'classes':[],'rosters':<String,dynamic>{},'krs':[],'attendance':[],'grades':[],'guidance':[],
  };
}

void main(){
  for(final role in ['Mahasiswa','Dosen','admin']){
    testWidgets('Dashboard $role pada lebar 320 tidak overflow dan menu sesuai role',(tester)async{
      tester.view.physicalSize=const Size(320,2600);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final api=CampusAuthApi();addTearDown(api.dispose);
      await tester.pumpWidget(MaterialApp(home:ProfileAcademicScreen(api:api,store:DashboardFixture(api,role))));
      await tester.pumpAndSettle();
      expect(find.text('Ruang akademik Anda'),findsOneWidget);
      expect(find.byType(ChoiceChip),findsNothing);
      expect(find.text('Pengelolaan'),role=='admin'?findsOneWidget:findsNothing);
      expect(tester.takeException(),isNull);
    });
  }
  testWidgets('Menu membuka halaman terpisah dan kembali ke dashboard',(tester)async{
    tester.view.physicalSize=const Size(390,2400);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final api=CampusAuthApi();addTearDown(api.dispose);
    await tester.pumpWidget(MaterialApp(home:ProfileAcademicScreen(api:api,store:DashboardFixture(api,'Mahasiswa'))));
    await tester.pumpAndSettle();
    final jadwal=find.text('Jadwal');await tester.ensureVisible(jadwal);await tester.tap(jadwal);await tester.pumpAndSettle();
    expect(find.text('Belum ada jadwal'),findsOneWidget);
    await tester.pageBack();await tester.pumpAndSettle();
    expect(find.text('Ruang akademik Anda'),findsOneWidget);expect(tester.takeException(),isNull);
  });
}

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final StorageService storage = await StorageService.buka();
  runApp(SmartCampusApp(storage: storage));
}

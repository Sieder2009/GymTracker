import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'services/storage_service.dart';
import 'state/gym_photos_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  final storage = await StorageService.create();
  final photosDir = await resolveGymPhotosDir();
  runApp(IronpeakApp(storage: storage, photosDir: photosDir));
}

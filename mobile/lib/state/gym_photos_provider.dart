import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/constants.dart';
import '../models/gym_photo.dart';
import '../services/storage_service.dart';

const String _kGymPhotosKey = 'ironpeak:gymPhotos';

/// Resolves (and creates if needed) the on-device folder gym photos live
/// in. Called once at app startup (see `main.dart`) so [GymPhotosProvider]
/// itself can stay a synchronous constructor like every other provider —
/// the async directory lookup happens exactly once, before `runApp`. Falls
/// back to the system temp dir if the platform's documents directory isn't
/// available for some reason — fail-soft, matching [StorageService], so a
/// resolution problem never blocks app startup (worst case: photos don't
/// survive a reinstall on that one platform, the app still opens).
Future<Directory> resolveGymPhotosDir() async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'gym_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  } catch (_) {
    final dir = Directory(p.join(Directory.systemTemp.path, 'ironpeak_gym_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

/// Photos are real files in [photosDir]; only the lightweight
/// id/date pairs are persisted in the local database (see [GymPhoto]) —
/// storing image bytes as JSON text would be wasteful and slow.
class GymPhotosProvider extends ChangeNotifier {
  GymPhotosProvider(this._storage, this.photosDir) : _photos = _initial(_storage);

  final StorageService _storage;
  final Directory photosDir;
  List<GymPhoto> _photos;

  /// Newest first.
  List<GymPhoto> get photos => List.unmodifiable(_photos.reversed);

  String pathFor(GymPhoto photo) => p.join(photosDir.path, photo.id);

  static List<GymPhoto> _initial(StorageService storage) {
    final decoded = storage.readJson<List<GymPhoto>>(
      _kGymPhotosKey,
      (raw) => (raw as List).map((e) => GymPhoto.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return decoded ?? [];
  }

  void _persist() {
    _storage.writeJson(_kGymPhotosKey, () => _photos.map((e) => e.toJson()).toList());
  }

  Future<void> addFromXFile(XFile file) async {
    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final id = '${DateTime.now().microsecondsSinceEpoch}$ext';
    await file.saveTo(p.join(photosDir.path, id));
    _photos = [..._photos, GymPhoto(id: id, date: todayIso())];
    _persist();
    notifyListeners();
  }

  Future<void> removePhoto(GymPhoto photo) async {
    _photos = _photos.where((p) => p.id != photo.id).toList();
    _persist();
    notifyListeners();
    final file = File(pathFor(photo));
    if (await file.exists()) await file.delete();
  }
}

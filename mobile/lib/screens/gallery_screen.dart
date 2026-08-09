import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/gym_photo.dart';
import '../state/gym_photos_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../widgets/app_shell.dart';

bool get _cameraAvailable =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

/// Local-only progress-photo gallery — files live in the app's own document
/// directory (see `state/gym_photos_provider.dart`), never uploaded
/// anywhere. Camera capture is offered only on Android/iOS: desktop/web
/// have no OS-level "take a photo" UI, so there [ImageSource.gallery]
/// (file picker) is the only option — matching image_picker's own platform
/// support rather than showing a button that would silently fail.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file == null || !context.mounted) return;
    await context.read<GymPhotosProvider>().addFromXFile(file);
  }

  void _showAddSheet(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.actionChooseFromGallery),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pick(context, ImageSource.gallery);
              },
            ),
            if (_cameraAvailable)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(t.actionTakePhoto),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pick(context, ImageSource.camera);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final provider = context.watch<GymPhotosProvider>();
    final photos = provider.photos;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.titleGallery),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: t.actionAddPhoto,
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: photos.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_outlined, size: 40, color: colors.mut),
                      const SizedBox(height: 12),
                      Text(
                        t.emptyGalleryNoPhotos,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.mut),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _showAddSheet(context),
                        child: Text(t.actionAddPhoto),
                      ),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, kFloatingNavClearance),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: photos.length,
                itemBuilder: (context, i) {
                  final photo = photos[i];
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _PhotoViewerScreen(photo: photo),
                    )),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      child: Image.file(
                        File(provider.pathFor(photo)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PhotoViewerScreen extends StatelessWidget {
  const _PhotoViewerScreen({required this.photo});

  final GymPhoto photo;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final provider = context.watch<GymPhotosProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(photo.date, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(t.deletePhotoTitle),
                  content: Text(t.deletePhotoBody),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.actionCancel)),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(t.actionDelete, style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await provider.removePhoto(photo);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(provider.pathFor(photo))),
        ),
      ),
    );
  }
}

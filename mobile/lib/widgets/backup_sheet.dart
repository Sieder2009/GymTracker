import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/storage_service.dart';
import '../state/toast_provider.dart';
import '../theme/app_colors.dart';

const int _kBackupFormatVersion = 1;

/// Local-only backup/restore: everything the app has stored gets bundled
/// into one JSON blob. Two ways to move it around, both still "the app has
/// no server" -- copy to clipboard/paste back (original, works anywhere),
/// or save/share as an actual file (through the OS's native share sheet,
/// so the user can pick "Save to Files" -> iCloud Drive on iOS or their
/// Drive app on Android) and pick it back up with a file picker on another
/// device. Either way, the file only ever goes wherever the user
/// explicitly chooses to put it -- nothing is uploaded automatically.
Future<void> showBackupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _BackupSheet(),
  );
}

class _BackupSheet extends StatefulWidget {
  const _BackupSheet();

  @override
  State<_BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends State<_BackupSheet> {
  final TextEditingController _importController = TextEditingController();

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  String _payload(StorageService storage) => jsonEncode({
        'app': 'ironpeak',
        'version': _kBackupFormatVersion,
        'data': storage.exportAll(),
      });

  Future<void> _copyToClipboard() async {
    final storage = context.read<StorageService>();
    await Clipboard.setData(ClipboardData(text: _payload(storage)));
    if (!mounted) return;
    context
        .read<ToastProvider>()
        .show(AppLocalizations.of(context)!.toastCopiedToClipboard);
  }

  Future<void> _shareAsFile() async {
    final storage = context.read<StorageService>();
    final dir = await getTemporaryDirectory();
    final date = DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/ironpeak-backup-$date.json');
    await file.writeAsString(_payload(storage));
    if (!mounted) return;
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    if (!mounted) return;
    setState(() => _importController.text = content);
    context
        .read<ToastProvider>()
        .show(AppLocalizations.of(context)!.toastFileImported);
  }

  Future<void> _restore() async {
    final t = AppLocalizations.of(context)!;
    final toast = context.read<ToastProvider>();
    final Map<String, dynamic> parsed;
    try {
      final decoded = jsonDecode(_importController.text.trim());
      if (decoded is! Map<String, dynamic> || decoded['data'] is! Map) {
        throw const FormatException('missing data');
      }
      parsed = (decoded['data'] as Map).cast<String, dynamic>();
    } catch (_) {
      toast.show(t.toastRestoreInvalid);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.restoreConfirmTitle),
        content: Text(t.restoreConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.actionCancel)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.actionRestore,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<StorageService>().importAll(parsed);
    if (!mounted) return;
    toast.show(t.toastRestoreDone);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 20, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.titleBackup,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Text(t.backupExportHint, style: TextStyle(color: colors.mut)),
              const SizedBox(height: 4),
              Text(t.backupFileHint,
                  style: TextStyle(color: colors.mut, fontSize: 12)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: Text(t.actionCopyToClipboard),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareAsFile,
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: Text(t.actionSaveToFiles),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(t.backupImportHint, style: TextStyle(color: colors.mut)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: Text(t.actionImportFromFile),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _importController,
                maxLines: 4,
                decoration: InputDecoration(hintText: t.hintBackupPaste),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: _restore, child: Text(t.actionRestore)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

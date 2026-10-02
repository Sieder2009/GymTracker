import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Android resource XMLs are only compiled by aapt2 inside the (slow)
/// Gradle build, so a mistake there shows up late -- as a failed release
/// workflow. This catches the one that already happened once, in the plain
/// test run: XML forbids a double hyphen inside a comment, and aapt2 rejects
/// the whole file ("not well-formed (invalid token)") if one sneaks in, e.g.
/// from a "--" used as a dash in prose.
void main() {
  test('Android resource XML comments never contain a double hyphen', () {
    final res = Directory('android/app/src/main/res');
    expect(res.existsSync(), isTrue, reason: 'run from the mobile/ directory');

    final xmlFiles = res
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.xml'));
    expect(xmlFiles, isNotEmpty);

    for (final file in xmlFiles) {
      final text = file.readAsStringSync();
      for (final comment in RegExp(r'<!--(.*?)-->', dotAll: true).allMatches(text)) {
        expect(
          comment.group(1)!.contains('--'),
          isFalse,
          reason: '${file.path}: a "--" inside an XML comment is not '
              'well-formed and makes aapt2 fail the Android build',
        );
      }
    }
  });
}

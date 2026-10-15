import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/theme/launcher_icons.dart';

import '../tool/verify_launcher_aliases.dart' hide main;

/// The fixtures are trimmed `aapt2 dump xmltree --file AndroidManifest.xml`
/// outputs of the spike builds that proved the alias setup. The release one
/// has IronpeakActivity without its launcher filter, three launcher aliases
/// in the reversed order the manifest merger writes them, and a plugin
/// activity plus a disabled service the rules must ignore. The debug one has
/// IronpeakActivity as the plain launcher activity and no aliases.
///
/// Nothing here runs aapt2 or looks at the real Android SDK: the iOS and
/// macOS workflows run `flutter test` too, on machines without one.
const String _fixtures = 'test/fixtures/launcher_aliases';
const String _releasePath = '$_fixtures/release_manifest_dump.txt';
const String _debugPath = '$_fixtures/debug_manifest_dump.txt';

final String _releaseDump = File(_releasePath).readAsStringSync();
final String _debugDump = File(_debugPath).readAsStringSync();

List<String> _release(String dump) => checkRelease(readLauncherManifest(dump));
List<String> _debug(String dump) => checkDebug(readLauncherManifest(dump));

int _indent(String line) => line.length - line.trimLeft().length;

/// Rewrites the block (element line, attributes, children) of the activity
/// or alias whose android:name ends with [name].
String _edit(String dump, String name, String Function(String block) edit) {
  final lines = const LineSplitter().convert(dump);
  final nameLine = lines.indexWhere(
      (l) => l.contains(':name(0x01010003)="') && l.contains('$name" (Raw'));
  expect(nameLine, isNot(-1), reason: 'no component $name in the dump');
  var start = nameLine;
  while (!lines[start].trimLeft().startsWith('E: ')) {
    start--;
  }
  var end = start + 1;
  while (end < lines.length && _indent(lines[end]) > _indent(lines[start])) {
    end++;
  }
  return [
    ...lines.sublist(0, start),
    edit(lines.sublist(start, end).join('\n')),
    ...lines.sublist(end),
  ].join('\n');
}

String _withoutLines(String block, String containing) =>
    block.split('\n').where((l) => !l.contains(containing)).join('\n');

/// A MAIN/LAUNCHER intent filter as aapt2 prints it inside an element that
/// is indented by [elementIndent].
String _launcherFilter(int elementIndent) {
  final pad = ' ' * (elementIndent + 4);
  const ns = 'http://schemas.android.com/apk/res/android';
  return [
    '${pad}E: intent-filter (line=1)',
    '$pad    E: action (line=2)',
    '$pad      A: $ns:name(0x01010003)="android.intent.action.MAIN" '
        '(Raw: "android.intent.action.MAIN")',
    '$pad    E: category (line=3)',
    '$pad      A: $ns:name(0x01010003)="android.intent.category.LAUNCHER" '
        '(Raw: "android.intent.category.LAUNCHER")',
  ].join('\n');
}

String _addLauncherFilter(String block) =>
    '$block\n${_launcherFilter(_indent(block.split('\n').first))}';

String _setEnabled(String block, String value) => block.replaceFirst(
    RegExp(r'enabled\(0x0101000e\)=\S+'), 'enabled(0x0101000e)=$value');

void main() {
  test('expects the default alias of the launcher icon contract', () {
    expect(defaultLauncherAlias, LauncherIcons.defaultVariant.androidAlias);
  });

  group('readLauncherManifest', () {
    test('reads activities and aliases in manifest order', () {
      final manifest = readLauncherManifest(_releaseDump);
      expect(manifest.packageName, 'com.ironpeak.ironpeak_mobile');
      expect(manifest.components.map((c) => manifest.shortName(c.name)), [
        '.IronpeakActivity',
        '.LauncherIcon_light_red',
        '.LauncherIcon_dark_blue',
        '.MainActivity',
        'io.flutter.plugins.urllauncher.WebViewActivity',
      ]);
      final [activity, red, blue, main, webView] = manifest.components;
      expect(activity.isAlias, isFalse);
      expect(activity.isLauncher, isFalse);
      expect(activity.line, 98);
      for (final alias in [red, blue, main]) {
        expect(alias.isAlias, isTrue);
        expect(alias.isLauncher, isTrue);
        expect(alias.targetActivity, 'com.ironpeak.ironpeak_mobile.IronpeakActivity');
        expect(alias.icon, '@0x7f0c0000');
        expect(alias.exported, 'true');
      }
      expect([red, blue, main].map((a) => a.enabledByDefault), [false, false, true]);
      expect(webView.isLauncher, isFalse);
    });

    test('a missing android:enabled means enabled', () {
      final manifest = readLauncherManifest(_edit(_releaseDump, '.MainActivity',
          (b) => _withoutLines(b, ':enabled(')));
      final main = manifest.components[3];
      expect(main.enabled, isNull);
      expect(main.enabledByDefault, isTrue);
    });

    test('MAIN and LAUNCHER in different filters are no launcher entry', () {
      const ns = 'http://schemas.android.com/apk/res/android';
      const dump = '''
N: android=$ns (line=2)
  E: manifest (line=2)
    A: package="com.example" (Raw: "com.example")
      E: application (line=3)
          E: activity (line=4)
            A: $ns:name(0x01010003)=".Split" (Raw: ".Split")
              E: intent-filter (line=5)
                  E: action (line=6)
                    A: $ns:name(0x01010003)="android.intent.action.MAIN" (Raw: "android.intent.action.MAIN")
              E: intent-filter (line=7)
                  E: category (line=8)
                    A: $ns:name(0x01010003)="android.intent.category.LAUNCHER" (Raw: "android.intent.category.LAUNCHER")
''';
      final split = readLauncherManifest(dump).components.single;
      expect(split.name, 'com.example.Split');
      expect(split.isLauncher, isFalse);
    });

    test('CRLF, a byte order mark and UTF-16 read the same as LF', () {
      String describe(String dump) {
        final manifest = readLauncherManifest(dump);
        return [
          for (final c in manifest.components)
            '${c.tag} ${c.name} ${c.isLauncher} ${c.enabledByDefault} '
                '${c.targetActivity} ${c.icon}',
        ].join('\n');
      }

      final expected = describe(_releaseDump);
      final crlf = _releaseDump.replaceAll('\n', '\r\n');
      expect(describe('\uFEFF$crlf'), expected);
      expect(describe(decodeDump(utf8.encode('\uFEFF$crlf'))), expected);
      final utf16le = <int>[0xFF, 0xFE];
      for (final unit in crlf.codeUnits) {
        utf16le.addAll([unit & 0xFF, unit >> 8]);
      }
      expect(describe(decodeDump(utf16le)), expected);

      // The byte order marks themselves never reach the parser.
      expect(decodeDump([0xEF, 0xBB, 0xBF, 0x45, 0x3A]), 'E:');
      expect(decodeDump([0xFF, 0xFE, 0x45, 0x00, 0x3A, 0x00]), 'E:');
      expect(decodeDump([0xFE, 0xFF, 0x00, 0x45, 0x00, 0x3A]), 'E:');
      expect(decodeDump([0x45, 0x3A]), 'E:');
    });

    test('also reads the older aapt format', () {
      // aapt (v1) leaves out the namespace URI, prints booleans as typed
      // values and indents attributes and children alike.
      const dump = '''
N: android=http://schemas.android.com/apk/res/android
  E: manifest (line=2)
    A: package="com.example" (Raw: "com.example")
    E: application (line=10)
      E: activity (line=11)
        A: android:name(0x01010003)=".RealActivity" (Raw: ".RealActivity")
      E: activity-alias (line=20)
        A: android:icon(0x01010002)=@0x7f0c0000
        A: android:name(0x01010003)=".MainActivity" (Raw: ".MainActivity")
        A: android:exported(0x01010010)=(type 0x12)0xffffffff
        A: android:targetActivity(0x01010202)=".RealActivity" (Raw: ".RealActivity")
        E: intent-filter (line=25)
          E: action (line=26)
            A: android:name(0x01010003)="android.intent.action.MAIN" (Raw: "android.intent.action.MAIN")
          E: category (line=27)
            A: android:name(0x01010003)="android.intent.category.LAUNCHER" (Raw: "android.intent.category.LAUNCHER")
      E: activity-alias (line=30)
        A: android:icon(0x01010002)=@0x7f0c0001
        A: android:name(0x01010003)="com.example.Other" (Raw: "com.example.Other")
        A: android:enabled(0x0101000e)=(type 0x12)0x0
        A: android:exported(0x01010010)=(type 0x12)0xffffffff
        A: android:targetActivity(0x01010202)="com.example.RealActivity" (Raw: "com.example.RealActivity")
        E: intent-filter (line=35)
          E: action (line=36)
            A: android:name(0x01010003)="android.intent.action.MAIN" (Raw: "android.intent.action.MAIN")
          E: category (line=37)
            A: android:name(0x01010003)="android.intent.category.LAUNCHER" (Raw: "android.intent.category.LAUNCHER")
''';
      final manifest = readLauncherManifest(dump);
      expect(manifest.components.map((c) => c.enabledByDefault), [true, true, false]);
      expect(manifest.components.map((c) => c.isLauncher), [false, true, true]);
      expect(checkRelease(manifest), isEmpty);
    });

    test('rejects text that is not a manifest dump', () {
      expect(() => readLauncherManifest('hello'), throwsFormatException);
      expect(() => readLauncherManifest('  E: manifest (line=2)\n'),
          throwsFormatException);
    });

    test('resolves class names relative to the package', () {
      expect(resolveClassName('com.example', '.Foo'), 'com.example.Foo');
      expect(resolveClassName('com.example', 'Foo'), 'com.example.Foo');
      expect(resolveClassName('com.example', 'org.other.Foo'), 'org.other.Foo');
    });
  });

  group('release rules', () {
    test('pass on the spike release build', () {
      expect(_release(_releaseDump), isEmpty);
    });

    test('fail on a debug build', () {
      final problems = _release(_debugDump);
      expect(problems, [
        contains('<activity> .IronpeakActivity still has a MAIN/LAUNCHER'),
        contains('No <activity-alias> has a MAIN/LAUNCHER intent filter'),
      ]);
    });

    test('fail when the activity keeps its launcher filter', () {
      final dump = _edit(_releaseDump, '.IronpeakActivity', _addLauncherFilter);
      expect(_release(dump), [contains('.IronpeakActivity still has a MAIN/LAUNCHER')]);
    });

    test('fail when two aliases are enabled', () {
      final dump = _edit(_releaseDump, '.LauncherIcon_dark_blue',
          (b) => _setEnabled(b, 'true'));
      expect(_release(dump), [
        contains('2 launcher aliases are enabled by default '
            '(.LauncherIcon_dark_blue, .MainActivity)'),
      ]);
    });

    test('fail when an alias lacks android:enabled="false"', () {
      final dump = _edit(_releaseDump, '.LauncherIcon_light_red',
          (b) => _withoutLines(b, ':enabled('));
      expect(_release(dump), [contains('2 launcher aliases are enabled by default')]);
    });

    test('fail when no alias is enabled', () {
      final dump =
          _edit(_releaseDump, '.MainActivity', (b) => _setEnabled(b, 'false'));
      expect(_release(dump), [contains('No launcher alias is enabled by default')]);
    });

    test('fail when another alias than the default one is enabled', () {
      var dump = _edit(_releaseDump, '.MainActivity', (b) => _setEnabled(b, 'false'));
      dump = _edit(dump, '.LauncherIcon_dark_blue', (b) => _setEnabled(b, 'true'));
      expect(_release(dump), [
        contains('enabled by default is .LauncherIcon_dark_blue, but it must be '
            '.MainActivity'),
      ]);
    });

    test('fail when android:enabled cannot be evaluated', () {
      final dump = _edit(_releaseDump, '.LauncherIcon_dark_blue',
          (b) => _setEnabled(b, '@0x7f050000'));
      expect(_release(dump), [contains('android:enabled=@0x7f050000, which is not a literal')]);
    });

    test('fail when an alias has no icon', () {
      final dump = _edit(_releaseDump, '.LauncherIcon_light_red',
          (b) => _withoutLines(b, ':icon('));
      expect(_release(dump), [contains('.LauncherIcon_light_red has no android:icon')]);
    });

    test('fail when an alias is not exported', () {
      final dump = _edit(_releaseDump, '.LauncherIcon_light_red',
          (b) => b.replaceFirst('exported(0x01010010)=true', 'exported(0x01010010)=false'));
      expect(_release(dump), [contains('.LauncherIcon_light_red is not exported')]);
    });

    test('fail when the aliases open different activities', () {
      final dump = _edit(
        _releaseDump,
        '.LauncherIcon_light_red',
        (b) => b.replaceAll('com.ironpeak.ironpeak_mobile.IronpeakActivity',
            'io.flutter.plugins.urllauncher.WebViewActivity'),
      );
      expect(_release(dump), [
        contains('open different activities'),
        // WebViewActivity also comes after the alias.
        contains('.LauncherIcon_light_red comes before its target'),
      ]);
    });

    test('fail when the target activity is declared after the aliases', () {
      late String activity;
      var dump = _edit(_releaseDump, '.IronpeakActivity', (b) {
        activity = b;
        return '';
      });
      dump = _edit(dump, '.MainActivity', (b) => '$b\n$activity');
      expect(readLauncherManifest(dump).components.first.name,
          endsWith('.LauncherIcon_light_red'));
      expect(_release(dump), [
        for (final alias in ['light_red', 'dark_blue'])
          contains('.LauncherIcon_$alias comes before its target <activity> '
              '.IronpeakActivity'),
        contains('.MainActivity comes before its target'),
      ]);
    });

    test('fail when the target activity does not exist', () {
      final dump = _edit(_releaseDump, '.IronpeakActivity',
          (b) => b.replaceAll('IronpeakActivity', 'RenamedActivity'));
      expect(_release(dump), [
        for (final _ in [1, 2, 3]) contains('which is not an <activity> of this manifest'),
      ]);
    });

    test('fail when the target activity is disabled', () {
      final dump = _edit(_releaseDump, '.IronpeakActivity', (b) {
        final lines = b.split('\n');
        lines.insert(2, '            A: http://schemas.android.com/apk/res/android'
            ':enabled(0x0101000e)=false');
        return lines.join('\n');
      });
      expect(_release(dump), [
        for (final _ in [1, 2, 3]) contains('which is disabled'),
      ]);
    });

    test('fail when there are no aliases', () {
      var dump = _releaseDump;
      for (final alias in ['.LauncherIcon_light_red', '.LauncherIcon_dark_blue', '.MainActivity']) {
        dump = _edit(dump, alias, (_) => '');
      }
      expect(_release(dump), [contains('No <activity-alias> has a MAIN/LAUNCHER')]);
    });

    test('fail when two components share a name', () {
      final dump = _edit(_releaseDump, '.LauncherIcon_dark_blue',
          (b) => b.replaceAll('LauncherIcon_dark_blue', 'LauncherIcon_light_red'));
      expect(_release(dump), [
        contains('.LauncherIcon_light_red is declared 2 times '
            '(<activity-alias>, <activity-alias>)'),
      ]);
    });
  });

  group('debug rules', () {
    test('pass on the spike debug build', () {
      expect(_debug(_debugDump), isEmpty);
    });

    test('fail on a release build', () {
      expect(_debug(_releaseDump), [
        contains('Launcher alias .MainActivity is enabled in a debug build'),
        contains('Expected exactly one launcher <activity> (the one `flutter run` '
            'starts), found 0.'),
      ]);
    });

    test('tolerate disabled aliases', () {
      final dump = _edit(_releaseDump, '.MainActivity', (b) => _setEnabled(b, 'false'));
      final withLauncher = _edit(dump, '.IronpeakActivity', _addLauncherFilter);
      expect(_debug(withLauncher), isEmpty);
    });

    test('fail without a launcher activity', () {
      final dump = _edit(_debugDump, '.IronpeakActivity', (b) {
        final lines = b.split('\n');
        final filter = lines.indexWhere((l) => l.contains('E: intent-filter'));
        return lines.sublist(0, filter).join('\n');
      });
      expect(_debug(dump), [contains('found 0')]);
    });

    test('fail with two launcher activities', () {
      final dump = _edit(_debugDump, 'WebViewActivity', _addLauncherFilter);
      expect(_debug(dump), [
        contains('found 2: .IronpeakActivity, '
            'io.flutter.plugins.urllauncher.WebViewActivity'),
      ]);
    });
  });

  group('report', () {
    test('lists the launcher entries and the verdict', () {
      final manifest = readLauncherManifest(_releaseDump);
      final ok = formatReport(manifest, BuildKind.release, [], source: 'app.apk');
      expect(ok, contains('Launcher entries of app.apk (release rules)'));
      expect(ok, matches(RegExp(r'\.MainActivity +-> \.IronpeakActivity  launcher, ENABLED')));
      expect(ok, contains('OK: 3 launcher aliases, only .MainActivity enabled'));
      final failed = formatReport(manifest, BuildKind.debug, ['a', 'b'], source: 'x');
      expect(failed, contains('FAILED, 2 problems:\n  - a\n  - b'));
    });
  });

  group('command line', () {
    late Directory temp;
    setUp(() => temp = Directory.systemTemp.createTempSync('launcher_aliases'));
    tearDown(() => temp.deleteSync(recursive: true));

    Future<(int, String, String)> runTool(List<String> args,
        {Map<String, String> environment = const {}}) async {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = await run(args, out: out, err: err, environment: environment);
      return (code, '$out', '$err');
    }

    test('exits 0 when the rules hold', () async {
      final (code, out, _) = await runTool(['--release', '--dump', _releasePath]);
      expect(code, 0);
      expect(out, contains('OK: 3 launcher aliases'));
      final (debugCode, _, _) = await runTool(['--debug', '--dump=$_debugPath']);
      expect(debugCode, 0);
    });

    test('exits 1 and annotates on GitHub Actions when a rule is broken',
        () async {
      final (code, out, _) = await runTool(['--debug', '--dump', _releasePath],
          environment: {'GITHUB_ACTIONS': 'true'});
      expect(code, 1);
      expect(out, contains('FAILED, 2 problems'));
      expect('::error title=Launcher aliases::'.allMatches(out), hasLength(2));
    });

    test('exits 2 when nothing could be checked', () async {
      final notADump = File('${temp.path}/not_a_dump.txt')..writeAsStringSync('hello');
      for (final args in [
        <String>[],
        ['--release'],
        ['--release', '--debug', 'app.apk'],
        ['--release', 'app.apk', '--dump', _releasePath],
        ['--release', '--dump'],
        ['--release', '--frobnicate', 'app.apk'],
        ['--release', '${temp.path}/missing.apk'],
        ['--release', '--dump', '${temp.path}/missing.txt'],
        ['--release', '--dump', notADump.path],
      ]) {
        final (code, _, err) = await runTool(args);
        expect(code, 2, reason: '$args');
        expect(err, startsWith('verify_launcher_aliases: '), reason: '$args');
      }
    });

    test('parses the documented options', () {
      final apk = parseArguments(['--release', 'app.apk', '--aapt2', 'bin/aapt2']);
      expect((apk.kind, apk.apk, apk.dump, apk.aapt2),
          (BuildKind.release, 'app.apk', null, 'bin/aapt2'));
      final dump = parseArguments(['--dump=d.txt', '--debug']);
      expect((dump.kind, dump.apk, dump.dump), (BuildKind.debug, null, 'd.txt'));
      expect(parseArguments(['--help']).help, isTrue);
    });
  });

  group('finding aapt2', () {
    late Directory temp;
    setUp(() => temp = Directory.systemTemp.createTempSync('fake_sdk'));
    tearDown(() => temp.deleteSync(recursive: true));

    String sdk(String name, Map<String, bool> buildTools) {
      final root = '${temp.path}${Platform.pathSeparator}$name';
      buildTools.forEach((version, hasAapt2) {
        final dir = Directory('$root/build-tools/$version')
          ..createSync(recursive: true);
        if (hasAapt2) File('${dir.path}/aapt2').writeAsStringSync('');
      });
      Directory(root).createSync(recursive: true);
      return root;
    }

    File properties(String text) =>
        File('${temp.path}/local.properties')..writeAsStringSync(text);

    final noProperties = File('does/not/exist/local.properties');

    test('takes the newest build-tools that has aapt2', () {
      final home = sdk('home', {
        '9.0.0': true,
        '30.0.3': true,
        '35.0.1': true,
        '36.0.0': true,
        '37.0.0-rc1': false,
      });
      expect(
        findAapt2(
          environment: {'ANDROID_HOME': home},
          localProperties: noProperties,
          windows: false,
        ),
        endsWith('36.0.0${Platform.pathSeparator}aapt2'),
      );
    });

    test('falls back from ANDROID_HOME to ANDROID_SDK_ROOT to sdk.dir', () {
      final empty = sdk('empty', {'36.0.0': false});
      final root = sdk('root', {'34.0.0': true});
      final local = sdk('local', {'35.0.0': true});
      // Escaped like Gradle writes it, which matters for Windows paths.
      final escaped = local.replaceAll(r'\', r'\\').replaceAll(':', r'\:');
      final props = properties('flutter.sdk=/flutter\nsdk.dir=$escaped\n');
      String? find(Map<String, String> env, File localProperties) => findAapt2(
          environment: env, localProperties: localProperties, windows: false);

      expect(find({'ANDROID_HOME': empty, 'ANDROID_SDK_ROOT': root}, props),
          contains('34.0.0'));
      expect(find({'ANDROID_HOME': empty}, props), contains('35.0.0'));
      expect(find({'ANDROID_HOME': empty}, noProperties), isNull);
      expect(find({}, noProperties), isNull);
    });

    test('looks for aapt2.exe on Windows', () {
      final home = sdk('home', {'36.0.0': true});
      expect(
        findAapt2(environment: {'ANDROID_HOME': home}, localProperties: noProperties, windows: true),
        isNull,
      );
      File('$home/build-tools/36.0.0/aapt2.exe').writeAsStringSync('');
      expect(
        findAapt2(environment: {'ANDROID_HOME': home}, localProperties: noProperties, windows: true),
        endsWith('aapt2.exe'),
      );
    });

    test('orders build-tools versions numerically', () {
      final versions = ['36.0.0', '9.0.0', '35.0.0', '35.0.0-rc1', '30.0.3']
        ..sort(compareBuildToolsVersions);
      expect(versions, ['9.0.0', '30.0.3', '35.0.0-rc1', '35.0.0', '36.0.0']);
    });

    test('unescapes sdk.dir the way Gradle writes it', () {
      expect(readSdkDir(r'sdk.dir=C\:\\Program Files (x86)\\Android\\android-sdk'),
          r'C:\Program Files (x86)\Android\android-sdk');
      expect(readSdkDir('# comment\nsdk.dir = /opt/android-sdk \n'), '/opt/android-sdk');
      expect(readSdkDir('flutter.sdk=/flutter'), isNull);
    });
  });
}

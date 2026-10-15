// Checks the home-screen launcher entries of a built APK.
//
// The launcher icon follows the app's appearance by switching between
// <activity-alias> elements that all open IronpeakActivity (see
// lib/theme/launcher_icons.dart). Release builds get those aliases from the
// overlay android/app/src/release/AndroidManifest.xml, which also strips
// IronpeakActivity's own launcher entry; debug and profile builds keep
// IronpeakActivity as the plain launcher activity, because `flutter run`
// only starts <activity> elements. A mistake in that setup still builds
// fine and only shows on a phone -- as two home-screen icons, or none at
// all -- so this reads the manifest that actually got merged into the APK.
//
// Usage (from mobile/):
//
//   dart run tool/verify_launcher_aliases.dart --release build/app/outputs/flutter-apk/app-release.apk
//   dart run tool/verify_launcher_aliases.dart --debug build/app/outputs/flutter-apk/app-debug.apk
//   dart run tool/verify_launcher_aliases.dart --release --dump manifest_dump.txt
//
// The APK is read with `aapt2 dump xmltree --file AndroidManifest.xml`.
// aapt2 is --aapt2 <path> if given, else the one in the newest build-tools/
// of ANDROID_HOME, ANDROID_SDK_ROOT or sdk.dir from android/local.properties
// (first that has one). --dump checks a saved output of that command
// instead of an APK.
//
// Exit code 0: the rules hold. 1: a rule is broken (the report says which).
// 2: nothing was checked (bad arguments, no aapt2, unreadable APK or dump).
//
// Only dart:io: Flutter isn't loadable outside `flutter test`, which is also
// why the default alias below is a copy of the contract in
// lib/theme/launcher_icons.dart rather than an import of it. And since the
// script needs no packages, plain `dart tool/verify_launcher_aliases.dart`
// works too and skips the build hooks of the app's native dependencies
// (sqlite3, objective_c) that `dart run` runs first -- CI uses that form.
import 'dart:convert';
import 'dart:io';

/// The launcher alias a fresh install has enabled. It keeps the name the
/// real launcher activity had before the icon became switchable, so
/// home-screen shortcuts made by older versions still resolve after the
/// update. Mirrors `LauncherIcons.defaultVariant.androidAlias`;
/// test/verify_launcher_aliases_test.dart keeps the two in sync.
const String defaultLauncherAlias = '.MainActivity';

const String usage = '''
Usage: dart run tool/verify_launcher_aliases.dart (--release | --debug) <apk> [--aapt2 <path>]
       dart run tool/verify_launcher_aliases.dart (--release | --debug) --dump <file>

Checks the launcher entries of the APK's merged AndroidManifest.xml.
  --release       release rules: launcher aliases only, exactly one enabled
  --debug         debug/profile rules: one launcher <activity>, no enabled alias
  --aapt2 <path>  the aapt2 to run (default: newest build-tools of ANDROID_HOME,
                  ANDROID_SDK_ROOT or sdk.dir in android/local.properties)
  --dump <file>   check a saved `aapt2 dump xmltree --file AndroidManifest.xml`
                  output instead of an APK
Exit code: 0 rules hold, 1 a rule is broken, 2 nothing was checked.''';

/// Which rules apply: release builds carry the launcher aliases, debug and
/// profile builds don't.
enum BuildKind { release, debug }

// --- parsing -------------------------------------------------------------

/// One element of an `aapt2 dump xmltree` listing.
class XmlTreeElement {
  XmlTreeElement(this.name, {this.line});

  final String name;

  /// The element's line in the merged manifest, as the dump reports it.
  final int? line;

  /// Attribute values by name. Android attributes are keyed `android:<name>`
  /// whether the dump spells the namespace URI out (aapt2) or not (aapt).
  final Map<String, String> attributes = {};

  final List<XmlTreeElement> children = [];

  Iterable<XmlTreeElement> childrenNamed(String name) =>
      children.where((child) => child.name == name);
}

final RegExp _elementLine = RegExp(r'^E: (\S+)(?: \(line=(\d+)\))?');

// `A: <name>[(0x<attribute id>)]=<value>`. The name can be a namespace URI
// plus local name, which contains colons of its own.
final RegExp _attributeLine =
    RegExp(r'^A: ([^=(]+)(?:\(0x[0-9a-fA-F]+\))?=(.*)$');

const String _androidNamespace = 'http://schemas.android.com/apk/res/android:';

final RegExp _quotedValue = RegExp(r'^"((?:[^"\\]|\\.)*)"');

/// Parses the text of `aapt2 dump xmltree` into a tree. The returned root
/// is synthetic; its children are the dump's top-level elements (normally
/// just `manifest`).
///
/// The dump has no closing tags, only indentation, and aapt2 indents an
/// element's attributes less than its children while aapt indents both the
/// same. Either way an element's parent is the closest earlier element with
/// less indentation, and an attribute belongs to the closest earlier element
/// with less indentation than the attribute.
XmlTreeElement parseXmlTree(String dump) {
  final root = XmlTreeElement('');
  final open = <(int, XmlTreeElement)>[];
  // A stray byte order mark needs no handling: trimLeft() counts it as
  // whitespace, and the first line is the namespace declaration anyway.
  for (final line in const LineSplitter().convert(dump)) {
    final content = line.trimLeft();
    final isElement = content.startsWith('E: ');
    if (!isElement && !content.startsWith('A: ')) continue;
    final indent = line.length - content.length;
    while (open.isNotEmpty && open.last.$1 >= indent) {
      open.removeLast();
    }
    if (isElement) {
      final match = _elementLine.firstMatch(content);
      if (match == null) continue;
      final element =
          XmlTreeElement(match[1]!, line: int.tryParse(match[2] ?? ''));
      (open.isEmpty ? root : open.last.$2).children.add(element);
      open.add((indent, element));
    } else {
      final match = _attributeLine.firstMatch(content);
      if (match == null || open.isEmpty) continue;
      open.last.$2.attributes[_attributeName(match[1]!)] =
          _attributeValue(match[2]!);
    }
  }
  return root;
}

String _attributeName(String qualified) =>
    qualified.startsWith(_androidNamespace)
        ? 'android:${qualified.substring(_androidNamespace.length)}'
        : qualified;

/// `"text" (Raw: "text")` -> `text`; anything else (`true`, `@0x7f0c0000`,
/// `0x40003fb4`) as printed.
String _attributeValue(String raw) {
  final quoted = _quotedValue.firstMatch(raw);
  if (quoted == null) return raw.trim();
  return quoted[1]!.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);
}

final RegExp _aaptBoolean = RegExp(r'^\(type 0x12\)0x([0-9a-fA-F]+)$');

/// A boolean attribute value as aapt2 (`true`) or aapt (`(type 0x12)0x...`)
/// prints it; null for anything else, e.g. a `@bool/...` resource reference.
bool? _literalBool(String value) {
  if (value == 'true') return true;
  if (value == 'false') return false;
  final typed = _aaptBoolean.firstMatch(value);
  return typed == null ? null : int.parse(typed[1]!, radix: 16) != 0;
}

/// Decodes a saved dump. aapt2 writes UTF-8; a dump captured with Windows
/// PowerShell's `>` is UTF-16 with a byte order mark instead.
String decodeDump(List<int> bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16(bytes, littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16(bytes, littleEndian: false);
  }
  // utf8.decode drops a leading byte order mark by itself.
  return utf8.decode(bytes, allowMalformed: true);
}

String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
  final units = <int>[
    for (var i = 2; i + 1 < bytes.length; i += 2)
      littleEndian ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1],
  ];
  return String.fromCharCodes(units);
}

// --- the manifest ----------------------------------------------------------

/// An `<activity>` or `<activity-alias>` of the merged manifest.
class ManifestComponent {
  ManifestComponent({
    required this.isAlias,
    required this.name,
    required this.isLauncher,
    this.line,
    this.targetActivity,
    this.icon,
    this.enabled,
    this.exported,
  });

  /// An `<activity-alias>` rather than an `<activity>`.
  final bool isAlias;

  /// Fully qualified, like every class name below.
  final String name;

  /// Has an intent filter with both ACTION_MAIN and CATEGORY_LAUNCHER in
  /// it, i.e. is an app icon on the home screen whenever it is enabled.
  final bool isLauncher;

  final int? line;
  final String? targetActivity;

  /// android:icon as dumped (a resource id such as `@0x7f0c0000`).
  final String? icon;

  /// android:enabled and android:exported as dumped; null when absent.
  final String? enabled;
  final String? exported;

  /// Whether the component is enabled until the app changes that at
  /// runtime: no android:enabled means enabled. Null when the value is not
  /// a literal boolean, e.g. a resource reference, which can't be resolved
  /// here.
  bool? get enabledByDefault => enabled == null ? true : _literalBool(enabled!);

  String get tag => isAlias ? '<activity-alias>' : '<activity>';
}

/// The launcher-relevant part of a merged AndroidManifest.xml.
class LauncherManifest {
  LauncherManifest(this.packageName, this.components);

  final String packageName;

  /// Every `<activity>` and `<activity-alias>` of the application, in
  /// manifest order -- which matters, see [checkRelease].
  final List<ManifestComponent> components;

  /// [name] relative to the package where it is inside it, e.g.
  /// `.MainActivity`, as manifests and launcher_icons.dart spell it.
  String shortName(String name) => name.startsWith('$packageName.')
      ? name.substring(packageName.length)
      : name;
}

/// Expands a manifest class name the way PackageManager does: `.Foo` and a
/// bare `Foo` are relative to the package. The merged manifest in an APK
/// already has fully qualified names, but comparing targets must not depend
/// on that.
String resolveClassName(String packageName, String name) {
  if (name.startsWith('.')) return '$packageName$name';
  if (!name.contains('.')) return '$packageName.$name';
  return name;
}

/// Reads the activities and aliases out of a dumped AndroidManifest.xml.
/// Throws a [FormatException] when [dump] isn't one.
LauncherManifest readLauncherManifest(String dump) {
  final manifests = parseXmlTree(dump).childrenNamed('manifest');
  if (manifests.isEmpty) {
    throw const FormatException('no <manifest> element; expected the output '
        'of `aapt2 dump xmltree --file AndroidManifest.xml <apk>`');
  }
  final manifest = manifests.first;
  final packageName = manifest.attributes['package'] ?? '';
  if (packageName.isEmpty) {
    throw const FormatException('<manifest> has no package attribute');
  }
  final components = <ManifestComponent>[];
  for (final application in manifest.childrenNamed('application')) {
    for (final element in application.children) {
      final isAlias = element.name == 'activity-alias';
      if (!isAlias && element.name != 'activity') continue;
      final name = element.attributes['android:name'] ?? '';
      if (name.isEmpty) {
        throw FormatException(
            '<${element.name}> without android:name (line ${element.line})');
      }
      final target = element.attributes['android:targetActivity'];
      components.add(ManifestComponent(
        isAlias: isAlias,
        name: resolveClassName(packageName, name),
        isLauncher: _isLauncher(element),
        line: element.line,
        targetActivity:
            target == null ? null : resolveClassName(packageName, target),
        icon: element.attributes['android:icon'],
        enabled: element.attributes['android:enabled'],
        exported: element.attributes['android:exported'],
      ));
    }
  }
  return LauncherManifest(packageName, components);
}

// MAIN and LAUNCHER only make a launcher entry inside the same filter.
bool _isLauncher(XmlTreeElement component) =>
    component.childrenNamed('intent-filter').any((filter) =>
        _hasName(filter, 'action', 'android.intent.action.MAIN') &&
        _hasName(filter, 'category', 'android.intent.category.LAUNCHER'));

bool _hasName(XmlTreeElement parent, String element, String name) => parent
    .childrenNamed(element)
    .any((child) => child.attributes['android:name'] == name);

// --- rules -------------------------------------------------------------------

/// Everything wrong with a release build's launcher entries; empty when
/// nothing is.
List<String> checkRelease(LauncherManifest manifest) {
  final problems = <String>[];
  String short(String name) => manifest.shortName(name);
  final components = manifest.components;

  for (final activity in components.where((c) => !c.isAlias && c.isLauncher)) {
    problems.add('<activity> ${short(activity.name)} still has a MAIN/LAUNCHER '
        'intent filter, so it shows up as a home-screen icon of its own next '
        'to the enabled alias. The release overlay must remove it '
        '(<intent-filter tools:node="removeAll"/>).');
  }

  final aliases = [
    for (final c in components)
      if (c.isAlias && c.isLauncher) c,
  ];
  if (aliases.isEmpty) {
    problems.add('No <activity-alias> has a MAIN/LAUNCHER intent filter: the '
        'launcher aliases of android/app/src/release/AndroidManifest.xml are '
        'not in this build.');
  }

  final targets = {
    for (final alias in aliases)
      if (alias.targetActivity != null) alias.targetActivity!,
  };
  if (targets.length > 1) {
    problems.add('The launcher aliases open different activities '
        '(${targets.map(short).join(', ')}); they must all open the same one.');
  }
  // PackageManager resolves an alias's target among the activities parsed
  // so far, so a target declared after the alias fails the install.
  for (final alias in components.where((c) => c.isAlias)) {
    final target = alias.targetActivity;
    if (target == null) {
      problems.add('<activity-alias> ${short(alias.name)} has no '
          'android:targetActivity.');
      continue;
    }
    final index = components.indexWhere((c) => !c.isAlias && c.name == target);
    if (index < 0) {
      problems.add('<activity-alias> ${short(alias.name)} targets '
          '${short(target)}, which is not an <activity> of this manifest.');
    } else if (index > components.indexOf(alias)) {
      problems.add('<activity-alias> ${short(alias.name)} comes before its '
          'target <activity> ${short(target)}; Android only accepts a target '
          'declared earlier in the manifest, so the install would fail.');
    } else if (components[index].enabledByDefault == false) {
      problems.add('<activity-alias> ${short(alias.name)} targets '
          '${short(target)}, which is disabled (android:enabled=false), so the '
          'icon could not open the app.');
    }
  }

  for (final alias in aliases.where((a) => a.enabledByDefault == null)) {
    problems.add('Launcher alias ${short(alias.name)} has '
        'android:enabled=${alias.enabled}, which is not a literal true or '
        'false, so which icon a fresh install shows cannot be checked.');
  }
  final enabled = [
    for (final alias in aliases)
      if (alias.enabledByDefault ?? false) alias,
  ];
  final expectedDefault =
      resolveClassName(manifest.packageName, defaultLauncherAlias);
  if (aliases.isNotEmpty && enabled.isEmpty) {
    problems.add('No launcher alias is enabled by default, so a fresh install '
        'has no home-screen icon at all.');
  } else if (enabled.length > 1) {
    problems.add('${enabled.length} launcher aliases are enabled by default '
        '(${enabled.map((a) => short(a.name)).join(', ')}), so a fresh install '
        'shows ${enabled.length} home-screen icons; exactly one may be.');
  } else if (enabled.length == 1 && enabled.single.name != expectedDefault) {
    problems.add('The launcher alias enabled by default is '
        '${short(enabled.single.name)}, but it must be $defaultLauncherAlias: '
        'that is the name home-screen shortcuts from older versions point at, '
        'and where an update leaves people who never switched icons.');
  }

  for (final alias in aliases) {
    if (alias.icon == null) {
      problems.add('Launcher alias ${short(alias.name)} has no android:icon, '
          'so it would show the application icon instead of its own variant.');
    }
    if (_literalBool(alias.exported ?? '') != true) {
      problems.add('Launcher alias ${short(alias.name)} is not exported '
          '(android:exported=${alias.exported ?? 'unset'}), so launchers '
          'cannot open it.');
    }
  }

  problems.addAll(_duplicateNames(manifest));
  return problems;
}

/// Everything wrong with a debug or profile build's launcher entries; empty
/// when nothing is.
List<String> checkDebug(LauncherManifest manifest) {
  final problems = <String>[];
  String short(String name) => manifest.shortName(name);
  // Disabled aliases would be harmless here; enabled ones are what the
  // release overlay brings along. A non-literal android:enabled counts as
  // enabled because it can't be ruled out.
  final launchers = [
    for (final c in manifest.components)
      if (c.isLauncher && c.enabledByDefault != false) c,
  ];
  for (final alias in launchers.where((c) => c.isAlias)) {
    problems.add('Launcher alias ${short(alias.name)} is enabled in a debug '
        'build. Debug and profile builds must not get the release overlay: '
        'the alias adds a second home-screen icon, and `flutter run` only '
        'starts a launcher <activity>.');
  }
  final activities = [
    for (final c in launchers)
      if (!c.isAlias) short(c.name),
  ];
  if (activities.length != 1) {
    problems.add('Expected exactly one launcher <activity> (the one '
        '`flutter run` starts), found ${activities.length}'
        '${activities.isEmpty ? '' : ': ${activities.join(', ')}'}.');
  }
  problems.addAll(_duplicateNames(manifest));
  return problems;
}

List<String> checkManifest(LauncherManifest manifest, BuildKind kind) =>
    kind == BuildKind.release ? checkRelease(manifest) : checkDebug(manifest);

List<String> _duplicateNames(LauncherManifest manifest) {
  final tags = <String, List<String>>{};
  for (final c in manifest.components) {
    (tags[c.name] ??= []).add(c.tag);
  }
  return [
    for (final MapEntry(key: name, value: declared) in tags.entries)
      if (declared.length > 1)
        '${manifest.shortName(name)} is declared ${declared.length} times '
            '(${declared.join(', ')}); component names must be unique.',
  ];
}

// --- report ------------------------------------------------------------------

/// What the manifest declares, then the verdict.
String formatReport(
  LauncherManifest manifest,
  BuildKind kind,
  List<String> problems, {
  required String source,
}) {
  final out = StringBuffer()
    ..writeln('Launcher entries of $source (${kind.name} rules)')
    ..writeln('package ${manifest.packageName}');
  final names = [for (final c in manifest.components) manifest.shortName(c.name)];
  // Align the columns after the name; rows without any (plain activities
  // such as plugin screens) don't need to widen them.
  var width = 0;
  for (final (i, c) in manifest.components.indexed) {
    if ((c.isAlias || c.isLauncher) && names[i].length > width) {
      width = names[i].length;
    }
  }
  for (final (i, c) in manifest.components.indexed) {
    final row = StringBuffer('  ${c.tag.padRight(17)}${names[i].padRight(width)}');
    if (c.targetActivity != null) {
      row.write('  -> ${manifest.shortName(c.targetActivity!)}');
    }
    if (c.isLauncher) {
      final state = switch (c.enabledByDefault) {
        true => 'ENABLED',
        false => 'disabled',
        null => 'enabled=${c.enabled}',
      };
      row.write('  launcher, $state');
    }
    if (c.isAlias) row.write(', icon ${c.icon ?? 'none'}');
    out.writeln(row.toString().trimRight());
  }
  if (problems.isEmpty) {
    final aliases =
        manifest.components.where((c) => c.isAlias && c.isLauncher).toList();
    final enabled = aliases.where((c) => c.enabledByDefault ?? false);
    out.writeln(kind == BuildKind.release
        ? 'OK: ${aliases.length} launcher aliases, only '
            '${enabled.map((c) => manifest.shortName(c.name)).join()} enabled '
            'by default.'
        : 'OK: one launcher activity, no enabled launcher alias.');
  } else {
    out.writeln('FAILED, ${problems.length} '
        '${problems.length == 1 ? 'problem' : 'problems'}:');
    for (final problem in problems) {
      out.writeln('  - $problem');
    }
  }
  return out.toString();
}

// --- finding aapt2 -----------------------------------------------------------

/// Compares build-tools directory names such as `36.0.0` or `35.0.0-rc1`
/// numerically (a string sort puts `9.0.0` after `36.0.0`); a pre-release
/// sorts before its release.
int compareBuildToolsVersions(String a, String b) {
  List<int> numbers(String v) => [
        for (final m in RegExp(r'\d+').allMatches(v.split('-').first))
          int.parse(m[0]!),
      ];
  final na = numbers(a);
  final nb = numbers(b);
  for (var i = 0; i < na.length || i < nb.length; i++) {
    final x = i < na.length ? na[i] : 0;
    final y = i < nb.length ? nb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  final aPre = a.contains('-');
  if (aPre != b.contains('-')) return aPre ? -1 : 1;
  return a.compareTo(b);
}

/// The value of `sdk.dir` in a local.properties text, unescaped (Gradle
/// writes Windows paths as `C\:\\Users\\...`).
String? readSdkDir(String properties) {
  for (final line in const LineSplitter().convert(properties)) {
    final match = RegExp(r'^\s*sdk\.dir\s*[=:]\s*(.*?)\s*$').firstMatch(line);
    if (match != null) {
      return match[1]!.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);
    }
  }
  return null;
}

/// aapt2 from the newest version under an SDK's build-tools/ that has one.
String? newestAapt2(Directory buildTools, {bool? windows}) {
  if (!buildTools.existsSync()) return null;
  final executable = (windows ?? Platform.isWindows) ? 'aapt2.exe' : 'aapt2';
  String version(Directory d) =>
      d.path.split(RegExp(r'[\\/]')).lastWhere((part) => part.isNotEmpty);
  final versions = buildTools.listSync().whereType<Directory>().toList()
    ..sort((a, b) => compareBuildToolsVersions(version(b), version(a)));
  for (final dir in versions) {
    final aapt2 = File('${dir.path}${Platform.pathSeparator}$executable');
    if (aapt2.existsSync()) return aapt2.path;
  }
  return null;
}

/// Finds aapt2 in the SDKs named by ANDROID_HOME, ANDROID_SDK_ROOT and
/// [localProperties]' sdk.dir, in that order. [localProperties] defaults to
/// android/local.properties next to this script, which Flutter writes on
/// the first build.
String? findAapt2({
  required Map<String, String> environment,
  File? localProperties,
  bool? windows,
}) {
  final sdks = [
    for (final key in const ['ANDROID_HOME', 'ANDROID_SDK_ROOT'])
      if (environment[key]?.isNotEmpty ?? false) environment[key]!,
  ];
  final properties = localProperties ?? _scriptLocalProperties();
  if (properties != null && properties.existsSync()) {
    final sdkDir = readSdkDir(properties.readAsStringSync());
    if (sdkDir != null && sdkDir.isNotEmpty) sdks.add(sdkDir);
  }
  for (final sdk in sdks) {
    final aapt2 = newestAapt2(
      Directory('$sdk${Platform.pathSeparator}build-tools'),
      windows: windows,
    );
    if (aapt2 != null) return aapt2;
  }
  return null;
}

File? _scriptLocalProperties() {
  final script = Platform.script;
  if (script.scheme != 'file') return null;
  return File.fromUri(script.resolve('../android/local.properties'));
}

// --- command line ------------------------------------------------------------

class UsageError implements Exception {
  UsageError(this.message);

  final String message;
}

class VerifierOptions {
  VerifierOptions({
    required this.kind,
    this.apk,
    this.dump,
    this.aapt2,
    this.help = false,
  });

  final BuildKind kind;
  final String? apk;
  final String? dump;
  final String? aapt2;
  final bool help;
}

/// Throws a [UsageError] for anything but the forms in [usage].
VerifierOptions parseArguments(List<String> arguments) {
  BuildKind? kind;
  String? apk;
  String? dump;
  String? aapt2;
  var i = 0;
  String valueOf(String option, String argument) {
    if (argument.startsWith('$option=')) {
      return argument.substring(option.length + 1);
    }
    if (i + 1 >= arguments.length) throw UsageError('$option needs a value');
    i++;
    return arguments[i];
  }

  for (; i < arguments.length; i++) {
    final argument = arguments[i];
    if (argument == '-h' || argument == '--help') {
      return VerifierOptions(kind: BuildKind.release, help: true);
    } else if (argument == '--release' || argument == '--debug') {
      final value = argument == '--release' ? BuildKind.release : BuildKind.debug;
      if (kind != null && kind != value) {
        throw UsageError('pass --release or --debug, not both');
      }
      kind = value;
    } else if (argument == '--aapt2' || argument.startsWith('--aapt2=')) {
      aapt2 = valueOf('--aapt2', argument);
    } else if (argument == '--dump' || argument.startsWith('--dump=')) {
      dump = valueOf('--dump', argument);
    } else if (argument.startsWith('-')) {
      throw UsageError('unknown option $argument');
    } else if (apk != null) {
      throw UsageError('more than one APK given');
    } else {
      apk = argument;
    }
  }
  if (kind == null) throw UsageError('pass --release or --debug');
  if ((apk == null) == (dump == null)) {
    throw UsageError('pass either an APK or --dump <file>');
  }
  return VerifierOptions(kind: kind, apk: apk, dump: dump, aapt2: aapt2);
}

class _NotChecked implements Exception {
  _NotChecked(this.message);

  final String message;
}

/// The command line, minus the process exit, so tests can run it. Returns
/// the exit code. On GitHub Actions every problem also becomes an error
/// annotation, which shows on the run's summary page without opening the
/// log.
Future<int> run(
  List<String> arguments, {
  StringSink? out,
  StringSink? err,
  Map<String, String>? environment,
}) async {
  final report = out ?? stdout;
  final errors = err ?? stderr;
  final env = environment ?? Platform.environment;
  final annotate = env['GITHUB_ACTIONS'] == 'true';

  void annotation(String message) {
    if (!annotate) return;
    final escaped = message
        .replaceAll('%', '%25')
        .replaceAll('\r', '%0D')
        .replaceAll('\n', '%0A');
    report.writeln('::error title=Launcher aliases::$escaped');
  }

  final VerifierOptions options;
  try {
    options = parseArguments(arguments);
  } on UsageError catch (e) {
    errors
      ..writeln('verify_launcher_aliases: ${e.message}')
      ..writeln()
      ..writeln(usage);
    return 2;
  }
  if (options.help) {
    report.writeln(usage);
    return 0;
  }

  final String source;
  final LauncherManifest manifest;
  try {
    final String dump;
    if (options.dump != null) {
      source = options.dump!;
      dump = decodeDump(File(source).readAsBytesSync());
    } else {
      source = options.apk!;
      if (!File(source).existsSync()) throw _NotChecked('no APK at $source');
      final aapt2 = options.aapt2 ?? findAapt2(environment: env);
      if (aapt2 == null) {
        throw _NotChecked('aapt2 not found. Pass --aapt2 <path>, or point '
            'ANDROID_HOME (or ANDROID_SDK_ROOT) at an Android SDK with '
            'build-tools installed.');
      }
      report.writeln('aapt2: $aapt2');
      final result = await Process.run(
        aapt2,
        ['dump', 'xmltree', '--file', 'AndroidManifest.xml', source],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) {
        throw _NotChecked('aapt2 failed with exit code ${result.exitCode}: '
            '${'${result.stderr}'.trim()}');
      }
      dump = result.stdout as String;
    }
    manifest = readLauncherManifest(dump);
  } on _NotChecked catch (e) {
    errors.writeln('verify_launcher_aliases: ${e.message}');
    annotation(e.message);
    return 2;
  } on FormatException catch (e) {
    errors.writeln('verify_launcher_aliases: not a manifest dump: ${e.message}');
    annotation('not a manifest dump: ${e.message}');
    return 2;
  } on IOException catch (e) {
    // FileSystemException (unreadable dump) and ProcessException (aapt2
    // not runnable).
    errors.writeln('verify_launcher_aliases: $e');
    annotation('$e');
    return 2;
  }

  final problems = checkManifest(manifest, options.kind);
  report.write(formatReport(manifest, options.kind, problems, source: source));
  problems.forEach(annotation);
  return problems.isEmpty ? 0 : 1;
}

Future<void> main(List<String> arguments) async {
  exitCode = await run(arguments);
}

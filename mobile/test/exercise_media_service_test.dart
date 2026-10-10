import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ironpeak_mobile/services/exercise_media_service.dart';
import 'package:path/path.dart' as p;

const _base = 'https://cdn.example.test/gh/owner/dataset@abc123/';
const _a = '0001-AAAAAAA';
const _b = '0002-BBBBBBB';
const _c = '0003-CCCCCCC';

/// A tiny byte string that passes the service's GIF magic-byte check --
/// the service never decodes, so it doesn't need to be a real image.
Uint8List _fakeGif(int seed) =>
    Uint8List.fromList([...'GIF89a'.codeUnits, seed, seed + 1, seed + 2]);

/// Plain `test()` (not testWidgets): real file I/O would stall under
/// testWidgets' fake async zone.
void main() {
  late Directory tempDir;
  late Directory cacheDir;
  late List<Uri> requests;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exercise_media_test');
    cacheDir = Directory(p.join(tempDir.path, 'exercise_media'));
    requests = [];
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Serves a distinct fake GIF per basename, recording every request.
  MockClient gifServer({Set<String> failing = const {}}) => MockClient((request) async {
        requests.add(request.url);
        final name = p.basenameWithoutExtension(request.url.path);
        if (failing.contains(name)) return http.Response('not found', 404);
        return http.Response.bytes(_fakeGif(name.codeUnitAt(3)), 200);
      });

  ExerciseMediaService service(http.Client client, {int memoryCacheSize = 40}) => ExerciseMediaService(
        client: client,
        cacheDirectory: () async => cacheDir,
        baseUrl: _base,
        memoryCacheSize: memoryCacheSize,
      );

  File fileFor(String basename) => File(p.join(cacheDir.path, '$basename.gif'));

  test('gifUri appends to the pinned base, with or without a trailing slash', () {
    const expected = 'https://cdn.example.test/gh/owner/dataset@abc123/videos/$_a.gif';
    final client = gifServer();
    expect(service(client).gifUri(_a).toString(), expected);
    final noSlash = ExerciseMediaService(
        client: client, cacheDirectory: () async => cacheDir, baseUrl: _base.substring(0, _base.length - 1));
    expect(noSlash.gifUri(_a).toString(), expected);
  });

  test('first load fetches and writes the disk cache', () async {
    final bytes = await service(gifServer()).loadGif(_a);
    expect(requests, [Uri.parse('${_base}videos/$_a.gif')]);
    expect(bytes, _fakeGif('1'.codeUnitAt(0)));
    expect(await fileFor(_a).readAsBytes(), bytes);
    expect(cacheDir.listSync().whereType<File>().map((f) => p.basename(f.path)), ['$_a.gif'],
        reason: 'no temp files left behind');
  });

  test('memory cache: same instance again, no new request', () async {
    final s = service(gifServer());
    final first = await s.loadGif(_a);
    final second = await s.loadGif(_a);
    expect(identical(first, second), isTrue);
    expect(identical(s.peekMemory(_a), first), isTrue);
    expect(requests, hasLength(1));
  });

  test('a new service instance loads from disk without the network', () async {
    final bytes = await service(gifServer()).loadGif(_a);
    final offline = service(MockClient((_) async => throw const SocketException('offline')));
    expect(offline.peekMemory(_a), isNull);
    expect(await offline.loadGif(_a), bytes);
    expect(requests, hasLength(1));
  });

  test('LRU eviction falls back to disk, not the network', () async {
    final s = service(gifServer(), memoryCacheSize: 2);
    await s.loadGif(_a);
    await s.loadGif(_b);
    await s.loadGif(_c);
    expect(s.peekMemory(_a), isNull);
    expect(s.peekMemory(_c), isNotNull);
    await s.loadGif(_a);
    expect(requests, hasLength(3));
  });

  test('a non-GIF response throws and is never cached', () async {
    var html = true;
    final s = service(MockClient((request) async {
      requests.add(request.url);
      return html
          ? http.Response('<html>captive portal</html>', 200)
          : http.Response.bytes(_fakeGif(7), 200);
    }));
    await expectLater(s.loadGif(_a), throwsA(isA<ExerciseMediaException>()));
    expect(fileFor(_a).existsSync(), isFalse);
    expect(s.peekMemory(_a), isNull);
    expect(await s.isCached(_a), isFalse);

    html = false; // a retry goes back to the network
    expect(await s.loadGif(_a), _fakeGif(7));
    expect(requests, hasLength(2));
  });

  test('HTTP errors throw', () async {
    final s = service(gifServer(failing: {_a}));
    await expectLater(s.loadGif(_a), throwsA(isA<ExerciseMediaException>()));
    expect(fileFor(_a).existsSync(), isFalse);
  });

  test('a corrupt disk file is replaced by a fresh download', () async {
    await cacheDir.create(recursive: true);
    await fileFor(_a).writeAsString('garbage');
    final bytes = await service(gifServer()).loadGif(_a);
    expect(requests, hasLength(1));
    expect(await fileFor(_a).readAsBytes(), bytes);
  });

  test('concurrent loads of one basename share one request', () async {
    final gate = Completer<void>();
    final s = service(MockClient((request) async {
      requests.add(request.url);
      await gate.future;
      return http.Response.bytes(_fakeGif(1), 200);
    }));
    final first = s.loadGif(_a);
    final second = s.loadGif(_a);
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(requests, hasLength(1));
    expect(identical(results[0], results[1]), isTrue);
  });

  test('a failed in-flight load is not handed out again', () async {
    var fail = true;
    final s = service(MockClient((request) async {
      requests.add(request.url);
      return fail ? http.Response('x', 500) : http.Response.bytes(_fakeGif(2), 200);
    }));
    await expectLater(s.loadGif(_a), throwsA(isA<ExerciseMediaException>()));
    fail = false;
    expect(await s.loadGif(_a), _fakeGif(2));
  });

  test('invalid basenames are rejected without any request', () async {
    final s = service(gifServer());
    await expectLater(s.loadGif('../../etc/passwd'), throwsArgumentError);
    await expectLater(s.loadGif('0025-EIeI8Vf.gif'), throwsArgumentError);
    expect(() => s.gifUri('nope'), throwsArgumentError);
    expect(await s.isCached('nope'), isFalse);
    expect(requests, isEmpty);
  });

  test('downloadAll reports progress, skips cached files, counts failures', () async {
    final s = service(gifServer(failing: {_c}));
    await s.loadGif(_a); // already on disk
    requests.clear();

    final progress = <List<int>>[];
    final result = await s.downloadAll(
      [_a, _b, _c, _b, 'bad-name'],
      onProgress: (done, total) => progress.add([done, total]),
    );

    expect(result.total, 4); // distinct
    expect(result.skipped, 1);
    expect(result.downloaded, 1);
    expect(result.failed, 2); // _c (404) + the invalid name
    expect(result.cancelled, isFalse);
    expect(progress.first, [0, 4]);
    expect(progress.last, [4, 4]);
    expect(requests.map((u) => p.basenameWithoutExtension(u.path)).toSet(), {_b, _c});
    expect(fileFor(_b).existsSync(), isTrue);
    expect(s.peekMemory(_b), isNull, reason: 'bulk downloads bypass the memory cache');
    expect(await s.cachedBasenames(), {_a, _b});
  });

  test('downloadAll stops starting new files once cancelled', () async {
    final s = service(gifServer());
    var calls = 0;
    final result = await s.downloadAll(
      [_a, _b, _c],
      concurrency: 1,
      isCancelled: () => calls++ >= 1, // allow exactly one item
    );
    expect(result.cancelled, isTrue);
    expect(result.downloaded, 1);
    expect(requests, hasLength(1));
  });

  test('cacheSizeBytes and clearCache', () async {
    final s = service(gifServer());
    expect(await s.cacheSizeBytes(), 0);
    final a = await s.loadGif(_a);
    final b = await s.loadGif(_b);
    expect(await s.cacheSizeBytes(), a.length + b.length);
    expect(await s.isCached(_a), isTrue);

    await s.clearCache();
    expect(await s.cacheSizeBytes(), 0);
    expect(await s.isCached(_a), isFalse);
    expect(s.peekMemory(_a), isNull);
    await s.loadGif(_a);
    expect(requests, hasLength(3), reason: 'cleared means back to the network');
  });

  test('a load in flight during clearCache does not re-cache afterwards', () async {
    final gate = Completer<void>();
    final s = service(MockClient((request) async {
      requests.add(request.url);
      await gate.future;
      return http.Response.bytes(_fakeGif(3), 200);
    }));
    final pending = s.loadGif(_a);
    await Future<void>.delayed(Duration.zero);
    await s.clearCache();
    gate.complete();
    expect(await pending, _fakeGif(3), reason: 'the caller still gets its bytes');
    expect(fileFor(_a).existsSync(), isFalse);
    expect(s.peekMemory(_a), isNull);
    expect(await s.cacheSizeBytes(), 0);
  });

  test('a bulk download in flight during clearCache leaves nothing on disk', () async {
    final gate = Completer<void>();
    final s = service(MockClient((request) async {
      requests.add(request.url);
      await gate.future;
      return http.Response.bytes(_fakeGif(4), 200);
    }));
    final run = s.downloadAll([_a, _b]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await s.clearCache();
    gate.complete();
    final result = await run;
    expect(result.downloaded, 0);
    expect(result.failed, 2);
    expect(await s.cachedBasenames(), isEmpty);
  });

  test('a new load after clearCache does not join the stale in-flight one', () async {
    final gate = Completer<void>();
    final s = service(MockClient((request) async {
      requests.add(request.url);
      if (requests.length == 1) await gate.future;
      return http.Response.bytes(_fakeGif(5), 200);
    }));
    final stale = s.loadGif(_a);
    await Future<void>.delayed(Duration.zero);
    await s.clearCache();
    final fresh = await s.loadGif(_a); // must not wait on the gated request
    expect(requests, hasLength(2));
    expect(fileFor(_a).existsSync(), isTrue);
    expect(identical(s.peekMemory(_a), fresh), isTrue);
    gate.complete();
    await stale;
    expect(identical(s.peekMemory(_a), fresh), isTrue, reason: 'stale result must not replace it');
    expect(fileFor(_a).existsSync(), isTrue, reason: 'stale write must not delete the fresh file');
  });

  test('evict forgets one animation in memory and on disk', () async {
    final s = service(gifServer());
    await s.loadGif(_a);
    await s.evict(_a);
    expect(s.peekMemory(_a), isNull);
    expect(fileFor(_a).existsSync(), isFalse);
  });

  test('no usable cache directory: still loads, disk calls degrade', () async {
    final s = ExerciseMediaService(
      client: gifServer(),
      cacheDirectory: () async => throw const FileSystemException('none'),
      baseUrl: _base,
    );
    expect(await s.loadGif(_a), isNotNull);
    expect(await s.cacheSizeBytes(), 0);
    expect(await s.isCached(_a), isFalse);
    await s.clearCache();
    final result = await s.downloadAll([_b]);
    expect(result.total, 0);
  });
}

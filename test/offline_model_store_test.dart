import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:edge_alpha/src/services/offline_model_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory directory;
  final bytes = utf8.encode('GGUF fixture contents for download verification');
  late OfflineModelSpec spec;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('edge-offline-test-');
    spec = OfflineModelSpec(
      url: 'https://example.test/model.gguf',
      fileName: 'model.gguf',
      bytes: bytes.length,
      sha256Hex: sha256.convert(bytes).toString(),
    );
  });
  tearDown(() => directory.delete(recursive: true));

  OfflineModelStore storeWith(MockClient client) => OfflineModelStore(
    directory: () async => directory,
    spec: spec,
    clientFactory: () => client,
  );

  Future<void> download(OfflineModelStore store) =>
      store.download(onProgress: (_, _) {}, onVerifying: () {});

  test('download is installed only after checksum verification', () async {
    final store = storeWith(
      MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    expect(await store.isInstalled(), isFalse);
    await download(store);
    expect(await store.isInstalled(), isTrue);
    expect(await (await store.file).readAsBytes(), bytes);
    expect(await store.downloadedBytes(), 0);
  });

  test('resumes a partial model using the exact byte range', () async {
    final store = storeWith(
      MockClient((request) async {
        expect(request.headers['Range'], 'bytes=10-');
        return http.Response.bytes(
          bytes.sublist(10),
          206,
          headers: {
            'content-range': 'bytes 10-${bytes.length - 1}/${bytes.length}',
          },
        );
      }),
    );
    await File(
      '${(await store.file).path}.part',
    ).writeAsBytes(bytes.sublist(0, 10));
    await download(store);
    expect(await store.verify(await store.file), isTrue);
  });

  test('restarts safely if server ignores Range', () async {
    final store = storeWith(
      MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    await File(
      '${(await store.file).path}.part',
    ).writeAsBytes(bytes.sublist(0, 10));
    await download(store);
    expect(await (await store.file).readAsBytes(), bytes);
  });

  test('rejects corrupt data and removes its partial file', () async {
    final corrupt = List<int>.of(bytes)..[12] = 0;
    final store = storeWith(
      MockClient((_) async => http.Response.bytes(corrupt, 200)),
    );
    await expectLater(download(store), throwsFormatException);
    expect(await store.isInstalled(), isFalse);
    expect(await store.downloadedBytes(), 0);
  });

  test('rejects wrong range without modifying the partial model', () async {
    final store = storeWith(
      MockClient(
        (_) async => http.Response.bytes(
          bytes,
          206,
          headers: {
            'content-range': 'bytes 0-${bytes.length - 1}/${bytes.length}',
          },
        ),
      ),
    );
    await File(
      '${(await store.file).path}.part',
    ).writeAsBytes(bytes.sublist(0, 10));
    await expectLater(download(store), throwsFormatException);
    expect(await store.downloadedBytes(), 10);
    expect(await store.isInstalled(), isFalse);
  });

  test('truncated download remains resumable but is never installed', () async {
    final store = storeWith(
      MockClient((_) async => http.Response.bytes(bytes.sublist(0, 10), 200)),
    );
    await expectLater(download(store), throwsA(isA<HttpException>()));
    expect(await store.downloadedBytes(), 10);
    expect(await store.isInstalled(), isFalse);
  });

  test('pause preserves downloaded bytes without installing', () async {
    final store = storeWith(
      MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    await expectLater(
      store.download(
        onProgress: (received, _) {
          if (received > 0) store.pause();
        },
        onVerifying: () => fail('Paused downloads must not be installed'),
      ),
      throwsA(isA<DownloadPaused>()),
    );
    expect(await store.isInstalled(), isFalse);
    expect(await store.downloadedBytes(), bytes.length);
  });

  test(
    'completed partial file can be verified without network access',
    () async {
      final store = storeWith(
        MockClient((_) async => throw StateError('Network used')),
      );
      await File('${(await store.file).path}.part').writeAsBytes(bytes);
      await download(store);
      expect(await store.isInstalled(), isTrue);
      await store.remove();
      expect(await store.isInstalled(), isFalse);
    },
  );
}

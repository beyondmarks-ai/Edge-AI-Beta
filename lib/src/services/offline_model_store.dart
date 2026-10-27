import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class OfflineModelSpec {
  const OfflineModelSpec({
    required this.url,
    required this.fileName,
    required this.bytes,
    required this.sha256Hex,
  });

  final String url;
  final String fileName;
  final int bytes;
  final String sha256Hex;

  static const qwen = OfflineModelSpec(
    url:
        'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/'
        '91cad51170dc346986eccefdc2dd33a9da36ead9/'
        'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    fileName: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    bytes: 1117320736,
    sha256Hex:
        '6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e',
  );
}

class DownloadPaused implements Exception {
  const DownloadPaused();
  @override
  String toString() => 'Download paused. Tap Resume download to continue.';
}

/// Owns only the pinned model and its temporary file in app-private storage.
class OfflineModelStore {
  OfflineModelStore({
    required this.directory,
    this.spec = OfflineModelSpec.qwen,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final Future<Directory> Function() directory;
  final OfflineModelSpec spec;
  final http.Client Function() _clientFactory;
  http.Client? _client;
  bool _busy = false;
  bool _paused = false;

  Future<File> get file async =>
      File('${(await directory()).path}/${spec.fileName}');

  Future<bool> isInstalled() async {
    final model = await file;
    return await model.exists() && await model.length() == spec.bytes;
  }

  Future<int> downloadedBytes() async {
    final part = File('${(await file).path}.part');
    return await part.exists() ? part.length() : 0;
  }

  Future<bool> verify(File model) async {
    if (!await model.exists() || await model.length() != spec.bytes) {
      return false;
    }
    final path = model.path;
    // Hash the file off the UI isolate without holding the model in RAM.
    final digest = await Isolate.run(
      () async => (await sha256.bind(File(path).openRead()).first).toString(),
    );
    return digest == spec.sha256Hex;
  }

  void pause() {
    _paused = true;
    _client?.close();
  }

  Future<void> download({
    required void Function(int received, int total) onProgress,
    required void Function() onVerifying,
  }) async {
    if (_busy) throw StateError('A model download is already running.');
    _busy = true;
    _paused = false;
    try {
      final target = await file;
      await target.parent.create(recursive: true);
      final part = File('${target.path}.part');
      var offset = await part.exists() ? await part.length() : 0;
      if (offset > spec.bytes) {
        await part.delete();
        offset = 0;
      }
      onProgress(offset, spec.bytes);
      if (_paused) throw const DownloadPaused();
      if (offset < spec.bytes) {
        final client = _clientFactory();
        _client = client;
        final request = http.Request('GET', Uri.parse(spec.url));
        if (offset > 0) request.headers['Range'] = 'bytes=$offset-';
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 45));
        if (response.statusCode == 200) {
          // Servers may ignore Range: restart rather than append a second file.
          offset = 0;
        } else if (response.statusCode == 206) {
          final expected = 'bytes $offset-${spec.bytes - 1}/${spec.bytes}';
          if (response.headers['content-range'] != expected) {
            throw const FormatException('Invalid model download range. Retry.');
          }
        } else {
          throw HttpException(
            'Model download failed (HTTP ${response.statusCode}).',
          );
        }
        final sink = part.openWrite(
          mode: offset == 0 ? FileMode.write : FileMode.append,
        );
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 45),
          )) {
            if (_paused) throw const DownloadPaused();
            if (offset + chunk.length > spec.bytes) {
              throw const FormatException(
                'Model download is larger than expected.',
              );
            }
            sink.add(chunk);
            // Backpressure prevents a slow disk from buffering a gigabyte in RAM.
            await sink.flush();
            offset += chunk.length;
            onProgress(offset, spec.bytes);
          }
        } finally {
          await sink.close();
        }
      }
      if (_paused) throw const DownloadPaused();
      if (await part.length() != spec.bytes) {
        throw const HttpException('Download interrupted. Resume to finish.');
      }
      onVerifying();
      if (!await verify(part)) {
        await part.delete();
        throw const FormatException(
          'Model verification failed. Download again.',
        );
      }
      if (_paused) throw const DownloadPaused();
      if (await target.exists()) await target.delete();
      await part.rename(target.path);
    } catch (_) {
      if (_paused) throw const DownloadPaused();
      rethrow;
    } finally {
      _client?.close();
      _client = null;
      _busy = false;
    }
  }

  Future<void> remove() async {
    if (_busy) {
      throw StateError('Pause the download before removing the model.');
    }
    final target = await file;
    for (final candidate in [target, File('${target.path}.part')]) {
      if (await candidate.exists()) await candidate.delete();
    }
  }
}

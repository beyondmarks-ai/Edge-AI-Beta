import 'package:llamadart/llamadart.dart';

abstract interface class OfflineChatRuntime {
  Future<void> load(String path);
  Stream<String> reply(String question);
  void stop();
  void reset();
  Future<void> dispose();
}

class LlamaOfflineChatRuntime implements OfflineChatRuntime {
  LlamaEngine? _engine;
  ChatSession? _session;

  @override
  Future<void> load(String path) async {
    _engine = await LlamaEngine.load(
      LlamaModel(ModelSource.path(path)),
      params: const LlamaCppModelParams(
        contextSize: 2048,
        device: ComputeDevice.cpu,
        gpuLayers: 0,
        batchSize: 128,
      ),
    );
    _session = ChatSession(
      _engine!,
      maxContextTokens: 2048,
      systemPrompt:
          'You are Edge AI, a helpful offline assistant. '
          'Give concise, accurate answers. You have no internet, live attendance, '
          'camera observations, student records or uploaded PDFs. '
          'Never invent access to these sources. If asked about them, explain '
          'that the user needs the cloud assistant while connected. '
          'Acknowledge uncertainty when you do not know an answer.',
    );
  }

  @override
  Stream<String> reply(String question) {
    final session = _session;
    if (session == null) throw StateError('Load the offline model first.');
    return session.create([
      LlamaTextContent(question),
    ], params: const GenerationParams(maxTokens: 384, temp: 0.6)).textDeltas();
  }

  @override
  void stop() => _engine?.cancelGeneration();

  @override
  void reset() => _session?.reset();

  @override
  Future<void> dispose() async {
    stop();
    await _engine?.dispose();
    _engine = null;
    _session = null;
  }
}

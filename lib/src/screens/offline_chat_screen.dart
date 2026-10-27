import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/offline_chat_runtime.dart';
import '../services/offline_model_store.dart';

/// Available before cloud setup/sign-in; never receives a cloud repository.
class OfflineChatButton extends StatelessWidget {
  const OfflineChatButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.offline_bolt_outlined),
    label: const Text('Open offline chat'),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Offline chat')),
          body: const OfflineChatScreen(),
        ),
      ),
    ),
  );
}

class OfflineChatScreen extends StatefulWidget {
  const OfflineChatScreen({super.key, this.store, this.runtime});
  final OfflineModelStore? store;
  final OfflineChatRuntime? runtime;

  @override
  State<OfflineChatScreen> createState() => _OfflineChatScreenState();
}

class _OfflineChatScreenState extends State<OfflineChatScreen>
    with WidgetsBindingObserver {
  late final OfflineModelStore store;
  late final OfflineChatRuntime runtime;
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <({bool user, String text})>[];
  Future<void>? work;
  bool checking = true;
  bool installed = false;
  bool loaded = false;
  bool busy = false;
  bool downloading = false;
  bool generating = false;
  bool stopped = false;
  bool closed = false;
  bool background = false;
  double progress = 0;
  String? status;
  String? error;

  bool get supported =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store =
        widget.store ??
        OfflineModelStore(
          directory: () async {
            final support = await getApplicationSupportDirectory();
            return Directory('${support.path}/offline_models');
          },
        );
    runtime = widget.runtime ?? LlamaOfflineChatRuntime();
    _check();
  }

  Future<void> _check() async {
    try {
      if (!supported) return;
      final exists = await store.isInstalled();
      final bytes = await store.downloadedBytes();
      if (closed) return;
      setState(() {
        installed = exists;
        progress = bytes / store.spec.bytes;
      });
    } catch (_) {
      if (!closed) {
        setState(
          () => error =
              'Could not open local model storage. Retry or restart the app.',
        );
      }
    } finally {
      if (!closed) setState(() => checking = false);
    }
  }

  void _run(Future<void> Function() action) {
    if (busy || closed) return;
    setState(() {
      busy = true;
      error = null;
    });
    work = () async {
      try {
        await action();
      } catch (e) {
        if (!closed && !stopped) {
          setState(
            () =>
                error = e is DownloadPaused ? e.toString() : 'Offline chat: $e',
          );
        }
      } finally {
        if (!closed) {
          setState(() {
            busy = false;
            downloading = false;
            generating = false;
            status = null;
          });
        }
      }
    }();
  }

  void download() => _run(() async {
    stopped = false;
    setState(() {
      downloading = true;
      status = 'Downloading model';
    });
    await store.download(
      onProgress: (received, total) {
        if (closed) return;
        final next = received / total;
        // Avoid rebuilding on every network packet.
        if ((next - progress).abs() >= .002 || received == total) {
          setState(() => progress = next);
        }
      },
      onVerifying: () {
        if (!closed) setState(() => status = 'Verifying model');
      },
    );
    if (!closed) setState(() => installed = true);
  });

  void send() {
    final question = input.text.trim();
    if (!installed || question.isEmpty || busy) return;
    _run(() async {
      stopped = false;
      if (!loaded) {
        setState(() => status = 'Loading offline model');
        final model = await store.file;
        if (!await store.verify(model)) {
          if (!closed) setState(() => installed = false);
          throw const FormatException(
            'Local model is damaged. Download it again.',
          );
        }
        if (closed || background) return;
        await runtime.load(model.path);
        loaded = true;
      }
      if (closed || background) return;
      setState(() {
        status = 'Thinking on this device';
        generating = true;
        input.clear();
        messages.add((user: true, text: question));
        messages.add((user: false, text: ''));
      });
      _scroll();
      final index = messages.length - 1;
      try {
        await for (final token in runtime.reply(question)) {
          if (closed) break;
          setState(
            () => messages[index] = (
              user: false,
              text: messages[index].text + token,
            ),
          );
          _scroll();
        }
      } finally {
        if (!closed && messages[index].text.isEmpty) {
          setState(() {
            messages[index] = (
              user: false,
              text: stopped
                  ? 'Response stopped.'
                  : 'No response. Please try again.',
            );
            input.text = question;
          });
        }
      }
    });
  }

  void stop() {
    stopped = true;
    runtime.stop();
  }

  void _scroll() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!closed && scroll.hasClients) {
      scroll.jumpTo(scroll.position.maxScrollExtent);
    }
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) background = false;
    if (state == AppLifecycleState.paused) {
      background = true;
      if (downloading) store.pause();
      if (generating) stop();
    }
  }

  @override
  void dispose() {
    closed = true;
    WidgetsBinding.instance.removeObserver(this);
    store.pause();
    runtime.stop();
    // Wait for a native load/generation before releasing its resources.
    unawaited(() async {
      await work;
      try {
        await runtime.dispose();
      } catch (_) {
        /* Already shutting down. */
      }
    }());
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!supported) {
      return const Center(
        child: Text('Offline chat is available in the installed app.'),
      );
    }
    if (checking) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Runs on this device. Live attendance and PDFs require cloud chat.',
                ),
              ),
              if (installed) ...[
                IconButton(
                  tooltip: 'New offline chat',
                  onPressed: busy
                      ? null
                      : () {
                          runtime.reset();
                          setState(() {
                            messages.clear();
                            input.clear();
                            error = null;
                          });
                        },
                  icon: const Icon(Icons.add_comment_outlined),
                ),
                PopupMenuButton<String>(
                  enabled: !busy,
                  tooltip: 'Offline model',
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove downloaded model'),
                    ),
                  ],
                  onSelected: (_) => _run(() async {
                    await runtime.dispose();
                    loaded = false;
                    await store.remove();
                    if (!closed) {
                      setState(() {
                        installed = false;
                        progress = 0;
                        messages.clear();
                      });
                    }
                  }),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: !installed
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Icon(Icons.offline_bolt_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Set up offline chat',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Download Qwen2.5 1.5B once (1.12 GB), then chat without internet or sign-in. Use Wi-Fi and keep this screen open. Downloads pause when the app goes into the background.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Recommended: 4 GB RAM or more and 2 GB free storage. Replies may be slower and less accurate than cloud chat.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Model: Qwen, Apache 2.0 license. Your messages are not sent with the download.',
                    ),
                    TextButton(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: 'Edge AI',
                      ),
                      child: const Text('Open-source licenses'),
                    ),
                    const SizedBox(height: 24),
                    if (downloading || progress > 0) ...[
                      LinearProgressIndicator(value: progress.clamp(0, 1)),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% downloaded',
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: busy ? null : download,
                      icon: const Icon(Icons.download),
                      label: Text(
                        progress > 0
                            ? 'Resume download'
                            : 'Download model · 1.12 GB',
                      ),
                    ),
                    if (downloading)
                      TextButton(
                        onPressed: store.pause,
                        child: const Text('Pause download'),
                      ),
                  ],
                )
              : messages.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Ready for offline chat. Ask a general question.\n\nMessages stay in this screen and are cleared when you leave it.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final message = messages[index];
                    return Align(
                      alignment: message.user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            message.text.isEmpty ? 'Thinking…' : message.text,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(status!, key: const ValueKey('offline-status')),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              error!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (installed)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      enabled: !busy,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 1000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask offline…',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: generating ? 'Stop response' : 'Send offline',
                    onPressed: generating
                        ? stop
                        : busy
                        ? null
                        : send,
                    icon: Icon(generating ? Icons.stop : Icons.send),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

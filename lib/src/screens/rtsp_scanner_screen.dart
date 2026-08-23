import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

import '../models/edge_models.dart';
import '../services/edge_repository.dart';

class RtspScannerScreen extends StatefulWidget {
  const RtspScannerScreen({
    super.key,
    required this.repository,
    required this.sessionId,
    required this.onDetected,
  });

  final EdgeRepository repository;
  final String sessionId;
  final ValueChanged<Student> onDetected;

  @override
  State<RtspScannerScreen> createState() => _RtspScannerScreenState();
}

class _RtspScannerScreenState extends State<RtspScannerScreen> {
  static const storage = FlutterSecureStorage();
  static const urlKey = 'edge_ai_rtsp_url';
  static const usernameKey = 'edge_ai_rtsp_username';
  static const passwordKey = 'edge_ai_rtsp_password';

  final url = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  VlcPlayerController? player;
  Timer? timer;
  bool connecting = false;
  bool monitoring = false;
  bool sending = false;
  bool obscurePassword = true;
  String zone = 'AUTO';
  String status = 'Enter the RTSP Camera Server address.';
  List<VisualObservation> observations = const [];

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final values = await Future.wait([
      storage.read(key: urlKey),
      storage.read(key: usernameKey),
      storage.read(key: passwordKey),
    ]);
    if (!mounted) return;
    url.text = values[0] ?? '';
    username.text = values[1] ?? '';
    password.text = values[2] ?? '';
    if (url.text.isNotEmpty) connect();
  }

  String validatedStreamUrl() {
    final uri = Uri.tryParse(url.text.trim());
    if (uri == null ||
        !{'rtsp', 'rtsps'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      throw const FormatException(
        'Use a complete address such as rtsp://192.168.1.20:8554/live.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Remove credentials from the URL and use the secure fields below.',
      );
    }
    if (username.text.isEmpty) return uri.toString();
    final userInfo = password.text.isEmpty
        ? Uri.encodeComponent(username.text)
        : '${Uri.encodeComponent(username.text)}:${Uri.encodeComponent(password.text)}';
    return uri.replace(userInfo: userInfo).toString();
  }

  Future<void> connect() async {
    setState(() {
      connecting = true;
      status = 'Connecting to RTSP camera...';
    });
    try {
      final streamUrl = validatedStreamUrl();
      await storage.write(key: urlKey, value: url.text.trim());
      await storage.write(key: usernameKey, value: username.text);
      await storage.write(key: passwordKey, value: password.text);
      stopMonitoring();
      final previous = player;
      player = null;
      if (previous != null) await previous.dispose();
      final next = VlcPlayerController.network(
        streamUrl,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(
          rtp: VlcRtpOptions([VlcRtpOptions.rtpOverRtsp(true)]),
          advanced: VlcAdvancedOptions([
            VlcAdvancedOptions.networkCaching(800),
            VlcAdvancedOptions.liveCaching(500),
          ]),
          video: VlcVideoOptions([
            VlcVideoOptions.dropLateFrames(true),
            VlcVideoOptions.skipFrames(true),
          ]),
        ),
      );
      next.addListener(playerChanged);
      setState(() {
        player = next;
        status = 'Stream configured. Wait for video, then start monitoring.';
      });
    } catch (error) {
      setState(() => status = 'RTSP connection error: $error');
    } finally {
      if (mounted) setState(() => connecting = false);
    }
  }

  void playerChanged() {
    final value = player?.value;
    if (!mounted || value == null) return;
    if (value.hasError) {
      setState(() => status = 'Stream error: ${value.errorDescription}');
    } else if (value.isPlaying && !monitoring) {
      setState(() => status = 'RTSP stream connected.');
    }
  }

  void toggleMonitoring() {
    if (monitoring) {
      stopMonitoring();
      setState(() => status = 'Detection monitoring stopped.');
      return;
    }
    final controller = player;
    if (controller == null || !controller.value.isInitialized) {
      setState(() => status = 'Connect the RTSP stream first.');
      return;
    }
    timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => analyzeSnapshot(),
    );
    setState(() {
      monitoring = true;
      status = 'Monitoring for enrolled faces every 3 seconds.';
    });
    analyzeSnapshot();
  }

  void stopMonitoring() {
    timer?.cancel();
    timer = null;
    monitoring = false;
  }

  Future<void> analyzeSnapshot() async {
    final controller = player;
    if (controller == null || sending || !controller.value.isPlaying) return;
    setState(() => sending = true);
    File? snapshot;
    try {
      final bytes = await controller.takeSnapshot();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('The RTSP player did not return a frame yet.');
      }
      snapshot = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}edge-ai-rtsp-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await snapshot.writeAsBytes(bytes, flush: true);
      final result = await widget.repository.scanFrame(
        image: snapshot,
        sessionId: widget.sessionId,
        cameraId: 'android-rtsp-camera',
        zone: zone,
      );
      if (!mounted) return;
      for (final student in result.detected) {
        widget.onDetected(student);
      }
      setState(() {
        observations = result.observations;
        if (result.detected.isNotEmpty) {
          status =
              'Detected ${result.detected.map((item) => item.name).join(', ')}';
        } else if (result.unknownFaces > 0) {
          status =
              '${result.unknownFaces} unknown face(s); identity not guessed.';
        } else {
          status = 'No enrolled face detected in the latest frame.';
        }
      });
    } catch (error) {
      if (mounted) setState(() => status = 'Frame analysis failed: $error');
    } finally {
      if (snapshot != null && await snapshot.exists()) await snapshot.delete();
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    player?.removeListener(playerChanged);
    player?.dispose();
    url.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'RTSP live camera',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 4),
      const Text(
        'Use the LAN address displayed by the RTSP Camera Server app. Both phones must be on the same Wi-Fi network.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: url,
        keyboardType: TextInputType.url,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'RTSP URL',
          hintText: 'rtsp://192.168.1.20:8554/live',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: username,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Username (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: password,
              obscureText: obscurePassword,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Password (optional)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => obscurePassword = !obscurePassword),
                  icon: Icon(
                    obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: zone,
              decoration: const InputDecoration(
                labelText: 'Camera zone',
                border: OutlineInputBorder(),
              ),
              items: const ['AUTO', 'ENTRANCE', 'EXIT', 'CLASSROOM']
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => zone = value ?? zone),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: connecting ? null : connect,
              icon: const Icon(Icons.link),
              label: Text(connecting ? 'Connecting...' : 'Save & connect'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: Colors.black,
          child: player == null
              ? const AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Center(child: Icon(Icons.videocam_off, size: 52)),
                )
              : VlcPlayer(
                  controller: player!,
                  aspectRatio: 16 / 9,
                  placeholder: const Center(child: CircularProgressIndicator()),
                ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: sending
              ? const CircularProgressIndicator()
              : Icon(monitoring ? Icons.radar : Icons.info_outline),
          title: Text(status),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: player == null ? null : toggleMonitoring,
        icon: Icon(monitoring ? Icons.stop : Icons.play_arrow),
        label: Text(monitoring ? 'Stop monitoring' : 'Start face monitoring'),
      ),
      if (observations.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(
          'Gemini visual context',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        ...observations.map(
          (item) => Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(item.summary),
              subtitle: Text(
                [
                  if (item.clothing.isNotEmpty)
                    'Clothing: ${item.clothing.join(', ')}',
                  if (item.carriedObjects.isNotEmpty)
                    'Objects: ${item.carriedObjects.join(', ')}',
                  'Posture: ${item.posture}',
                  'Position: ${item.scenePosition}',
                ].join('\n'),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

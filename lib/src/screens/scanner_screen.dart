import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/edge_models.dart';
import '../services/edge_repository.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    required this.repository,
    required this.sessionId,
    required this.onDetected,
  });
  final EdgeRepository repository;
  final String sessionId;
  final ValueChanged<Student> onDetected;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? controller;
  Timer? timer;
  bool sending = false;
  bool continuous = false;
  String status = 'Camera not started';
  String zone = 'AUTO';

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera found');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final next = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted) return;
      setState(() {
        controller = next;
        status = 'Ready';
      });
    } catch (e) {
      if (mounted) setState(() => status = 'Camera unavailable: $e');
    }
  }

  Future<void> scanFile(File file) async {
    if (sending) return;
    setState(() {
      sending = true;
      status = 'Scanning frame…';
    });
    try {
      final result = await widget.repository.scanFrame(
        image: file,
        sessionId: widget.sessionId,
        cameraId: 'android-camera-1',
        zone: zone,
      );
      if (result.detected.isEmpty) {
        setState(
          () => status = result.unknownFaces > 0
              ? '${result.unknownFaces} unknown face(s)'
              : 'No enrolled student detected',
        );
      } else {
        final names = result.detected.map((item) => item.name).join(', ');
        setState(() => status = 'Detected: $names');
        widget.onDetected(result.detected.first);
      }
    } catch (e) {
      setState(() => status = 'Scan failed: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> capture() async {
    final camera = controller;
    if (camera == null ||
        !camera.value.isInitialized ||
        camera.value.isTakingPicture) {
      return;
    }
    final image = await camera.takePicture();
    await scanFile(File(image.path));
  }

  void toggleContinuous() {
    if (continuous) {
      timer?.cancel();
      setState(() {
        continuous = false;
        status = 'Continuous scanning stopped';
      });
    } else {
      timer = Timer.periodic(const Duration(seconds: 3), (_) => capture());
      setState(() {
        continuous = true;
        status = 'Continuous scanning every 3 seconds';
      });
      capture();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Frame scanner', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 4),
      const Text(
        'Sample frames are sent to Rekognition. Raw images are not retained by the API.',
      ),
      const SizedBox(height: 16),
      AspectRatio(
        aspectRatio: controller?.value.aspectRatio ?? 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: controller?.value.isInitialized == true
              ? CameraPreview(controller!)
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(Icons.videocam_off, size: 54),
                  ),
                ),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: zone,
        decoration: const InputDecoration(
          labelText: 'Camera zone',
          border: OutlineInputBorder(),
        ),
        items:
            const [
                  'AUTO',
                  'ENTRANCE',
                  'EXIT',
                  'LEFT ROW',
                  'CENTER ROW',
                  'RIGHT ROW',
                  'BACK ROW',
                  'CLASSROOM',
                ]
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
        onChanged: (value) => setState(() => zone = value ?? zone),
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: sending
              ? const CircularProgressIndicator()
              : const Icon(Icons.analytics_outlined),
          title: Text(status),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: controller == null || sending ? null : capture,
              icon: const Icon(Icons.camera),
              label: const Text('Scan now'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: controller == null ? null : toggleContinuous,
              icon: Icon(continuous ? Icons.stop : Icons.play_arrow),
              label: Text(continuous ? 'Stop' : 'Continuous'),
            ),
          ),
        ],
      ),
      TextButton.icon(
        onPressed: () async {
          final image = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
          );
          if (image != null) await scanFile(File(image.path));
        },
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Scan an existing image'),
      ),
    ],
  );
}

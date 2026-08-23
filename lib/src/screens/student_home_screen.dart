import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/edge_models.dart';
import '../services/edge_repository.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    super.key,
    required this.repository,
    required this.profile,
    required this.onEnrollmentChanged,
    required this.onSignOut,
  });

  final EdgeRepository repository;
  final UserProfile profile;
  final VoidCallback onEnrollmentChanged;
  final VoidCallback onSignOut;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  Future<MyAttendance>? attendance;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    if (widget.profile.enrolled) {
      attendance = widget.repository.myAttendance();
      timer = Timer.periodic(const Duration(seconds: 15), (_) => reload());
    }
  }

  void reload() {
    if (mounted && widget.profile.enrolled) {
      setState(() {
        attendance = widget.repository.myAttendance();
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.enrolled) {
      return GuidedFaceEnrollmentScreen(
        repository: widget.repository,
        onComplete: widget.onEnrollmentChanged,
        onSignOut: widget.onSignOut,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('My attendance'),
        actions: [
          IconButton(
            onPressed: widget.onSignOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          reload();
          await attendance;
        },
        child: FutureBuilder<MyAttendance>(
          future: attendance,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 180),
                  Center(child: Text('${snapshot.error}')),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            final student = data.student;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Hello, ${student.name}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(student.rollNumber),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: _statusColor(student.status),
                          child: const Icon(
                            Icons.how_to_reg,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.status,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(student.zone ?? 'No classroom sighting yet'),
                              if (student.lastSeenAt != null)
                                Text(
                                  'Last seen ${DateFormat.yMMMd().add_jm().format(student.lastSeenAt!)}',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => GuidedFaceEnrollmentScreen(
                          repository: widget.repository,
                          existing: student,
                          onComplete: () {
                            Navigator.of(context).pop();
                            reload();
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.face_retouching_natural),
                  label: const Text('Improve my face profile'),
                ),
                const SizedBox(height: 24),
                Text(
                  'My timeline',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (data.events.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No attendance events recorded yet.'),
                    ),
                  ),
                ...data.events.map(
                  (event) => Card(
                    child: ListTile(
                      leading: Icon(_eventIcon(event.type)),
                      title: Text(event.label),
                      subtitle: Text(
                        [
                          DateFormat.yMMMd().add_jm().format(event.timestamp),
                          if (event.zone != null) event.zone!,
                        ].join(' • '),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class GuidedFaceEnrollmentScreen extends StatefulWidget {
  const GuidedFaceEnrollmentScreen({
    super.key,
    required this.repository,
    required this.onComplete,
    this.existing,
    this.onSignOut,
  });

  final EdgeRepository repository;
  final Student? existing;
  final VoidCallback onComplete;
  final VoidCallback? onSignOut;

  @override
  State<GuidedFaceEnrollmentScreen> createState() =>
      _GuidedFaceEnrollmentScreenState();
}

class _GuidedFaceEnrollmentScreenState
    extends State<GuidedFaceEnrollmentScreen> {
  static const poses = ['FRONT', 'LEFT', 'RIGHT', 'UP', 'DOWN'];
  static const prompts = [
    'Look straight at the camera',
    'Turn your head slowly left',
    'Turn your head slowly right',
    'Tilt your chin slightly up',
    'Tilt your chin slightly down',
  ];

  late final TextEditingController name;
  late final TextEditingController roll;
  CameraController? camera;
  final List<File> captures = [];
  bool checking = false;
  bool saving = false;
  bool consent = false;
  String feedback = 'Place your face inside the oval.';

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.existing?.name ?? '');
    roll = TextEditingController(text: widget.existing?.rollNumber ?? '');
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final selected = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final next = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted) return;
      setState(() => camera = next);
    } catch (error) {
      if (mounted) setState(() => feedback = 'Camera unavailable: $error');
    }
  }

  Future<void> capture() async {
    final controller = camera;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        checking ||
        captures.length >= poses.length) {
      return;
    }
    setState(() {
      checking = true;
      feedback = 'Checking lighting, sharpness and head angle...';
    });
    try {
      final photo = await controller.takePicture();
      final file = File(photo.path);
      final result = await widget.repository.checkFace(
        image: file,
        expected: poses[captures.length],
      );
      if (result.accepted) captures.add(file);
      setState(() => feedback = result.message);
    } catch (error) {
      setState(() => feedback = 'Could not check photo: $error');
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> enroll() async {
    if (name.text.trim().isEmpty || roll.text.trim().isEmpty) {
      setState(() => feedback = 'Enter your name and roll number.');
      return;
    }
    if (captures.length != poses.length) {
      setState(() => feedback = 'Complete all five guided photos first.');
      return;
    }
    if (!consent) {
      setState(
        () => feedback = 'Consent is required to create a face profile.',
      );
      return;
    }
    setState(() => saving = true);
    try {
      await widget.repository.selfEnroll(
        name: name.text.trim(),
        rollNumber: roll.text.trim(),
        faceImages: captures,
      );
      widget.onComplete();
    } catch (error) {
      setState(() => feedback = 'Enrollment failed: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    camera?.dispose();
    name.dispose();
    roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complete = captures.length == poses.length;
    final prompt = complete ? 'All photos accepted' : prompts[captures.length];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Set up my profile' : 'Improve profile',
        ),
        actions: [
          if (widget.onSignOut != null)
            IconButton(
              onPressed: widget.onSignOut,
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: roll,
            decoration: const InputDecoration(
              labelText: 'Roll number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: camera?.value.aspectRatio ?? 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (camera?.value.isInitialized == true)
                    CameraPreview(camera!)
                  else
                    const ColoredBox(
                      color: Colors.black,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  Center(
                    child: Container(
                      width: 190,
                      height: 245,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: complete ? Colors.greenAccent : Colors.white,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Card(
                      color: Colors.black.withValues(alpha: .72),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          prompt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: captures.length / poses.length),
          const SizedBox(height: 8),
          Text(
            '${captures.length} of ${poses.length} accepted • $feedback',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: complete || checking ? null : capture,
            icon: checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt),
            label: Text(checking ? 'Checking photo...' : 'Capture this angle'),
          ),
          CheckboxListTile(
            value: consent,
            onChanged: (value) => setState(() => consent = value ?? false),
            contentPadding: EdgeInsets.zero,
            title: const Text('I consent to biometric face enrollment'),
            subtitle: const Text(
              'Photos are processed in memory. Managed face vectors are retained for attendance until deletion is requested.',
            ),
          ),
          FilledButton.icon(
            onPressed: saving ? null : enroll,
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(saving ? 'Saving profile...' : 'Create face profile'),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) => switch (status) {
  'PRESENT' => Colors.green,
  'RETURNED' => Colors.cyan,
  'LEFT' => Colors.orange,
  _ => Colors.redAccent,
};

IconData _eventIcon(String type) => switch (type) {
  'ARRIVED' => Icons.login,
  'RETURNED' => Icons.keyboard_return,
  'LEFT' => Icons.logout,
  'MOVED' => Icons.directions_walk,
  _ => Icons.schedule,
};

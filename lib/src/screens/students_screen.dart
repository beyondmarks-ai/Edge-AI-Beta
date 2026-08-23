import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/edge_models.dart';
import '../services/edge_repository.dart';
import 'timeline_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, required this.repository});
  final EdgeRepository repository;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  late Future<List<Student>> future;

  @override
  void initState() {
    super.initState();
    future = widget.repository.students();
  }

  void reload() => setState(() {
    future = widget.repository.students();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => EnrollmentScreen(repository: widget.repository),
          ),
        );
        if (changed == true) reload();
      },
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('Enroll'),
    ),
    body: FutureBuilder<List<Student>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text('Students', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('${snapshot.data!.length} face profiles'),
            const SizedBox(height: 16),
            ...snapshot.data!.map(
              (student) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TimelineScreen(
                          repository: widget.repository,
                          student: student,
                        ),
                      ),
                    ),
                    leading: CircleAvatar(
                      child: Text(student.name.characters.first),
                    ),
                    title: Text(student.name),
                    subtitle: Text(
                      '${student.rollNumber} • ${student.faceCount} face samples',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({super.key, required this.repository});
  final EdgeRepository repository;

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final id = TextEditingController();
  final name = TextEditingController();
  final roll = TextEditingController();
  final picker = ImagePicker();
  List<XFile> images = [];
  bool saving = false;
  String? error;

  @override
  void dispose() {
    id.dispose();
    name.dispose();
    roll.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    final selected = await picker.pickMultiImage(
      imageQuality: 75,
      maxWidth: 720,
      maxHeight: 720,
      limit: 10,
    );
    setState(() => images = selected);
  }

  Future<void> save() async {
    if (id.text.trim().isEmpty ||
        name.text.trim().isEmpty ||
        images.length < 5) {
      setState(
        () => error =
            'Enter student details and select at least 5 clear face images.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.enroll(
        id: id.text.trim(),
        name: name.text.trim(),
        rollNumber: roll.text.trim(),
        faceImages: images.map((item) => File(item.path)).toList(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Enroll student')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Add 5–10 images: front, left, right, looking slightly up and down.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: id,
          decoration: const InputDecoration(
            labelText: 'Student ID',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: name,
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
        OutlinedButton.icon(
          onPressed: pickImages,
          icon: const Icon(Icons.add_a_photo),
          label: Text(
            images.isEmpty
                ? 'Choose face images'
                : '${images.length} images selected',
          ),
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(images[index].path),
                  width: 72,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: const Icon(Icons.face_retouching_natural),
          label: Text(
            saving ? 'Creating face profile…' : 'Create face profile',
          ),
        ),
      ],
    ),
  );
}

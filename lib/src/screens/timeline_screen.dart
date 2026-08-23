import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/edge_models.dart';
import '../services/edge_repository.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({
    super.key,
    required this.repository,
    required this.student,
  });
  final EdgeRepository repository;
  final Student student;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(student.name)),
    body: FutureBuilder<List<TimelineEvent>>(
      future: repository.timeline(student.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final event = snapshot.data![index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(_icon(event.type))),
                title: Text(event.label),
                subtitle: Text(
                  [
                    DateFormat('dd MMM, hh:mm:ss a').format(event.timestamp),
                    if (event.zone != null) event.zone!,
                    if (event.similarity != null)
                      '${event.similarity!.toStringAsFixed(1)}% match',
                  ].join(' • '),
                ),
              ),
            );
          },
        );
      },
    ),
  );

  IconData _icon(String type) => switch (type) {
    'ARRIVED' => Icons.login,
    'LEFT' => Icons.logout,
    'RETURNED' => Icons.keyboard_return,
    'MOVED' => Icons.directions_walk,
    _ => Icons.visibility,
  };
}

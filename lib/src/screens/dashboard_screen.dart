import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/edge_models.dart';
import '../services/edge_repository.dart';
import 'timeline_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.sessionId,
    this.lastDetected,
  });
  final EdgeRepository repository;
  final String sessionId;
  final Student? lastDetected;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> future;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    future = widget.repository.dashboard(widget.sessionId);
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {
          future = widget.repository.dashboard(widget.sessionId);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastDetected?.id != widget.lastDetected?.id ||
        oldWidget.sessionId != widget.sessionId) {
      setState(() {
        future = widget.repository.dashboard(widget.sessionId);
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    setState(() {
      future = widget.repository.dashboard(widget.sessionId);
    });
    await future;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: reload,
    child: FutureBuilder<DashboardData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            children: [
              const SizedBox(height: 180),
              Center(
                child: Text('Could not load dashboard: ${snapshot.error}'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Live classroom',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Session ${data.sessionId} • ${DateFormat.jm().format(DateTime.now())}',
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                _Metric(
                  label: 'Present',
                  value: data.present,
                  color: Colors.green,
                ),
                _Metric(
                  label: 'Absent',
                  value: data.absent,
                  color: Colors.redAccent,
                ),
                _Metric(label: 'Left', value: data.left, color: Colors.orange),
                _Metric(
                  label: 'Returned',
                  value: data.returned,
                  color: Colors.cyan,
                ),
              ],
            ),
            if (widget.lastDetected != null) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_search)),
                  title: Text('${widget.lastDetected!.name} detected'),
                  subtitle: Text(
                    widget.lastDetected!.zone ?? 'Current classroom',
                  ),
                  trailing: const Icon(Icons.bolt, color: Colors.amber),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Student locations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            ...data.students.map(
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
                      [
                        student.rollNumber,
                        if (student.zone != null) student.zone!,
                        if (student.lastSeenAt != null)
                          'seen ${DateFormat.jm().format(student.lastSeenAt!)}',
                      ].join(' • '),
                    ),
                    trailing: _Status(status: student.status),
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

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'PRESENT' => Colors.green,
      'RETURNED' => Colors.cyan,
      'LEFT' => Colors.orange,
      'ABSENT' => Colors.redAccent,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(status),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: .12),
    );
  }
}

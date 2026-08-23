import 'package:flutter/material.dart';

import 'config/edge_ai_config.dart';
import 'models/edge_models.dart';
import 'screens/assistant_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/rtsp_scanner_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/students_screen.dart';
import 'screens/student_home_screen.dart';
import 'services/auth_service.dart';
import 'services/edge_repository.dart';

class EdgeAiApp extends StatefulWidget {
  const EdgeAiApp({super.key, required this.config, required this.auth});
  final EdgeAiConfig config;
  final AuthService auth;

  @override
  State<EdgeAiApp> createState() => _EdgeAiAppState();
}

class _EdgeAiAppState extends State<EdgeAiApp> {
  bool? _signedIn;
  late final EdgeRepository _repository;
  Future<UserProfile>? _profile;

  @override
  void initState() {
    super.initState();
    _repository = widget.config.cloudConfigured
        ? CloudEdgeRepository(widget.config, widget.auth)
        : DemoEdgeRepository();
    widget.auth.isSignedIn().then((value) {
      if (mounted) {
        setState(() {
          _signedIn = value;
          if (value) _profile = _repository.me();
        });
      }
    });
  }

  void signedIn() => setState(() {
    _signedIn = true;
    _profile = _repository.me();
  });

  Future<void> signOut() async {
    await widget.auth.signOut();
    setState(() {
      _signedIn = false;
      _profile = null;
    });
  }

  void refreshProfile() => setState(() {
    _profile = _repository.me();
  });

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B5FEF),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Edge AI',
      theme: ThemeData(
        colorScheme: colors,
        scaffoldBackgroundColor: const Color(0xFF0C1020),
        cardTheme: const CardThemeData(
          color: Color(0xFF151B2F),
          margin: EdgeInsets.zero,
        ),
        useMaterial3: true,
      ),
      home: _signedIn == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : !_signedIn!
          ? LoginScreen(auth: widget.auth, onSignedIn: signedIn)
          : FutureBuilder<UserProfile>(
              future: _profile,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Text('Could not load account: ${snapshot.error}'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return snapshot.data!.isAdmin
                    ? EdgeShell(
                        repository: _repository,
                        demoMode: !widget.config.cloudConfigured,
                        onSignOut: widget.config.cloudConfigured
                            ? signOut
                            : null,
                      )
                    : StudentHomeScreen(
                        repository: _repository,
                        profile: snapshot.data!,
                        onEnrollmentChanged: refreshProfile,
                        onSignOut: signOut,
                      );
              },
            ),
    );
  }
}

class EdgeShell extends StatefulWidget {
  const EdgeShell({
    super.key,
    required this.repository,
    required this.demoMode,
    this.onSignOut,
  });
  final EdgeRepository repository;
  final bool demoMode;
  final VoidCallback? onSignOut;

  @override
  State<EdgeShell> createState() => _EdgeShellState();
}

class _EdgeShellState extends State<EdgeShell> {
  int _index = 0;
  final sessionId = 'current';
  Student? lastDetected;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        repository: widget.repository,
        sessionId: sessionId,
        lastDetected: lastDetected,
      ),
      StudentsScreen(repository: widget.repository),
      ScannerScreen(
        repository: widget.repository,
        sessionId: sessionId,
        onDetected: (student) => setState(() {
          lastDetected = student;
          _index = 0;
        }),
      ),
      RtspScannerScreen(
        repository: widget.repository,
        sessionId: sessionId,
        onDetected: (student) => setState(() {
          lastDetected = student;
        }),
      ),
      AssistantScreen(repository: widget.repository, sessionId: sessionId),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/branding/edge_ai_logo.png',
              width: 36,
              height: 36,
              semanticLabel: 'Edge AI logo',
            ),
            const SizedBox(width: 10),
            const Text('Edge AI'),
          ],
        ),
        actions: [
          if (widget.demoMode)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Chip(label: Text('DEMO')),
            ),
          if (widget.onSignOut != null)
            IconButton(
              onPressed: widget.onSignOut,
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.center_focus_strong_outlined),
            selectedIcon: Icon(Icons.center_focus_strong),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'RTSP',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),
        ],
      ),
    );
  }
}

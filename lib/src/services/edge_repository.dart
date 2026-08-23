import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/edge_ai_config.dart';
import '../models/edge_models.dart';
import 'auth_service.dart';

abstract interface class EdgeRepository {
  Future<UserProfile> me();
  Future<MyAttendance> myAttendance();
  Future<FaceCheckResult> checkFace({
    required File image,
    required String expected,
  });
  Future<Student> selfEnroll({
    required String name,
    required String rollNumber,
    required List<File> faceImages,
  });
  Future<List<Student>> students();
  Future<Student> enroll({
    required String id,
    required String name,
    required String rollNumber,
    required List<File> faceImages,
  });
  Future<DashboardData> dashboard(String sessionId);
  Future<List<TimelineEvent>> timeline(String studentId);
  Future<ScanResult> scanFrame({
    required File image,
    required String sessionId,
    required String cameraId,
    required String zone,
  });
  Future<AssistantReply> askAssistant(
    String question, {
    String? sessionId,
    String? conversationId,
    String? documentId,
  });
  Future<List<AssistantConversation>> assistantChats();
  Future<List<AssistantMessage>> assistantChat(String conversationId);
  Future<List<RagDocument>> documents();
  Future<RagDocument> uploadDocument(File file, String fileName);
}

class CloudEdgeRepository implements EdgeRepository {
  CloudEdgeRepository(this.config, this.auth);
  final EdgeAiConfig config;
  final AuthService auth;

  Uri _uri(String path) => Uri.parse('${config.apiBaseUrl}$path');

  Future<Map<String, String>> _headers() async {
    final token = await auth.accessToken();
    return {
      'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };
  }

  Future<List<String>> _encodeImages(List<File> files) async {
    final images = <String>[];
    for (final file in files) {
      images.add(base64Encode(await file.readAsBytes()));
    }
    return images;
  }

  @override
  Future<UserProfile> me() async => UserProfile.fromJson(
    await _request('GET', '/me') as Map<String, dynamic>,
  );

  @override
  Future<MyAttendance> myAttendance() async => MyAttendance.fromJson(
    await _request('GET', '/me/attendance') as Map<String, dynamic>,
  );

  @override
  Future<FaceCheckResult> checkFace({
    required File image,
    required String expected,
  }) async => FaceCheckResult.fromJson(
    await _request(
          'POST',
          '/me/face-check',
          body: {
            'expected': expected,
            'image': base64Encode(await image.readAsBytes()),
          },
        )
        as Map<String, dynamic>,
  );

  @override
  Future<Student> selfEnroll({
    required String name,
    required String rollNumber,
    required List<File> faceImages,
  }) async => Student.fromJson(
    await _request(
          'POST',
          '/me/enroll',
          body: {
            'name': name,
            'rollNumber': rollNumber,
            'images': await _encodeImages(faceImages),
          },
        )
        as Map<String, dynamic>,
  );

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _headers();
    final encoded = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await http.get(_uri(path), headers: headers),
      'POST' => await http.post(_uri(path), headers: headers, body: encoded),
      _ => throw ArgumentError('Unsupported HTTP method $method'),
    };
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message'] : response.body;
      throw Exception(message ?? 'Request failed (${response.statusCode})');
    }
    return decoded;
  }

  @override
  Future<List<Student>> students() async {
    final json = await _request('GET', '/students') as Map<String, dynamic>;
    return (json['items'] as List)
        .map((item) => Student.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<Student> enroll({
    required String id,
    required String name,
    required String rollNumber,
    required List<File> faceImages,
  }) async {
    final images = await _encodeImages(faceImages);
    final json =
        await _request(
              'POST',
              '/students/enroll',
              body: {
                'studentId': id,
                'name': name,
                'rollNumber': rollNumber,
                'images': images,
              },
            )
            as Map<String, dynamic>;
    return Student.fromJson(json);
  }

  @override
  Future<DashboardData> dashboard(String sessionId) async =>
      DashboardData.fromJson(
        await _request('GET', '/sessions/$sessionId/dashboard')
            as Map<String, dynamic>,
      );

  @override
  Future<List<TimelineEvent>> timeline(String studentId) async {
    final json =
        await _request('GET', '/students/$studentId/timeline')
            as Map<String, dynamic>;
    return (json['items'] as List)
        .map((item) => TimelineEvent.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<ScanResult> scanFrame({
    required File image,
    required String sessionId,
    required String cameraId,
    required String zone,
  }) async {
    final json =
        await _request(
              'POST',
              '/frames/scan',
              body: {
                'sessionId': sessionId,
                'cameraId': cameraId,
                'zone': zone,
                'capturedAt': DateTime.now().toUtc().toIso8601String(),
                'image': base64Encode(await image.readAsBytes()),
              },
            )
            as Map<String, dynamic>;
    return ScanResult.fromJson(json);
  }

  @override
  Future<AssistantReply> askAssistant(
    String question, {
    String? sessionId,
    String? conversationId,
    String? documentId,
  }) async {
    final json =
        await _request(
              'POST',
              '/assistant',
              body: {
                'question': question,
                'sessionId': ?sessionId,
                'conversationId': ?conversationId,
                'documentId': documentId,
              },
            )
            as Map<String, dynamic>;
    return AssistantReply.fromJson(json);
  }

  @override
  Future<List<AssistantConversation>> assistantChats() async {
    final json =
        await _request('GET', '/assistant/chats') as Map<String, dynamic>;
    return ((json['items'] as List?) ?? const [])
        .map(
          (item) => AssistantConversation.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  @override
  Future<List<AssistantMessage>> assistantChat(String conversationId) async {
    final json =
        await _request(
              'GET',
              '/assistant/chats/${Uri.encodeComponent(conversationId)}',
            )
            as Map<String, dynamic>;
    return ((json['messages'] as List?) ?? const [])
        .map(
          (item) =>
              AssistantMessage.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<List<RagDocument>> documents() async {
    final json = await _request('GET', '/documents') as Map<String, dynamic>;
    return ((json['items'] as List?) ?? const [])
        .map(
          (item) =>
              RagDocument.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<RagDocument> uploadDocument(File file, String fileName) async {
    final size = await file.length();
    final upload =
        await _request(
              'POST',
              '/documents/upload',
              body: {'fileName': fileName, 'sizeBytes': size},
            )
            as Map<String, dynamic>;
    final uploadResponse = await http.put(
      Uri.parse(upload['uploadUrl'] as String),
      headers: const {'content-type': 'application/pdf'},
      body: await file.readAsBytes(),
    );
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw Exception(
        'Secure PDF upload failed (${uploadResponse.statusCode}).',
      );
    }
    final documentId = upload['documentId'] as String;
    final json =
        await _request('POST', '/documents/$documentId/ingest')
            as Map<String, dynamic>;
    return RagDocument.fromJson(json);
  }
}

class DemoEdgeRepository implements EdgeRepository {
  final Map<String, List<AssistantMessage>> _assistantMessages = {};
  final Map<String, AssistantConversation> _assistantConversations = {};
  final List<Student> _students = [
    Student(
      id: '3GN23AI058',
      name: 'Vachanashree',
      rollNumber: '3GN23AI058',
      faceCount: 5,
      status: 'PRESENT',
      lastSeenAt: DateTime.now().subtract(const Duration(seconds: 20)),
      zone: 'LEFT ROW',
    ),
    Student(
      id: '3GN23AI045',
      name: 'Sanchita',
      rollNumber: '3GN23AI045',
      faceCount: 5,
      status: 'RETURNED',
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 2)),
      zone: 'CENTER ROW',
    ),
    const Student(
      id: '3GN23AI061',
      name: 'Vaishnavi',
      rollNumber: '3GN23AI061',
      faceCount: 5,
      status: 'ABSENT',
    ),
  ];

  @override
  Future<UserProfile> me() async =>
      const UserProfile(role: 'ADMIN', enrolled: true);

  @override
  Future<MyAttendance> myAttendance() async => MyAttendance(
    student: _students.first,
    events: await timeline(_students.first.id),
  );

  @override
  Future<FaceCheckResult> checkFace({
    required File image,
    required String expected,
  }) async => FaceCheckResult(
    accepted: true,
    message: 'Perfect ${expected.toLowerCase()} photo.',
  );

  @override
  Future<Student> selfEnroll({
    required String name,
    required String rollNumber,
    required List<File> faceImages,
  }) async => enroll(
    id: rollNumber,
    name: name,
    rollNumber: rollNumber,
    faceImages: faceImages,
  );

  @override
  Future<List<Student>> students() async => List.unmodifiable(_students);

  @override
  Future<Student> enroll({
    required String id,
    required String name,
    required String rollNumber,
    required List<File> faceImages,
  }) async {
    final student = Student(
      id: id,
      name: name,
      rollNumber: rollNumber,
      faceCount: faceImages.length,
    );
    _students.add(student);
    return student;
  }

  @override
  Future<DashboardData> dashboard(String sessionId) async => DashboardData(
    sessionId: sessionId,
    present: _students.where((s) => s.status == 'PRESENT').length,
    absent: _students.where((s) => s.status == 'ABSENT').length,
    left: _students.where((s) => s.status == 'LEFT').length,
    returned: _students.where((s) => s.status == 'RETURNED').length,
    students: List.unmodifiable(_students),
  );

  @override
  Future<List<TimelineEvent>> timeline(String studentId) async => [
    TimelineEvent(
      type: 'ARRIVED',
      timestamp: DateTime.now().subtract(const Duration(minutes: 52)),
      label: 'Attendance marked present',
      zone: 'ENTRANCE',
      similarity: 98.4,
    ),
    TimelineEvent(
      type: 'MOVED',
      timestamp: DateTime.now().subtract(const Duration(minutes: 35)),
      label: 'Moved to left row',
      zone: 'LEFT ROW',
    ),
    TimelineEvent(
      type: 'RETURNED',
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      label: 'Returned to classroom',
      zone: 'ENTRANCE',
      similarity: 97.9,
    ),
  ];

  @override
  Future<ScanResult> scanFrame({
    required File image,
    required String sessionId,
    required String cameraId,
    required String zone,
  }) async => ScanResult(detected: [_students.first], unknownFaces: 0);

  @override
  Future<AssistantReply> askAssistant(
    String question, {
    String? sessionId,
    String? conversationId,
    String? documentId,
  }) async {
    final id =
        conversationId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    const answer =
        'Demo response: 2 students are currently present. Sanchita returned after leaving briefly. Connect AWS and Google Cloud to answer from live data.';
    _assistantMessages.putIfAbsent(id, () => []).addAll([
      AssistantMessage(role: 'USER', text: question, timestamp: now),
      AssistantMessage(role: 'ASSISTANT', text: answer, timestamp: now),
    ]);
    final existing = _assistantConversations[id];
    _assistantConversations[id] = AssistantConversation(
      id: id,
      title:
          existing?.title ??
          question.substring(0, question.length.clamp(0, 60)),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    return AssistantReply(answer: answer, conversationId: id);
  }

  @override
  Future<List<AssistantConversation>> assistantChats() async {
    final chats = _assistantConversations.values.toList();
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return chats;
  }

  @override
  Future<List<AssistantMessage>> assistantChat(String conversationId) async =>
      List.unmodifiable(_assistantMessages[conversationId] ?? const []);

  @override
  Future<List<RagDocument>> documents() async => const [];

  @override
  Future<RagDocument> uploadDocument(File file, String fileName) async =>
      RagDocument(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        fileName: fileName,
        status: 'READY',
        updatedAt: DateTime.now(),
        pageCount: 1,
        chunkCount: 1,
      );
}

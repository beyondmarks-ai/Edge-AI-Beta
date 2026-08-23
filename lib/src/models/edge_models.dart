class Student {
  const Student({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.faceCount,
    this.status = 'UNKNOWN',
    this.lastSeenAt,
    this.zone,
  });

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['studentId'] as String,
    name: json['name'] as String? ?? 'Unknown',
    rollNumber: json['rollNumber'] as String? ?? '',
    faceCount: (json['faceCount'] as num?)?.toInt() ?? 0,
    status: json['status'] as String? ?? 'UNKNOWN',
    lastSeenAt: _date(json['lastSeenAt']),
    zone: json['zone'] as String?,
  );

  final String id;
  final String name;
  final String rollNumber;
  final int faceCount;
  final String status;
  final DateTime? lastSeenAt;
  final String? zone;
}

class TimelineEvent {
  const TimelineEvent({
    required this.type,
    required this.timestamp,
    required this.label,
    this.zone,
    this.similarity,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
    type: json['eventType'] as String? ?? 'SIGHTING',
    timestamp: _date(json['timestamp']) ?? DateTime.now(),
    label: json['label'] as String? ?? json['eventType'] as String? ?? '',
    zone: json['zone'] as String?,
    similarity: (json['similarity'] as num?)?.toDouble(),
  );

  final String type;
  final DateTime timestamp;
  final String label;
  final String? zone;
  final double? similarity;
}

class DashboardData {
  const DashboardData({
    required this.sessionId,
    required this.present,
    required this.absent,
    required this.left,
    required this.returned,
    required this.students,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
    sessionId: json['sessionId'] as String? ?? 'current',
    present: (json['present'] as num?)?.toInt() ?? 0,
    absent: (json['absent'] as num?)?.toInt() ?? 0,
    left: (json['left'] as num?)?.toInt() ?? 0,
    returned: (json['returned'] as num?)?.toInt() ?? 0,
    students: ((json['students'] as List?) ?? const [])
        .map((item) => Student.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
  );

  final String sessionId;
  final int present;
  final int absent;
  final int left;
  final int returned;
  final List<Student> students;
}

class ScanResult {
  const ScanResult({
    required this.detected,
    required this.unknownFaces,
    this.observations = const [],
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
    detected: ((json['detected'] as List?) ?? const [])
        .map((item) => Student.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    unknownFaces: (json['unknownFaces'] as num?)?.toInt() ?? 0,
    observations: ((json['observations'] as List?) ?? const [])
        .map(
          (item) => VisualObservation.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
  );

  final List<Student> detected;
  final int unknownFaces;
  final List<VisualObservation> observations;
}

class VisualObservation {
  const VisualObservation({
    required this.studentId,
    required this.clothing,
    required this.carriedObjects,
    required this.posture,
    required this.scenePosition,
    required this.summary,
  });

  factory VisualObservation.fromJson(Map<String, dynamic> json) =>
      VisualObservation(
        studentId: json['studentId'] as String? ?? '',
        clothing: ((json['clothing'] as List?) ?? const [])
            .map((item) => '$item')
            .toList(),
        carriedObjects: ((json['carriedObjects'] as List?) ?? const [])
            .map((item) => '$item')
            .toList(),
        posture: json['posture'] as String? ?? 'unknown',
        scenePosition: json['scenePosition'] as String? ?? 'not visible',
        summary: json['summary'] as String? ?? 'Visual context recorded.',
      );

  final String studentId;
  final List<String> clothing;
  final List<String> carriedObjects;
  final String posture;
  final String scenePosition;
  final String summary;
}

class UserProfile {
  const UserProfile({required this.role, required this.enrolled, this.student});

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    role: json['role'] as String? ?? 'STUDENT',
    enrolled: json['enrolled'] as bool? ?? false,
    student: json['student'] is Map
        ? Student.fromJson(Map<String, dynamic>.from(json['student'] as Map))
        : null,
  );

  final String role;
  final bool enrolled;
  final Student? student;
  bool get isAdmin => role == 'ADMIN';
}

class MyAttendance {
  const MyAttendance({required this.student, required this.events});

  factory MyAttendance.fromJson(Map<String, dynamic> json) => MyAttendance(
    student: Student.fromJson(
      Map<String, dynamic>.from(json['student'] as Map),
    ),
    events: ((json['items'] as List?) ?? const [])
        .map((item) => TimelineEvent.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
  );

  final Student student;
  final List<TimelineEvent> events;
}

class FaceCheckResult {
  const FaceCheckResult({
    required this.accepted,
    required this.message,
    this.yaw,
    this.pitch,
    this.brightness,
    this.sharpness,
  });

  factory FaceCheckResult.fromJson(Map<String, dynamic> json) =>
      FaceCheckResult(
        accepted: json['accepted'] as bool? ?? false,
        message: json['message'] as String? ?? 'Try again.',
        yaw: (json['yaw'] as num?)?.toDouble(),
        pitch: (json['pitch'] as num?)?.toDouble(),
        brightness: (json['brightness'] as num?)?.toDouble(),
        sharpness: (json['sharpness'] as num?)?.toDouble(),
      );

  final bool accepted;
  final String message;
  final double? yaw;
  final double? pitch;
  final double? brightness;
  final double? sharpness;
}

class AssistantReply {
  const AssistantReply({
    required this.answer,
    required this.conversationId,
    this.sources = const [],
  });

  factory AssistantReply.fromJson(Map<String, dynamic> json) => AssistantReply(
    answer: json['answer'] as String? ?? '',
    conversationId: json['conversationId'] as String? ?? '',
    sources: ((json['sources'] as List?) ?? const [])
        .map(
          (item) =>
              AssistantSource.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );

  final String answer;
  final String conversationId;
  final List<AssistantSource> sources;
}

class AssistantSource {
  const AssistantSource({
    required this.fileName,
    required this.page,
    required this.score,
  });

  factory AssistantSource.fromJson(Map<String, dynamic> json) =>
      AssistantSource(
        fileName: json['fileName'] as String? ?? 'PDF',
        page: (json['page'] as num?)?.toInt() ?? 1,
        score: (json['score'] as num?)?.toDouble() ?? 0,
      );

  final String fileName;
  final int page;
  final double score;
}

class RagDocument {
  const RagDocument({
    required this.id,
    required this.fileName,
    required this.status,
    required this.updatedAt,
    this.pageCount,
    this.chunkCount,
    this.error,
  });

  factory RagDocument.fromJson(Map<String, dynamic> json) => RagDocument(
    id: json['documentId'] as String? ?? '',
    fileName: json['fileName'] as String? ?? 'document.pdf',
    status: json['status'] as String? ?? 'PROCESSING',
    updatedAt: _date(json['updatedAt']) ?? DateTime.now(),
    pageCount: (json['pageCount'] as num?)?.toInt(),
    chunkCount: (json['chunkCount'] as num?)?.toInt(),
    error: json['error'] as String?,
  );

  final String id;
  final String fileName;
  final String status;
  final DateTime updatedAt;
  final int? pageCount;
  final int? chunkCount;
  final String? error;
  bool get isReady => status == 'READY';
}

class AssistantConversation {
  const AssistantConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.documentId,
  });

  factory AssistantConversation.fromJson(Map<String, dynamic> json) =>
      AssistantConversation(
        id: json['conversationId'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled chat',
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
        updatedAt: _date(json['updatedAt']) ?? DateTime.now(),
        documentId: json['documentId'] as String?,
      );

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? documentId;
}

class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  factory AssistantMessage.fromJson(Map<String, dynamic> json) =>
      AssistantMessage(
        role: json['role'] as String? ?? 'ASSISTANT',
        text: json['text'] as String? ?? '',
        timestamp: _date(json['timestamp']) ?? DateTime.now(),
      );

  final String role;
  final String text;
  final DateTime timestamp;
  bool get isUser => role == 'USER';
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

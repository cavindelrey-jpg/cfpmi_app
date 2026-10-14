// lib/models/classroom.dart
// Academia Classroom models — a live/prepared lesson (ClassroomSession) and
// its attached files (ClassroomResource). Backed by public.classroom_sessions
// / public.classroom_resources (see
// supabase/migrations/20261014140000_academia_classroom.sql).

enum ClassroomStatus { prepared, live, ended }

extension ClassroomStatusX on ClassroomStatus {
  String get wire => name;
  static ClassroomStatus fromWire(String? s) => switch (s) {
        'live' => ClassroomStatus.live,
        'ended' => ClassroomStatus.ended,
        _ => ClassroomStatus.prepared,
      };
}

/// Visibility of a classroom resource to STUDENTS (section 9 of the spec).
enum ResourceVisibility { teacherOnly, hidden, released, afterClass }

extension ResourceVisibilityX on ResourceVisibility {
  String get wire => switch (this) {
        ResourceVisibility.teacherOnly => 'teacher_only',
        ResourceVisibility.hidden => 'hidden',
        ResourceVisibility.released => 'released',
        ResourceVisibility.afterClass => 'after_class',
      };
  String get label => switch (this) {
        ResourceVisibility.teacherOnly => 'Teacher only',
        ResourceVisibility.hidden => 'Hidden',
        ResourceVisibility.released => 'Released',
        ResourceVisibility.afterClass => 'After class',
      };
  static ResourceVisibility fromWire(String? s) => switch (s) {
        'teacher_only' => ResourceVisibility.teacherOnly,
        'released' => ResourceVisibility.released,
        'after_class' => ResourceVisibility.afterClass,
        _ => ResourceVisibility.hidden,
      };
}

class ClassroomSession {
  final String id;
  final String schoolId;
  final String classLevel;
  final String subject;
  final String topic;
  final String teacherId;
  final String teacherName;
  final ClassroomStatus status;
  final int currentSlide;
  final List<String> slideUrls;
  final String? originalFile;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const ClassroomSession({
    required this.id,
    required this.schoolId,
    required this.classLevel,
    this.subject = '',
    this.topic = '',
    this.teacherId = '',
    this.teacherName = '',
    this.status = ClassroomStatus.prepared,
    this.currentSlide = 0,
    this.slideUrls = const [],
    this.originalFile,
    this.startedAt,
    this.endedAt,
  });

  int get slideCount => slideUrls.length;
  bool get isLive => status == ClassroomStatus.live;
  String? get currentSlideUrl =>
      (slideUrls.isNotEmpty && currentSlide >= 0 && currentSlide < slideUrls.length)
          ? slideUrls[currentSlide]
          : null;

  factory ClassroomSession.fromMap(Map<String, dynamic> m) {
    final raw = m['slide_urls'];
    final slides = <String>[];
    if (raw is List) {
      slides.addAll(raw.map((e) => e.toString()));
    }
    return ClassroomSession(
      id: m['id']?.toString() ?? '',
      schoolId: m['school_id']?.toString() ?? '',
      classLevel: m['class_level']?.toString() ?? '',
      subject: m['subject']?.toString() ?? '',
      topic: m['topic']?.toString() ?? '',
      teacherId: m['teacher_id']?.toString() ?? '',
      teacherName: m['teacher_name']?.toString() ?? '',
      status: ClassroomStatusX.fromWire(m['status']?.toString()),
      currentSlide: (m['current_slide'] as num?)?.toInt() ?? 0,
      slideUrls: slides,
      originalFile: m['original_file']?.toString(),
      startedAt: m['started_at'] != null ? DateTime.tryParse(m['started_at'].toString()) : null,
      endedAt: m['ended_at'] != null ? DateTime.tryParse(m['ended_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'school_id': schoolId,
        'class_level': classLevel,
        'subject': subject,
        'topic': topic,
        'teacher_id': teacherId,
        'teacher_name': teacherName,
        'status': status.wire,
        'current_slide': currentSlide,
        'slide_urls': slideUrls,
        'original_file': originalFile,
      };
}

class ClassroomResource {
  final String id;
  final String sessionId;
  final String schoolId;
  final String title;
  final String kind; // document|image|pdf|video|pptx|link
  final String url;
  final ResourceVisibility visibility;
  final int position;

  const ClassroomResource({
    required this.id,
    required this.sessionId,
    required this.schoolId,
    this.title = '',
    this.kind = 'document',
    this.url = '',
    this.visibility = ResourceVisibility.hidden,
    this.position = 0,
  });

  factory ClassroomResource.fromMap(Map<String, dynamic> m) => ClassroomResource(
        id: m['id']?.toString() ?? '',
        sessionId: m['session_id']?.toString() ?? '',
        schoolId: m['school_id']?.toString() ?? '',
        title: m['title']?.toString() ?? '',
        kind: m['kind']?.toString() ?? 'document',
        url: m['url']?.toString() ?? '',
        visibility: ResourceVisibilityX.fromWire(m['visibility']?.toString()),
        position: (m['position'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toInsertMap() => {
        'session_id': sessionId,
        'school_id': schoolId,
        'title': title,
        'kind': kind,
        'url': url,
        'visibility': visibility.wire,
        'position': position,
      };
}

// lib/models/school_class.dart
// Configurable school-specific class model supporting arbitrary class naming schemes
// (e.g., Upper C, Lower C, 1A, Technical Year 1, Form 1–5, Lower/Upper Sixth).

class SchoolClass {
  final String id;
  final String schoolId;
  final String name;
  final String? code;
  final String? programme;
  final String? academicYear;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SchoolClass({
    required this.id,
    required this.schoolId,
    required this.name,
    this.code,
    this.programme,
    this.academicYear,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SchoolClass.fromMap(Map<String, dynamic> map) {
    return SchoolClass(
      id: map['id']?.toString() ?? '',
      schoolId: map['school_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString(),
      programme: map['programme']?.toString(),
      academicYear: map['academic_year']?.toString(),
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] == null ? true : (map['is_active'] as bool),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school_id': schoolId,
      'name': name,
      if (code != null) 'code': code,
      if (programme != null) 'programme': programme,
      if (academicYear != null) 'academic_year': academicYear,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SchoolClass copyWith({
    String? id,
    String? schoolId,
    String? name,
    String? code,
    String? programme,
    String? academicYear,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SchoolClass(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      code: code ?? this.code,
      programme: programme ?? this.programme,
      academicYear: academicYear ?? this.academicYear,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

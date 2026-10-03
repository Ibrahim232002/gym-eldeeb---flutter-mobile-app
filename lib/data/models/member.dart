/// Member model reflecting the public.members Supabase table
class Member {
  final String id;
  final String gymId;
  final String fullName;
  final String? phone;
  final String? notes;
  final DateTime joinDate;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;
  final String? legacyRef;

  const Member({
    required this.id,
    required this.gymId,
    required this.fullName,
    this.phone,
    this.notes,
    required this.joinDate,
    this.isActive = true,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncVersion = 1,
    this.legacyRef,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      gymId: json['gym_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
      joinDate: json['join_date'] != null
          ? DateTime.parse(json['join_date'] as String)
          : DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
      syncVersion: json['sync_version'] as int? ?? 1,
      legacyRef: json['legacy_ref'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_id': gymId,
      'full_name': fullName,
      'phone': phone,
      'notes': notes,
      'join_date': joinDate.toIso8601String().substring(0, 10),
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_version': syncVersion,
      'legacy_ref': legacyRef,
    };
  }

  Member copyWith({
    String? id,
    String? gymId,
    String? fullName,
    String? phone,
    String? notes,
    DateTime? joinDate,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? syncVersion,
    String? legacyRef,
  }) {
    return Member(
      id: id ?? this.id,
      gymId: gymId ?? this.gymId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      joinDate: joinDate ?? this.joinDate,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      legacyRef: legacyRef ?? this.legacyRef,
    );
  }
}

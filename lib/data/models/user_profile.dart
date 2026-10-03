/// User profile entity reflecting the public.profiles Supabase table
class UserProfile {
  final String id;
  final String? gymId;
  final String fullName;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    this.gymId,
    required this.fullName,
    this.role = 'coach',
    this.createdAt,
    this.updatedAt,
  });

  /// Check if user has owner privileges
  bool get isOwner => role.toLowerCase() == 'owner';

  /// Check if user is associated with a gym
  bool get hasGym => gymId != null && gymId!.isNotEmpty;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      gymId: json['gym_id'] as String?,
      fullName: (json['full_name'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'coach',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_id': gymId,
      'full_name': fullName,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? gymId,
    String? fullName,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      gymId: gymId ?? this.gymId,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

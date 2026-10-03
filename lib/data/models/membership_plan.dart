/// MembershipPlan model reflecting the public.membership_plans Supabase table
class MembershipPlan {
  final String id;
  final String gymId;
  final String name;
  final int durationDays;
  final double price;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;

  const MembershipPlan({
    required this.id,
    required this.gymId,
    required this.name,
    this.durationDays = 30,
    this.price = 0.0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncVersion = 1,
  });

  factory MembershipPlan.fromJson(Map<String, dynamic> json) {
    return MembershipPlan(
      id: json['id'] as String,
      gymId: json['gym_id'] as String,
      name: json['name'] as String? ?? '',
      durationDays: json['duration_days'] as int? ?? 30,
      price: (json['price'] as num? ?? 0.0).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_id': gymId,
      'name': name,
      'duration_days': durationDays,
      'price': price,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_version': syncVersion,
    };
  }

  MembershipPlan copyWith({
    String? id,
    String? gymId,
    String? name,
    int? durationDays,
    double? price,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? syncVersion,
  }) {
    return MembershipPlan(
      id: id ?? this.id,
      gymId: gymId ?? this.gymId,
      name: name ?? this.name,
      durationDays: durationDays ?? this.durationDays,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }
}

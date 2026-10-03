/// Membership model reflecting the public.memberships Supabase table
class Membership {
  final String id;
  final String gymId;
  final String memberId;
  final String? planId;
  final DateTime startDate;
  final DateTime endDate;
  final double price;
  final String status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;

  const Membership({
    required this.id,
    required this.gymId,
    required this.memberId,
    this.planId,
    required this.startDate,
    required this.endDate,
    this.price = 0.0,
    this.status = 'active',
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncVersion = 1,
  });

  bool get isExpired {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return endDate.isBefore(today);
  }

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: json['id'] as String,
      gymId: json['gym_id'] as String,
      memberId: json['member_id'] as String,
      planId: json['plan_id'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : DateTime.now(),
      price: (json['price'] as num? ?? 0.0).toDouble(),
      status: json['status'] as String? ?? 'active',
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_id': gymId,
      'member_id': memberId,
      'plan_id': planId,
      'start_date': startDate.toIso8601String().substring(0, 10),
      'end_date': endDate.toIso8601String().substring(0, 10),
      'price': price,
      'status': status,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_version': syncVersion,
    };
  }

  Membership copyWith({
    String? id,
    String? gymId,
    String? memberId,
    String? planId,
    DateTime? startDate,
    DateTime? endDate,
    double? price,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? syncVersion,
  }) {
    return Membership(
      id: id ?? this.id,
      gymId: gymId ?? this.gymId,
      memberId: memberId ?? this.memberId,
      planId: planId ?? this.planId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      price: price ?? this.price,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }
}
// 

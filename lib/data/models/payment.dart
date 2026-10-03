/// Payment model reflecting the public.payments Supabase table
class Payment {
  final String id;
  final String gymId;
  final String? membershipId;
  final double amount;
  final String paymentMethod;
  final DateTime paidAt;
  final String? recordedBy;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncVersion;

  const Payment({
    required this.id,
    required this.gymId,
    this.membershipId,
    required this.amount,
    this.paymentMethod = 'cash',
    required this.paidAt,
    this.recordedBy,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.syncVersion = 1,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      gymId: json['gym_id'] as String,
      membershipId: json['membership_id'] as String?,
      amount: (json['amount'] as num? ?? 0.0).toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : DateTime.now(),
      recordedBy: json['recorded_by'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      syncVersion: json['sync_version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_id': gymId,
      'membership_id': membershipId,
      'amount': amount,
      'payment_method': paymentMethod,
      'paid_at': paidAt.toIso8601String(),
      'recorded_by': recordedBy,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_version': syncVersion,
    };
  }

  Payment copyWith({
    String? id,
    String? gymId,
    String? membershipId,
    double? amount,
    String? paymentMethod,
    DateTime? paidAt,
    String? recordedBy,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncVersion,
  }) {
    return Payment(
      id: id ?? this.id,
      gymId: gymId ?? this.gymId,
      membershipId: membershipId ?? this.membershipId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAt: paidAt ?? this.paidAt,
      recordedBy: recordedBy ?? this.recordedBy,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }
}

/// ImportRow model reflecting the public.import_rows Supabase table
class ImportRow {
  final String id;
  final String batchId;
  final String gymId;
  final int rowNumber;
  final Map<String, dynamic> rawData;
  final String? fullName;
  final String? phone;
  final DateTime? joinDate;
  final double? paymentAmount;
  final String status;
  final String? errorMessage;
  final String? memberId;
  final DateTime createdAt;

  const ImportRow({
    required this.id,
    required this.batchId,
    required this.gymId,
    required this.rowNumber,
    required this.rawData,
    this.fullName,
    this.phone,
    this.joinDate,
    this.paymentAmount,
    this.status = 'pending',
    this.errorMessage,
    this.memberId,
    required this.createdAt,
  });

  factory ImportRow.fromJson(Map<String, dynamic> json) {
    return ImportRow(
      id: json['id'] as String,
      batchId: json['batch_id'] as String,
      gymId: json['gym_id'] as String,
      rowNumber: json['row_number'] as int? ?? 1,
      rawData: json['raw_data'] as Map<String, dynamic>? ?? {},
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      joinDate: json['join_date'] != null
          ? DateTime.tryParse(json['join_date'] as String)
          : null,
      paymentAmount: json['payment_amount'] != null
          ? (json['payment_amount'] as num).toDouble()
          : null,
      status: json['status'] as String? ?? 'pending',
      errorMessage: json['error_message'] as String?,
      memberId: json['member_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_id': batchId,
      'gym_id': gymId,
      'row_number': rowNumber,
      'raw_data': rawData,
      'full_name': fullName,
      'phone': phone,
      'join_date': joinDate?.toIso8601String().substring(0, 10),
      'payment_amount': paymentAmount,
      'status': status,
      'error_message': errorMessage,
      'member_id': memberId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

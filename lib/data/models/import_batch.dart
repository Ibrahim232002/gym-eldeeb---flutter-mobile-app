/// ImportBatch model reflecting the public.import_batches Supabase table
class ImportBatch {
  final String id;
  final String gymId;
  final String? importedBy;
  final String sourceType;
  final String? fileName;
  final int totalRows;
  final int importedRows;
  final int failedRows;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;

  const ImportBatch({
    required this.id,
    required this.gymId,
    this.importedBy,
    required this.sourceType,
    this.fileName,
    this.totalRows = 0,
    this.importedRows = 0,
    this.failedRows = 0,
    this.status = 'pending',
    required this.createdAt,
    this.completedAt,
  });

  factory ImportBatch.fromJson(Map<String, dynamic> json) {
    return ImportBatch(
      id: json['id'] as String,
      gymId: json['gym_id'] as String,
      importedBy: json['imported_by'] as String?,
      sourceType: json['source_type'] as String? ?? 'csv',
      fileName: json['file_name'] as String?,
      totalRows: json['total_rows'] as int? ?? 0,
      importedRows: json['imported_rows'] as int? ?? 0,
      failedRows: json['failed_rows'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_id': gymId,
      'imported_by': importedBy,
      'source_type': sourceType,
      'file_name': fileName,
      'total_rows': totalRows,
      'imported_rows': importedRows,
      'failed_rows': failedRows,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}

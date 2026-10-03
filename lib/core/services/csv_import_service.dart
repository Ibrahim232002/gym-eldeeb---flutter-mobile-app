import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/supabase_constants.dart';
import 'data_sync_service.dart';

/// Parsed CSV row for previewing
class ParsedImportRow {
  final int rowNumber;
  final Map<String, dynamic> rawData;
  final String? fullName;
  final String? phone;
  final DateTime? joinDate;
  final double? paymentAmount;
  final String status; // 'valid', 'invalid'
  final String? errorMessage;

  ParsedImportRow({
    required this.rowNumber,
    required this.rawData,
    this.fullName,
    this.phone,
    this.joinDate,
    this.paymentAmount,
    this.status = 'valid',
    this.errorMessage,
  });
}

/// Provider for CsvImportService
final csvImportServiceProvider = Provider<CsvImportService>((ref) {
  final supabase = Supabase.instance.client;
  final syncService = ref.watch(dataSyncServiceProvider);
  return CsvImportService(supabase, syncService);
});

/// Service managing CSV Member Import using original Supabase tables
class CsvImportService {
  final SupabaseClient _supabase;
  final DataSyncService _syncService;

  CsvImportService(this._supabase, this._syncService);

  /// Pick a CSV file and return parsed rows for preview before final import
  Future<List<ParsedImportRow>> pickAndParseCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return [];
    }

    final fileBytes = result.files.first.bytes;
    if (fileBytes == null) {
      throw Exception('عذراً، فشل قراءة الملف المحدد.');
    }

    final csvString = utf8.decode(fileBytes);
    final rows = const CsvToListConverter().convert(csvString);

    if (rows.isEmpty) {
      throw Exception('الملف فارغ أو لا يحتوي على سطور صالحة.');
    }

    // Attempt column mapping from headers (first row)
    final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    
    int fullNameIdx = -1;
    int phoneIdx = -1;
    int joinDateIdx = -1;
    int paymentAmountIdx = -1;

    for (var i = 0; i < headers.length; i++) {
      final h = headers[i];
      if (h.contains('name') || h.contains('اسم') || h.contains('full_name')) {
        fullNameIdx = i;
      } else if (h.contains('phone') || h.contains('هاتف') || h.contains('موبايل') || h.contains('تليفون')) {
        phoneIdx = i;
      } else if (h.contains('date') || h.contains('تاريخ') || h.contains('انضمام')) {
        joinDateIdx = i;
      } else if (h.contains('amount') || h.contains('سعر') || h.contains('دفع') || h.contains('مبلغ')) {
        paymentAmountIdx = i;
      }
    }

    // Default fallbacks if header matches fail
    if (fullNameIdx == -1 && headers.isNotEmpty) fullNameIdx = 0;
    if (phoneIdx == -1 && headers.length > 1) phoneIdx = 1;

    final parsedRows = <ParsedImportRow>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((element) => element == null || element.toString().trim().isEmpty)) {
        continue;
      }

      final rawData = <String, dynamic>{};
      for (var col = 0; col < row.length; col++) {
        final colName = col < headers.length ? headers[col] : 'col_$col';
        rawData[colName] = row[col];
      }

      String? fullName;
      if (fullNameIdx != -1 && fullNameIdx < row.length) {
        fullName = row[fullNameIdx]?.toString().trim();
      }

      String? phone;
      if (phoneIdx != -1 && phoneIdx < row.length) {
        phone = row[phoneIdx]?.toString().trim();
      }

      DateTime? joinDate;
      if (joinDateIdx != -1 && joinDateIdx < row.length) {
        final dateStr = row[joinDateIdx]?.toString().trim();
        if (dateStr != null) {
          joinDate = DateTime.tryParse(dateStr);
        }
      }

      double? paymentAmount;
      if (paymentAmountIdx != -1 && paymentAmountIdx < row.length) {
        final amtStr = row[paymentAmountIdx]?.toString().trim();
        if (amtStr != null) {
          paymentAmount = double.tryParse(amtStr);
        }
      }

      // Basic validations
      String status = 'valid';
      String? errorMsg;

      if (fullName == null || fullName.isEmpty) {
        status = 'invalid';
        errorMsg = 'الاسم الكامل مطلوب';
      }

      parsedRows.add(ParsedImportRow(
        rowNumber: i + 1,
        rawData: rawData,
        fullName: fullName,
        phone: phone,
        joinDate: joinDate,
        paymentAmount: paymentAmount,
        status: status,
        errorMessage: errorMsg,
      ));
    }

    return parsedRows;
  }

  /// Execute final import to Supabase and Local Cache
  Future<Map<String, int>> executeImport({
    required String gymId,
    required String fileName,
    required List<ParsedImportRow> rowsToImport,
    required String? importedBy,
  }) async {
    final batchId = const Uuid().v4();
    final totalRows = rowsToImport.length;

    // Create import batch in remote Supabase (failsafe: offline handling also loads cached sync)
    try {
      await _supabase.from(SupabaseConstants.tableImportBatches).insert({
        'id': batchId,
        'gym_id': gymId,
        'imported_by': importedBy,
        'source_type': 'csv',
        'file_name': fileName,
        'total_rows': totalRows,
        'status': 'processing',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    var importedCount = 0;
    var failedCount = 0;

    for (final row in rowsToImport) {
      if (row.status == 'invalid') {
        failedCount++;
        continue;
      }

      try {
        final memberId = const Uuid().v4();
        
        // 1. Add Member
        await _syncService.addMember(
          fullName: row.fullName!,
          phone: row.phone,
          notes: 'مستورد من ملف CSV',
          joinDate: row.joinDate ?? DateTime.now(),
        );

        // 2. Add Payment if paymentAmount is defined
        if (row.paymentAmount != null && row.paymentAmount! > 0) {
          await _syncService.recordPayment(
            membershipId: null,
            amount: row.paymentAmount!,
            paymentMethod: 'cash',
            paidAt: row.joinDate ?? DateTime.now(),
            notes: 'دفعة مستوردة',
          );
        }

        importedCount++;

        // Log row status in remote import_rows
        try {
          await _supabase.from(SupabaseConstants.tableImportRows).insert({
            'id': const Uuid().v4(),
            'batch_id': batchId,
            'gym_id': gymId,
            'row_number': row.rowNumber,
            'raw_data': row.rawData,
            'full_name': row.fullName,
            'phone': row.phone,
            'join_date': row.joinDate?.toIso8601String().substring(0, 10),
            'payment_amount': row.paymentAmount,
            'status': 'completed',
            'member_id': memberId,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      } catch (e) {
        failedCount++;
        try {
          await _supabase.from(SupabaseConstants.tableImportRows).insert({
            'id': const Uuid().v4(),
            'batch_id': batchId,
            'gym_id': gymId,
            'row_number': row.rowNumber,
            'raw_data': row.rawData,
            'full_name': row.fullName,
            'phone': row.phone,
            'status': 'failed',
            'error_message': e.toString(),
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
    }

    // Complete batch
    try {
      await _supabase.from(SupabaseConstants.tableImportBatches).update({
        'status': 'completed',
        'imported_rows': importedCount,
        'failed_rows': failedCount,
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', batchId);
    } catch (_) {}

    // Synchronize latest cache
    await _syncService.syncAll();

    return {
      'total': totalRows,
      'imported': importedCount,
      'failed': failedCount,
    };
  }
}

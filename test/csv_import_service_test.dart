import 'package:flutter_test/flutter_test.dart';
import 'package:gym_eldeeb/core/services/csv_import_service.dart';

void main() {
  group('CSV import validation', () {
    test('parses valid Arabic/English headers and common dates', () {
      final rows = CsvImportService.parseCsvText('اسم,موبايل,تاريخ الانضمام,مبلغ\nAhmed Ali,01012345678,03/10/2026,"1,500"');
      expect(rows, hasLength(1));
      expect(rows.first.status, 'valid');
      expect(rows.first.fullName, 'Ahmed Ali');
      expect(rows.first.joinDate, isNotNull);
      expect(rows.first.paymentAmount, 1500);
    });

    test('rejects invalid date', () {
      final rows = CsvImportService.parseCsvText('name,phone,date,amount\nAhmed,01012345678,not-a-date,500');
      expect(rows.first.status, 'invalid');
      expect(rows.first.errorMessage, contains('تاريخ'));
    });

    test('rejects invalid amount and negative amount', () {
      final invalid = CsvImportService.parseCsvText('name,phone,date,amount\nAhmed,01012345678,2026-10-03,abc');
      expect(invalid.first.status, 'invalid');

      final negative = CsvImportService.parseCsvText('name,phone,date,amount\nAhmed,01012345678,2026-10-03,-50');
      expect(negative.first.status, 'invalid');
      expect(negative.first.errorMessage, contains('سالبة'));
    });

    test('rejects duplicate phone numbers inside the same file', () {
      final rows = CsvImportService.parseCsvText(
        'name,phone,date,amount\n'
        'Ahmed,01012345678,2026-10-03,500\n'
        'Mohamed,01012345678,2026-10-03,300',
      );

      expect(rows[0].status, 'valid');
      expect(rows[1].status, 'invalid');
      expect(rows[1].errorMessage, contains('مكرر'));
    });

    test('handles UTF-8 BOM', () {
      final rows = CsvImportService.parseCsvText('\uFEFFname,phone\nAhmed,01012345678');
      expect(rows.first.status, 'valid');
      expect(rows.first.fullName, 'Ahmed');
    });

    test('does not manufacture an import row for an empty CSV', () {
      expect(
        () => CsvImportService.parseCsvText(''),
        throwsException,
      );
    });
  });
}

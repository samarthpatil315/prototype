import 'package:flutter_test/flutter_test.dart';
import 'package:orbital_office/core/services/ai_service.dart';
import 'package:orbital_office/core/services/csv_service.dart';
import 'package:orbital_office/core/services/sync_service.dart';
import 'package:orbital_office/core/utilities/validators.dart';
import 'package:orbital_office/data/models/models.dart';

void main() {
  group('Validators', () {
    test('email validation', () {
      expect(Validators.email('demo@orbital.studio'), isNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('password policy', () {
      expect(Validators.password('abc12345'), isNull);
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('onlyletters'), isNotNull);
    });

    test('phone is optional unless required', () {
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('', requiredField: true), isNotNull);
      expect(Validators.phone('+91 98220 12345'), isNull);
    });
  });

  group('Sync conflict resolution', () {
    test('newer server data is never overwritten', () {
      final outcome = resolveConflict(
        localUpdatedAt: DateTime(2026, 1, 1),
        remoteUpdatedAt: DateTime(2026, 1, 2),
      );
      expect(outcome, SyncOutcome.keptRemoteNewer);
    });

    test('newer local data is pushed', () {
      final outcome = resolveConflict(
        localUpdatedAt: DateTime(2026, 1, 3),
        remoteUpdatedAt: DateTime(2026, 1, 2),
      );
      expect(outcome, SyncOutcome.pushed);
    });

    test('missing remote copy is pushed', () {
      final outcome = resolveConflict(
        localUpdatedAt: DateTime(2026, 1, 3),
        remoteUpdatedAt: null,
      );
      expect(outcome, SyncOutcome.pushed);
    });
  });

  group('Demo AI assistant', () {
    test('always labels output as unverified demo content', () {
      final out = AiService.demoGenerate('Write a business email');
      expect(out, contains('Demo AI'));
      expect(out, contains('NOT been verified'));
    });

    test('responds to known task types', () {
      expect(AiService.demoGenerate('Create a task list for a launch'),
          contains('Task list'));
      expect(AiService.demoGenerate('Write invoice descriptions'),
          contains('invoice descriptions'));
      expect(AiService.demoGenerate('Write a business letter'),
          contains('Subject:'));
    });

    test('summarise extracts sentences', () {
      final out = AiService.demoGenerate(
          'Summarize: Sales grew this quarter. Costs stayed flat. Two new clients joined.');
      expect(out, contains('Summary'));
      expect(out, contains('Sales grew'));
    });
  });

  group('CSV service', () {
    test('round-trips rows', () {
      final csv = CsvService.encode([
        ['Name', 'Stock'],
        ['Notebooks', 42],
      ]);
      final rows = CsvService.decode(csv);
      expect(rows.first, ['Name', 'Stock']);
      expect(rows[1][1].toString(), '42');
    });

    test('header parsing', () {
      final rows = CsvService.decodeWithHeaders('Name,Stock\nPens,10\n');
      expect(rows.single['Name'], 'Pens');
      expect(rows.single['Stock'], '10');
    });
  });

  group('Model JSON round-trips', () {
    test('invoice survives serialisation', () {
      final now = DateTime(2026, 1, 1);
      final inv = InvoiceDoc(
        id: 'inv-1',
        kind: BillingKind.invoice,
        number: 'INV-1001',
        items: [InvoiceItem(description: 'Design', quantity: 2, unitPrice: 500)],
        createdAt: now,
        updatedAt: now,
        taxLabel: 'GST',
        taxPercent: 18,
      );
      final restored = InvoiceDoc.fromJson(inv.toJson());
      expect(restored.number, 'INV-1001');
      expect(restored.totals.grandTotal, 1180);
      expect(restored.items.single.description, 'Design');
    });

    test('spreadsheet preserves formulas when saving', () {
      final now = DateTime(2026, 1, 1);
      final sheet = SpreadsheetDoc(
        id: 'sheet-1',
        title: 'Sales',
        cells: const {'A1': '2', 'A2': '=A1*3'},
        createdAt: now,
        updatedAt: now,
      );
      final restored = SpreadsheetDoc.fromJson(sheet.toJson());
      expect(restored.cells['A2'], '=A1*3');
    });

    test('customer lead stage survives serialisation', () {
      final now = DateTime(2026, 1, 1);
      final c = Customer(
        id: 'c1',
        name: 'Test',
        createdAt: now,
        updatedAt: now,
        stage: LeadStage.quotationSent,
      );
      expect(Customer.fromJson(c.toJson()).stage, LeadStage.quotationSent);
    });

    test('low stock detection', () {
      final p = Product(
        id: 'p1',
        name: 'Ink',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        stock: 3,
        lowStockThreshold: 5,
      );
      expect(p.isLowStock, isTrue);
      p.stock = 9;
      expect(p.isLowStock, isFalse);
    });
  });
}

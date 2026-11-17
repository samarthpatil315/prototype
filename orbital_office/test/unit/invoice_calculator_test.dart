import 'package:flutter_test/flutter_test.dart';
import 'package:orbital_office/core/services/invoice_calculator.dart';

void main() {
  group('InvoiceCalculator', () {
    test('simple subtotal and grand total without tax', () {
      final t = InvoiceCalculator.calculate(items: const [
        InvoiceLineInput(description: 'Design', quantity: 2, unitPrice: 5000),
        InvoiceLineInput(description: 'Video', quantity: 1, unitPrice: 12000),
      ]);
      expect(t.subtotal, 22000);
      expect(t.grandTotal, 22000);
      expect(t.balanceDue, 22000);
    });

    test('line discount, invoice discount and tax compose correctly', () {
      final t = InvoiceCalculator.calculate(
        items: const [
          InvoiceLineInput(
              description: 'Package',
              quantity: 1,
              unitPrice: 10000,
              discountPercent: 10),
        ],
        invoiceDiscountPercent: 10,
        taxPercent: 18,
      );
      // 10000 - 1000 (line) = 9000; -900 (invoice) = 8100; +18% = 9558
      expect(t.subtotal, 10000);
      expect(t.lineDiscountTotal, 1000);
      expect(t.invoiceDiscountAmount, 900);
      expect(t.taxableAmount, 8100);
      expect(t.taxAmount, 1458);
      expect(t.grandTotal, 9558);
    });

    test('payments reduce balance and set status', () {
      final t = InvoiceCalculator.calculate(
        items: const [
          InvoiceLineInput(description: 'X', quantity: 1, unitPrice: 1000),
        ],
        amountPaid: 400,
      );
      expect(t.balanceDue, 600);
      expect(paymentStatusFor(t), PaymentStatus.partial);

      final paid = InvoiceCalculator.calculate(
        items: const [
          InvoiceLineInput(description: 'X', quantity: 1, unitPrice: 1000),
        ],
        amountPaid: 1000,
      );
      expect(paymentStatusFor(paid), PaymentStatus.paid);
      expect(paid.isFullyPaid, isTrue);
    });

    test('zero-tax invoices never invent tax', () {
      final t = InvoiceCalculator.calculate(
        items: const [
          InvoiceLineInput(description: 'X', quantity: 3, unitPrice: 333),
        ],
        taxPercent: 0,
      );
      expect(t.taxAmount, 0);
      expect(t.grandTotal, 999);
    });

    test('discount percentages are clamped to 0-100', () {
      final t = InvoiceCalculator.calculate(
        items: const [
          InvoiceLineInput(
              description: 'X', quantity: 1, unitPrice: 100, discountPercent: 250),
        ],
      );
      expect(t.grandTotal, 0);
    });
  });

  group('Pipeline enums', () {
    test('lead stages round-trip through codes', () {
      for (final s in LeadStage.values) {
        expect(LeadStage.fromCode(s.code), s);
      }
      expect(LeadStage.fromCode('UNKNOWN'), LeadStage.newLead);
      expect(LeadStage.quotationSent.code, 'QUOTATION_SENT');
    });

    test('task enums round-trip', () {
      expect(TaskStatus.fromCode('IN_PROGRESS'), TaskStatus.inProgress);
      expect(TaskPriority.fromCode('HIGH'), TaskPriority.high);
    });
  });
}

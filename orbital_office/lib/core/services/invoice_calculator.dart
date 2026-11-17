/// Pure invoice/quotation maths. INR is the default currency at the UI
/// layer; this calculator is currency-agnostic and never assumes a tax
/// regime — the caller supplies [taxPercent] and a [taxLabel] (e.g. "GST",
/// "VAT", or empty for untaxed invoices).
library;

class InvoiceLineInput {
  const InvoiceLineInput({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
  });

  final String description;
  final double quantity;
  final double unitPrice;
  final double discountPercent;

  double get gross => quantity * unitPrice;
  double get discountAmount => gross * (discountPercent.clamp(0, 100) / 100);
  double get net => gross - discountAmount;
}

class InvoiceTotals {
  const InvoiceTotals({
    required this.subtotal,
    required this.lineDiscountTotal,
    required this.invoiceDiscountAmount,
    required this.taxableAmount,
    required this.taxAmount,
    required this.grandTotal,
    required this.amountPaid,
    required this.balanceDue,
  });

  final double subtotal;
  final double lineDiscountTotal;
  final double invoiceDiscountAmount;
  final double taxableAmount;
  final double taxAmount;
  final double grandTotal;
  final double amountPaid;
  final double balanceDue;

  bool get isFullyPaid => balanceDue <= 0.005 && grandTotal > 0;
}

class InvoiceCalculator {
  const InvoiceCalculator._();

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  static InvoiceTotals calculate({
    required List<InvoiceLineInput> items,
    double invoiceDiscountPercent = 0,
    double taxPercent = 0,
    double amountPaid = 0,
  }) {
    var subtotal = 0.0;
    var lineDiscounts = 0.0;
    for (final item in items) {
      subtotal += item.gross;
      lineDiscounts += item.discountAmount;
    }
    final afterLines = subtotal - lineDiscounts;
    final invoiceDiscount =
        afterLines * (invoiceDiscountPercent.clamp(0, 100) / 100);
    final taxable = afterLines - invoiceDiscount;
    final tax = taxable * (taxPercent.clamp(0, 100) / 100);
    final grand = _round2(taxable + tax);
    return InvoiceTotals(
      subtotal: _round2(subtotal),
      lineDiscountTotal: _round2(lineDiscounts),
      invoiceDiscountAmount: _round2(invoiceDiscount),
      taxableAmount: _round2(taxable),
      taxAmount: _round2(tax),
      grandTotal: grand,
      amountPaid: _round2(amountPaid),
      balanceDue: _round2(grand - amountPaid),
    );
  }
}

/// Lead pipeline stages for the CRM (Part 10).
enum LeadStage {
  newLead('NEW'),
  contacted('CONTACTED'),
  interested('INTERESTED'),
  quotationSent('QUOTATION_SENT'),
  converted('CONVERTED'),
  closed('CLOSED');

  const LeadStage(this.code);
  final String code;

  String get label => switch (this) {
        LeadStage.newLead => 'New',
        LeadStage.contacted => 'Contacted',
        LeadStage.interested => 'Interested',
        LeadStage.quotationSent => 'Quotation Sent',
        LeadStage.converted => 'Converted',
        LeadStage.closed => 'Closed',
      };

  static LeadStage fromCode(String? code) => LeadStage.values.firstWhere(
        (s) => s.code == code,
        orElse: () => LeadStage.newLead,
      );
}

enum TaskPriority {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const TaskPriority(this.code);
  final String code;
  String get label => name[0].toUpperCase() + name.substring(1);
  static TaskPriority fromCode(String? c) => TaskPriority.values.firstWhere(
        (p) => p.code == c,
        orElse: () => TaskPriority.medium,
      );
}

enum TaskStatus {
  toDo('TO_DO'),
  inProgress('IN_PROGRESS'),
  completed('COMPLETED');

  const TaskStatus(this.code);
  final String code;
  String get label => switch (this) {
        TaskStatus.toDo => 'To Do',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.completed => 'Completed',
      };
  static TaskStatus fromCode(String? c) => TaskStatus.values.firstWhere(
        (s) => s.code == c,
        orElse: () => TaskStatus.toDo,
      );
}

enum PaymentStatus { unpaid, partial, paid }

PaymentStatus paymentStatusFor(InvoiceTotals t) {
  if (t.amountPaid <= 0) return PaymentStatus.unpaid;
  if (t.balanceDue > 0.005) return PaymentStatus.partial;
  return PaymentStatus.paid;
}

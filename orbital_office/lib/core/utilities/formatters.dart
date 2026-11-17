import 'package:intl/intl.dart';

/// INR-first formatting helpers. Currency is configurable per invoice;
/// INR is only the default required by the specification.
class Formatters {
  const Formatters._();

  static final NumberFormat _inr =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  static String inr(num value) => _inr.format(value);

  static String money(num value, {String symbol = '₹'}) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: symbol,
      decimalDigits: 2,
    ).format(value);
  }

  static String number(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return NumberFormat('0.##', 'en_IN').format(value);
  }

  static String date(DateTime d) => DateFormat('dd MMM yyyy', 'en_IN').format(d);
  static String dateTime(DateTime d) =>
      DateFormat('dd MMM yyyy, hh:mm a', 'en_IN').format(d);

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(d);
  }
}

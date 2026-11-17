import 'package:csv/csv.dart';

/// CSV import/export helpers (inventory, customers, spreadsheets).
class CsvService {
  const CsvService._();

  static String encode(List<List<Object?>> rows) =>
      const ListToCsvConverter().convert(rows);

  static List<List<dynamic>> decode(String text) =>
      const CsvToListConverter(eol: '\n').convert(text);

  /// Parses CSV text with a header row into maps keyed by header name.
  static List<Map<String, String>> decodeWithHeaders(String text) {
    final rows = decode(text);
    if (rows.length < 2) return [];
    final headers = rows.first.map((h) => h.toString().trim()).toList();
    return [
      for (var r = 1; r < rows.length; r++)
        {
          for (var c = 0; c < headers.length; c++)
            headers[c]: c < rows[r].length ? rows[r][c].toString() : '',
        },
    ];
  }
}

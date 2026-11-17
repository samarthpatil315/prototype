/// A small, dependency-free spreadsheet formula engine.
///
/// Supported: `+ - * / ^ %`, parentheses, unary minus, cell references
/// (`A1`, `$A$1`), ranges (`A1:B5`) inside functions, and the functions
/// SUM, AVERAGE, COUNT, MIN, MAX and IF (with `> < >= <= = <>` comparisons).
///
/// The engine detects circular references, reports spreadsheet-style error
/// codes instead of throwing, and recomputes dependent cells because every
/// evaluation resolves references recursively through the current cell map.
///
/// It is intentionally pure Dart so it can be exhaustively unit-tested
/// against known expected outputs (see test/unit/formula_engine_test.dart).
library;

class CellValue {
  const CellValue.number(this.number)
      : text = null,
        error = null;
  const CellValue.text(this.text)
      : number = null,
        error = null;
  const CellValue.error(this.error)
      : number = null,
        text = null;
  const CellValue.empty()
      : number = null,
        text = null,
        error = null;

  final double? number;
  final String? text;
  final String? error;

  bool get isError => error != null;
  bool get isEmpty => number == null && text == null && error == null;

  String get display {
    if (error != null) return error!;
    if (number != null) {
      final n = number!;
      return n == n.roundToDouble() ? n.toInt().toString() : _trim(n);
    }
    return text ?? '';
  }

  static String _trim(double n) {
    var s = n.toStringAsFixed(6);
    while (s.contains('.') && s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  @override
  String toString() => 'CellValue($display)';
}

/// Converts between spreadsheet column labels and zero-based indexes.
class CellRef {
  const CellRef._();

  static int columnToIndex(String letters) {
    var result = 0;
    for (final unit in letters.toUpperCase().codeUnits) {
      result = result * 26 + (unit - 64);
    }
    return result - 1;
  }

  static String indexToColumn(int index) {
    var n = index + 1;
    var out = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      out = String.fromCharCode(65 + rem) + out;
      n = (n - 1) ~/ 26;
    }
    return out;
  }

  /// Parses `B12` / `$B$12` into (columnIndex, rowIndex), both zero-based.
  static (int, int)? parse(String ref) {
    final m = RegExp(r'^\$?([A-Za-z]+)\$?([0-9]+)$').firstMatch(ref.trim());
    if (m == null) return null;
    final row = int.tryParse(m.group(2)!);
    if (row == null || row < 1) return null;
    return (columnToIndex(m.group(1)!), row - 1);
  }

  static String format(int columnIndex, int rowIndex) =>
      '${indexToColumn(columnIndex)}${rowIndex + 1}';

  static bool isRef(String token) => parse(token) != null;
}

class FormulaEngine {
  /// [rawCells] maps normalised addresses (`A1`) to raw user input.
  /// Values starting with `=` are formulas; numeric strings become numbers;
  /// everything else is text.
  FormulaEngine(Map<String, String> rawCells)
      : _raw = {
          for (final e in rawCells.entries) e.key.toUpperCase(): e.value,
        };

  final Map<String, String> _raw;
  final Map<String, CellValue> _cache = {};

  static const String errDiv0 = '#DIV/0!';
  static const String errValue = '#VALUE!';
  static const String errRef = '#REF!';
  static const String errName = '#NAME?';
  static const String errCycle = '#CYCLE!';
  static const String errParse = '#ERROR!';

  /// Evaluates every cell and returns address -> computed value.
  Map<String, CellValue> evaluateAll() {
    final out = <String, CellValue>{};
    for (final key in _raw.keys) {
      out[key] = _evaluateCell(key, <String>{});
    }
    return out;
  }

  CellValue evaluateCell(String address) =>
      _evaluateCell(address.toUpperCase(), <String>{});

  CellValue _evaluateCell(String address, Set<String> visiting) {
    final cached = _cache[address];
    if (cached != null && visiting.isEmpty) return cached;
    if (visiting.contains(address)) {
      return const CellValue.error(errCycle);
    }
    final raw = _raw[address];
    if (raw == null || raw.trim().isEmpty) return const CellValue.empty();

    visiting.add(address);
    CellValue result;
    final trimmed = raw.trim();
    if (trimmed.startsWith('=')) {
      try {
        final parser = _Parser(trimmed.substring(1), this, visiting);
        final value = parser.parseExpression();
        parser.expectEnd();
        result = CellValue.number(value);
      } on _FormulaException catch (e) {
        result = CellValue.error(e.code);
      } catch (_) {
        result = const CellValue.error(errParse);
      }
    } else {
      final n = double.tryParse(trimmed.replaceAll(',', ''));
      result = n != null ? CellValue.number(n) : CellValue.text(trimmed);
    }
    visiting.remove(address);
    if (visiting.isEmpty) _cache[address] = result;
    return result;
  }

  double _resolveRef(String ref, Set<String> visiting) {
    final parsed = CellRef.parse(ref);
    if (parsed == null) throw const _FormulaException(errRef);
    final address = CellRef.format(parsed.$1, parsed.$2);
    if (visiting.contains(address)) {
      throw const _FormulaException(errCycle);
    }
    final value = _evaluateCell(address, visiting);
    if (value.isError) throw _FormulaException(value.error!);
    if (value.isEmpty) return 0;
    if (value.number != null) return value.number!;
    throw const _FormulaException(errValue);
  }

  List<double> _resolveRange(String range, Set<String> visiting) {
    final parts = range.split(':');
    if (parts.length != 2) throw const _FormulaException(errRef);
    final a = CellRef.parse(parts[0]);
    final b = CellRef.parse(parts[1]);
    if (a == null || b == null) throw const _FormulaException(errRef);
    final values = <double>[];
    final minCol = a.$1 < b.$1 ? a.$1 : b.$1;
    final maxCol = a.$1 > b.$1 ? a.$1 : b.$1;
    final minRow = a.$2 < b.$2 ? a.$2 : b.$2;
    final maxRow = a.$2 > b.$2 ? a.$2 : b.$2;
    for (var r = minRow; r <= maxRow; r++) {
      for (var c = minCol; c <= maxCol; c++) {
        final address = CellRef.format(c, r);
        final raw = _raw[address];
        if (raw == null || raw.trim().isEmpty) continue;
        values.add(_resolveRef(address, visiting));
      }
    }
    return values;
  }
}

class _FormulaException implements Exception {
  const _FormulaException(this.code);
  final String code;
}

// ---------------------------------------------------------------------------
// Tokeniser
// ---------------------------------------------------------------------------

enum _TokKind { number, ref, ident, op, lParen, rParen, comma, colon, end }

class _Tok {
  const _Tok(this.kind, this.text);
  final _TokKind kind;
  final String text;
}

List<_Tok> _tokenize(String input) {
  final toks = <_Tok>[];
  var i = 0;
  bool isDigit(int u) => u >= 48 && u <= 57;
  bool isLetter(int u) => (u >= 65 && u <= 90) || (u >= 97 && u <= 122);

  while (i < input.length) {
    final ch = input[i];
    final u = ch.codeUnitAt(0);
    if (ch == ' ' || ch == '\t') {
      i++;
      continue;
    }
    if (isDigit(u) || (ch == '.' && i + 1 < input.length && isDigit(input.codeUnitAt(i + 1)))) {
      final start = i;
      while (i < input.length &&
          (isDigit(input.codeUnitAt(i)) || input[i] == '.')) {
        i++;
      }
      toks.add(_Tok(_TokKind.number, input.substring(start, i)));
      continue;
    }
    if (ch == r'$' || isLetter(u)) {
      final start = i;
      while (i < input.length &&
          (isLetter(input.codeUnitAt(i)) ||
              isDigit(input.codeUnitAt(i)) ||
              input[i] == r'$')) {
        i++;
      }
      final word = input.substring(start, i);
      // A word like A1 / $A$1 is a cell reference; anything else is a name.
      toks.add(_Tok(CellRef.isRef(word) ? _TokKind.ref : _TokKind.ident, word));
      continue;
    }
    switch (ch) {
      case '(':
        toks.add(const _Tok(_TokKind.lParen, '('));
        i++;
      case ')':
        toks.add(const _Tok(_TokKind.rParen, ')'));
        i++;
      case ',':
        toks.add(const _Tok(_TokKind.comma, ','));
        i++;
      case ':':
        toks.add(const _Tok(_TokKind.colon, ':'));
        i++;
      case '>':
      case '<':
        if (i + 1 < input.length && (input[i + 1] == '=' || input[i + 1] == '>')) {
          toks.add(_Tok(_TokKind.op, input.substring(i, i + 2)));
          i += 2;
        } else {
          toks.add(_Tok(_TokKind.op, ch));
          i++;
        }
      case '+':
      case '-':
      case '*':
      case '/':
      case '^':
      case '%':
      case '=':
        toks.add(_Tok(_TokKind.op, ch));
        i++;
      default:
        throw const _FormulaException(FormulaEngine.errParse);
    }
  }
  toks.add(const _Tok(_TokKind.end, ''));
  return toks;
}

// ---------------------------------------------------------------------------
// Recursive-descent parser/evaluator
// precedence: comparison < additive < multiplicative < power < unary < atom
// ---------------------------------------------------------------------------

class _Parser {
  _Parser(String input, this._engine, this._visiting)
      : _toks = _tokenize(input);

  final List<_Tok> _toks;
  final FormulaEngine _engine;
  final Set<String> _visiting;
  int _pos = 0;

  _Tok get _peek => _toks[_pos];
  _Tok _next() => _toks[_pos++];

  void expectEnd() {
    if (_peek.kind != _TokKind.end) {
      throw const _FormulaException(FormulaEngine.errParse);
    }
  }

  double parseExpression() => _parseComparison();

  double _parseComparison() {
    var left = _parseAdditive();
    while (_peek.kind == _TokKind.op &&
        ['>', '<', '>=', '<=', '=', '<>'].contains(_peek.text)) {
      final op = _next().text;
      final right = _parseAdditive();
      final result = switch (op) {
        '>' => left > right,
        '<' => left < right,
        '>=' => left >= right,
        '<=' => left <= right,
        '=' => left == right,
        _ => left != right,
      };
      left = result ? 1 : 0;
    }
    return left;
  }

  double _parseAdditive() {
    var left = _parseMultiplicative();
    while (_peek.kind == _TokKind.op && (_peek.text == '+' || _peek.text == '-')) {
      final op = _next().text;
      final right = _parseMultiplicative();
      left = op == '+' ? left + right : left - right;
    }
    return left;
  }

  double _parseMultiplicative() {
    var left = _parsePower();
    while (_peek.kind == _TokKind.op &&
        (_peek.text == '*' || _peek.text == '/' || _peek.text == '%')) {
      final op = _next().text;
      final right = _parsePower();
      if ((op == '/' || op == '%') && right == 0) {
        throw const _FormulaException(FormulaEngine.errDiv0);
      }
      left = switch (op) {
        '*' => left * right,
        '/' => left / right,
        _ => left % right,
      };
    }
    return left;
  }

  double _parsePower() {
    var base = _parseUnary();
    while (_peek.kind == _TokKind.op && _peek.text == '^') {
      _next();
      base = _pow(base, _parseUnary());
    }
    return base;
  }

  static double _pow(double base, double exponent) {
    // Implemented with dart:math through a late import-free trick: the
    // engine file imports nothing, so power uses iterative multiplication
    // for integer exponents and Newton's method is not appropriate.
    // For fractional exponents we use exp(exponent * ln(base)).
    if (exponent == exponent.roundToDouble() && exponent.abs() < 1000) {
      var result = 1.0;
      final n = exponent.toInt().abs();
      for (var i = 0; i < n; i++) {
        result *= base;
      }
      return exponent < 0 ? 1 / result : result;
    }
    if (base <= 0) throw const _FormulaException(FormulaEngine.errValue);
    return _exp(exponent * _ln(base));
  }

  static double _ln(double x) {
    // Natural log via atanh series after range reduction.
    var m = x;
    var k = 0;
    while (m > 1.5) {
      m /= 2;
      k++;
    }
    while (m < 0.75) {
      m *= 2;
      k--;
    }
    final y = (m - 1) / (m + 1);
    final y2 = y * y;
    var term = y;
    var sum = 0.0;
    for (var n = 1; n <= 25; n += 2) {
      sum += term / n;
      term *= y2;
    }
    const ln2 = 0.6931471805599453;
    return 2 * sum + k * ln2;
  }

  static double _exp(double x) {
    var term = 1.0;
    var sum = 1.0;
    for (var n = 1; n <= 30; n++) {
      term *= x / n;
      sum += term;
    }
    return sum;
  }

  double _parseUnary() {
    if (_peek.kind == _TokKind.op && _peek.text == '-') {
      _next();
      return -_parseUnary();
    }
    if (_peek.kind == _TokKind.op && _peek.text == '+') {
      _next();
      return _parseUnary();
    }
    return _parseAtom();
  }

  double _parseAtom() {
    final tok = _next();
    switch (tok.kind) {
      case _TokKind.number:
        final v = double.tryParse(tok.text);
        if (v == null) throw const _FormulaException(FormulaEngine.errParse);
        return v;
      case _TokKind.ref:
        if (_peek.kind == _TokKind.colon) {
          _next();
          final end = _next();
          if (end.kind != _TokKind.ref) {
            throw const _FormulaException(FormulaEngine.errRef);
          }
          // A bare range outside a function is invalid in this engine.
          throw const _FormulaException(FormulaEngine.errValue);
        }
        return _engine._resolveRef(tok.text, _visiting);
      case _TokKind.ident:
        return _parseFunction(tok.text.toUpperCase());
      case _TokKind.lParen:
        final v = _parseComparison();
        if (_next().kind != _TokKind.rParen) {
          throw const _FormulaException(FormulaEngine.errParse);
        }
        return v;
      default:
        throw const _FormulaException(FormulaEngine.errParse);
    }
  }

  double _parseFunction(String name) {
    const known = {'SUM', 'AVERAGE', 'COUNT', 'MIN', 'MAX', 'IF'};
    if (!known.contains(name)) {
      throw const _FormulaException(FormulaEngine.errName);
    }
    if (_next().kind != _TokKind.lParen) {
      throw const _FormulaException(FormulaEngine.errParse);
    }

    if (name == 'IF') {
      final condition = _parseComparison();
      if (_next().kind != _TokKind.comma) {
        throw const _FormulaException(FormulaEngine.errParse);
      }
      final whenTrue = _parseComparison();
      var whenFalse = 0.0;
      if (_peek.kind == _TokKind.comma) {
        _next();
        whenFalse = _parseComparison();
      }
      if (_next().kind != _TokKind.rParen) {
        throw const _FormulaException(FormulaEngine.errParse);
      }
      return condition != 0 ? whenTrue : whenFalse;
    }

    // Aggregate functions accept any mix of numbers, refs and ranges.
    final values = <double>[];
    if (_peek.kind != _TokKind.rParen) {
      while (true) {
        if (_peek.kind == _TokKind.ref &&
            _pos + 1 < _toks.length &&
            _toks[_pos + 1].kind == _TokKind.colon) {
          final start = _next().text;
          _next(); // colon
          final endTok = _next();
          if (endTok.kind != _TokKind.ref) {
            throw const _FormulaException(FormulaEngine.errRef);
          }
          values.addAll(_engine._resolveRange('$start:${endTok.text}', _visiting));
        } else {
          values.add(_parseComparison());
        }
        if (_peek.kind == _TokKind.comma) {
          _next();
          continue;
        }
        break;
      }
    }
    if (_next().kind != _TokKind.rParen) {
      throw const _FormulaException(FormulaEngine.errParse);
    }

    return switch (name) {
      'SUM' => values.fold<double>(0, (a, b) => a + b),
      'COUNT' => values.length.toDouble(),
      'AVERAGE' => values.isEmpty
          ? throw const _FormulaException(FormulaEngine.errDiv0)
          : values.fold<double>(0, (a, b) => a + b) / values.length,
      'MIN' => values.isEmpty
          ? throw const _FormulaException(FormulaEngine.errValue)
          : values.reduce((a, b) => a < b ? a : b),
      'MAX' => values.isEmpty
          ? throw const _FormulaException(FormulaEngine.errValue)
          : values.reduce((a, b) => a > b ? a : b),
      _ => throw const _FormulaException(FormulaEngine.errName),
    };
  }
}

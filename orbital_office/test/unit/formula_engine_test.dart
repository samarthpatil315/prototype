import 'package:flutter_test/flutter_test.dart';
import 'package:orbital_office/core/services/formula_engine.dart';

void main() {
  group('CellRef', () {
    test('parses and formats addresses', () {
      expect(CellRef.parse('B12'), (1, 11));
      expect(CellRef.parse('\$A\$1'), (0, 0));
      expect(CellRef.format(27, 0), 'AB1');
      expect(CellRef.columnToIndex('AA'), 26);
      expect(CellRef.indexToColumn(26), 'AA');
      expect(CellRef.parse('not-a-ref'), isNull);
    });
  });

  group('FormulaEngine arithmetic', () {
    CellValue eval(String formula, [Map<String, String> cells = const {}]) {
      final engine = FormulaEngine({...cells, 'Z9': formula});
      return engine.evaluateCell('Z9');
    }

    test('basic operators and precedence', () {
      expect(eval('=2+3*4').number, 14);
      expect(eval('=(2+3)*4').number, 20);
      expect(eval('=10/4').number, 2.5);
      expect(eval('=2^10').number, 1024);
      expect(eval('=10%3').number, 1);
      expect(eval('=-5+3').number, -2);
      expect(eval('=1.5*2').number, 3);
    });

    test('cell references and dependent recalculation', () {
      final engine = FormulaEngine({
        'A1': '5',
        'A2': '7',
        'B1': '=A1+A2',
        'B2': '=B1*2',
      });
      final all = engine.evaluateAll();
      expect(all['B1']!.number, 12);
      expect(all['B2']!.number, 24);
    });

    test('aggregate functions over ranges', () {
      final cells = {'A1': '10', 'A2': '20', 'A3': '30', 'A4': '40'};
      expect(eval('=SUM(A1:A4)', cells).number, 100);
      expect(eval('=AVERAGE(A1:A4)', cells).number, 25);
      expect(eval('=COUNT(A1:A4)', cells).number, 4);
      expect(eval('=MIN(A1:A4)', cells).number, 10);
      expect(eval('=MAX(A1:A4)', cells).number, 40);
      expect(eval('=SUM(A1:A2, 5, B1)', {...cells, 'B1': '3'}).number, 38);
    });

    test('IF with comparisons', () {
      expect(eval('=IF(5>3, 100, 200)').number, 100);
      expect(eval('=IF(5<3, 100, 200)').number, 200);
      expect(eval('=IF(A1>=10, 1, 0)', {'A1': '10'}).number, 1);
      expect(eval('=IF(A1<>10, 1, 0)', {'A1': '10'}).number, 0);
    });

    test('error handling', () {
      expect(eval('=1/0').error, FormulaEngine.errDiv0);
      expect(eval('=NOSUCHFN(1)').error, FormulaEngine.errName);
      expect(eval('=A1+', {'A1': '1'}).error, FormulaEngine.errParse);
      expect(eval('=A1', {'A1': 'text'}).error, FormulaEngine.errValue);
    });

    test('circular references are detected, not crashed', () {
      final engine = FormulaEngine({'A1': '=B1+1', 'B1': '=A1+1'});
      final all = engine.evaluateAll();
      expect(all['A1']!.error, FormulaEngine.errCycle);
    });

    test('self reference is a cycle', () {
      final engine = FormulaEngine({'A1': '=A1+1'});
      expect(engine.evaluateCell('A1').error, FormulaEngine.errCycle);
    });

    test('empty cells resolve to zero inside formulas', () {
      expect(eval('=B7+5').number, 5);
    });

    test('text and numeric literals', () {
      final engine = FormulaEngine({'A1': 'Hello', 'A2': '42'});
      expect(engine.evaluateCell('A1').text, 'Hello');
      expect(engine.evaluateCell('A2').number, 42);
    });
  });
}

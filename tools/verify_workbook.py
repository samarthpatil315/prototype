#!/usr/bin/env python3
"""
Independent check of the DEMO workbook.

Recalculates the saved .xlsx with the `formulas` engine (no Excel involved),
prints the key figures and fails if any cell evaluates to an Excel error.

    python3 -m venv .venv && .venv/bin/pip install formulas
    .venv/bin/python tools/verify_workbook.py
"""

import sys
from pathlib import Path

import formulas

FILE = Path(__file__).resolve().parents[1] / "deliverables" / "Apex_Enterprises_Office_Management_DEMO.xlsx"
FN = FILE.name

PROBES = [
    # sheet, cell, expectation (None = just report), tolerance
    ("Attendance Oct-2026", "C40", 31, 0),        # calendar days
    ("Attendance Oct-2026", "C41", 4, 0),         # Sundays
    ("Attendance Oct-2026", "C42", 5, 0),         # Saturdays
    ("Attendance Oct-2026", "C43", 2, 0),         # declared holidays in the month
    ("Attendance Oct-2026", "C46", 27, 0),        # calendar days less Sundays
    ("Attendance Oct-2026", "C47", 25, 0),        # NET working days
    ("Attendance Oct-2026", "C48", 200, 0),       # standard hours
    ("Leave Records", "A5", 36, 0),               # requests logged
    ("Leave Records", "D5", 32, 0),               # approved or availed
    ("Leave Records", "G5", 61, 0),               # days taken
    ("Leave Records", "J5", 3, 0),                # pending
    ("Leave Records", "M5", 2, 0),                # LWP days
    ("Salary Calculation", "L34", 1447600, 0),    # monthly gross
    ("Salary Calculation", "X34", 1390550, 0),    # net payout
    ("Salary Calculation", "W34", 57050, 0),      # total deductions
    ("Salary Calculation", "Z34", 43200, 0),      # employer PF
    ("Salary Calculation", "S34", 7450, 0),       # attendance deduction
    ("Department Details", "D5", 26, 0),          # approved headcount
    ("Department Details", "F5", 24, 0),          # actual headcount
    ("Department Details", "K5", 2, 0),           # vacancies
    ("Department Details", "H5", 1630000, 0),     # monthly budget
    ("Department Details", "P17", 1447600, 0),    # actual monthly cost
    ("Dashboard", "L9", 0.96, 0.005),             # attendance %
    ("Dashboard", "V9", 7450, 0),                 # loss of pay
    ("Dashboard", "AA9", 2, 0),                   # vacancies
    ("Dashboard", "B14", 1447600, 0),             # gross
    ("Dashboard", "G14", 1390550, 0),             # net payout
]


def main():
    if not FILE.exists():
        sys.exit(f"missing {FILE} - run tools/build_employee_workbook.py first")
    model = formulas.ExcelModel().loads(str(FILE)).finish()
    sol = model.calculate()

    def value(sheet, cell):
        suffix = "]" + sheet.upper() + "'!" + cell
        for key, val in sol.items():
            if key.upper().endswith(suffix):
                try:
                    return val.value[0, 0]
                except Exception:
                    return None
        return None

    failures = 0
    print(f"{'sheet':22s} {'cell':6s} {'value':>14s} {'expected':>14s}")
    print("-" * 60)
    for sheet, cell, expected, tol in PROBES:
        got = value(sheet, cell)
        ok = True
        if expected is not None and isinstance(got, (int, float)):
            ok = abs(got - expected) <= tol
        elif expected is not None:
            ok = False
        failures += 0 if ok else 1
        print(f"{sheet:22s} {cell:6s} {str(round(got, 4) if isinstance(got, float) else got):>14s} "
              f"{str(expected):>14s}  {'' if ok else '<-- MISMATCH'}")

    error_cells = []
    for key, val in sol.items():
        try:
            x = val.value[0, 0]
        except Exception:
            continue
        if isinstance(x, str) and x.startswith("#"):
            error_cells.append(key.split("]")[-1])

    print("-" * 60)
    print(f"cells evaluated : {len(sol)}")
    print(f"Excel error cells: {len(error_cells)}")
    if error_cells:
        print("  first few:", error_cells[:10])
    print("RESULT:", "PASS" if failures == 0 and not error_cells else "FAIL")
    return 0 if failures == 0 and not error_cells else 1


if __name__ == "__main__":
    sys.exit(main())

# Apex Enterprises — Office Management DEMO Workbook

**File:** `deliverables/Apex_Enterprises_Office_Management_DEMO.xlsx`
**Type:** editable Excel workbook (.xlsx, no macros — opens in Excel 2016+, LibreOffice Calc, Google Sheets)
**Status:** **DEMO** — every company, person, e-mail, phone number and amount is fictional

A formula-driven office administration pack for a fictional Pune-based company, "Apex Enterprises".
Replace the sample data with real data and the attendance, leave, salary and dashboard figures
recalculate themselves. There are no hard-coded summary numbers anywhere.

---

## 1. What is inside

| # | Tab | What it holds |
|---|-----|----------------|
| 1 | **Dashboard** | Management view: 6 people KPIs, 6 payroll KPIs, 3 insight cards, 4 charts, a department league table and a reading guide |
| 2 | **Attendance Oct-2026** | A calendar per employee for the payroll month + a 12-step working-day calculator |
| 3 | **Leave Records** | Leave register (36 requests), live balance matrix, editable leave policy, chart |
| 4 | **Salary Calculation** | Payroll register for 24 employees + position salary template + pay-policy block |
| 5 | **Employee Database** | Master record: 24 employees, 21 columns, 5 calculated columns |
| 6 | **Contact Directory** | Filterable directory, quick-lookup panel, extension quick-dial |
| 7 | **Department Details** | 8 departments with budgets, approved headcount, live cost/tenure roll-up, department inspector |
| 8 | **Holidays** | 2026 declared-holiday calendar (list is extendable to row 40) |
| 9 | **Usage Guide** | In-workbook manual: sheets, daily tasks, every calculation, data validation, limitations |
| 10 | **Lists** | Drop-down sources + the single reporting-month switch (internal) |

### Sample data at a glance
- 24 fictional employees, 8 departments, 22 positions, 5 leave types, 7 attendance codes
- Reporting month: **October 2026** (31 calendar days, 4 Sundays, 2 declared holidays → **25 working days**). The dates were chosen so the demo lands on 22 weekdays + 2 Saturdays + 1 working Sunday, which is exactly the 25 that the calculator returns.
- 36 leave requests spread across the year, including one pending and one rejected, so every status colour is visible
- A few deliberately unbalanced cases so the calculations are visible in action: 2 unmarked absences, 2 leave-without-pay days, 3 half days, 2 work-from-home days, 1 extra weekly off and 1 Sunday worked (overtime-equivalent)

---

## 2. Five-minute tour

1. **Open the Dashboard.** Everything is a formula. Note the five/six-figure totals at the top.
2. **Go to Employee Database → row 24 (Harish Nambiar).** Change his Designation to `Senior Process Associate`
   and watch his Basic, HRA, net salary and the whole payroll total move.
3. **Go to Attendance Oct-2026.** The day grid is pre-filled: `P` for present, `WO` for Sundays, `HOL` for the
   two declared holidays, `L`/`LWP` stamped from the leave register. Overwrite one `P` with `H` (absent) and see
   *Paid Days*, *Attendance %* and *Unpaid Shortfall* change, plus the loss-of-pay figure on the dashboard.
4. **Go to Leave Records, section A.** Add a row: pick an Employee ID, `Earned Leave`, a date in October, 2 days,
   status `Approved`. The attendance grid immediately shows `L` on those days, and the balance matrix drops by 2.
5. **Change the reporting month.** Go to **Lists → A5** and enter `01-Nov-2026`. The attendance title, the day
   grid, working days, the salary day columns and the dashboard all rebuild for November.

---

## 3. How the calculations work

### Working days (attendance sheet, "Working-day calculator" block, column C)
This demo treats **Sunday as the weekly off** and **Saturday as a working day** — typical for a small Indian
office that works six days a week:

```
Calendar days                      31
- Sundays                           4
- Saturdays                          5   (reference only; they stay working days)
= Working days (5-day week ref)     22
- Declared holidays on a Mon-Sat     2   (Fri 2 Oct Gandhi Jayanti, Wed 21 Oct Dussehra)
= NET WORKING DAYS                  25   <-- used by attendance % and payroll
```

Every step is a separate visible formula, so if your office is a five-day week you can switch the model by
changing the *net working days* row — the rest of the workbook follows automatically.

### Attendance (blue columns on the right of the grid)
| Column | Formula |
|---|---|
| Payable Days | P + WFH + HD + L + LWP + WO + HOL + H (audit count = days in the month) |
| Present Days | P + WFH + (HD × 0.5) |
| Paid Days | MIN(net working days, Present Days + paid leave) |
| Attendance % | Present Days ÷ net working days |
| Extras | MAX(0, Present Days − net working days) → paid at 1.5× as overtime-equivalent |
| Unpaid Shortfall | MAX(0, net working days − Paid Days) → drives loss of pay |

### Leave balances (Leave Records, section B)
`Remaining = entitlement − days already approved or availed`, where the entitlement comes from the editable
policy in section C: **Earned 18, Casual 12, Sick 10** days per year. Comp Off and Leave Without Pay have no
entitlement and are tracked as days used. Pending and rejected requests never reduce a balance.

### Salary (Salary Calculation)
```
Basic            ← Position Salary Template, matched on Designation
HRA              = 40% of Basic
Gross            = Basic + HRA + Conveyance + Special Allowance
Per-day rate     = Gross ÷ net working days
Paid days        ← attendance sheet
Attendance dedn  = Unpaid Shortfall × per-day rate
PF (employee)    = 12% of Basic, capped at a ₹15,000 wage ceiling
Professional tax = ₹200 above ₹15,000 gross, ₹150 above ₹10,000, else nil
Net salary       = Gross − attendance dedn − PF − PT − other deductions (never below zero)
Employer PF      = same 12% cap, shown as an extra cost (not deducted from net)
```

### Department roll-up (Department Details)
Employees, active/probation/notice counts, vacancies, headcount utilisation, actual monthly cost (sum of gross
by department), budget utilisation, average tenure and hours per month are all live `COUNTIFS`/`SUMIF`/`AVERAGEIF`
formulas pointing at the other sheets.

---

## 4. Data validation

| Where | Input rule |
|---|---|
| Employee Database: Department, Designation, Grade, Location, Shift, Status, Gender, Blood Group, Employment Type | Drop-downs, all sourced from visible lists you can extend |
| Employee Database: Date of Joining, Extension, Work e-mail length | Date range, 4-digit whole number, ≤ 60 characters |
| Attendance day grid | Drop-down: `P, WFH, HD, L, LWP, WO, HOL, H` — anything else is rejected |
| Leave Records: Employee ID / Leave Type / Status / From date / Days | Validated against the database, the leave policy, a date range and 0.5–60 days |
| Leave policy: entitlement | Whole number 0–60 |
| Salary template: Basic, allowances | 5,000–5,00,000 / 0–2,00,000, with a clear error message |
| Salary register: Other deductions | Must be zero or positive |
| Department master: budget, approved headcount | Numeric range, whole number 0–500 |
| Holidays: date, type | 2026–2027 dates, fixed type list |
| Contact Directory: personal e-mail | Must contain "@" |
| Lists: reporting month | Any date 2026–2030 |

Every drop-down also shows an input prompt explaining what to pick.

---

## 5. Colour key

| Colour | Meaning |
|---|---|
| Navy | Headers, section rules, totals |
| Gold / amber | The month switch and the amber cells are the ones you are meant to change |
| Blue cells | Automatic — formulas you should not type over |
| Green / red / amber fills | Present & money-in / shortfall, deduction, vacancy / pending or attention needed |
| Pale row bands | Alternating bands for readability only |

---

## 6. Editing rules

- **Do not type in** Employee Database Q–T · Attendance AI–AV · Leave Records B, C, E, K–N · Salary Calculation
  G–Y · Contact Directory A–F, I · Department Details I–V. They carry formulas.
- **Add employees in the first empty row (34 onward) and filter rather than re-sort** — the attendance, leave,
  salary and contact sheets point at specific Employee Database rows.
- **Mark leavers, do not delete them:** set Status to `Notice Period` or `Exited`.
- **Month-end:** save a copy named for the month, then change `Lists!A5` and clear the typed attendance codes so
  the previous month's exceptions do not carry over.
- Press **F9** if a figure ever looks stale (the workbook is set to recalculate fully on open).

---

## 7. Important limitations — please read

- **Illustrative, not statutory.** HRA at 40%, a 12% PF cap, simplified professional-tax slabs and 1.5× overtime
  are demonstration rules. Real Indian payroll also involves ESI, gratuity, TDS, statutory bonus and
  state-specific professional tax — none of that is modelled here.
- **All data is fictional.** Apex Enterprises, its employees, the `apex-demo.example` domain, phone numbers,
  addresses and budgets are invented. Do not use them for real correspondence or payments.
- **One payroll month.** The attendance grid covers a single month; keep month-end copies for history.
- **The attendance sheet name** (`Attendance Oct-2026`) is a label only. If you change the reporting month, rename
  the tab when you archive it.
- **Before real use:** replace the sample rows, rebuild the pay template against your own salary structure, and
  have HR and finance sign off on the statutory assumptions.

---

## 8. Rebuilding or extending the demo

The workbook is generated by a script so it can be regenerated or re-themed:

```bash
python3 -m venv .venv && .venv/bin/pip install openpyxl
.venv/bin/python tools/build_employee_workbook.py        # rebuilds the .xlsx
.venv/bin/python tools/verify_workbook.py                # optional: recalculates and prints key figures
```

`tools/verify_workbook.py` uses the `formulas` package to recalculate the saved file independently of Excel;
on the shipped workbook it reports **0 error cells across ~5,000 evaluated cells**, and the key figures below.

### Verified values on the shipped file (October 2026)

| Measure | Value |
|---|---|
| Employees / departments | 24 / 8 |
| Calendar days · Sundays · declared holidays · **net working days** | 31 · 4 · 2 · **25** |
| Total present days (all employees) | 575 |
| Headcount-weighted attendance | 96% |
| Leave requests / approved-or-availed / days taken / pending / LWP | 36 / 32 / 61 / 3 / 2 |
| Monthly gross · net payout · deductions · employer PF | ₹14,47,600 · ₹13,90,550 · ₹57,050 · ₹43,200 |
| Loss of pay recovered | ₹5,806 |
| Approved headcount · actual headcount · vacancies | 26 · 24 · 2 |
| Monthly department budget vs actual cost | ₹16,30,000 vs ₹14,47,600 (88.8%) |

---

*Prepared as a DEMO deliverable: fictional company, sample data, editable formulas and an in-workbook usage guide.*

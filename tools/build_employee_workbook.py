#!/usr/bin/env python3
"""
Builder for the Apex Enterprises - Office Management DEMO workbook.

Run:  python3 tools/build_employee_workbook.py
Out:  deliverables/Apex_Enterprises_Office_Management_DEMO.xlsx

Design notes
------------
* Everything derived (attendance counts, balances, salary, dashboard) is a live
  formula, so the workbook stays editable: replace sample data, figures recalc.
* Column letters are computed, never hand-typed, to keep formulas aligned.
* The only macros-free approach is used, so the file opens in Excel, LibreOffice
  Calc and Google Sheets.
"""

import calendar
import datetime as dt
import random
from pathlib import Path

from openpyxl import Workbook
from openpyxl.chart import BarChart, DoughnutChart, PieChart, Reference
from openpyxl.chart.label import DataLabelList
from openpyxl.chart.marker import DataPoint
from openpyxl.comments import Comment
from openpyxl.formatting.rule import CellIsRule, ColorScaleRule, DataBarRule
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter as CL
from openpyxl.workbook.defined_name import DefinedName
from openpyxl.workbook.properties import CalcProperties
from openpyxl.worksheet.properties import PageSetupProperties
from openpyxl.worksheet.datavalidation import DataValidation

OUT_DIR = Path(__file__).resolve().parents[1] / "deliverables"
OUT_FILE = OUT_DIR / "Apex_Enterprises_Office_Management_DEMO.xlsx"

# --------------------------------------------------------------------------
# Palette
# --------------------------------------------------------------------------
NAVY = "16294B"
NAVY_SOFT = "24406E"
ACCENT = "C8963E"
GOLD_RULE = "E2C98A"
TEAL = "1F6F78"
TEAL_BG = "D7EAEC"
GREY_BG = "F2F4F7"
GREY_LINE = "D3D8E0"
WHITE = "FFFFFF"
TEXT = "1F2430"
MUTED = "5B6472"
GREEN = "1E7A4B"
GREEN_BG = "DDF1E4"
AMBER = "B4762A"
AMBER_BG = "FCEFD6"
RED = "B3261E"
RED_BG = "FBE4E2"
BLUE_BG = "E4EDF9"
PURPLE = "6B3FA0"

FONT_NAME = "Calibri"
THIN = Side(style="thin", color=GREY_LINE)
BOX = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)


def font(size=10, bold=False, color=TEXT, italic=False):
    return Font(name=FONT_NAME, size=size, bold=bold, color=color, italic=italic)


def fill(color):
    return PatternFill("solid", start_color=color, end_color=color)


def title_block(ws, title, subtitle, last_col=8, banner_rows=2):
    for r in range(1, banner_rows + 1):
        for c in range(1, last_col + 1):
            ws.cell(row=r, column=c).fill = fill(NAVY)
    last = CL(last_col)
    ws.merge_cells(f"A1:{last}1")
    ws.merge_cells(f"A2:{last}2")
    ws["A1"] = title
    ws["A1"].font = font(15, True, WHITE)
    ws["A1"].alignment = Alignment(vertical="center", horizontal="left", indent=1)
    ws["A2"] = subtitle
    ws["A2"].font = font(9, False, "C9D4E6", italic=True)
    ws["A2"].alignment = Alignment(vertical="center", horizontal="left", indent=1)
    ws.row_dimensions[1].height = 30
    ws.row_dimensions[2].height = 18
    rule = banner_rows + 1
    for c in range(1, last_col + 1):
        ws.cell(row=rule, column=c).fill = fill(ACCENT)
    ws.row_dimensions[rule].height = 4


def section(ws, row, text, last_col=8, color=NAVY):
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=last_col)
    cell = ws.cell(row=row, column=1, value=text)
    cell.font = font(10.5, True, color)
    cell.alignment = Alignment(vertical="center", indent=1)
    for c in range(1, last_col + 1):
        ws.cell(row=row, column=c).border = Border(
            bottom=Side(style="thin", color=GOLD_RULE))
    ws.row_dimensions[row].height = 20


def header_row(ws, row, headers, widths=None, height=32, start_col=1):
    for i, h in enumerate(headers):
        c = ws.cell(row=row, column=start_col + i, value=h)
        c.font = font(9.5, True, WHITE)
        c.fill = fill(NAVY)
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        c.border = Border(left=Side(style="thin", color=NAVY_SOFT),
                          right=Side(style="thin", color=NAVY_SOFT),
                          bottom=Side(style="medium", color=ACCENT))
    ws.row_dimensions[row].height = height
    if widths:
        for i, w in enumerate(widths):
            ws.column_dimensions[CL(start_col + i)].width = w


def zebra(ws, first_row, last_row, first_col, last_col, band=GREY_BG):
    for r in range(first_row, last_row + 1):
        for c in range(first_col, last_col + 1):
            cell = ws.cell(row=r, column=c)
            cell.border = BOX
            if (r - first_row) % 2 == 1:
                cell.fill = fill(band)


def note(ws, row, text, last_col=8, color=MUTED, size=8.5, merge=True):
    if merge:
        ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=last_col)
    c = ws.cell(row=row, column=1, value=text)
    c.font = font(size, False, color, italic=True)
    c.alignment = Alignment(vertical="center", wrap_text=True, indent=1)
    ws.row_dimensions[row].height = 15


def kpi2(ws, row, col, label, value_formula, sub, accent, fmt="0"):
    """3-row KPI tile spanning two columns: label / big value / sub-note."""
    lab = ws.cell(row=row, column=col, value=label)
    val = ws.cell(row=row + 1, column=col, value=value_formula)
    nt = ws.cell(row=row + 2, column=col, value=sub)
    ws.merge_cells(start_row=row, start_column=col, end_row=row, end_column=col + 1)
    ws.merge_cells(start_row=row + 1, start_column=col, end_row=row + 1, end_column=col + 1)
    ws.merge_cells(start_row=row + 2, start_column=col, end_row=row + 2, end_column=col + 1)
    border = Border(left=Side(style="thick", color=accent), top=THIN, right=THIN, bottom=THIN)
    for r in range(row, row + 3):
        for cc in (col, col + 1):
            cell = ws.cell(row=r, column=cc)
            cell.fill = fill(WHITE)
            cell.border = border
    lab.font = font(8.5, True, MUTED)
    lab.alignment = Alignment(horizontal="left", vertical="center", indent=1)
    val.font = font(16, True, NAVY)
    val.alignment = Alignment(horizontal="left", vertical="center", indent=1)
    val.number_format = fmt
    nt.font = font(7.5, False, MUTED, italic=True)
    nt.alignment = Alignment(horizontal="left", vertical="center", indent=1)
    ws.row_dimensions[row].height = 15
    ws.row_dimensions[row + 1].height = 25
    ws.row_dimensions[row + 2].height = 14


def kpi_wide(ws, row, col, span, label, value_formula, sub, accent, fmt="0"):
    """KPI tile spanning `span` columns - used on the dashboard grid."""
    lab = ws.cell(row=row, column=col, value=label)
    val = ws.cell(row=row + 1, column=col, value=value_formula)
    nt = ws.cell(row=row + 2, column=col, value=sub)
    for r in range(row, row + 3):
        ws.merge_cells(start_row=r, start_column=col, end_row=r, end_column=col + span - 1)
    border = Border(left=Side(style="thick", color=accent), top=THIN, right=THIN, bottom=THIN)
    for r in range(row, row + 3):
        for cc in range(col, col + span):
            cell = ws.cell(row=r, column=cc)
            cell.fill = fill(WHITE)
            cell.border = border
    lab.font = font(9, True, MUTED)
    lab.alignment = Alignment(horizontal="left", vertical="center", indent=1)
    val.font = font(17, True, NAVY)
    val.alignment = Alignment(horizontal="left", vertical="center", indent=1)
    val.number_format = fmt
    nt.font = font(8, False, MUTED, italic=True)
    nt.alignment = Alignment(horizontal="left", vertical="center", indent=1)
    ws.row_dimensions[row].height = 16
    ws.row_dimensions[row + 1].height = 30
    ws.row_dimensions[row + 2].height = 15


# --------------------------------------------------------------------------
# Sample master data (all fictional)
# --------------------------------------------------------------------------
random.seed(20261117)

MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

DEPTS = [
    # code, name, head, cost centre, location, shift, monthly budget, extension, email, approved headcount
    ("OPS", "Operations", "Rohan Deshmukh", "CC-1001", "Pune HQ", "General (9:30-18:30)",
     280000, "2101", "operations@apex-demo.example", 5),
    ("HR", "Human Resources", "Ananya Iyer", "CC-1002", "Pune HQ", "General (9:30-18:30)",
     150000, "2102", "hr@apex-demo.example", 3),
    ("FIN", "Finance & Accounts", "Sanjay Kulkarni", "CC-1003", "Pune HQ", "General (9:30-18:30)",
     220000, "2103", "finance@apex-demo.example", 3),
    ("SAL", "Sales", "Meera Joshi", "CC-1004", "Pune HQ", "General (9:30-18:30)",
     215000, "2104", "sales@apex-demo.example", 3),
    ("MKT", "Marketing", "Kabir Nair", "CC-1005", "Pune HQ", "General (9:30-18:30)",
     145000, "2105", "marketing@apex-demo.example", 2),
    ("IT", "Information Technology", "Vikram Sethi", "CC-1006", "Pune HQ", "General (9:30-18:30)",
     310000, "2106", "it.support@apex-demo.example", 4),
    ("CS", "Client Services", "Priya Menon", "CC-1007", "Pune HQ", "General (9:30-18:30)",
     170000, "2107", "clientservices@apex-demo.example", 3),
    ("ADM", "Administration", "Neha Kulkarni", "CC-1008", "Pune HQ", "General (9:30-18:30)",
     140000, "2108", "admin@apex-demo.example", 3),
]

FEMALE = {"Ananya Iyer", "Meera Joshi", "Priya Menon", "Neha Kulkarni", "Sneha Rane",
          "Nisha Kamble", "Kavya Pillai", "Divya Shetty", "Tanvi Bhosale", "Ishita Verma",
          "Pooja Sawant"}

# id, name, dept, designation, grade, location, shift, doj, email, personal, extension,
# mobile, emergency contact, emergency phone, address, blood group
EMPLOYEES = [
    ("EMP-1001", "Rohan Deshmukh", "Operations", "Operations Manager", "M2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2019, 4, 15), "rohan.deshmukh@apex-demo.example",
     "rohan.d@example.com", "2201", "+91 98200 11001", "Smita Deshmukh", "+91 98200 21001",
     "12B, Silver Oak, Kothrud, Pune 411038", "B+"),
    ("EMP-1002", "Ananya Iyer", "Human Resources", "HR Manager", "M2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2018, 7, 2), "ananya.iyer@apex-demo.example",
     "ananya.iyer@example.com", "2202", "+91 98200 11002", "Ramesh Iyer", "+91 98200 21002",
     "Flat 7, Green Meadows, Baner, Pune 411045", "O+"),
    ("EMP-1003", "Sanjay Kulkarni", "Finance & Accounts", "Finance Controller", "M2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2017, 1, 9), "sanjay.kulkarni@apex-demo.example",
     "sanjay.k@example.com", "2203", "+91 98200 11003", "Vaishali Kulkarni", "+91 98200 21003",
     "Plot 21, Shanti Residency, Aundh, Pune 411007", "A+"),
    ("EMP-1004", "Meera Joshi", "Sales", "Sales Manager", "M1", "Pune HQ",
     "General (9:30-18:30)", dt.date(2020, 2, 17), "meera.joshi@apex-demo.example",
     "meera.joshi@example.com", "2204", "+91 98200 11004", "Aniket Joshi", "+91 98200 21004",
     "A-304, Sunrise Towers, Wakad, Pune 411057", "B+"),
    ("EMP-1005", "Kabir Nair", "Marketing", "Marketing Manager", "M1", "Pune HQ",
     "General (9:30-18:30)", dt.date(2021, 6, 1), "kabir.nair@apex-demo.example",
     "kabir.nair@example.com", "2205", "+91 98200 11005", "Latha Nair", "+91 98200 21005",
     "5, Palm Grove, Viman Nagar, Pune 411014", "AB+"),
    ("EMP-1006", "Vikram Sethi", "Information Technology", "IT Manager", "M2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2016, 11, 21), "vikram.sethi@apex-demo.example",
     "vikram.sethi@example.com", "2206", "+91 98200 11006", "Ritu Sethi", "+91 98200 21006",
     "C-9, Tech Park Residences, Hinjewadi, Pune 411057", "O-"),
    ("EMP-1007", "Priya Menon", "Client Services", "Client Services Lead", "M1", "Pune HQ",
     "General (9:30-18:30)", dt.date(2019, 9, 30), "priya.menon@apex-demo.example",
     "priya.menon@example.com", "2207", "+91 98200 11007", "Suresh Menon", "+91 98200 21007",
     "14, Lake View, Kalyani Nagar, Pune 411006", "A-"),
    ("EMP-1008", "Neha Kulkarni", "Administration", "Admin Manager", "M1", "Pune HQ",
     "General (9:30-18:30)", dt.date(2020, 8, 10), "neha.kulkarni@apex-demo.example",
     "neha.k@example.com", "2208", "+91 98200 11008", "Prakash Kulkarni", "+91 98200 21008",
     "3, Maple Court, Pashan, Pune 411021", "B-"),
    ("EMP-1009", "Arjun Patel", "Operations", "Senior Process Associate", "E3", "Pune HQ",
     "General (9:30-18:30)", dt.date(2021, 3, 8), "arjun.patel@apex-demo.example",
     "arjun.patel@example.com", "2209", "+91 98200 11009", "Nilesh Patel", "+91 98200 21009",
     "B-12, Riverdale, Pimple Saudagar, Pune 411027", "O+"),
    ("EMP-1010", "Sneha Rane", "Operations", "Process Associate", "E2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2022, 5, 23), "sneha.rane@apex-demo.example",
     "sneha.rane@example.com", "2210", "+91 98200 11010", "Uday Rane", "+91 98200 21010",
     "22, Sai Heights, Chinchwad, Pune 411033", "A+"),
    ("EMP-1011", "Rahul Bhat", "Operations", "Process Associate", "E2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2023, 1, 16), "rahul.bhat@apex-demo.example",
     "rahul.bhat@example.com", "2211", "+91 98200 11011", "Sushma Bhat", "+91 98200 21011",
     "6, Ganga Apartments, Kharadi, Pune 411014", "B+"),
    ("EMP-1012", "Nisha Kamble", "Human Resources", "HR Executive", "E2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2022, 11, 14), "nisha.kamble@apex-demo.example",
     "nisha.kamble@example.com", "2212", "+91 98200 11012", "Ganesh Kamble", "+91 98200 21012",
     "9, Vasant Vihar, Karve Nagar, Pune 411052", "O+"),
    ("EMP-1013", "Aditya Rao", "Finance & Accounts", "Accounts Executive", "E2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2021, 7, 5), "aditya.rao@apex-demo.example",
     "aditya.rao@example.com", "2213", "+91 98200 11013", "Shobha Rao", "+91 98200 21013",
     "17, Deepali Residency, Dhanori, Pune 411015", "AB-"),
    ("EMP-1014", "Kavya Pillai", "Finance & Accounts", "Accounts Assistant", "E1", "Pune HQ",
     "General (9:30-18:30)", dt.date(2024, 2, 1), "kavya.pillai@apex-demo.example",
     "kavya.pillai@example.com", "2214", "+91 98200 11014", "Mohan Pillai", "+91 98200 21014",
     "44, Gokul Nagar, Hadapsar, Pune 411028", "B+"),
    ("EMP-1015", "Imran Shaikh", "Sales", "Senior Sales Executive", "E3", "Pune HQ",
     "General (9:30-18:30)", dt.date(2020, 10, 12), "imran.shaikh@apex-demo.example",
     "imran.shaikh@example.com", "2215", "+91 98200 11015", "Farida Shaikh", "+91 98200 21015",
     "8, Aman Plaza, Camp, Pune 411001", "O+"),
    ("EMP-1016", "Divya Shetty", "Sales", "Sales Executive", "E2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2023, 4, 3), "divya.shetty@apex-demo.example",
     "divya.shetty@example.com", "2216", "+91 98200 11016", "Ravi Shetty", "+91 98200 21016",
     "31, Blue Bell, Magarpatta, Pune 411013", "A+"),
    ("EMP-1017", "Yash Chavan", "Marketing", "Content Specialist", "E2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2022, 8, 22), "yash.chavan@apex-demo.example",
     "yash.chavan@example.com", "2217", "+91 98200 11017", "Manisha Chavan", "+91 98200 21017",
     "2, Shubhankar, NIBM Road, Pune 411048", "B-"),
    ("EMP-1018", "Farhan Qureshi", "Information Technology", "Senior Developer", "E3", "Pune HQ",
     "General (9:30-18:30)", dt.date(2019, 5, 27), "farhan.qureshi@apex-demo.example",
     "farhan.q@example.com", "2218", "+91 98200 11018", "Ayesha Qureshi", "+91 98200 21018",
     "19, Cyber Heights, Balewadi, Pune 411045", "O+"),
    ("EMP-1019", "Tanvi Bhosale", "Information Technology", "Support Engineer", "E2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2023, 9, 11), "tanvi.bhosale@apex-demo.example",
     "tanvi.bhosale@example.com", "2219", "+91 98200 11019", "Santosh Bhosale", "+91 98200 21019",
     "27, Krishna Kunj, Katraj, Pune 411046", "A+"),
    ("EMP-1020", "Manish Gupta", "Information Technology", "Network Administrator", "E2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2021, 12, 6), "manish.gupta@apex-demo.example",
     "manish.gupta@example.com", "2220", "+91 98200 11020", "Rekha Gupta", "+91 98200 21020",
     "5, Shivneri, Warje, Pune 411058", "B+"),
    ("EMP-1021", "Ishita Verma", "Client Services", "Client Support Executive", "E2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2022, 3, 14), "ishita.verma@apex-demo.example",
     "ishita.verma@example.com", "2221", "+91 98200 11021", "Ajay Verma", "+91 98200 21021",
     "11, Rose Villa, Kondhwa, Pune 411048", "AB+"),
    ("EMP-1022", "Siddharth Kale", "Client Services", "Client Support Executive", "E1", "Pune HQ",
     "General (9:30-18:30)", dt.date(2024, 7, 15), "siddharth.kale@apex-demo.example",
     "siddharth.kale@example.com", "2222", "+91 98200 11022", "Vandana Kale", "+91 98200 21022",
     "36, Omkar Residency, Thergaon, Pune 411033", "O-"),
    ("EMP-1023", "Pooja Sawant", "Administration", "Office Coordinator", "E2", "Pune HQ",
     "General (9:30-18:30)", dt.date(2021, 10, 18), "pooja.sawant@apex-demo.example",
     "pooja.sawant@example.com", "2223", "+91 98200 11023", "Milind Sawant", "+91 98200 21023",
     "4, Sanskruti, Bhumkar Chowk, Pune 411057", "B+"),
    ("EMP-1024", "Harish Nambiar", "Administration", "Facilities Assistant", "E1", "Pune HQ",
     "General (9:30-18:30)", dt.date(2019, 8, 5), "harish.nambiar@apex-demo.example",
     "harish.nambiar@example.com", "2224", "+91 98200 11024", "Geeta Nambiar", "+91 98200 21024",
     "10, Anand Park, Vadgaon, Pune 411041", "A+"),
]

# title, department, grade, basic, conveyance, special allowance
POSITIONS = [
    ("Operations Manager", "Operations", "M2", 62500, 6000, 12000),
    ("HR Manager", "Human Resources", "M2", 57500, 5500, 11000),
    ("Finance Controller", "Finance & Accounts", "M2", 65000, 6000, 13000),
    ("Sales Manager", "Sales", "M1", 52500, 6000, 10000),
    ("Marketing Manager", "Marketing", "M1", 50000, 5500, 9500),
    ("IT Manager", "Information Technology", "M2", 67500, 6000, 13000),
    ("Client Services Lead", "Client Services", "M1", 47500, 5000, 9000),
    ("Admin Manager", "Administration", "M1", 42500, 4500, 7500),
    ("Senior Process Associate", "Operations", "E3", 31000, 3500, 6000),
    ("Process Associate", "Operations", "E2", 24000, 3000, 4500),
    ("HR Executive", "Human Resources", "E2", 25000, 3000, 4000),
    ("Accounts Executive", "Finance & Accounts", "E2", 27000, 3000, 4500),
    ("Accounts Assistant", "Finance & Accounts", "E1", 19000, 2500, 2500),
    ("Senior Sales Executive", "Sales", "E3", 33000, 4000, 9000),
    ("Sales Executive", "Sales", "E2", 23000, 3500, 7000),
    ("Content Specialist", "Marketing", "E2", 26000, 3000, 3500),
    ("Senior Developer", "Information Technology", "E3", 46000, 4000, 7000),
    ("Support Engineer", "Information Technology", "E2", 27500, 3000, 4000),
    ("Network Administrator", "Information Technology", "E2", 29000, 3000, 4500),
    ("Client Support Executive", "Client Services", "E2", 21000, 2500, 3000),
    ("Office Coordinator", "Administration", "E2", 20000, 2500, 2500),
    ("Facilities Assistant", "Administration", "E1", 15000, 2000, 1500),
]
POS_BY_TITLE = {p[0]: p for p in POSITIONS}

# code, name, entitlement, tracked balance?, rule
LEAVE_TYPES = [
    ("EL", "Earned Leave", 18, True, "Accrues 1.5 days per completed month of service"),
    ("CL", "Casual Leave", 12, True, "Short unplanned absence, maximum 3 days at a time"),
    ("SL", "Sick Leave", 10, True, "Medical certificate required beyond 2 consecutive days"),
    ("CO", "Comp Off", 0, False, "Credited against approved weekend or holiday work"),
    ("LWP", "Leave Without Pay", 0, False, "No entitlement - unpaid days, salary deduction applies"),
]
LEAVE_NAMES = [t[1] for t in LEAVE_TYPES]
ENTITLEMENT = {t[1]: t[2] for t in LEAVE_TYPES}

ATT_CODES = [
    ("P", "Present"),
    ("WFH", "Work From Home"),
    ("HD", "Half Day"),
    ("L", "Paid leave"),
    ("LWP", "Leave without pay"),
    ("WO", "Weekly Off"),
    ("HOL", "Holiday"),
    ("H", "Absent / Unmarked"),
]
ATT_LABEL = {c[0]: c[1] for c in ATT_CODES}
ATT_STYLE = {
    "P": ("C6EFCE", "0B5D2E"),
    "WFH": ("D6E9F8", "1F4E79"),
    "HD": ("FFE9C7", "7A4E00"),
    "L": ("FBD9D5", "8C1D18"),
    "LWP": ("F6D9B8", "7A4212"),
    "H": ("F4C7C3", "7A1210"),
    "WO": ("E9E9E9", "6B7280"),
    "HOL": ("EDE2F5", "5B2D8E"),
}

HOLIDAYS = [
    (dt.date(2026, 1, 1), "New Year's Day", "National"),
    (dt.date(2026, 1, 26), "Republic Day", "National"),
    (dt.date(2026, 3, 4), "Holi", "Festival"),
    (dt.date(2026, 5, 1), "Maharashtra Day", "State"),
    (dt.date(2026, 8, 15), "Independence Day", "National"),
    (dt.date(2026, 9, 14), "Ganesh Chaturthi", "Festival"),
    (dt.date(2026, 10, 2), "Gandhi Jayanti", "National"),
    (dt.date(2026, 10, 21), "Dussehra", "Festival"),
    (dt.date(2026, 11, 9), "Diwali - Laxmi Puja", "Festival"),
    (dt.date(2026, 11, 10), "Diwali - Balipratipada", "Festival"),
    (dt.date(2026, 12, 25), "Christmas Day", "Festival"),
]
HOLIDAY_MAP = {d: n for d, n, _t in HOLIDAYS}

PAY_YEAR, PAY_MONTH = 2026, 10
DAYS_IN_MONTH = calendar.monthrange(PAY_YEAR, PAY_MONTH)[1]
PAY_MONTH_LABEL = f"{calendar.month_name[PAY_MONTH]} {PAY_YEAR}"
MONTH_CELL = "Lists!$A$5"
MONTH_DATE = f"DATE(YEAR({MONTH_CELL}),MONTH({MONTH_CELL}),1)"

# --------------------------------------------------------------------------
# Row / column plan
# --------------------------------------------------------------------------
EMP_SHEET = "Employee Database"
ATT_SHEET = "Attendance Oct-2026"
LEAVE_SHEET = "Leave Records"
SAL_SHEET = "Salary Calculation"
DEPT_SHEET = "Department Details"
CONTACT_SHEET = "Contact Directory"
DASH_SHEET = "Dashboard"
GUIDE_SHEET = "Usage Guide"
HOL_SHEET = "Holidays"
LISTS_SHEET = "Lists"

FIRST = 10
LAST = 33
N_EMP = len(EMPLOYEES)
assert N_EMP == LAST - FIRST + 1

# employee database columns
E_ID, E_NAME, E_DEPT, E_DESIG, E_GRADE, E_LOC, E_STATUS, E_DOJ = 1, 2, 3, 4, 5, 6, 7, 8
E_MAIL, E_EXT, E_GENDER, E_BLOOD, E_MGR, E_ROLE, E_TYPE, E_CTC = 9, 10, 11, 12, 13, 14, 15, 16
E_TENURE, E_SVCSTAT, E_BAND, E_PROB = 17, 18, 19, 20
E_SHIFT = 21
EMP_LAST_COL = E_SHIFT

# attendance columns
ATT_DAY_FIRST = 4
ATT_DAY_LAST = ATT_DAY_FIRST + DAYS_IN_MONTH - 1
AC_P = ATT_DAY_LAST + 1
AC_WFH, AC_HD, AC_L, AC_LWP, AC_WO, AC_HOL, AC_H = (
    AC_P + 1, AC_P + 2, AC_P + 3, AC_P + 4, AC_P + 5, AC_P + 6, AC_P + 7)
AC_PAYABLE = AC_H + 1
AC_PRESENT = AC_PAYABLE + 1
AC_PAID = AC_PRESENT + 1
AC_PCT = AC_PAID + 1
AC_EXTRA = AC_PCT + 1
AC_SHORT = AC_EXTRA + 1
ATT_LAST_COL = AC_SHORT

# salary columns
SC_ID, SC_NAME, SC_DEPT, SC_DESIG, SC_GRADE, SC_DOJ = 1, 2, 3, 4, 5, 6
SC_BASIC, SC_HRA, SC_CONV, SC_SPEC = 7, 8, 9, 10
SC_ALLOW, SC_GROSS = 11, 12
SC_WDAYS, SC_PRESENT, SC_PAID, SC_LWP = 13, 14, 15, 16
SC_RATE, SC_OT, SC_DED_ATT = 17, 18, 19
SC_PF, SC_PT, SC_OTHER, SC_TOTDED, SC_NET, SC_ANNUAL = 20, 21, 22, 23, 24, 25
SC_ERPF, SC_CTC = 26, 27

SAL_TMPL_HDR = 45
SAL_TMPL_FIRST = SAL_TMPL_HDR + 1
SAL_TMPL_LAST = SAL_TMPL_FIRST + 60

LV_FIRST, LV_LAST = 10, 45
LVR = "'Leave Records'"
LV_ABS = f"{LVR}!$A${LV_FIRST}:$A${LV_LAST}"
LV_FROM = f"{LVR}!$D${LV_FIRST}:$D${LV_LAST}"
LV_TO = f"{LVR}!$E${LV_FIRST}:$E${LV_LAST}"
LV_TYPE = f"{LVR}!$F${LV_FIRST}:$F${LV_LAST}"
LV_DAYS = f"{LVR}!$G${LV_FIRST}:$G${LV_LAST}"
LV_STATUS = f"{LVR}!$H${LV_FIRST}:$H${LV_LAST}"
LV_EMPID = f"{LVR}!$A${LV_FIRST}:$A${LV_LAST}"
LV_LIVE = (f'(({LV_STATUS}="Approved")+({LV_STATUS}="Availed"))')
LV_BAL_HDR = LV_LAST + 4
LV_BAL_FIRST = LV_BAL_HDR + 1
LV_BAL_LAST = LV_BAL_FIRST + N_EMP - 1
LV_POL_HDR = LV_BAL_LAST + 3
LV_POL_FIRST = LV_POL_HDR + 1
LV_POL_LAST = LV_POL_FIRST + len(LEAVE_TYPES) - 1

DEP_FIRST, DEP_LAST = 9, 16
DTR = DEP_LAST + 1

# ---------------------------------------------
# Working-day engine (attendance sheet, rows ER..ER+13, values in column C)
# Attendance model: Sundays are the weekly off; Saturdays are working days;
# declared holidays that fall Mon-Sat are paid days off.
# ---------------------------------------------
ER = LAST + 4                     # title row is ER-1
ENG_MONTH = ER                    # payroll month
ENG_START = ER + 1                # month start
ENG_END = ER + 2                  # month end
ENG_CAL = ER + 3                  # calendar days
ENG_SUN = ER + 4                  # Sundays
ENG_SAT = ER + 5                  # Saturdays
ENG_HOLALL = ER + 6               # declared holidays in the month
ENG_HOLWD = ER + 7                # ...of those that fall on a Mon-Sat
ENG_SATOFF = ER + 8               # working days in a 5-day week (info)
ENG_WD = ER + 9                   # calendar days less Sundays
ENG_NET = ER + 10                 # NET working days = ENG_WD - ENG_HOLWD
ENG_HRS = ER + 11                 # standard hours in the month
CAL_REF = f"=$C${ENG_CAL}"
SUN_REF = f"=$C${ENG_SUN}"
SAT_REF = f"=$C${ENG_SAT}"
HOL_REF = f"=$C${ENG_HOLALL}"
WD_REF = f"=$C${ENG_WD}"
NET_REF = f"=$C${ENG_NET}"

# department columns
D_CODE, D_NAME, D_HEAD, D_CC, D_BUDGET, D_APPROVED = 1, 2, 3, 4, 5, 6
D_LOC, D_SHIFT, D_EMP, D_ACTIVE, D_PROB, D_NOTICE = 7, 8, 9, 10, 11, 12
D_VAC, D_UTIL, D_BUD_EMP, D_COST, D_AVGGROSS, D_BUDUTIL = 13, 14, 15, 16, 17, 18
D_TENURE, D_HOURS, D_EXT, D_EMAIL = 19, 20, 21, 22


def c(col, row):
    """Absolute-free cell reference like C10."""
    return f"{CL(col)}{row}"


def rng(col, first, last, sheet=None, absolute=True):
    base = f"${CL(col)}${first}:${CL(col)}${last}" if absolute else f"{CL(col)}{first}:{CL(col)}{last}"
    return f"'{sheet}'!{base}" if sheet else base


DEPTS_RNG = f"'{DEPT_SHEET}'!$B${DEP_FIRST}:$B${DEP_LAST}"
POSITION_TITLES_RNG = f"'{SAL_SHEET}'!$B${SAL_TMPL_FIRST}:$B${SAL_TMPL_FIRST + 60}"
LEAVE_NAMES_RNG = f"'{LEAVE_SHEET}'!$A${LV_POL_FIRST}:$A${LV_POL_LAST}"
EMP_IDS_RNG = f"'{EMP_SHEET}'!$A${FIRST}:$A${LAST}"
EMP_NAMES_RNG = f"'{EMP_SHEET}'!$B${FIRST}:$B${LAST}"

wb = Workbook()
wb.remove(wb.active)
ws_dash = wb.create_sheet(DASH_SHEET)
ws_att = wb.create_sheet(ATT_SHEET)
ws_leave = wb.create_sheet(LEAVE_SHEET)
ws_sal = wb.create_sheet(SAL_SHEET)
ws_emp = wb.create_sheet(EMP_SHEET)
ws_cont = wb.create_sheet(CONTACT_SHEET)
ws_dept = wb.create_sheet(DEPT_SHEET)
ws_hol = wb.create_sheet(HOL_SHEET)
ws_guide = wb.create_sheet(GUIDE_SHEET)
ws_lists = wb.create_sheet(LISTS_SHEET)

# ==========================================================================
# HOLIDAYS
# ==========================================================================
ws = ws_hol
ws.sheet_properties.tabColor = MUTED
title_block(ws, "HOLIDAY CALENDAR  |  DEMO  |  2026",
            "Read by the attendance grid and the working-day calculator. Add or remove dates and everything "
            "recalculates. Sundays are already the weekly off - list only declared holidays.", last_col=8)
header_row(ws, 4, ["Date", "Holiday", "Day", "Weekday No.", "Falls on a working day (Mon-Sat)?",
                   "Type"], widths=[15, 30, 12, 12, 24, 12], height=40)
for i, (d, name, kind) in enumerate(HOLIDAYS):
    r = 5 + i
    ws.cell(row=r, column=1, value=d).number_format = "dd-mmm-yyyy"
    ws.cell(row=r, column=2, value=name)
    ws.cell(row=r, column=3, value=f'=TEXT($A{r},"dddd")')
    ws.cell(row=r, column=4, value=f'=IF($A{r}="","",WEEKDAY($A{r},2))')
    ws.cell(row=r, column=5, value=f'=IF($A{r}="",0,IF(WEEKDAY($A{r},2)<=6,1,0))')
    ws.cell(row=r, column=6, value=kind)
zebra(ws, 5, 40, 1, 6)
for r in range(5, 41):
    for col in (1, 3, 4, 5):
        ws.cell(row=r, column=col).alignment = Alignment(horizontal="center")
    ws.cell(row=r, column=2).font = font(10) if r <= 5 + len(HOLIDAYS) - 1 else font(10, False, MUTED)
dv = DataValidation(type="date", operator="between", formula1="DATE(2026,1,1)", formula2="DATE(2027,12,31)",
                    allow_blank=True, showErrorMessage=True, errorTitle="Holiday date",
                    error="Enter a date between 01-Jan-2026 and 31-Dec-2027.")
ws.add_data_validation(dv); dv.add("A5:A40")
dv = DataValidation(type="list", formula1='"National,Festival,State,Company"', allow_blank=True)
ws.add_data_validation(dv); dv.add("F5:F40")
ws.freeze_panes = "A5"
note(ws, 18, "Rows 17-40 are intentionally blank: add your own declared holidays there. "
             "Only dates inside the payroll month affect attendance and working-day counts.", last_col=4)

# ==========================================================================
# LISTS
# ==========================================================================
ws = ws_lists
ws.sheet_properties.tabColor = MUTED
title_block(ws, "LISTS & SETTINGS  |  INTERNAL",
            "Drop-down sources and the reporting-month switch. You may extend any list downward - the "
            "drop-downs pick up new entries automatically. Do not clear this sheet.", last_col=10)
header_row(ws, 4, ["Reporting Month", "", "Attendance Code", "Leave Type", "Code", "Shift",
                   "Grade", "Gender", "Blood Group", "Yes / No", "Location"],
           widths=[17, 10, 16, 22, 8, 26, 8, 10, 12, 9, 16], height=30)
for i, loc in enumerate(["Pune HQ", "Pune Annexe", "Mumbai Office", "Remote", "Client Site"]):
    cell = ws.cell(row=5 + i, column=11, value=loc)
    cell.border = BOX
    cell.font = font(10)
ws["A5"] = dt.date(PAY_YEAR, PAY_MONTH, 1)
ws["A5"].number_format = "mmmm yyyy"
ws["A5"].font = font(13, True, AMBER)
ws["A5"].fill = fill(AMBER_BG)
ws["A5"].alignment = Alignment(horizontal="center", vertical="center")
ws["A6"] = "Any date in A5"
ws["A6"].font = font(8.5, False, MUTED, italic=True)
dv = DataValidation(type="date", operator="between", formula1="DATE(2026,1,1)", formula2="DATE(2030,12,31)",
                    allow_blank=False, showErrorMessage=True, errorTitle="Reporting month",
                    error="Enter any date inside the month you want to report on, e.g. 01-Oct-2026.")
ws.add_data_validation(dv); dv.add("A5")
head_txt = ws.cell(row=3, column=1, value="Month switch: A5")
head_txt.font = font(9, True, "FFFFFF")
head_txt.alignment = Alignment(indent=1)
for i, m in enumerate(MONTHS):
    c2 = ws.cell(row=5 + i, column=2, value=m)
    c2.border = BOX
    c2.font = font(9, False, MUTED)
for i, (code, label) in enumerate(ATT_CODES):
    cell = ws.cell(row=5 + i, column=3, value=code)
    cell.font = font(10, True, ATT_STYLE.get(code, ("", TEXT))[1])
for i, t in enumerate(LEAVE_TYPES):
    ws.cell(row=5 + i, column=4, value=t[1])
    ws.cell(row=5 + i, column=5, value=t[0])
for i, s in enumerate(["General (9:30-18:30)", "Early (8:00-17:00)", "Late (11:00-20:00)",
                       "Night (22:00-6:00)", "Flexible"]):
    ws.cell(row=5 + i, column=6, value=s)
for i, g in enumerate(["E1", "E2", "E3", "M1", "M2"]):
    ws.cell(row=5 + i, column=7, value=g)
for i, g in enumerate(["Male", "Female"]):
    ws.cell(row=5 + i, column=8, value=g)
for i, b in enumerate(["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"]):
    ws.cell(row=5 + i, column=9, value=b)
ws["J5"] = "Yes"
ws["J6"] = "No"
for r in range(5, 17):
    for cc in range(1, 11):
        cell = ws.cell(row=r, column=cc)
        cell.border = BOX
        if cell.value is not None:
            cell.font = font(10)
ws["B5"].font = font(11, True, AMBER)
ws.merge_cells("A19:J19")
note(ws, 19, "Leave Type / Code feed the leave register. Attendance codes feed the day-grid drop-down. Shift, "
             "Grade, Gender and Blood Group feed the Employee Database drop-downs.", last_col=10)
ws.merge_cells("A20:J20")
note(ws, 20, "A5 is the single reporting-month switch: attendance, holidays, working days, salary day columns and "
             "the dashboard all read it. The sheet name 'Attendance Oct-2026' is only a label.", last_col=10)

SHIFT_RNG = f"'{LISTS_SHEET}'!$F$5:$F$9"
LOCATION_RNG = f"'{LISTS_SHEET}'!$K$5:$K$9"
GRADE_RNG = f"'{LISTS_SHEET}'!$G$5:$G$9"
GENDER_RNG = f"'{LISTS_SHEET}'!$H$5:$H$6"
BLOOD_RNG = f"'{LISTS_SHEET}'!$I$5:$I$12"
MONTHS_RNG = f"'{LISTS_SHEET}'!$B$5:$B$16"

# ==========================================================================
# EMPLOYEE DATABASE
# ==========================================================================
ws = ws_emp
ws.sheet_properties.tabColor = TEAL
title_block(ws, "EMPLOYEE DATABASE  |  DEMO  |  Apex Enterprises",
            "Master record of the sample workforce. Add a new hire from row 34 and every other sheet follows. "
            "Columns Q-T are calculated - type in A-P only. Column U is the shift.",
            last_col=EMP_LAST_COL)
kpi2(ws, 4, 1, "TOTAL EMPLOYEES", f"=COUNTA($A${FIRST}:$A${LAST})", "rows on the register", TEAL)
kpi2(ws, 4, 4, "ACTIVE", f'=COUNTIF($G${FIRST}:$G${LAST},"Active")', "currently on roll", GREEN)
kpi2(ws, 4, 7, "DEPARTMENTS", f"=COUNTIF({rng(D_EMP, DEP_FIRST, DEP_LAST, DEPT_SHEET)},\">0\")",
     "with at least one employee", NAVY)
kpi2(ws, 4, 10, "AVG TENURE", f"=ROUND(AVERAGE($Q${FIRST}:$Q${LAST}),1)", "years of service", ACCENT, "0.0")
kpi2(ws, 4, 13, "PROBATION", f'=COUNTIF($T${FIRST}:$T${LAST},"Yes")', "joined in last 6 months", AMBER)
note(ws, 8, "Row-linked: the Attendance, Leave, Salary and Contact sheets point at these rows. Please do not insert "
            "or re-sort rows - filter with the arrows in row 9 instead. New hires go in the first empty row (34+).",
     last_col=EMP_LAST_COL)

headers = ["Employee ID", "Full Name", "Department", "Designation", "Grade", "Location", "Status",
           "Date of Joining", "Work E-mail", "Extension", "Gender", "Blood Group", "Reporting Manager",
           "Role / Band", "Employment Type", "Annual CTC (approx.)",
           "Years of Service", "Service Status", "Tenure Band", "Probation?", "Shift"]
widths = [12, 20, 22, 26, 7, 9, 13, 13, 33, 10, 9, 10, 20, 20, 14, 15, 11, 12, 12, 10, 23]
header_row(ws, 9, headers, widths=widths, height=36)

STATUSES = ["Active"] * 21 + ["On Probation"] * 2 + ["Notice Period"]
HEAD_OF = {d[1]: d[2] for d in DEPTS}

for i, e in enumerate(EMPLOYEES):
    r = FIRST + i
    (eid, name, dept, desig, grade, loc, shift, doj, email, _p, ext,
     _m, _ec, _ep, _addr, blood) = e
    mgr = HEAD_OF[dept]
    if mgr == name:
        mgr = "Founder / Director (demo)"
    role = "People Manager" if grade in ("M1", "M2") else "Individual Contributor"
    ctc = round(sum(POS_BY_TITLE[desig][3:6]) * 12 / 1000) * 1000
    values = {
        E_ID: eid, E_NAME: name, E_DEPT: dept, E_DESIG: desig, E_GRADE: grade,
        E_LOC: loc, E_STATUS: STATUSES[i], E_DOJ: doj, E_MAIL: email, E_EXT: ext,
        E_GENDER: "Female" if name in FEMALE else "Male", E_BLOOD: blood, E_MGR: mgr,
        E_ROLE: role, E_TYPE: "Full Time", E_CTC: ctc, E_SHIFT: shift,
    }
    for col, val in values.items():
        ws.cell(row=r, column=col, value=val)
    ws.cell(row=r, column=E_DOJ).number_format = "dd-mmm-yyyy"
    ws.cell(row=r, column=E_CTC).number_format = "#,##0"
    q = f'=IF($H{r}="","",ROUND(YEARFRAC($H{r},{MONTH_DATE}),1))'
    ws.cell(row=r, column=E_TENURE, value=q).number_format = "0.0"
    ws.cell(row=r, column=E_SVCSTAT,
            value=f'=IF($G{r}="","",IF(OR($G{r}="Notice Period",$G{r}="Exited"),"Exiting","Continuing"))')
    ws.cell(row=r, column=E_BAND,
            value=f'=IF($Q{r}="","",IF($Q{r}<1,"< 1 yr",IF($Q{r}<3,"1-3 yrs",IF($Q{r}<5,"3-5 yrs","5+ yrs"))))')
    ws.cell(row=r, column=E_PROB,
            value=f'=IF($H{r}="","",IF($H{r}>EDATE({MONTH_DATE},-6),"Yes","No"))')

zebra(ws, FIRST, LAST, 1, EMP_LAST_COL)
for r in range(FIRST, LAST + 1):
    ws.cell(row=r, column=E_NAME).font = font(10, True, TEXT)
    for col in range(1, EMP_LAST_COL + 1):
        cell = ws.cell(row=r, column=col)
        if col != E_NAME:
            cell.font = font(10)
        if col in (E_ID, E_GRADE, E_LOC, E_STATUS, E_EXT, E_GENDER, E_BLOOD, E_CTC, E_TENURE, E_PROB):
            cell.alignment = Alignment(horizontal="center")
        if col in (E_TENURE, E_SVCSTAT, E_BAND, E_PROB):
            cell.fill = fill(BLUE_BG)
            cell.font = font(9.5, False, NAVY)
    ws.cell(row=r, column=E_SHIFT).font = font(8.5, False, MUTED)

EMSG = dict(showErrorMessage=True, errorTitle="Value not allowed",
            error="Please choose a value from the drop-down list.")
GROW = 60  # formulas/DV allow growth to row 60


def add_list_dv(ws, cells, formula, title=None, prompt=None, allow_blank=True):
    dv = DataValidation(type="list", formula1=formula, allow_blank=allow_blank, **EMSG)
    if title:
        dv.promptTitle = title
        dv.showInputMessage = True
        dv.prompt = prompt or "Choose from the list."
    ws.add_data_validation(dv)
    dv.add(cells)
    return dv


add_list_dv(ws, f"C{FIRST}:C{GROW}", DEPTS_RNG, "Department", "Pick a department from Department Details.")
add_list_dv(ws, f"D{FIRST}:D{GROW}", POSITION_TITLES_RNG, "Designation",
            "Pick a position - it drives the Basic pay in Salary Calculation.")
add_list_dv(ws, f"E{FIRST}:E{GROW}", GRADE_RNG, "Grade", "E1-E3 executive, M1-M2 manager.")
add_list_dv(ws, f"F{FIRST}:F{GROW}", LOCATION_RNG, "Location", "Where the employee is based.")
add_list_dv(ws, f"U{FIRST}:U{GROW}", SHIFT_RNG, "Shift", "Default shift for this employee.")
add_list_dv(ws, f"G{FIRST}:G{GROW}", '"Active,On Probation,Notice Period,Exited"', "Status",
            "Use 'Exited' instead of deleting a leaver's row.")
add_list_dv(ws, f"O{FIRST}:O{GROW}", '"Full Time,Part Time,Contract,Intern"')
add_list_dv(ws, f"K{FIRST}:K{GROW}", GENDER_RNG)
add_list_dv(ws, f"L{FIRST}:L{GROW}", BLOOD_RNG)
dv = DataValidation(type="date", operator="between", formula1="DATE(2000,1,1)", formula2="DATE(2035,12,31)",
                    allow_blank=True, showErrorMessage=True, errorTitle="Date of Joining",
                    error="Enter a valid date, for example 15-Apr-2019.")
ws.add_data_validation(dv); dv.add(f"H{FIRST}:H{GROW}")
dv = DataValidation(type="whole", operator="between", formula1="1000", formula2="9999",
                    allow_blank=True, showErrorMessage=True, errorTitle="Extension",
                    error="Extension must be a 4-digit number, e.g. 2201.")
ws.add_data_validation(dv); dv.add(f"J{FIRST}:J{GROW}")
dv = DataValidation(type="textLength", operator="lessThanOrEqual", formula1="60", allow_blank=True,
                    showErrorMessage=True, errorTitle="E-mail", error="Maximum 60 characters.")
ws.add_data_validation(dv); dv.add(f"I{FIRST}:I{GROW}")

ws.conditional_formatting.add(f"G{FIRST}:G{LAST}", CellIsRule(
    operator="equal", formula=['"Active"'], fill=fill(GREEN_BG), font=font(9.5, True, GREEN)))
ws.conditional_formatting.add(f"G{FIRST}:G{LAST}", CellIsRule(
    operator="equal", formula=['"Notice Period"'], fill=fill(AMBER_BG), font=font(9.5, True, AMBER)))
ws.conditional_formatting.add(f"G{FIRST}:G{LAST}", CellIsRule(
    operator="equal", formula=['"On Probation"'], fill=fill(BLUE_BG), font=font(9.5, True, NAVY)))

ws.freeze_panes = "C10"
ws.auto_filter.ref = f"A9:T{LAST}"
note(ws, LAST + 2, "Q Years of Service = YEARFRAC(joining date, payroll month).  R Service Status flags leavers.  "
                   "S Tenure Band groups service length.  T Probation? = joined within the last 6 months.",
     last_col=EMP_LAST_COL)

# ==========================================================================
# ATTENDANCE
# ==========================================================================
ws = ws_att
ws.sheet_properties.tabColor = ACCENT
title_block(ws, f"MONTHLY ATTENDANCE  |  DEMO  |  {PAY_MONTH_LABEL.upper()}",
            "One row per employee, one column per calendar day. Sundays and declared holidays fill themselves in. "
            "Overwrite P with WFH, HD, L, H or WO as needed - the blue columns count everything for you.",
            last_col=ATT_LAST_COL)
ws["A1"] = (f'="MONTHLY ATTENDANCE  |  DEMO  |  "&UPPER(TEXT({MONTH_DATE},"mmmm yyyy"))')
ws["A1"].font = font(15, True, WHITE)
ws["A1"].alignment = Alignment(vertical="center", horizontal="left", indent=1)

# compact month strip - the day columns are far too narrow for full KPI tiles
strip = [
    (1, 2, "PAYROLL MONTH", f"={MONTH_DATE}", "mmmm yyyy", NAVY),
    (4, 6, "CALENDAR DAYS", CAL_REF, "0", TEAL),
    (7, 9, "WORKING DAYS", NET_REF, "0", GREEN),
    (10, 13, "DECLARED HOLIDAYS", HOL_REF, "0", AMBER),
]
for c1, c2, label, formula, fmt, colour in strip:
    ws.merge_cells(start_row=4, start_column=c1, end_row=4, end_column=c2)
    lab = ws.cell(row=4, column=c1, value=label)
    lab.font = font(8.5, True, MUTED)
    lab.alignment = Alignment(horizontal="center", vertical="center")
    ws.merge_cells(start_row=5, start_column=c1, end_row=5, end_column=c2)
    val = ws.cell(row=5, column=c1, value=formula)
    val.font = font(15, True, colour)
    val.number_format = fmt
    val.alignment = Alignment(horizontal="center", vertical="center")
for r in (4, 5):
    ws.row_dimensions[r].height = 16 if r == 4 else 22

att_headers = ["Employee ID", "Employee Name", "Department"] + list(range(1, DAYS_IN_MONTH + 1)) + \
              ["P", "WFH", "HD", "L", "LWP", "WO", "HOL", "H", "Payable Days", "Present Days",
               "Paid Days", "Attendance %", "Extras", "Unpaid Shortfall"]
header_row(ws, 9, att_headers, height=34)
for i, w in enumerate([12, 21, 22]):
    ws.column_dimensions[CL(1 + i)].width = w
for d in range(1, DAYS_IN_MONTH + 1):
    ws.column_dimensions[CL(ATT_DAY_FIRST + d - 1)].width = 3.9
for i, w in enumerate([5, 5.6, 5.4, 4.6, 5.6, 5.4, 6, 4.8, 8.6, 8.6, 8, 8.6, 7.5, 9]):
    ws.column_dimensions[CL(AC_P + i)].width = w

# holiday flag strip (row 8) - sits above the day numbers so it never clashes with the title
for d in range(1, DAYS_IN_MONTH + 1):
    date = dt.date(PAY_YEAR, PAY_MONTH, d)
    holiday = date in HOLIDAY_MAP
    cell = ws.cell(row=8, column=ATT_DAY_FIRST + d - 1, value="*" if holiday else None)
    cell.font = font(9, True, WHITE if holiday else MUTED)
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.fill = fill(ACCENT if holiday else GREY_BG)
    if holiday:
        cell.comment = Comment(f"{date:%d-%b-%Y} - {HOLIDAY_MAP[date]}", "Apex Ops")

for i in range(N_EMP):
    r = FIRST + i
    emp_row = FIRST + i
    ws.cell(row=r, column=1, value=f"='{EMP_SHEET}'!$A${emp_row}")
    ws.cell(row=r, column=2, value=f"='{EMP_SHEET}'!$B${emp_row}")
    ws.cell(row=r, column=3, value=f"='{EMP_SHEET}'!$C${emp_row}")
    for d in range(1, DAYS_IN_MONTH + 1):
        col = ATT_DAY_FIRST + d - 1
        cell = ws.cell(row=r, column=col)
        base = f"DATE(YEAR(Lists!$A$5),MONTH(Lists!$A$5),{d})"
        cell.value = (f'=IF(DAY({base})<>{d},"",'
                      f'IF(COUNTIF(Holidays!$A$5:$A$40,{base})>0,"HOL",'
                      f'IF(WEEKDAY({base},2)=7,"WO",'
                      f'IF(SUMPRODUCT(({LV_ABS}=$A{r})*({LV_FROM}<={base})*({LV_TO}>={base})*'
                      f'({LV_TYPE}="Leave Without Pay")*({LV_LIVE}))>0,"LWP",'
                      f'IF(SUMPRODUCT(({LV_ABS}=$A{r})*({LV_FROM}<={base})*({LV_TO}>={base})*'
                      f'({LV_TYPE}<>"Leave Without Pay")*({LV_LIVE}))>0,"L","P")))))')
        cell.font = font(7.5)
        cell.alignment = Alignment(horizontal="center")
        cell.border = Border(left=Side(style="hair", color=GREY_LINE),
                             right=Side(style="hair", color=GREY_LINE),
                             top=Side(style="hair", color=GREY_LINE),
                             bottom=Side(style="hair", color=GREY_LINE))
    grid = f"${CL(ATT_DAY_FIRST)}{r}:${CL(ATT_DAY_LAST)}{r}"
    for col, code in [(AC_P, "P"), (AC_WFH, "WFH"), (AC_HD, "HD"), (AC_L, "L"),
                      (AC_LWP, "LWP"), (AC_WO, "WO"), (AC_HOL, "HOL"), (AC_H, "H")]:
        ws.cell(row=r, column=col, value=f'=COUNTIF({grid},"{code}")')
    p, wfh, hd, lv, lwp = CL(AC_P), CL(AC_WFH), CL(AC_HD), CL(AC_L), CL(AC_LWP)
    wo, hol, ab = CL(AC_WO), CL(AC_HOL), CL(AC_H)
    pres, paid = CL(AC_PRESENT), CL(AC_PAID)
    ws.cell(row=r, column=AC_PAYABLE,
            value=f"=${p}{r}+${wfh}{r}+${hd}{r}+${lv}{r}+${lwp}{r}+${wo}{r}+${hol}{r}+${ab}{r}")
    ws.cell(row=r, column=AC_PRESENT, value=f"=${p}{r}+${wfh}{r}+${hd}{r}*0.5")
    ws.cell(row=r, column=AC_PAID, value=f"=MIN($C${ENG_NET},${pres}{r}+${lv}{r})")
    ws.cell(row=r, column=AC_PCT,
            value=f'=IF($C${ENG_NET}=0,"",${pres}{r}/$C${ENG_NET})').number_format = "0.0%"
    ws.cell(row=r, column=AC_EXTRA, value=f"=MAX(0,${pres}{r}-$C${ENG_NET})")
    ws.cell(row=r, column=AC_SHORT, value=f"=MAX(0,$C${ENG_NET}-${paid}{r})")

    band = WHITE if i % 2 == 0 else GREY_BG
    for col in range(1, ATT_LAST_COL + 1):
        cell = ws.cell(row=r, column=col)
        if col <= 3:
            cell.fill = fill(band)
            cell.border = BOX
            cell.font = font(9)
            if col == 2:
                cell.font = font(9, True, TEXT)
        elif col > ATT_DAY_LAST:
            cell.fill = fill(BLUE_BG)
            cell.border = BOX
            cell.font = font(9, False, NAVY)
            cell.alignment = Alignment(horizontal="center")
    ws.row_dimensions[r].height = 17

# --- a handful of hand-entered days so the demo shows every code in use ---
# (employee index, day of month, code). Leave-driven L / LWP days are stamped by formula,
# so these only cover unplanned absences, WFH, half days, extra weekly offs and overtime.
SAMPLE_MARKS = [
    (9, 21, "H"), (9, 22, "H"),          # two unmarked absences -> loss of pay
    (11, 8, "HD"), (21, 27, "HD"),        # half days
    (15, 6, "WFH"), (15, 7, "WFH"),       # work from home
    (23, 15, "WO"),                       # an extra weekly off granted
    (14, 4, "P"),                         # worked on a Sunday -> counts as overtime-equivalent
]
for emp_idx, day, code in SAMPLE_MARKS:
    cell = ws.cell(row=FIRST + emp_idx, column=ATT_DAY_FIRST + day - 1, value=code)
    cell.font = font(8, True, ATT_STYLE[code][1])
    cell.fill = fill(ATT_STYLE[code][0])

grid_ref = f"D{FIRST}:{CL(ATT_DAY_LAST)}{LAST}"
for code, (bg, fg) in ATT_STYLE.items():
    ws.conditional_formatting.add(grid_ref, CellIsRule(
        operator="equal", formula=[f'"{code}"'], fill=fill(bg), font=font(8, True, fg)))
ws.conditional_formatting.add(f"{CL(AC_PCT)}{FIRST}:{CL(AC_PCT)}{LAST}", ColorScaleRule(
    start_type="num", start_value=0, start_color="F8C9C4",
    mid_type="num", mid_value=0.85, mid_color="FFEFC2",
    end_type="num", end_value=1, end_color="B7E4C7"))
ws.conditional_formatting.add(f"{CL(AC_EXTRA)}{FIRST}:{CL(AC_EXTRA)}{LAST}", CellIsRule(
    operator="greaterThan", formula=["0"], fill=fill(GREEN_BG), font=font(9, True, GREEN)))
ws.conditional_formatting.add(f"{CL(AC_SHORT)}{FIRST}:{CL(AC_SHORT)}{LAST}", CellIsRule(
    operator="greaterThan", formula=["0"], fill=fill(RED_BG), font=font(9, True, RED)))

dv = DataValidation(type="list", formula1='"P,WFH,HD,L,WO,HOL,H"', allow_blank=True,
                    showErrorMessage=True, errorTitle="Attendance code",
                    error="Use P, WFH, HD, L, WO, HOL or H.")
dv.promptTitle = "Attendance code"
dv.prompt = "P · WFH · HD · L · WO · HOL · H"
dv.showInputMessage = True
ws.add_data_validation(dv); dv.add(grid_ref)

ws.freeze_panes = "D10"

# ---- working-day calculator block ----
section(ws, ER - 1, "WORKING-DAY CALCULATOR  -  automatic, do not overwrite", last_col=9)
calc_rows = [
    ("Payroll month", f"={MONTH_DATE}", "mmm yyyy", True),
    ("Month start", f"=DATE(YEAR({MONTH_CELL}),MONTH({MONTH_CELL}),1)", "dd-mmm-yyyy", False),
    ("Month end", f"=EOMONTH($C${ENG_START},0)", "dd-mmm-yyyy", False),
    ("Calendar days", f"=DAY($C${ENG_END})", "0", False),
    ("Sundays (weekly off)", f"=INT(($C${ENG_CAL}+WEEKDAY($C${ENG_START}-7,2)-1)/7)",
     "0", False),
    ("Saturdays (working days here)", f"=INT(($C${ENG_CAL}+WEEKDAY($C${ENG_START}-6,2)-1)/7)",
     "0", False),
    ("Declared holidays in the month",
     f'=SUMPRODUCT((Holidays!$A$5:$A$40<>"")*(Holidays!$A$5:$A$40>=$C${ENG_START})*'
     f'(Holidays!$A$5:$A$40<=$C${ENG_END}))', "0", False),
    ("...of those, on a Mon-Sat",
     f'=SUMPRODUCT((Holidays!$A$5:$A$40<>"")*(Holidays!$A$5:$A$40>=$C${ENG_START})*'
     f'(Holidays!$A$5:$A$40<=$C${ENG_END})*Holidays!$E$5:$E$40)', "0", False),
    ("...if all Saturdays off",
     f"=$C${ENG_CAL}-$C${ENG_SUN}-$C${ENG_SAT}", "0", False),
    ("Calendar days less Sundays", f"=$C${ENG_CAL}-$C${ENG_SUN}", "0", False),
    ("NET WORKING DAYS",
     f"=$C${ENG_WD}-$C${ENG_HOLWD}", "0", True),
    ("Standard hours in the month", f"=$C${ENG_NET}*8", "0", False),
]
for i, (label, formula, fmt, highlight) in enumerate(calc_rows):
    r = ER + i
    lc = ws.cell(row=r, column=1, value=label)
    lc.font = font(9, highlight, NAVY if highlight else MUTED)
    ws.merge_cells(start_row=r, start_column=1, end_row=r, end_column=2)
    vc = ws.cell(row=r, column=3, value=formula)
    vc.font = font(10, True, ACCENT if highlight else NAVY)
    vc.number_format = fmt
    vc.alignment = Alignment(horizontal="center")
    vc.fill = fill(AMBER_BG if highlight else GREY_BG)
    vc.border = BOX

LEG = ER + 15
ws.cell(row=LEG - 1, column=1, value="CODE LEGEND").font = font(9.5, True, NAVY)
for i, (code, label) in enumerate(ATT_CODES):
    r = LEG + i
    cell = ws.cell(row=r, column=1, value=code)
    cell.font = font(9, True, ATT_STYLE[code][1])
    cell.fill = fill(ATT_STYLE[code][0])
    cell.alignment = Alignment(horizontal="center")
    cell.border = BOX
    txt = ws.cell(row=r, column=3, value=label)
    txt.font = font(9, False, MUTED)

note(ws, ER + 23, "Paid Days = present days + paid leave, capped at the working-day count. Unpaid Shortfall = "
                  "working days minus paid days: it drives the loss-of-pay deduction in Salary Calculation. "
                  "Leave approved on the Leave Records tab is stamped into the grid automatically.", last_col=12)


# ==========================================================================
# LEAVE RECORDS
# ==========================================================================
ws = ws_leave
ws.sheet_properties.tabColor = PURPLE
title_block(ws, "LEAVE RECORDS & BALANCE TRACKER  |  DEMO  |  2026",
            "Log each request in section A. Section B shows every employee's live balance, section C holds the "
            "entitlement policy. Only Approved and Availed days reduce a balance or hit attendance.",
            last_col=14)
kpi2(ws, 4, 1, "REQUESTS", f"=COUNTA($B${LV_FIRST}:$B${LV_LAST})", "rows in the register", NAVY)
kpi2(ws, 4, 4, "APPROVED / AVAILED",
     f'=COUNTIF($H${LV_FIRST}:$H${LV_LAST},"Approved")+COUNTIF($H${LV_FIRST}:$H${LV_LAST},"Availed")',
     "of all requests", GREEN)
kpi2(ws, 4, 7, "DAYS TAKEN",
     f'=SUMIF($H${LV_FIRST}:$H${LV_LAST},"Approved",$G${LV_FIRST}:$G${LV_LAST})'
     f'+SUMIF($H${LV_FIRST}:$H${LV_LAST},"Availed",$G${LV_FIRST}:$G${LV_LAST})',
     "approved + availed days", TEAL, "0.0")
kpi2(ws, 4, 10, "PENDING", f'=COUNTIF($H${LV_FIRST}:$H${LV_LAST},"Pending")', "awaiting a decision", AMBER)
kpi2(ws, 4, 13, "LWP DAYS",
     f'=SUMIFS($G${LV_FIRST}:$G${LV_LAST},$F${LV_FIRST}:$F${LV_LAST},"Leave Without Pay",'
     f'$H${LV_FIRST}:$H${LV_LAST},"<>Rejected")', "unpaid - deducted in payroll", RED, "0.0")

section(ws, 8, "A.  LEAVE REGISTER  -  one row per request", last_col=14)
lv_headers = ["Employee ID", "Employee Name", "Department", "From Date", "To Date", "Leave Type",
              "Days", "Status", "Reason", "Approver", "In Payroll Month?", "Opening Balance",
              "Remaining After This Row", "Reflected in Attendance?"]
lv_widths = [12, 19, 20, 12, 12, 19, 7, 11, 27, 15, 12, 12, 14, 13]
header_row(ws, 9, lv_headers, widths=lv_widths, height=36)

REQUESTS = [
    # (employee index, leave type, from date, days, status, reason)
    (0, "Earned Leave", dt.date(2026, 10, 5), 2, "Availed", "Family function"),
    (0, "Earned Leave", dt.date(2026, 4, 20), 3, "Availed", "Short break"),
    (1, "Earned Leave", dt.date(2026, 10, 12), 3, "Availed", "Vacation - Kochi"),
    (1, "Sick Leave", dt.date(2026, 9, 8), 2, "Availed", "Viral fever"),
    (1, "Casual Leave", dt.date(2026, 6, 3), 1, "Availed", "Personal work"),
    (2, "Earned Leave", dt.date(2026, 11, 16), 2, "Approved", "Wedding in the family"),
    (2, "Casual Leave", dt.date(2026, 7, 14), 1, "Availed", "Bank work"),
    (3, "Casual Leave", dt.date(2026, 10, 19), 1, "Availed", "Apartment registration"),
    (3, "Earned Leave", dt.date(2026, 5, 11), 4, "Availed", "Family trip"),
    (4, "Sick Leave", dt.date(2026, 10, 27), 2, "Availed", "Dental procedure"),
    (4, "Earned Leave", dt.date(2026, 8, 24), 2, "Availed", "Personal"),
    (5, "Earned Leave", dt.date(2026, 10, 6), 4, "Availed", "Diwali travel"),
    (5, "Casual Leave", dt.date(2026, 3, 17), 1, "Availed", "Relocation"),
    (6, "Casual Leave", dt.date(2026, 10, 14), 1, "Availed", "Parent-teacher meeting"),
    (6, "Earned Leave", dt.date(2026, 12, 21), 4, "Pending", "Year-end holiday"),
    (7, "Earned Leave", dt.date(2026, 9, 21), 2, "Availed", "Personal work"),
    (7, "Casual Leave", dt.date(2026, 2, 10), 2, "Availed", "House shifting"),
    (8, "Sick Leave", dt.date(2026, 10, 8), 1, "Availed", "Migraine"),
    (8, "Earned Leave", dt.date(2026, 6, 22), 3, "Availed", "Native place"),
    (9, "Casual Leave", dt.date(2026, 10, 20), 1, "Rejected", "Peak-day coverage"),
    (9, "Leave Without Pay", dt.date(2026, 10, 12), 2, "Approved", "No paid balance left"),
    (10, "Earned Leave", dt.date(2026, 10, 1), 3, "Availed", "Native place visit"),
    (10, "Sick Leave", dt.date(2026, 8, 12), 2, "Availed", "Fever"),
    (11, "Sick Leave", dt.date(2026, 9, 29), 2, "Availed", "Food poisoning"),
    (11, "Casual Leave", dt.date(2026, 4, 7), 1, "Availed", "Documentation"),
    (12, "Casual Leave", dt.date(2026, 11, 5), 1, "Approved", "Bank work"),
    (12, "Earned Leave", dt.date(2026, 7, 20), 3, "Availed", "Family visit"),
    (13, "Earned Leave", dt.date(2026, 12, 21), 4, "Pending", "Year-end holiday"),
    (13, "Sick Leave", dt.date(2026, 5, 18), 1, "Availed", "Medical check-up"),
    (14, "Earned Leave", dt.date(2026, 10, 13), 2, "Availed", "Family trip"),
    (15, "Comp Off", dt.date(2026, 10, 9), 1, "Availed", "Month-end close support"),
    (15, "Casual Leave", dt.date(2026, 6, 9), 1, "Availed", "Personal reason"),
    (16, "Casual Leave", dt.date(2026, 10, 7), 1, "Availed", "Passport appointment"),
    (16, "Earned Leave", dt.date(2026, 9, 7), 2, "Availed", "Short trip"),
    (17, "Earned Leave", dt.date(2026, 11, 12), 5, "Pending", "Annual vacation"),
    (17, "Sick Leave", dt.date(2026, 4, 27), 2, "Availed", "Seasonal flu"),
    (18, "Sick Leave", dt.date(2026, 10, 22), 1, "Availed", "Doctor visit"),
    (19, "Casual Leave", dt.date(2026, 11, 3), 1, "Approved", "Personal errand"),
    (20, "Comp Off", dt.date(2026, 11, 2), 1, "Approved", "Weekend release support"),
    (20, "Earned Leave", dt.date(2026, 8, 3), 3, "Availed", "Family function"),
    (21, "Leave Without Pay", dt.date(2026, 11, 17), 2, "Approved", "Extended leave - no balance"),
    (22, "Casual Leave", dt.date(2026, 11, 9), 1, "Approved", "Festival"),
    (22, "Sick Leave", dt.date(2026, 6, 16), 2, "Availed", "Recovery after viral fever"),
    (23, "Sick Leave", dt.date(2026, 10, 29), 1, "Availed", "Routine check-up"),
    (23, "Earned Leave", dt.date(2026, 3, 9), 2, "Availed", "Family event"),
]

A_RANGE = f"$A${LV_FIRST}:$A${LV_LAST}"
F_RANGE = f"$F${LV_FIRST}:$F${LV_LAST}"
G_RANGE = f"$G${LV_FIRST}:$G${LV_LAST}"
H_RANGE = f"$H${LV_FIRST}:$H${LV_LAST}"
POL_TYPE = f"$A${LV_POL_FIRST}:$A${LV_POL_LAST}"
POL_ENT = f"$C${LV_POL_FIRST}:$C${LV_POL_LAST}"

for i, (idx, ltype, start, days, status, reason) in enumerate(REQUESTS):
    r = LV_FIRST + i
    emp_row = FIRST + idx
    ws.cell(row=r, column=1, value=f"='{EMP_SHEET}'!$A${emp_row}")
    ws.cell(row=r, column=2, value=f"='{EMP_SHEET}'!$B${emp_row}")
    ws.cell(row=r, column=3, value=f"='{EMP_SHEET}'!$C${emp_row}")
    ws.cell(row=r, column=4, value=start).number_format = "dd-mmm-yyyy"
    ws.cell(row=r, column=5, value=f'=IF($D{r}="","",$D{r}+$G{r}-1)').number_format = "dd-mmm-yyyy"
    ws.cell(row=r, column=6, value=ltype)
    ws.cell(row=r, column=7, value=days)
    ws.cell(row=r, column=8, value=status)
    ws.cell(row=r, column=9, value=reason)
    emp_dept = EMPLOYEES[idx][2]
    ws.cell(row=r, column=10, value="Ananya Iyer" if emp_dept != "Human Resources" else "Rohan Deshmukh")
    ws.cell(row=r, column=11, value=(
        f'=IF(OR($D{r}="",AND($H{r}<>"Approved",$H{r}<>"Availed")),"",'
        f'IF(AND($D{r}>={MONTH_DATE},$D{r}<=EOMONTH({MONTH_DATE},0)),"Yes","No"))'))
    ws.cell(row=r, column=12, value=(
        f'=IF($A{r}="","",MAX(0,IFERROR(INDEX({POL_ENT},MATCH($F{r},{POL_TYPE},0)),0)'
        f'-SUMPRODUCT(($A${LV_FIRST}:$A${LV_LAST}=$A{r})*($F${LV_FIRST}:$F${LV_LAST}=$F{r})*'
        f'(ROW($A${LV_FIRST}:$A${LV_LAST})<ROW())*'
        f'(($H${LV_FIRST}:$H${LV_LAST}="Approved")+($H${LV_FIRST}:$H${LV_LAST}="Availed"))*'
        f'$G${LV_FIRST}:$G${LV_LAST})))'))
    ws.cell(row=r, column=13, value=(
        f'=IF($A{r}="","",IF(OR($H{r}="Approved",$H{r}="Availed"),MAX(0,$L{r}-$G{r}),$L{r}))'))
    ws.cell(row=r, column=14, value=(
        f'=IF($A{r}="","",IF(AND($H{r}="Availed",$K{r}="Yes"),"Yes","-"))'))

zebra(ws, LV_FIRST, LV_LAST, 1, 14)
for r in range(LV_FIRST, LV_LAST + 1):
    ws.cell(row=r, column=2).font = font(9, True, TEXT)
    for col in range(1, 15):
        cell = ws.cell(row=r, column=col)
        if col != 2:
            cell.font = font(9)
        if col in (4, 5, 7, 8, 11, 12, 13, 14):
            cell.alignment = Alignment(horizontal="center")
        if col in (6, 9, 10):
            cell.alignment = Alignment(horizontal="left", vertical="center")
        if col in (12, 13):
            cell.fill = fill(BLUE_BG)
            cell.font = font(9, True, NAVY)

add_list_dv(ws, f"A{LV_FIRST}:A{LV_LAST}", EMP_IDS_RNG, "Employee ID",
            "Pick an ID - name and department fill themselves.")
add_list_dv(ws, f"F{LV_FIRST}:F{LV_LAST}", POL_TYPE, "Leave type", "Earned, Casual, Sick, Comp Off or LWP.")
add_list_dv(ws, f"H{LV_FIRST}:H{LV_LAST}", '"Pending,Approved,Rejected,Availed,Cancelled"', "Status",
            "Only Approved and Availed reduce balances and hit attendance.")
dv = DataValidation(type="date", operator="between", formula1="DATE(2026,1,1)", formula2="DATE(2027,12,31)",
                    allow_blank=True, showErrorMessage=True, errorTitle="From date",
                    error="Enter a date between 01-Jan-2026 and 31-Dec-2027.")
ws.add_data_validation(dv); dv.add(f"D{LV_FIRST}:D{LV_LAST}")
dv = DataValidation(type="decimal", operator="between", formula1="0.5", formula2="60", allow_blank=True,
                    showErrorMessage=True, errorTitle="Days",
                    error="Leave days must be between 0.5 and 60.")
ws.add_data_validation(dv); dv.add(f"G{LV_FIRST}:G{LV_LAST}")

for status, (bg, fg) in {"Approved": (GREEN_BG, GREEN), "Availed": (BLUE_BG, NAVY),
                         "Pending": (AMBER_BG, AMBER), "Rejected": (RED_BG, RED),
                         "Cancelled": (GREY_BG, MUTED)}.items():
    ws.conditional_formatting.add(f"H{LV_FIRST}:H{LV_LAST}", CellIsRule(
        operator="equal", formula=[f'"{status}"'], fill=fill(bg), font=font(9, True, fg)))

ws.freeze_panes = "D10"
ws.auto_filter.ref = f"A9:N{LV_LAST}"
note(ws, LV_LAST + 1, "Opening Balance = this year's entitlement minus approved or availed days of the same type "
                      "on earlier rows. Pending and rejected rows do not reduce a balance.", last_col=14)

# ---- B. balances ----
section(ws, LV_BAL_HDR - 1,
        "B.  LEAVE BALANCE MATRIX  -  automatic.  C-G: days remaining (entitlement minus approved/availed).  "
        "H-L: days used, where Comp Off and Leave Without Pay appear.", last_col=13)
bal_headers = ["Employee ID", "Employee Name"] + LEAVE_NAMES + \
              [f"{n} used" for n in LEAVE_NAMES] + ["Total remaining", "Total used"]
header_row(ws, LV_BAL_HDR, bal_headers, height=40)
bal_widths = [13, 20, 12.5, 12.5, 11.5, 11, 15, 12.5, 12.5, 11.5, 11, 15, 12, 11]

for i in range(N_EMP):
    r = LV_BAL_FIRST + i
    emp_row = FIRST + i
    ws.cell(row=r, column=1, value=f"='{EMP_SHEET}'!$A${emp_row}")
    ws.cell(row=r, column=2, value=f"='{EMP_SHEET}'!$B${emp_row}")
    for j, (code, lname, ent, tracked, _rule) in enumerate(LEAVE_TYPES):
        used_col = 8 + j
        ws.cell(row=r, column=used_col, value=(
            f'=SUMIFS({G_RANGE},{A_RANGE},$A{r},{F_RANGE},"{lname}",{H_RANGE},"<>Rejected")'))
        if tracked:
            formula = f'=MAX(0,{ent}-${CL(used_col)}{r})'
        else:
            formula = f'=MAX(0,${CL(used_col)}{r})'
        ws.cell(row=r, column=3 + j, value=formula)
    ws.cell(row=r, column=13, value=f"=SUM($C{r}:$G{r})")
    ws.cell(row=r, column=14, value=f"=SUM($H{r}:$L{r})")

for i, w in enumerate(bal_widths):
    cur = ws.column_dimensions[CL(1 + i)].width or 0
    ws.column_dimensions[CL(1 + i)].width = max(cur, w)

zebra(ws, LV_BAL_FIRST, LV_BAL_LAST, 1, 14)
for r in range(LV_BAL_FIRST, LV_BAL_LAST + 1):
    ws.cell(row=r, column=2).font = font(9, True, TEXT)
    for col in range(3, 15):
        cell = ws.cell(row=r, column=col)
        cell.alignment = Alignment(horizontal="center")
        cell.font = font(9)
    for col in range(3, 8):
        cell = ws.cell(row=r, column=col)
        cell.fill = fill(BLUE_BG)
        cell.font = font(9, True, NAVY)
    for col in range(8, 13):
        cell = ws.cell(row=r, column=col)
        cell.fill = fill(GREY_BG)
        cell.font = font(9, False, MUTED)
    ws.cell(row=r, column=13).font = font(9, True, NAVY)
    ws.cell(row=r, column=14).font = font(9, True, AMBER)

ws.conditional_formatting.add(f"C{LV_BAL_FIRST}:E{LV_BAL_LAST}", ColorScaleRule(
    start_type="num", start_value=0, start_color="F8C9C4",
    mid_type="percentile", mid_value=50, mid_color="FFEFC2",
    end_type="num", end_value=18, end_color="B7E4C7"))
ws.conditional_formatting.add(f"M{LV_BAL_FIRST}:M{LV_BAL_LAST}", DataBarRule(
    start_type="num", start_value=0, end_type="max", color=TEAL, showValue=True))

# ---- C. policy ----
section(ws, LV_POL_HDR - 1, "C.  LEAVE POLICY  -  edit here, balances recalculate", last_col=10)
header_row(ws, LV_POL_HDR, ["Leave Type", "Code", "Entitlement (days / year)", "Balance Tracked?",
                            "Rule / note"], height=32)
for i, w in enumerate([22, 8, 16, 13, 52]):
    ws.column_dimensions[CL(1 + i)].width = max(ws.column_dimensions[CL(1 + i)].width or 0, w)
for i, (code, lname, ent, tracked, rule) in enumerate(LEAVE_TYPES):
    r = LV_POL_FIRST + i
    ws.cell(row=r, column=1, value=lname)
    ws.cell(row=r, column=2, value=code)
    ws.cell(row=r, column=3, value=ent)
    ws.cell(row=r, column=4, value="Yes" if tracked else "No")
    ws.cell(row=r, column=5, value=rule)
zebra(ws, LV_POL_FIRST, LV_POL_LAST, 1, 5)
for r in range(LV_POL_FIRST, LV_POL_LAST + 1):
    ws.cell(row=r, column=1).font = font(9, True, TEXT)
    for col in (2, 3, 4):
        ws.cell(row=r, column=col).alignment = Alignment(horizontal="center")
        ws.cell(row=r, column=col).font = font(9)
    ws.cell(row=r, column=5).font = font(9, False, MUTED)
dv = DataValidation(type="whole", operator="between", formula1="0", formula2="60", allow_blank=True,
                    showErrorMessage=True, errorTitle="Entitlement",
                    error="Entitlement must be between 0 and 60 days.")
ws.add_data_validation(dv); dv.add(f"C{LV_POL_FIRST}:C{LV_POL_LAST}")
note(ws, LV_POL_LAST + 2, "Remaining = entitlement minus approved/availed days. Comp Off and LWP have no "
                          "entitlement, so their remaining column mirrors the days used. Leave Type names must "
                          "match section A and the Lists tab - rename in all three places.", last_col=12)

# ---- chart: leave days by type ----
CH = LV_POL_LAST + 4
ws.cell(row=CH, column=1, value="Leave type").font = font(9, True, NAVY)
ws.cell(row=CH, column=2, value="Days approved").font = font(9, True, NAVY)
for i, (code, lname, ent, tracked, _r) in enumerate(LEAVE_TYPES):
    ws.cell(row=CH + 1 + i, column=1, value=lname).font = font(9, False, MUTED)
    cell = ws.cell(row=CH + 1 + i, column=2,
                   value=f'=SUMIFS({G_RANGE},{F_RANGE},$A{CH + 1 + i},{H_RANGE},"<>Rejected")')
    cell.font = font(9, True, TEXT)
    cell.alignment = Alignment(horizontal="center")
ch = BarChart()
ch.type = "bar"
ch.title = "Leave days by type (approved + availed)"
ch.height, ch.width = 7.4, 15
ch.style = 10
ch.gapWidth = 45
ch.legend = None
data = Reference(ws, min_col=2, min_row=CH, max_row=CH + len(LEAVE_TYPES))
cats = Reference(ws, min_col=1, min_row=CH + 1, max_row=CH + len(LEAVE_TYPES))
ch.add_data(data, titles_from_data=True)
ch.set_categories(cats)
ch.dLbls = DataLabelList(); ch.dLbls.showVal = True
ch.series[0].graphicalProperties.solidFill = PURPLE
ws.add_chart(ch, f"D{CH}")

# ==========================================================================
# SALARY CALCULATION
# ==========================================================================
ws = ws_sal
ws.sheet_properties.tabColor = GREEN
title_block(ws, f"SALARY CALCULATION  |  DEMO  |  {PAY_MONTH_LABEL.upper()}",
            "Illustrative payroll register. Basic pay comes from the Position Salary Template at the bottom of "
            "this sheet; days come from the Attendance sheet; PF and professional tax use simplified demo rules.",
            last_col=SC_CTC)
ws["A1"] = f'="SALARY CALCULATION  |  DEMO  |  "&UPPER(TEXT({MONTH_DATE},"mmmm yyyy"))'
ws["A1"].font = font(15, True, WHITE)
ws["A1"].alignment = Alignment(vertical="center", horizontal="left", indent=1)
kpi2(ws, 4, 1, "MONTHLY GROSS", f"=SUM(${CL(SC_GROSS)}${FIRST}:${CL(SC_GROSS)}${LAST})",
     "basic + allowances", NAVY, "#,##0")
kpi2(ws, 4, 4, "TOTAL ALLOWANCES", f"=SUM(${CL(SC_ALLOW)}${FIRST}:${CL(SC_ALLOW)}${LAST})",
     "HRA + conveyance + special", TEAL, "#,##0")
kpi2(ws, 4, 7, "ATTENDANCE DEDUCTION", f"=SUM(${CL(SC_DED_ATT)}${FIRST}:${CL(SC_DED_ATT)}${LAST})",
     "loss of pay for the month", RED, "#,##0")
kpi2(ws, 4, 10, "NET PAYOUT", f"=SUM(${CL(SC_NET)}${FIRST}:${CL(SC_NET)}${LAST})",
     "gross less deductions, this month", GREEN, "#,##0")
kpi2(ws, 4, 13, "EMPLOYER PF (COST)", f"=SUM(${CL(SC_ERPF)}${FIRST}:${CL(SC_ERPF)}${LAST})",
     "12% of basic, capped", AMBER, "#,##0")

section(ws, 8, f"PAYROLL REGISTER  -  {PAY_MONTH_LABEL.upper()}", last_col=SC_CTC)
sal_headers = ["Emp ID", "Employee Name", "Department", "Designation", "Grade", "Date of Joining",
               "Basic", "HRA (40%)", "Conveyance", "Special Allowance", "Total Allowances",
               "Gross Salary (monthly)", "Working Days", "Present Days", "Paid Days",
               "LWP Days (info)", "Per-Day Rate", "Overtime Pay", "Attendance Deduction",
               "PF Employee (12%)", "Professional Tax", "Other Deductions", "Total Deductions",
               "NET SALARY", "Annual Gross (approx.)", "Employer PF (cost)", "Total Cost to Company"]
sal_widths = [9, 26, 21, 25, 8, 12, 11, 10, 11, 12, 12, 14, 9, 9, 9, 10, 10, 11, 13, 12, 11, 11, 12, 14, 15, 12, 16]
header_row(ws, 9, sal_headers, widths=sal_widths, height=52)

for i in range(N_EMP):
    r = FIRST + i
    emp_row = FIRST + i
    att_row = FIRST + i
    ws.cell(row=r, column=SC_ID, value=f"='{EMP_SHEET}'!$A${emp_row}")
    ws.cell(row=r, column=SC_NAME, value=f"='{EMP_SHEET}'!$B${emp_row}")
    ws.cell(row=r, column=SC_DEPT, value=f"='{EMP_SHEET}'!$C${emp_row}")
    ws.cell(row=r, column=SC_DESIG, value=f"='{EMP_SHEET}'!$D${emp_row}")
    ws.cell(row=r, column=SC_GRADE, value=f"='{EMP_SHEET}'!$E${emp_row}")
    ws.cell(row=r, column=SC_DOJ, value=f"='{EMP_SHEET}'!$H${emp_row}").number_format = "dd-mmm-yy"
    look = f"MATCH(${CL(SC_DESIG)}{r},$B${SAL_TMPL_FIRST}:$B${SAL_TMPL_LAST},0)"
    ws.cell(row=r, column=SC_BASIC,
            value=f"=IFERROR(INDEX($C${SAL_TMPL_FIRST}:$C${SAL_TMPL_LAST},{look}),0)")
    ws.cell(row=r, column=SC_HRA, value=f"=ROUND(${CL(SC_BASIC)}{r}*0.4,0)")
    ws.cell(row=r, column=SC_CONV,
            value=f"=IFERROR(INDEX($D${SAL_TMPL_FIRST}:$D${SAL_TMPL_LAST},{look}),0)")
    ws.cell(row=r, column=SC_SPEC,
            value=f"=IFERROR(INDEX($E${SAL_TMPL_FIRST}:$E${SAL_TMPL_LAST},{look}),0)")
    ws.cell(row=r, column=SC_ALLOW, value=f"=SUM(${CL(SC_HRA)}{r}:${CL(SC_SPEC)}{r})")
    ws.cell(row=r, column=SC_GROSS, value=f"=${CL(SC_BASIC)}{r}+${CL(SC_ALLOW)}{r}")
    ws.cell(row=r, column=SC_WDAYS, value=f"='{ATT_SHEET}'!$C${ENG_NET}")
    ws.cell(row=r, column=SC_PRESENT, value=f"='{ATT_SHEET}'!${CL(AC_PRESENT)}${att_row}")
    ws.cell(row=r, column=SC_PAID, value=f"='{ATT_SHEET}'!${CL(AC_PAID)}${att_row}")
    ws.cell(row=r, column=SC_LWP, value=(
        f'=SUMIFS({LV_DAYS},{LV_EMPID},${CL(SC_ID)}{r},{LV_TYPE},"Leave Without Pay",{LV_STATUS},"Approved",'
        f'{LV_FROM},">="&DATE(YEAR({MONTH_CELL}),MONTH({MONTH_CELL}),1),'
        f'{LV_FROM},"<="&EOMONTH(DATE(YEAR({MONTH_CELL}),MONTH({MONTH_CELL}),1),0))'))
    ws.cell(row=r, column=SC_RATE,
            value=f"=IFERROR(ROUND(${CL(SC_GROSS)}{r}/MAX(1,${CL(SC_WDAYS)}{r}),2),0)").number_format = "0.00"
    ws.cell(row=r, column=SC_OT,
            value=f"=ROUND('{ATT_SHEET}'!${CL(AC_EXTRA)}${att_row}*${CL(SC_RATE)}{r}*1.5,0)")
    ws.cell(row=r, column=SC_DED_ATT,
            value=f"=ROUND('{ATT_SHEET}'!${CL(AC_SHORT)}${att_row}*${CL(SC_RATE)}{r},0)")
    ws.cell(row=r, column=SC_PF,
            value=f"=ROUND(MIN(${CL(SC_BASIC)}{r},15000)*0.12,0)")
    ws.cell(row=r, column=SC_PT,
            value=f"=IF(${CL(SC_GROSS)}{r}>=15000,200,IF(${CL(SC_GROSS)}{r}>=10000,150,0))")
    other = 400 if i % 6 == 4 else 0
    ws.cell(row=r, column=SC_OTHER, value=other)
    ws.cell(row=r, column=SC_TOTDED, value=f"=SUM(${CL(SC_DED_ATT)}{r}:${CL(SC_OTHER)}{r})")
    ws.cell(row=r, column=SC_NET, value=f"=MAX(0,${CL(SC_GROSS)}{r}-${CL(SC_TOTDED)}{r})")
    ws.cell(row=r, column=SC_ANNUAL, value=f"=ROUND(${CL(SC_GROSS)}{r}*12,0)")
    ws.cell(row=r, column=SC_ERPF, value=f"=ROUND(MIN(${CL(SC_BASIC)}{r},15000)*0.12,0)")
    ws.cell(row=r, column=SC_CTC, value=f"=${CL(SC_GROSS)}{r}+${CL(SC_ERPF)}{r}")

zebra(ws, FIRST, LAST, 1, SC_CTC)
for r in range(FIRST, LAST + 1):
    for col in range(1, SC_CTC + 1):
        cell = ws.cell(row=r, column=col)
        cell.font = font(9)
        if col >= SC_BASIC:
            cell.number_format = "#,##0"
        if col in (SC_GRADE, SC_WDAYS, SC_PRESENT, SC_PAID, SC_LWP):
            cell.alignment = Alignment(horizontal="center")
        if col == SC_RATE:
            cell.font = font(9, False, MUTED)
        if col in (SC_GROSS, SC_NET):
            cell.fill = fill(BLUE_BG)
            cell.font = font(9, True, NAVY)
        if col in (SC_DED_ATT,):
            cell.fill = fill(RED_BG)
        if col in (SC_ALLOW, SC_TOTDED):
            cell.font = font(9, False, MUTED)
    ws.cell(row=r, column=SC_NAME).font = font(9, True, TEXT)
    ws.cell(row=r, column=SC_ID).font = font(9, False, MUTED)

TR = LAST + 1
ws.merge_cells(start_row=TR, start_column=1, end_row=TR, end_column=SC_DOJ)
ws.cell(row=TR, column=1, value="TOTAL")
ws.cell(row=TR, column=1).alignment = Alignment(horizontal="right", indent=1)
for col in range(1, SC_CTC + 1):
    cell = ws.cell(row=TR, column=col)
    cell.fill = fill(NAVY)
    cell.font = font(10, True, WHITE)
    cell.border = Border(top=Side(style="medium", color=ACCENT))
sum_cols = [SC_BASIC, SC_HRA, SC_CONV, SC_SPEC, SC_ALLOW, SC_GROSS, SC_PRESENT, SC_PAID,
            SC_LWP, SC_OT, SC_DED_ATT, SC_PF, SC_PT, SC_OTHER, SC_TOTDED, SC_NET, SC_ANNUAL,
            SC_ERPF, SC_CTC]
for col in sum_cols:
    cell = ws.cell(row=TR, column=col,
                   value=f"=SUM({CL(col)}{FIRST}:{CL(col)}{LAST})")
    cell.alignment = Alignment(horizontal="center")
    cell.number_format = "#,##0"
    if col in (SC_PRESENT, SC_PAID, SC_LWP):
        cell.number_format = "0.0"
ws.cell(row=TR, column=SC_WDAYS, value=f"=MAX({CL(SC_WDAYS)}{FIRST}:{CL(SC_WDAYS)}{LAST})")
ws.cell(row=TR, column=SC_WDAYS).alignment = Alignment(horizontal="center")
ws.cell(row=TR, column=SC_RATE, value=f"=IFERROR({CL(SC_NET)}{TR}/{CL(SC_PAID)}{TR},0)")
ws.cell(row=TR, column=SC_RATE).number_format = "0.00"
ws.cell(row=TR, column=SC_RATE).alignment = Alignment(horizontal="center")
ws.row_dimensions[TR].height = 22

ws.conditional_formatting.add(f"{CL(SC_NET)}{FIRST}:{CL(SC_NET)}{LAST}", DataBarRule(
    start_type="num", start_value=0, end_type="max", color=GREEN, showValue=True))
ws.conditional_formatting.add(f"{CL(SC_DED_ATT)}{FIRST}:{CL(SC_DED_ATT)}{LAST}", CellIsRule(
    operator="greaterThan", formula=["0"], fill=fill(RED_BG), font=font(9, True, RED)))

ws.freeze_panes = "C10"
dv = DataValidation(type="decimal", operator="greaterThanOrEqual", formula1="0", allow_blank=True,
                    showErrorMessage=True, errorTitle="Other deductions",
                    error="Enter a positive amount, or leave it blank.")
ws.add_data_validation(dv); dv.add(f"{CL(SC_OTHER)}{FIRST}:{CL(SC_OTHER)}{LAST}")
dv = DataValidation(type="decimal", operator="between", formula1="5000", formula2="500000", allow_blank=True,
                    showErrorMessage=True, errorTitle="Basic pay",
                    error="Basic pay looks unrealistic - it should be between 5,000 and 5,00,000.")
ws.add_data_validation(dv); dv.add(f"C{SAL_TMPL_FIRST}:C{SAL_TMPL_LAST}")
dv = DataValidation(type="decimal", operator="between", formula1="0", formula2="200000", allow_blank=True,
                    showErrorMessage=True, errorTitle="Allowance",
                    error="Allowances should be between 0 and 2,00,000.")
ws.add_data_validation(dv); dv.add(f"D{SAL_TMPL_FIRST}:E{SAL_TMPL_LAST}")
note(ws, LAST + 2, "Paid Days = MIN(working days, present days). Attendance Deduction = (working days - paid days) "
                   "x per-day rate, so leave without pay is recovered once only. LWP Days is an audit column, not "
                   "a second deduction.", last_col=SC_CTC)

# ---- position salary template ----
section(ws, SAL_TMPL_HDR - 2, "POSITION SALARY TEMPLATE  -  edit a component and every salary line updates",
        last_col=8)
header_row(ws, SAL_TMPL_HDR, ["Grade", "Position", "Basic", "Conveyance", "Special Allowance",
                              "Gross (monthly)", "Annual (approx.)", "Employees in position"],
           height=32)
for i, (title, dept, grade, basic, conv, spec) in enumerate(POSITIONS):
    r = SAL_TMPL_FIRST + i
    ws.cell(row=r, column=1, value=grade).alignment = Alignment(horizontal="center")
    ws.cell(row=r, column=2, value=title)
    ws.cell(row=r, column=3, value=basic).number_format = "#,##0"
    ws.cell(row=r, column=4, value=conv).number_format = "#,##0"
    ws.cell(row=r, column=5, value=spec).number_format = "#,##0"
    ws.cell(row=r, column=6, value=f"=SUM($C{r}:$E{r})").number_format = "#,##0"
    ws.cell(row=r, column=7, value=f"=ROUND($F{r}*12,0)").number_format = "#,##0"
    ws.cell(row=r, column=8, value=f'=COUNTIF(${CL(SC_DESIG)}${FIRST}:${CL(SC_DESIG)}${LAST},$B{r})')
    ws.cell(row=r, column=8).alignment = Alignment(horizontal="center")
    for col in range(1, 9):
        cell = ws.cell(row=r, column=col)
        cell.border = BOX
        cell.font = font(9) if col != 2 else font(9, True, TEXT)
        if col in (3, 4, 5, 6, 7):
            cell.alignment = Alignment(horizontal="right")
        if col == 6:
            cell.fill = fill(BLUE_BG)
    if i % 2:
        for col in range(1, 6):
            ws.cell(row=r, column=col).fill = fill(GREY_BG)
for r in range(SAL_TMPL_FIRST + len(POSITIONS), SAL_TMPL_LAST + 1):
    for col in range(1, 9):
        ws.cell(row=r, column=col).border = BOX
ws.merge_cells(start_row=SAL_TMPL_LAST + 1, start_column=1, end_row=SAL_TMPL_LAST + 1, end_column=8)
templ_note = ws.cell(row=SAL_TMPL_LAST + 1, column=1,
                     value="Rows below the last position are blank on purpose: add a new position there and it "
                           "appears in the Designation drop-down.")
templ_note.font = font(8.5, False, MUTED, italic=True)

# ---- pay policy ----
PR = SAL_TMPL_LAST + 4
section(ws, PR, "PAY POLICY  -  simplified demo assumptions", last_col=10)
policy = [
    ("Basic salary", "From the Position Salary Template, matched on Designation"),
    ("HRA", "40% of basic (illustrative metro-style rate)"),
    ("Conveyance / Special allowance", "Fixed per position in the template"),
    ("Per-day rate", "Gross salary / working days in the month"),
    ("Attendance deduction", "(Working days - paid days) x per-day rate"),
    ("Overtime", "Extras (attendance) x per-day rate x 1.5"),
    ("PF - employee", "12% of basic, capped at a Rs.15,000 wage ceiling (demo cap)"),
    ("PF - employer", "Same 12% cap, shown as an additional cost, not deducted from net"),
    ("Professional tax", "Rs.200 above Rs.15,000 gross, Rs.150 above Rs.10,000, else nil"),
    ("Other deductions", "Manual entry column for advances, canteen, etc."),
    ("Net salary", "Gross - attendance deduction - PF - professional tax - other deductions (never below zero)"),
]
for i, (k, v) in enumerate(policy):
    r = PR + 1 + i
    ws.cell(row=r, column=1, value=k).font = font(9, True, NAVY)
    ws.merge_cells(start_row=r, start_column=1, end_row=r, end_column=2)
    ws.cell(row=r, column=3, value=v).font = font(9, False, MUTED)
    ws.merge_cells(start_row=r, start_column=3, end_row=r, end_column=10)
    ws.cell(row=r, column=3).alignment = Alignment(indent=1)
note(ws, PR + len(policy) + 2,
     "DEMO ONLY. These rules are deliberately simplified and the numbers are fictional. Real payroll also involves "
     "ESI, gratuity, TDS, statutory bonus and state-wise professional tax. Have HR/finance review any structure "
     "before it is used for actual payments.", last_col=10, color=RED)

# ==========================================================================
# DEPARTMENT DETAILS
# ==========================================================================
ws = ws_dept
ws.sheet_properties.tabColor = "2F5D8C"
title_block(ws, "DEPARTMENT DETAILS  |  DEMO  |  Apex Enterprises",
            "Eight sample departments with heads, budgets and approved headcount. The blue columns roll up "
            "employees, leave and cost from the other sheets - nobody types them.",
            last_col=D_EMAIL)
kpi2(ws, 4, 1, "DEPARTMENTS", f"=COUNTA($A${DEP_FIRST}:$A${DEP_LAST})", "on the register", NAVY)
kpi2(ws, 4, 4, "APPROVED HEADCOUNT", f"=SUM($F${DEP_FIRST}:$F${DEP_LAST})", "sanctioned positions", TEAL)
kpi2(ws, 4, 6, "ACTUAL HEADCOUNT", f"=SUM($I${DEP_FIRST}:$I${DEP_LAST})", "employees assigned", GREEN)
kpi2(ws, 4, 8, "MONTHLY BUDGET", f"=SUM($E${DEP_FIRST}:$E${DEP_LAST})", "all departments", ACCENT, "#,##0")
kpi2(ws, 4, 11, "VACANCIES", f"=SUM($M${DEP_FIRST}:$M${DEP_LAST})", "approved less actual", RED)

header_row(ws, 8, ["Dept Code", "Department", "Head of Department", "Cost Centre", "Monthly Budget",
                   "Approved Headcount", "Location", "Default Shift", "Employees", "Active",
                   "On Probation", "Notice Period", "Vacancies", "Headcount Utilisation",
                   "Budget per Employee", "Actual Monthly Cost", "Avg Monthly Gross",
                   "Budget Utilisation", "Avg Tenure (yrs)", "Hours / Month", "Extension",
                   "Dept E-mail"],
           widths=[10, 22, 19, 11, 14, 12, 10, 24, 10, 8, 11, 11, 10, 13, 14, 15, 14, 13, 11, 13, 10, 30],
           height=48)

for i, (code, name, head, cc, loc, shift, budget, ext, email, approved) in enumerate(DEPTS):
    r = DEP_FIRST + i
    ws.cell(row=r, column=D_CODE, value=code)
    ws.cell(row=r, column=D_NAME, value=name)
    ws.cell(row=r, column=D_HEAD, value=head)
    ws.cell(row=r, column=D_CC, value=cc)
    ws.cell(row=r, column=D_BUDGET, value=budget).number_format = "#,##0"
    ws.cell(row=r, column=D_APPROVED, value=approved)
    ws.cell(row=r, column=D_LOC, value=loc)
    ws.cell(row=r, column=D_SHIFT, value=shift)
    dept_rng = f"'{EMP_SHEET}'!$C${FIRST}:$C${LAST}"
    status_rng = f"'{EMP_SHEET}'!$G${FIRST}:$G${LAST}"
    ws.cell(row=r, column=D_EMP, value=f"=COUNTIF({dept_rng},$B{r})")
    ws.cell(row=r, column=D_ACTIVE, value=f'=COUNTIFS({dept_rng},$B{r},{status_rng},"Active")')
    ws.cell(row=r, column=D_PROB, value=f'=COUNTIFS({dept_rng},$B{r},{status_rng},"On Probation")')
    ws.cell(row=r, column=D_NOTICE, value=f'=COUNTIFS({dept_rng},$B{r},{status_rng},"Notice Period")')
    ws.cell(row=r, column=D_VAC, value=f"=MAX(0,$F{r}-$I{r})")
    ws.cell(row=r, column=D_UTIL, value=f"=IFERROR($I{r}/$F{r},0)").number_format = "0%"
    ws.cell(row=r, column=D_BUD_EMP, value=f"=IFERROR($E{r}/$I{r},0)").number_format = "#,##0"
    ws.cell(row=r, column=D_COST, value=(
        f'=IFERROR(SUMIF(\'{SAL_SHEET}\'!$C${FIRST}:$C${LAST},$B{r},'
        f"'{SAL_SHEET}'!${CL(SC_GROSS)}${FIRST}:${CL(SC_GROSS)}${LAST}),0)")).number_format = "#,##0"
    ws.cell(row=r, column=D_AVGGROSS, value=f"=IFERROR($P{r}/$I{r},0)").number_format = "#,##0"
    ws.cell(row=r, column=D_BUDUTIL, value=f"=IFERROR($P{r}/$E{r},0)").number_format = "0.0%"
    ws.cell(row=r, column=D_TENURE, value=(
        f"=IFERROR(AVERAGEIF({dept_rng},$B{r},'{EMP_SHEET}'!$Q${FIRST}:$Q${LAST}),0)")).number_format = "0.0"
    ws.cell(row=r, column=D_HOURS, value=f"='{ATT_SHEET}'!$C${ENG_HRS}").number_format = "0"
    ws.cell(row=r, column=D_EXT, value=ext)
    ws.cell(row=r, column=D_EMAIL, value=email)

zebra(ws, DEP_FIRST, DEP_LAST, 1, D_EMAIL)
for r in range(DEP_FIRST, DEP_LAST + 1):
    ws.cell(row=r, column=D_NAME).font = font(10, True, TEXT)
    for col in range(1, D_EMAIL + 1):
        cell = ws.cell(row=r, column=col)
        if col != D_NAME:
            cell.font = font(9)
        if col in (D_CODE, D_APPROVED, D_EMP, D_ACTIVE, D_PROB, D_NOTICE, D_VAC, D_UTIL,
                   D_TENURE, D_HOURS, D_EXT, D_BUDUTIL):
            cell.alignment = Alignment(horizontal="center")
        if col in (D_BUDGET, D_BUD_EMP, D_COST, D_AVGGROSS):
            cell.alignment = Alignment(horizontal="right")
        if col in (D_EMP, D_ACTIVE, D_PROB, D_NOTICE, D_VAC, D_UTIL, D_COST, D_AVGGROSS,
                   D_BUDUTIL, D_TENURE, D_BUD_EMP):
            cell.fill = fill(BLUE_BG)
            cell.font = font(9, False, NAVY)
    ws.cell(row=r, column=D_EMP).font = font(10, True, NAVY)
    ws.cell(row=r, column=D_COST).font = font(9, True, NAVY)

ws.merge_cells(start_row=DTR, start_column=1, end_row=DTR, end_column=D_CC)
ws.cell(row=DTR, column=1, value="TOTAL")
ws.cell(row=DTR, column=1).alignment = Alignment(horizontal="right", indent=1)
for col in range(1, D_EMAIL + 1):
    cell = ws.cell(row=DTR, column=col)
    cell.fill = fill(NAVY)
    cell.font = font(10, True, WHITE)
for col in (D_BUDGET, D_APPROVED, D_EMP, D_ACTIVE, D_PROB, D_NOTICE, D_VAC, D_COST):
    cell = ws.cell(row=DTR, column=col, value=f"=SUM({CL(col)}{DEP_FIRST}:{CL(col)}{DEP_LAST})")
    cell.number_format = "#,##0"
    cell.alignment = Alignment(horizontal="center")
ws.cell(row=DTR, column=D_UTIL, value=f"=IFERROR($I{DTR}/$F{DTR},0)").number_format = "0%"
ws.cell(row=DTR, column=D_BUDUTIL, value=f"=IFERROR($P{DTR}/$E{DTR},0)").number_format = "0.0%"
for col in (D_UTIL, D_BUDUTIL):
    ws.cell(row=DTR, column=col).alignment = Alignment(horizontal="center")
ws.row_dimensions[DTR].height = 20

ws.conditional_formatting.add(f"M{DEP_FIRST}:M{DEP_LAST}", CellIsRule(
    operator="greaterThan", formula=["0"], fill=fill(RED_BG), font=font(9, True, RED)))
ws.conditional_formatting.add(f"N{DEP_FIRST}:N{DEP_LAST}", ColorScaleRule(
    start_type="num", start_value=0, start_color="F8C9C4",
    mid_type="num", mid_value=0.85, mid_color="FFEFC2",
    end_type="num", end_value=1, end_color="B7E4C7"))
ws.conditional_formatting.add(f"R{DEP_FIRST}:R{DEP_LAST}", ColorScaleRule(
    start_type="num", start_value=0, start_color="B7E4C7",
    mid_type="num", mid_value=0.9, mid_color="FFEFC2",
    end_type="num", end_value=1.2, end_color="F8C9C4"))

dv = DataValidation(type="decimal", operator="between", formula1="0", formula2="100000000", allow_blank=True,
                    showErrorMessage=True, errorTitle="Monthly budget",
                    error="Enter the monthly budget as a number, e.g. 250000.")
ws.add_data_validation(dv); dv.add(f"E{DEP_FIRST}:E{DEP_LAST}")
dv = DataValidation(type="whole", operator="between", formula1="0", formula2="500", allow_blank=True,
                    showErrorMessage=True, errorTitle="Approved headcount",
                    error="Approved headcount must be a whole number between 0 and 500.")
ws.add_data_validation(dv); dv.add(f"F{DEP_FIRST}:F{DEP_LAST}")

ws.freeze_panes = "C9"

# add-a-department steps
AR = DTR + 3
section(ws, AR, "ADD A DEPARTMENT IN 3 STEPS", last_col=12)
steps = [
    "Type the code, name, head, cost centre, budget, approved headcount, location and shift in the first empty row.",
    "The blue columns count the employees whose Department on the Employee Database exactly matches this name.",
    "Assign people to it from the Department drop-down on the Employee Database tab - nothing else to do.",
]
for i, t in enumerate(steps):
    r = AR + 1 + i
    n = ws.cell(row=r, column=1, value=i + 1)
    n.font = font(10, True, WHITE)
    n.fill = fill(TEAL)
    n.alignment = Alignment(horizontal="center")
    ws.merge_cells(start_row=r, start_column=2, end_row=r, end_column=12)
    c2 = ws.cell(row=r, column=2, value=t)
    c2.font = font(9, False, TEXT)
    c2.alignment = Alignment(indent=1, vertical="center")

# live department check
SR = AR + 5
section(ws, SR, "LIVE DEPARTMENT CHECK  -  pick a department in the amber cell", last_col=12)
ws.merge_cells(start_row=SR + 1, start_column=1, end_row=SR + 1, end_column=3)
ws.cell(row=SR + 1, column=1, value="Department to inspect").font = font(9, True, MUTED)
ws.cell(row=SR + 1, column=1).alignment = Alignment(vertical="center", indent=1)
pick = ws.cell(row=SR + 1, column=4, value="Operations")
pick.font = font(10, True, NAVY)
pick.fill = fill(AMBER_BG)
pick.border = BOX
pick.alignment = Alignment(horizontal="center")
ws.merge_cells(start_row=SR + 1, start_column=4, end_row=SR + 1, end_column=5)
dv = DataValidation(type="list", formula1=DEPTS_RNG, allow_blank=False, **EMSG)
ws.add_data_validation(dv); dv.add(f"D{SR + 1}")

ws.merge_cells(start_row=SR + 1, start_column=1, end_row=SR + 1, end_column=1)
checks = [
    ("Employees in department", f"=IFERROR(COUNTIF({dept_rng},$D${SR + 1}),0)", "0"),
    ("Active employees", f'=IFERROR(COUNTIFS({dept_rng},$D${SR + 1},{status_rng},"Active"),0)', "0"),
    ("Approved headcount", f"=IFERROR(INDEX($F${DEP_FIRST}:$F${DEP_LAST},MATCH($D${SR + 1},$B${DEP_FIRST}:$B${DEP_LAST},0)),0)", "0"),
    ("Vacancies", f"=MAX(0,$D${SR + 3}-$D${SR + 2})", "0"),
    ("Monthly budget", f"=IFERROR(INDEX($E${DEP_FIRST}:$E${DEP_LAST},MATCH($D${SR + 1},$B${DEP_FIRST}:$B${DEP_LAST},0)),0)", "#,##0"),
    ("Actual monthly cost", f"=IFERROR(INDEX($P${DEP_FIRST}:$P${DEP_LAST},MATCH($D${SR + 1},$B${DEP_FIRST}:$B${DEP_LAST},0)),0)", "#,##0"),
    ("Budget used", f"=IFERROR($D${SR + 7}/$D${SR + 6},0)", "0.0%"),
    ("Average tenure (yrs)", f"=IFERROR(INDEX($S${DEP_FIRST}:$S${DEP_LAST},MATCH($D${SR + 1},$B${DEP_FIRST}:$B${DEP_LAST},0)),0)", "0.0"),
]
for i, (label, formula, fmt) in enumerate(checks):
    r = SR + 2 + i
    ws.merge_cells(start_row=r, start_column=1, end_row=r, end_column=3)
    lab = ws.cell(row=r, column=1, value=label)
    lab.font = font(9, False, MUTED)
    lab.alignment = Alignment(vertical="center", indent=1)
    lab.fill = fill(GREY_BG)
    lab.border = BOX
    for cc in (2, 3):
        ws.cell(row=r, column=cc).fill = fill(GREY_BG)
        ws.cell(row=r, column=cc).border = BOX
    ws.merge_cells(start_row=r, start_column=4, end_row=r, end_column=5)
    cell = ws.cell(row=r, column=4, value=formula)
    cell.font = font(10, True, NAVY)
    cell.number_format = fmt
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.fill = fill(WHITE)
    cell.border = BOX
    ws.cell(row=r, column=5).fill = fill(WHITE)
    ws.cell(row=r, column=5).border = BOX

# ==========================================================================
# CONTACT DIRECTORY
# ==========================================================================
ws = ws_cont
ws.sheet_properties.tabColor = NAVY_SOFT
title_block(ws, "EMPLOYEE CONTACT DIRECTORY  |  DEMO  |  Apex Enterprises",
            "Filterable staff directory. Columns A-F flow from the Employee Database; mobile, personal e-mail, "
            "emergency contact and address are maintained here. No real personal data is used.",
            last_col=12)
kpi2(ws, 4, 1, "CONTACTS", f"=COUNTA($B${FIRST}:$B${LAST})", "employees listed", NAVY)
kpi2(ws, 4, 4, "WORK E-MAILS", f"=COUNTA($E${FIRST}:$E${LAST})", "on apex-demo.example", TEAL)
kpi2(ws, 4, 7, "EMERGENCY CONTACTS", f"=COUNTA($J${FIRST}:$J${LAST})", "on file", GREEN)
kpi2(ws, 4, 10, "BLOOD GROUPS", f'=SUMPRODUCT(--($I${FIRST}:$I${LAST}<>""))',
     "recorded (not verified)", AMBER)

DIR_HEADERS = ["Emp ID", "Employee Name", "Department", "Designation", "Work E-mail", "Extension",
               "Mobile", "Personal E-mail", "Blood Group", "Emergency Contact",
               "Emergency Phone", "Residential Address"]
DIR_WIDTHS = [13, 20, 21, 24, 33, 10, 17, 25, 10, 20, 17, 44]
header_row(ws, 9, DIR_HEADERS, widths=DIR_WIDTHS, height=36)

link_cols = {1: E_ID, 2: E_NAME, 3: E_DEPT, 4: E_DESIG, 5: E_MAIL, 6: E_EXT, 9: E_BLOOD}
literal_idx = {7: 11, 8: 9, 10: 12, 11: 13, 12: 14}
for i, e in enumerate(EMPLOYEES):
    r = FIRST + i
    emp_row = FIRST + i
    for col in range(1, 13):
        if col in link_cols:
            value = f"='{EMP_SHEET}'!${CL(link_cols[col])}${emp_row}"
        else:
            value = e[literal_idx[col]]
        cell = ws.cell(row=r, column=col, value=value)
        cell.font = font(9)
        if col in (1, 6, 9):
            cell.alignment = Alignment(horizontal="center")
        if col == 2:
            cell.font = font(9, True, TEXT)
        if col == 5:
            cell.font = font(9, False, TEAL)
zebra(ws, FIRST, LAST, 1, 12)
for i, e in enumerate(EMPLOYEES):
    r = FIRST + i
    cell = ws.cell(row=r, column=5)
    cell.hyperlink = f"mailto:{e[8]}"
    cell.font = font(9, False, TEAL)
    ws.cell(row=r, column=6).number_format = "0"

ws.freeze_panes = "C10"
ws.auto_filter.ref = f"A9:L{LAST}"

dv = DataValidation(type="custom", formula1='=OR($H10="",ISNUMBER(SEARCH("@",$H10)))', allow_blank=True,
                    showErrorMessage=True, errorTitle="Personal e-mail",
                    error="That does not look like an e-mail address (no @ found).")
ws.add_data_validation(dv); dv.add(f"H{FIRST}:H{LAST+20}")

SQ = LAST + 3
section(ws, SQ, "QUICK LOOKUP  -  select an employee", last_col=6)
ws.cell(row=SQ + 1, column=1, value="Employee").font = font(9, True, MUTED)
sel = ws.cell(row=SQ + 1, column=2, value=EMPLOYEES[8][1])
sel.font = font(10, True, NAVY)
sel.fill = fill(AMBER_BG)
sel.border = BOX
ws.merge_cells(start_row=SQ + 1, start_column=2, end_row=SQ + 1, end_column=4)
dv = DataValidation(type="list", formula1=EMP_NAMES_RNG, allow_blank=False, **EMSG)
ws.add_data_validation(dv); dv.add(f"B{SQ + 1}")

lookup = [("Employee ID", 1), ("Department", 3), ("Designation", 4), ("Work E-mail", 5),
          ("Extension", 6), ("Mobile", 7), ("Emergency Contact", 10), ("Emergency Phone", 11),
          ("Blood Group", 9), ("Address", 12)]
for i, (label, col) in enumerate(lookup):
    r = SQ + 3 + i
    ws.cell(row=r, column=1, value=label).font = font(9, False, MUTED)
    formula = (f"=IFERROR(INDEX(${CL(col)}${FIRST}:${CL(col)}${LAST},"
               f"MATCH($B${SQ + 1},$B${FIRST}:$B${LAST},0)),\"\")")
    cell = ws.cell(row=r, column=2, value=formula)
    cell.font = font(9.5, True, TEXT)
    cell.fill = fill(GREY_BG)
    cell.border = BOX
    ws.merge_cells(start_row=r, start_column=2, end_row=r, end_column=5)
    cell.alignment = Alignment(vertical="center", indent=1)

# extension quick dial, department-wise
EQ = SQ + 16
section(ws, EQ, "EXTENSION QUICK-DIAL  -  filter by department for a printed list", last_col=6)
header_row(ws, EQ + 1, ["Extension", "Employee", "Department", "Mobile", "", "", "", "", "", "", "", ""],
           height=24)
for i in range(len(EMPLOYEES)):
    r = EQ + 2 + i
    emp_row = FIRST + i
    ws.cell(row=r, column=1, value=f"='{EMP_SHEET}'!$J${emp_row}").alignment = Alignment(horizontal="center")
    ws.cell(row=r, column=2, value=f"='{EMP_SHEET}'!$B${emp_row}")
    ws.cell(row=r, column=3, value=f"='{EMP_SHEET}'!$C${emp_row}")
    ws.cell(row=r, column=4, value=EMPLOYEES[i][11])
    for col in range(1, 5):
        cell = ws.cell(row=r, column=col)
        cell.border = BOX
        cell.font = font(9)
    ws.cell(row=r, column=1).font = font(9, True, NAVY)

# ==========================================================================
# DASHBOARD
# ==========================================================================
ws = ws_dash
ws.sheet_view.showGridLines = False
ws.sheet_properties.tabColor = "B3261E"
DASH_COLS = 34
ws.column_dimensions["A"].width = 1.6
for col in range(2, DASH_COLS + 1):
    ws.column_dimensions[CL(col)].width = 4.35

title_block(ws, "APEX ENTERPRISES  |  MONTHLY MANAGEMENT DASHBOARD  |  DEMO",
            "Headcount, attendance, leave and payroll on one screen. Every figure is a live formula - change the "
            "reporting month on the Lists tab and this page follows. All data is fictional.",
            last_col=DASH_COLS, banner_rows=3)
ws["A2"] = (f'="Headcount, attendance, leave and payroll for "&TEXT({MONTH_DATE},"mmmm yyyy")&'
            f'" - every figure is a live formula. Change the month on the Lists tab and this page '
            f'follows."')
ws["A2"].font = font(9, False, "C9D4E6", italic=True)
ws.row_dimensions[3].height = 18

ws["B5"] = f'="Month:  "&TEXT({MONTH_DATE},"mmmm yyyy")'
ws["B5"].font = font(13, True, NAVY)
ws["B5"].alignment = Alignment(horizontal="left", vertical="center", indent=1)
ws["B5"].fill = fill(WHITE)
ws["B5"].border = Border(left=Side(style="thick", color=ACCENT), top=THIN, right=THIN, bottom=THIN)
ws.merge_cells("B5:G5")
ws.row_dimensions[5].height = 22

# --- people KPI strip ---
section(ws, 7, "PEOPLE", last_col=DASH_COLS)
people = [
    ("HEADCOUNT", f"=COUNTA('{EMP_SHEET}'!$A${FIRST}:$A${LAST})", "on the register", TEAL, "0"),
    ("DEPARTMENTS", f"=COUNTIF({rng(D_EMP, DEP_FIRST, DEP_LAST, DEPT_SHEET)},\">0\")",
     "with staff", NAVY, "0"),
    ("ATTENDANCE", f"=IFERROR(SUM('{ATT_SHEET}'!${CL(AC_PRESENT)}${FIRST}:${CL(AC_PRESENT)}${LAST})/"
                   f"(COUNTA('{ATT_SHEET}'!$B${FIRST}:$B${LAST})*'{ATT_SHEET}'!$C${ENG_NET}),0)",
     "present / working days", GREEN, "0.0%"),
    ("LEAVE IN MONTH", f"=COUNTIF('{LEAVE_SHEET}'!$K${LV_FIRST}:$K${LV_LAST},\"Yes\")",
     "requests this month", AMBER, "0"),
    ("LOSS OF PAY", f"=SUM('{SAL_SHEET}'!${CL(SC_DED_ATT)}${FIRST}:${CL(SC_DED_ATT)}${LAST})",
     "unpaid days", RED, "#,##0"),
    ("VACANCIES", f"=SUM({rng(D_VAC, DEP_FIRST, DEP_LAST, DEPT_SHEET)})", "unfilled posts", PURPLE, "0"),
]
for i, (label, formula, sub, color, fmt) in enumerate(people):
    kpi_wide(ws, 8, 2 + i * 5, 4, label, formula, sub, color, fmt)
    ws.column_dimensions[CL(2 + i * 5 + 4)].width = 2.2

section(ws, 12, "PAYROLL SNAPSHOT", last_col=DASH_COLS)
payroll = [
    ("MONTHLY GROSS", f"=SUM('{SAL_SHEET}'!${CL(SC_GROSS)}${FIRST}:${CL(SC_GROSS)}${LAST})",
     "basic + allowances", NAVY, "#,##0"),
    ("NET PAYOUT", f"=SUM('{SAL_SHEET}'!${CL(SC_NET)}${FIRST}:${CL(SC_NET)}${LAST})",
     "after deductions", GREEN, "#,##0"),
    ("AVG NET SALARY", f"=IFERROR(AVERAGE('{SAL_SHEET}'!${CL(SC_NET)}${FIRST}:${CL(SC_NET)}${LAST}),0)",
     "per employee", TEAL, "#,##0"),
    ("DEDUCTIONS", f"=SUM('{SAL_SHEET}'!${CL(SC_TOTDED)}${FIRST}:${CL(SC_TOTDED)}${LAST})",
     "PF, tax, unpaid", RED, "#,##0"),
    ("EMPLOYER PF", f"=SUM('{SAL_SHEET}'!${CL(SC_ERPF)}${FIRST}:${CL(SC_ERPF)}${LAST})",
     "additional cost", AMBER, "#,##0"),
    ("BUDGET / MONTH", f"=SUM('{DEPT_SHEET}'!$E${DEP_FIRST}:$E${DEP_LAST})",
     "approved, monthly", PURPLE, "#,##0"),
]
for i, (label, formula, sub, color, fmt) in enumerate(payroll):
    kpi_wide(ws, 13, 2 + i * 5, 4, label, formula, sub, color, fmt)

# --- insight cards ---
section(ws, 17, "AT A GLANCE", last_col=DASH_COLS)
DD = f"'{DEPT_SHEET}'"
insights = [
    ("LARGEST DEPARTMENT",
     f'=INDEX({DD}!$B${DEP_FIRST}:$B${DEP_LAST},MATCH(MAX({DD}!$I${DEP_FIRST}:$I${DEP_LAST}),'
     f'{DD}!$I${DEP_FIRST}:$I${DEP_LAST},0))&" - "&MAX({DD}!$I${DEP_FIRST}:$I${DEP_LAST})&" people"',
     "by headcount", TEAL),
    ("BUDGET WATCH",
     f'=INDEX({DD}!$B${DEP_FIRST}:$B${DEP_LAST},MATCH(MAX({DD}!$R${DEP_FIRST}:$R${DEP_LAST}),'
     f'{DD}!$R${DEP_FIRST}:$R${DEP_LAST},0))&" - "&TEXT(MAX({DD}!$R${DEP_FIRST}:$R${DEP_LAST}),"0.0%")'
     f'&" used"',
     "actual cost vs approved budget", AMBER),
    ("MOST LEAVE TAKEN",
     f'=INDEX(\'{LEAVE_SHEET}\'!$B${LV_BAL_FIRST}:$B${LV_BAL_LAST},'
     f'MATCH(MAX(\'{LEAVE_SHEET}\'!$N${LV_BAL_FIRST}:$N${LV_BAL_LAST}),'
     f'\'{LEAVE_SHEET}\'!$N${LV_BAL_FIRST}:$N${LV_BAL_LAST},0))&"  -  "&'
     f'MAX(\'{LEAVE_SHEET}\'!$N${LV_BAL_FIRST}:$N${LV_BAL_LAST})&" days"',
     "all leave types, year to date", PURPLE),
]
for i, (label, formula, sub, color) in enumerate(insights):
    kpi_wide(ws, 18, 2 + i * 11, 10, label, formula, sub, color, "@")
    for col in range(2 + i * 11, 12 + i * 11):
        ws.cell(row=19, column=col).font = font(12, True, NAVY)

# --- helper data far right ---
HD = 36  # helper column start (AJ)
ws.cell(row=6, column=HD, value="helper").font = font(7, False, MUTED)
ws.cell(row=7, column=HD, value="Department").font = font(7, True, MUTED)
ws.cell(row=7, column=HD + 1, value="Headcount").font = font(7, True, MUTED)
ws.cell(row=7, column=HD + 2, value="Cost").font = font(7, True, MUTED)
ws.cell(row=7, column=HD + 3, value="Budget").font = font(7, True, MUTED)
for i in range(len(DEPTS)):
    r = 8 + i
    ws.cell(row=r, column=HD, value=f"='{DEPT_SHEET}'!$B${DEP_FIRST + i}").font = font(7, False, MUTED)
    ws.cell(row=r, column=HD + 1, value=f"='{DEPT_SHEET}'!$I${DEP_FIRST + i}").font = font(7, False, MUTED)
    ws.cell(row=r, column=HD + 2, value=f"='{DEPT_SHEET}'!$P${DEP_FIRST + i}").font = font(7, False, MUTED)
    ws.cell(row=r, column=HD + 3, value=f"='{DEPT_SHEET}'!$E${DEP_FIRST + i}").font = font(7, False, MUTED)
for col in range(HD, HD + 4):
    ws.column_dimensions[CL(col)].width = 15

# attendance mix helper
AH_ROW = 18
ws.cell(row=AH_ROW, column=HD, value="Attendance").font = font(7, True, MUTED)
ws.cell(row=AH_ROW, column=HD + 1, value="Days").font = font(7, True, MUTED)
att_mix = [
    ("Present (incl. half days)", f"=SUM('{ATT_SHEET}'!${CL(AC_P)}${FIRST}:${CL(AC_P)}${LAST})"
                                  f"+SUM('{ATT_SHEET}'!${CL(AC_WFH)}${FIRST}:${CL(AC_WFH)}${LAST})"
                                  f"+SUM('{ATT_SHEET}'!${CL(AC_HD)}${FIRST}:${CL(AC_HD)}${LAST})*0.5"),
    ("Work From Home", f"=SUM('{ATT_SHEET}'!${CL(AC_WFH)}${FIRST}:${CL(AC_WFH)}${LAST})"),
    ("Half Days", f"=SUM('{ATT_SHEET}'!${CL(AC_HD)}${FIRST}:${CL(AC_HD)}${LAST})"),
    ("On Leave", f"=SUM('{ATT_SHEET}'!${CL(AC_L)}${FIRST}:${CL(AC_L)}${LAST})"),
    ("Weekly Off + Holidays", f"=SUM('{ATT_SHEET}'!${CL(AC_WO)}${FIRST}:${CL(AC_WO)}${LAST})"
                              f"+SUM('{ATT_SHEET}'!${CL(AC_HOL)}${FIRST}:${CL(AC_HOL)}${LAST})"),
    ("Absent / Unmarked", f"=SUM('{ATT_SHEET}'!${CL(AC_H)}${FIRST}:${CL(AC_H)}${LAST})"),
]
for i, (label, formula) in enumerate(att_mix):
    r = AH_ROW + 1 + i
    ws.cell(row=r, column=HD, value=label).font = font(7, False, MUTED)
    ws.cell(row=r, column=HD + 1, value=formula).font = font(7, False, MUTED)

# leave helper
LH_ROW = AH_ROW + len(att_mix) + 3
ws.cell(row=LH_ROW, column=HD, value="Leave type").font = font(7, True, MUTED)
ws.cell(row=LH_ROW, column=HD + 1, value="Days").font = font(7, True, MUTED)
for i, (code, lname, ent, tracked, _r) in enumerate(LEAVE_TYPES):
    r = LH_ROW + 1 + i
    ws.cell(row=r, column=HD, value=lname).font = font(7, False, MUTED)
    ws.cell(row=r, column=HD + 1, value=(
        f"=SUMIFS('{LEAVE_SHEET}'!$G${LV_FIRST}:$G${LV_LAST},"
        f"'{LEAVE_SHEET}'!$F${LV_FIRST}:$F${LV_LAST},${CL(HD)}{r},"
        f"'{LEAVE_SHEET}'!$H${LV_FIRST}:$H${LV_LAST},\"<>Rejected\")")).font = font(7, False, MUTED)

# --- charts ---
c1 = BarChart()
c1.type = "bar"
c1.title = "Headcount by department"
c1.style = 10
c1.height, c1.width = 8.4, 13.0
c1.legend = None
c1.gapWidth = 45
data = Reference(ws, min_col=HD + 1, min_row=7, max_row=7 + len(DEPTS))
cats = Reference(ws, min_col=HD, min_row=8, max_row=7 + len(DEPTS))
c1.add_data(data, titles_from_data=True)
c1.set_categories(cats)
c1.dLbls = DataLabelList(); c1.dLbls.showVal = True
c1.series[0].graphicalProperties.solidFill = TEAL
c1.x_axis.majorGridlines = None
ws.add_chart(c1, "B22")

c2 = BarChart()
c2.type = "col"
c2.title = "Monthly salary cost vs budget by department"
c2.style = 10
c2.height, c2.width = 8.4, 13.0
c2.y_axis.numFmt = "#,##0"
c2.y_axis.majorGridlines = None
c2.gapWidth = 55
data = Reference(ws, min_col=HD + 2, max_col=HD + 3, min_row=7, max_row=7 + len(DEPTS))
c2.add_data(data, titles_from_data=True)
c2.set_categories(cats)
c2.series[0].graphicalProperties.solidFill = ACCENT
c2.series[1].graphicalProperties.solidFill = "C9D4E6"
ws.add_chart(c2, "S22")

c3 = DoughnutChart()
c3.title = "Attendance mix, all employees"
c3.style = 10
c3.height, c3.width = 8.4, 13.0
data = Reference(ws, min_col=HD + 1, min_row=AH_ROW, max_row=AH_ROW + len(att_mix))
cats3 = Reference(ws, min_col=HD, min_row=AH_ROW + 1, max_row=AH_ROW + len(att_mix))
c3.add_data(data, titles_from_data=True)
c3.set_categories(cats3)
c3.dLbls = DataLabelList(); c3.dLbls.showPercent = True
for i, color in enumerate(["2E8B57", "3C7FB1", "F0B429", "C0504D", "9AA5B1", "7A1210"]):
    pt = DataPoint(idx=i)
    pt.graphicalProperties.solidFill = color
    c3.series[0].data_points.append(pt)
ws.add_chart(c3, "B40")

c4 = PieChart()
c4.title = "Leave days by type (approved + availed)"
c4.style = 10
c4.height, c4.width = 8.4, 13.0
data = Reference(ws, min_col=HD + 1, min_row=LH_ROW, max_row=LH_ROW + len(LEAVE_TYPES))
cats4 = Reference(ws, min_col=HD, min_row=LH_ROW + 1, max_row=LH_ROW + len(LEAVE_TYPES))
c4.add_data(data, titles_from_data=True)
c4.set_categories(cats4)
c4.dLbls = DataLabelList(); c4.dLbls.showPercent = True
for i, color in enumerate(["1F6F78", "C8963E", "9AA5B1", "6B3FA0", "B3261E"]):
    pt = DataPoint(idx=i)
    pt.graphicalProperties.solidFill = color
    c4.series[0].data_points.append(pt)
ws.add_chart(c4, "S40")

# --- league table (merged fields) ---
LT = 58
section(ws, LT - 1, "DEPARTMENT LEAGUE TABLE", last_col=DASH_COLS)
league = [
    ("Department", 2, 5), ("Headcount", 7, 2), ("Approved", 9, 2), ("Vacancies", 11, 2),
    ("Monthly Cost", 13, 5), ("Budget", 18, 5), ("Budget Used", 23, 4), ("Avg Tenure", 27, 4),
]
for label, start, span in league:
    ws.merge_cells(start_row=LT, start_column=start, end_row=LT, end_column=start + span - 1)
    cell = ws.cell(row=LT, column=start, value=label)
    cell.font = font(9, True, WHITE)
    cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
    for col in range(start, start + span):
        ws.cell(row=LT, column=col).fill = fill(NAVY)
        ws.cell(row=LT, column=col).border = Border(bottom=Side(style="medium", color=ACCENT))
ws.row_dimensions[LT].height = 26

for i in range(len(DEPTS)):
    r = LT + 1 + i
    dr = DEP_FIRST + i
    vals = [
        (2, 5, f"='{DEPT_SHEET}'!$B${dr}", None, "left"),
        (7, 2, f"='{DEPT_SHEET}'!$I${dr}", "0", "center"),
        (9, 2, f"='{DEPT_SHEET}'!$F${dr}", "0", "center"),
        (11, 2, f"='{DEPT_SHEET}'!$M${dr}", "0", "center"),
        (13, 5, f"='{DEPT_SHEET}'!$P${dr}", "#,##0", "right"),
        (18, 5, f"='{DEPT_SHEET}'!$E${dr}", "#,##0", "right"),
        (23, 4, f"='{DEPT_SHEET}'!$R${dr}", "0.0%", "center"),
        (27, 4, f"='{DEPT_SHEET}'!$S${dr}", "0.0", "center"),
    ]
    for start, span, formula, fmt, align in vals:
        ws.merge_cells(start_row=r, start_column=start, end_row=r, end_column=start + span - 1)
        cell = ws.cell(row=r, column=start, value=formula)
        cell.font = font(9, True, NAVY) if start == 2 else font(9)
        cell.alignment = Alignment(horizontal=align, vertical="center", indent=1 if align == "left" else 0)
        if fmt:
            cell.number_format = fmt
        for col in range(start, start + span):
            cc = ws.cell(row=r, column=col)
            cc.border = BOX
            if i % 2:
                cc.fill = fill(GREY_BG)
    ws.row_dimensions[r].height = 18

ws.conditional_formatting.add(f"K{LT + 1}:L{LT + len(DEPTS)}", CellIsRule(
    operator="greaterThan", formula=["0"], fill=fill(RED_BG), font=font(9, True, RED)))
ws.conditional_formatting.add(f"W{LT + 1}:Z{LT + len(DEPTS)}", ColorScaleRule(
    start_type="num", start_value=0, start_color="B7E4C7",
    mid_type="num", mid_value=0.9, mid_color="FFEFC2",
    end_type="num", end_value=1.2, end_color="F8C9C4"))

FL = LT + len(DEPTS) + 3
section(ws, FL, "HOW TO READ THIS DASHBOARD", last_col=DASH_COLS)
tips = [
    "Change the reporting month in one place - Lists!A5 (any date inside the month); attendance and these tiles follow.",
    "Attendance % = present days across all employees / (employees x working days in the month).",
    "Actual cost comes from the Salary Calculation gross column; compare it with the approved budget to spot overspend.",
    "Vacancies = approved headcount minus employees assigned to that department on the Employee Database.",
    "Loss of pay is the attendance deduction in rupees, i.e. unpaid days x per-day rate.",
    "Every number here is live. Nothing on this sheet needs typing - see the Usage Guide tab for the full method.",
]
for i, t in enumerate(tips):
    r = FL + 1 + i
    mark = ws.cell(row=r, column=2, value="•")
    mark.font = font(9, True, ACCENT)
    mark.alignment = Alignment(horizontal="center")
    ws.merge_cells(start_row=r, start_column=3, end_row=r, end_column=DASH_COLS - 2)
    cell = ws.cell(row=r, column=3, value=t)
    cell.font = font(9, False, MUTED)
    cell.alignment = Alignment(vertical="center", indent=1)
    ws.row_dimensions[r].height = 15
ws.sheet_view.zoomScale = 90

# ==========================================================================
# USAGE GUIDE
# ==========================================================================
ws = ws_guide
ws.sheet_properties.tabColor = ACCENT
ws.sheet_view.showGridLines = False
ws.column_dimensions["A"].width = 1.6
ws.column_dimensions["B"].width = 5
ws.column_dimensions["C"].width = 26
ws.column_dimensions["D"].width = 104
title_block(ws, "USAGE GUIDE  |  APEX ENTERPRISES OFFICE MANAGEMENT DEMO",
            "Read this first: what each sheet does, how to use it, and what the sample figures mean.",
            last_col=4, banner_rows=3)
ws.row_dimensions[3].height = 18
ws.merge_cells("A3:D3")
ws["A3"] = "DEMO WORKBOOK  -  Apex Enterprises, its people and every figure here are fictional. " \
           "Use it to learn, train, or rebuild with your own data."
ws["A3"].font = font(9, True, WHITE)
ws["A3"].alignment = Alignment(indent=1, vertical="center")

row = 5


def g_section(text):
    global row
    row += 1
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=4)
    cell = ws.cell(row=row, column=1, value=text)
    cell.font = font(10.5, True, WHITE)
    cell.fill = fill(NAVY)
    cell.alignment = Alignment(vertical="center", indent=1)
    ws.row_dimensions[row].height = 22
    row += 1


def g_item(head, body, color=TEXT):
    global row
    ws.cell(row=row, column=3, value=head).font = font(9.5, True, NAVY)
    ws.cell(row=row, column=3).alignment = Alignment(vertical="top", wrap_text=True, indent=1)
    cell = ws.cell(row=row, column=4, value=body)
    cell.font = font(9.5, False, color)
    cell.alignment = Alignment(vertical="top", wrap_text=True, indent=1)
    lines = max(1, (len(body) // 105) + body.count("\n") + 1)
    ws.row_dimensions[row].height = 14.5 * lines
    row += 1


g_section("1.  WHAT THIS WORKBOOK IS")
g_item("Purpose", "A complete, formula-driven office administration demo for a fictional company. Seven working "
                  "sheets plus this guide, a holiday calendar and a helper lists tab. Replace the sample data with "
                  "your own and every summary, balance, salary line and dashboard tile recalculates.")
g_item("Built for", "HR and admin teams who want a realistic starting point, and trainers who need a safe dataset "
                    "to demonstrate attendance, leave and payroll logic.")
g_item("Format", "Microsoft Excel .xlsx, no macros. Opens in Excel 2016+, LibreOffice Calc and Google Sheets. "
                 "Enable editing / macros-free content if your copy opens in protected view.")
g_item("The DEMO label", "Every sheet header, the footer of every printed page and the file name carry DEMO. Before "
                         "real use, replace the sample rows, re-brand the headers and delete this guide.")

g_section("2.  THE SHEETS")
for head, body in [
    ("Dashboard", "The one-screen management view: six people tiles, six payroll tiles, three at-a-glance insight "
                  "cards, four charts and a department league table. Nothing here is typed by hand."),
    ("Attendance Oct-2026", "A calendar per employee for the payroll month. Sundays, declared holidays and approved "
                            "leave fill themselves in; you type P, WFH, HD, H or WO over the default. The blue "
                            "columns count every code, plus paid days, attendance %, overtime-equivalent extras and "
                            "unpaid shortfall."),
    ("Leave Records", "Section A logs each request (employee, type, dates, days, status). Section B shows every "
                      "employee's live balance per leave type. Section C holds the entitlement policy you can edit."),
    ("Salary Calculation", "The payroll register. Basic pay is looked up from the Position Salary Template at the "
                           "bottom of the sheet, working/present/paid days come from the attendance sheet, and "
                           "PF/professional tax use the simplified demo rules listed in the Pay Policy block."),
    ("Employee Database", "The master list of 24 employees. Columns A-P are typed or chosen from drop-downs; "
                          "Q-T calculate years of service, service status, tenure band and probation."),
    ("Contact Directory", "Extensions, mobiles, personal e-mails, emergency contacts and addresses, with a quick "
                          "lookup panel and a department-filterable extension list."),
    ("Department Details", "Eight departments with heads, cost centres, budgets and approved headcount, plus live "
                           "roll-ups of employees, vacancies, tenure and actual monthly cost."),
    ("Holidays", "The declared holiday list, with a weekday number and a Mon-Sat flag that the working-day "
                 "calculator reads."),
    ("Lists", "Drop-down sources and the reporting-month switch (A5 = year, A6 = month). Do not clear it."),
]:
    g_item(head, body)

g_section("3.  EVERYDAY TASKS")
for head, body in [
    ("Add a new employee", "Employee Database > first empty row (row 34) > type ID, name, date of joining, work "
                           "e-mail and extension; pick Department, Designation, Grade, Location, Shift and Status "
                           "from the drop-downs. Copy Q-T down from the row above."),
    ("Record attendance", "Attendance sheet > overwrite P in the day grid with WFH, HD, H or WO. Leave is stamped "
                          "in automatically from the leave register, so you only type the exceptions."),
    ("Log a leave request", "Leave Records section A > pick the Employee ID, choose Leave Type, enter From Date and "
                            "Days, set Status. To Date, the payroll-month flag and all balances fill themselves."),
    ("Approve or reject", "Change Status to Approved, Rejected or Cancelled. Only Approved and Availed reduce a "
                          "balance; Pending leaves it untouched."),
    ("Change the reporting month", "Lists > A5 (a single date inside the month). The attendance grid, holidays, "
                                   "working-day counts, salary day columns and the dashboard all follow. "
                                   "Column B on that tab is only a reference list of month names."),
    ("Change a salary component", "Salary Calculation > Position Salary Template > edit Basic, Conveyance or Special "
                                  "Allowance. Everyone in that position updates instantly."),
    ("Add a department", "Department Details > first empty row > complete columns A-H. Then assign people to it "
                         "from the Department drop-down."),
    ("Add a new position", "Salary Calculation > first empty row of the template (below the last position) > enter "
                           "grade, title and components. It appears in the Designation drop-down automatically."),
    ("Find a phone number", "Contact Directory > filter row 9 by Department, or use Quick Lookup at the bottom."),
    ("Mark someone as leaving", "Employee Database > Status = Notice Period (or Exited). Do not delete the row - "
                                "attendance, leave and salary history refer to it."),
    ("Month-end routine", "Save a copy named with the month. In the copy, overwrite Lists!A5 with a date in the new "
                          "month: the grid, the working-day counts and the dashboard all rebuild. Delete any typed "
                          "attendance codes from the previous month first (select the day columns and press Delete) "
                          "so the demo data does not carry over."),
]:
    g_item(head, body)

g_section("4.  HOW THE CALCULATIONS WORK")
for head, body in [
    ("Working days", "This demo treats Sunday as the weekly off and Saturday as a working day. Working days = "
                     "calendar days - Sundays - declared holidays that fall on a Monday to Saturday. October 2026 "
                     "therefore has 31 - 4 - 2 = 25. See the Working-day Calculator under the attendance grid "
                     "(column C) - one row per step. Change the model there if your office works a 5-day week."),
    ("Payable days", "Every day in the month: P + WFH + HD + L + LWP + WO + HOL + H. It is an audit count that must "
                     "always equal the number of days in the month."),
    ("Present days", "P + WFH + (Half Days x 0.5). Attendance % = present days / working days."),
    ("Paid days", "Present days + paid leave, capped at the working-day count. Leave without pay is excluded, which "
                  "is what turns it into a deduction."),
    ("Extras", "Present days above the working-day count - treated as overtime-equivalent in salary."),
    ("Unpaid shortfall", "Working days - paid days. This is what the salary sheet recovers, so paid leave never "
                         "costs the employee anything and leave without pay does."),
    ("Leave balance", "Entitlement for that leave type (Earned 18, Casual 12, Sick 10 - editable in section C) minus "
                      "every approved or availed day already recorded. Comp Off and LWP have no entitlement and are "
                      "tracked as days used. Balances reset with the calendar year."),
    ("Leave and the grid", "Approved or availed leave is stamped into the attendance grid automatically (L for paid "
                           "leave, LWP for leave without pay). You only type the exceptions: absences, WFH, half "
                           "days and extra week-ons or week-offs."),
    ("Gross salary", "Basic + HRA (40% of basic) + Conveyance + Special Allowance, looked up from the position "
                     "template by Designation."),
    ("Attendance deduction", "Unpaid shortfall x per-day rate, where per-day rate = gross / working days. Because "
                             "LWP days are already excluded from paid days, leave without pay is recovered once only."),
    ("Net salary", "Gross - attendance deduction - PF employee - professional tax - other deductions, floored at zero."),
    ("Total cost to company", "Gross + employer PF."),
    ("Department cost", "Sum of gross salaries of that department's employees, compared with the monthly budget."),
]:
    g_item(head, body)

g_section("5.  DATA VALIDATION AND DROP-DOWNS")
for head, body in [
    ("Department", "Employee Database C - list from Department Details. Add a department there to extend the list."),
    ("Designation", "Employee Database D - list from the Salary Calculation position template. Drives basic pay."),
    ("Grade, Location, Gender, Blood group, Status, Employment type", "Employee Database - fixed lists on the Lists "
                                                                     "tab or short inline lists."),
    ("Leave type and Status", "Leave Records F and H - status choices are Pending, Approved, Rejected, Availed, "
                              "Cancelled."),
    ("Attendance code", "Attendance day grid - P, WFH, HD, L, LWP, WO, HOL, H."),
    ("Employee ID / Name", "Leave Records and the quick-lookup panels - validated against the Employee Database."),
    ("Date and number checks", "Joining dates, leave dates, leave days (0.5-60), entitlements and extensions are all "
                               "range-checked with a clear error message if you type something impossible."),
]:
    g_item(head, body)

g_section("6.  COLOUR KEY")
g_item("Navy", "Headers, section rules and totals rows.")
g_item("Gold", "Month switch and the selection cells you are meant to edit.")
g_item("Blue cells", "Automatic - formulas you should not type over.")
g_item("Green / red / amber", "Positive or present (green), shortfall, deduction or vacancy (red), pending or "
                              "attention needed (amber).")
g_item("Pale bands", "Alternating row bands for readability; they carry no meaning.")

g_section("7.  LIMITATIONS AND SAFE USE")
g_item("Illustrative, not statutory", "HRA at 40%, a 12% PF cap at Rs.15,000, simplified professional tax slabs and "
                                      "1.5x overtime are demonstration rules. Real Indian payroll also involves ESI, "
                                      "gratuity, TDS, statutory bonus and state-specific professional tax - none of "
                                      "that is modelled here.", RED)
g_item("Fictional data", "Apex Enterprises, its employees, the apex-demo.example domain, phone numbers, addresses and "
                         "budgets are invented. Do not use them for real correspondence or payments.", RED)
g_item("One payroll month", "The attendance grid covers one month. Duplicate the sheet or keep a month-end copy for "
                            "historical attendance.", RED)
g_item("Row-linked sheets", "Attendance, Leave, Salary and Contact rows point at specific Employee Database rows. "
                            "Insert new hires at the bottom and filter rather than re-sorting.", RED)
g_item("Before real use", "Replace sample rows, review the pay template against your own structure, and have HR and "
                          "finance sign off on the statutory assumptions.", RED)

g_section("8.  QUICK REFERENCE")
for head, body in [
    ("File", "Apex_Enterprises_Office_Management_DEMO.xlsx"),
    ("Tabs", "Dashboard | Attendance Oct-2026 | Leave Records | Salary Calculation | Employee Database | "
             "Contact Directory | Department Details | Holidays | Usage Guide | Lists"),
    ("Sample company", f"Apex Enterprises, Pune HQ - {len(DEPTS)} departments, {len(EMPLOYEES)} fictional employees"),
    ("Reporting month", PAY_MONTH_LABEL),
    ("Attendance codes", "P Present | WFH Work From Home | HD Half Day | L Paid leave | LWP Leave without pay | "
                         "WO Weekly Off | HOL Holiday | H Absent or unmarked"),
    ("Leave types", "Earned | Casual | Sick | Comp Off | Leave Without Pay"),
    ("Recalculation", "Press F9 if a figure looks stale. The workbook is set to recalculate fully when opened."),
]:
    g_item(head, body)

row += 1
ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=4)
cell = ws.cell(row=row, column=1,
               value="DEMO  |  Apex Enterprises Office Management workbook  |  Fictional data - not for payroll, "
                     "statutory filing or real employee records.")
cell.font = font(9, True, RED)
cell.alignment = Alignment(horizontal="center", vertical="center")
cell.fill = fill(RED_BG)
ws.row_dimensions[row].height = 26

# ==========================================================================
# Workbook finishing
# ==========================================================================
for name, ref in [
    ("AttendanceGrid", f"'{ATT_SHEET}'!$D${FIRST}:${CL(ATT_DAY_LAST)}${LAST}"),
    ("EmployeeData", f"'{EMP_SHEET}'!$A${FIRST}:$T${LAST}"),
    ("LeaveRegister", f"'{LEAVE_SHEET}'!$A${LV_FIRST}:$N${LV_LAST}"),
    ("PayrollMonth", "Lists!$A$5:$A$6"),
    ("HolidayList", "Holidays!$A$5:$A$40"),
    ("WorkingDays", f"'{ATT_SHEET}'!$C${ENG_NET}"),
]:
    wb.defined_names.add(DefinedName(name, attr_text=ref))

tab_order = [DASH_SHEET, ATT_SHEET, LEAVE_SHEET, SAL_SHEET, EMP_SHEET, CONTACT_SHEET,
             DEPT_SHEET, HOL_SHEET, GUIDE_SHEET, LISTS_SHEET]
wb._sheets = [wb[n] for n in tab_order]
wb.active = 0

for name in tab_order:
    s = wb[name]
    s.page_setup.orientation = "landscape"
    s.page_setup.fitToWidth = 1
    s.page_setup.fitToHeight = 0
    s.sheet_properties.pageSetUpPr = PageSetupProperties(fitToPage=True)
    s.page_margins.left = s.page_margins.right = 0.3
    s.page_margins.top = s.page_margins.bottom = 0.4
    if name in (ATT_SHEET, LEAVE_SHEET, SAL_SHEET, EMP_SHEET, CONTACT_SHEET, DEPT_SHEET,
                DASH_SHEET):
        s.print_title_rows = "9:9" if name not in (DASH_SHEET,) else None
    s.oddFooter.center.text = "DEMO  |  Apex Enterprises - Office Management  |  Page &P of &N"
    s.oddFooter.center.size = 8
    s.oddFooter.center.color = "808080"
    s.oddHeader.right.text = "DEMO - fictional data"
    s.oddHeader.right.size = 8
    s.oddHeader.right.color = RED

wb.calculation = CalcProperties(calcMode="auto", fullCalcOnLoad=True)
wb.properties.title = "Apex Enterprises - Office Management DEMO"
wb.properties.subject = "Office administration demo: attendance, leave, salary, contacts, dashboard"
wb.properties.creator = "Arena.ai agent"
wb.properties.description = ("DEMO workbook for a fictional company. Employee database, monthly attendance, leave "
                             "tracker, illustrative salary calculation, department details, contact directory and "
                             "management dashboard. All data is fictional.")
wb.properties.keywords = "DEMO, office management, HR, attendance, payroll, dashboard, sample data"
wb.properties.category = "Office Management DEMO"

OUT_DIR.mkdir(parents=True, exist_ok=True)
wb.save(OUT_FILE)

# ----------------------------------------------------------------------
# openpyxl writes chart categories as <numRef>. When the category labels are
# text (department names, leave types) Excel would show 1, 2, 3 instead of the
# names, so rewrite those references as <strRef>.
# ----------------------------------------------------------------------
import re
import shutil
import zipfile


def _fix_chart_categories(path):
    tmp = path.with_suffix(".tmp.xlsx")
    with zipfile.ZipFile(path) as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if re.fullmatch(r"xl/charts/chart\d+\.xml", item.filename):
                text = data.decode()
                text = re.sub(r"<cat><numRef>(.*?)</numRef></cat>",
                              r"<cat><strRef>\1</strRef></cat>", text)
                data = text.encode()
            zout.writestr(item, data)
    shutil.move(tmp, path)


_fix_chart_categories(OUT_FILE)
print(f"Saved {OUT_FILE}")
print(f"Working-day calculator rows {ER}-{ENG_HRS}; working days C{ENG_WD}; net C{ENG_NET}; "
      f"holidays C{ENG_HOLALL}")
print(f"Attendance counts: P={CL(AC_P)} present={CL(AC_PRESENT)} pct={CL(AC_PCT)} "
      f"extra={CL(AC_EXTRA)} short={CL(AC_SHORT)}")

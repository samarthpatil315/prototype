import '../../data/models/models.dart';

/// Original ORBITAL-branded template catalogue (Part 14).
class TemplateCatalog {
  const TemplateCatalog._();

  static const List<String> categories = [
    'All',
    'Business',
    'Finance',
    'Education',
    'Marketing',
    'Office administration',
    'Presentations',
    'Reports',
    'Personal productivity',
  ];

  static const List<TemplateItem> all = [
    TemplateItem(id: 'tpl-proposal', title: 'Business Proposal', category: 'Business', kind: TemplateKind.document, description: 'Client-ready proposal with scope, timeline and pricing sections.'),
    TemplateItem(id: 'tpl-report', title: 'Business Report', category: 'Reports', kind: TemplateKind.document, description: 'Structured monthly business report with highlights and actions.'),
    TemplateItem(id: 'tpl-company-profile', title: 'Company Profile', category: 'Business', kind: TemplateKind.document, description: 'Introduce your company, services and portfolio elegantly.'),
    TemplateItem(id: 'tpl-letter', title: 'Official Letter', category: 'Office administration', kind: TemplateKind.document, description: 'Formal letterhead layout for official communication.'),
    TemplateItem(id: 'tpl-minutes', title: 'Meeting Minutes', category: 'Office administration', kind: TemplateKind.document, description: 'Agenda, decisions and action items in a clean format.'),
    TemplateItem(id: 'tpl-resume', title: 'Resume', category: 'Personal productivity', kind: TemplateKind.document, description: 'Minimal professional resume layout.'),
    TemplateItem(id: 'tpl-sales-tracker', title: 'Sales Tracker', category: 'Finance', kind: TemplateKind.spreadsheet, description: 'Daily sales with automatic totals and averages (live formulas).'),
    TemplateItem(id: 'tpl-expense-tracker', title: 'Expense Tracker', category: 'Finance', kind: TemplateKind.spreadsheet, description: 'Track spending by category with SUM formulas.'),
    TemplateItem(id: 'tpl-inventory-sheet', title: 'Inventory Sheet', category: 'Business', kind: TemplateKind.spreadsheet, description: 'Stock levels, reorder checks with IF formulas.'),
    TemplateItem(id: 'tpl-attendance', title: 'Attendance Register', category: 'Education', kind: TemplateKind.spreadsheet, description: 'Count present days automatically with COUNT logic.'),
    TemplateItem(id: 'tpl-salary', title: 'Salary Calculator', category: 'Finance', kind: TemplateKind.spreadsheet, description: 'Earnings, deductions and net pay calculations.'),
    TemplateItem(id: 'tpl-budget', title: 'Monthly Budget', category: 'Personal productivity', kind: TemplateKind.spreadsheet, description: 'Plan income and expenses month by month.'),
    TemplateItem(id: 'tpl-pitch', title: 'Pitch Deck', category: 'Presentations', kind: TemplateKind.presentation, description: 'Investor-ready pitch structure with ORBITAL styling.'),
    TemplateItem(id: 'tpl-product-deck', title: 'Product Presentation', category: 'Marketing', kind: TemplateKind.presentation, description: 'Showcase features, benefits and pricing.'),
    TemplateItem(id: 'tpl-education', title: 'Educational Slides', category: 'Education', kind: TemplateKind.presentation, description: 'Clear teaching slides with section breaks.'),
    TemplateItem(id: 'tpl-project-deck', title: 'Project Presentation', category: 'Presentations', kind: TemplateKind.presentation, description: 'Status, milestones and next steps for project reviews.'),
  ];

  static OrbitalDocument buildDocument(String templateId, String id, DateTime now) {
    DocBlock h(String t) => DocBlock(type: DocBlockType.heading, text: t);
    DocBlock p(String t) => DocBlock(type: DocBlockType.paragraph, text: t);
    DocBlock b(String t) => DocBlock(type: DocBlockType.bulletList, text: t);
    switch (templateId) {
      case 'tpl-letter':
        return OrbitalDocument(id: id, title: 'Official Letter', createdAt: now, updatedAt: now, blocks: [
          h('Official Letter'), p('Date: '), p('To,\n[Name]\n[Address]'),
          p('Subject: '), p('Respected Sir/Madam,'), p('[Write your message here.]'),
          p('Yours faithfully,\n[Your Name]\nORBITAL.STUDIO.3'),
        ]);
      case 'tpl-minutes':
        return OrbitalDocument(id: id, title: 'Meeting Minutes', createdAt: now, updatedAt: now, blocks: [
          h('Meeting Minutes'), p('Date:   Attendees:'),
          h('Agenda'), b(''), h('Decisions Taken'), b(''), h('Action Items'), b('Task — Owner — Due date'),
        ]);
      case 'tpl-resume':
        return OrbitalDocument(id: id, title: 'Resume', createdAt: now, updatedAt: now, blocks: [
          h('Your Name'), p('Professional title • phone • email • city'),
          h('Summary'), p('Two-line professional summary.'),
          h('Experience'), b('Role — Company — achievements'),
          h('Skills'), b('Skill 1, Skill 2, Skill 3'),
          h('Education'), b('Qualification — Institution — Year'),
        ]);
      case 'tpl-report':
        return OrbitalDocument(id: id, title: 'Business Report', createdAt: now, updatedAt: now, blocks: [
          h('Business Report'), h('Executive Summary'), p(''),
          h('Key Highlights'), b(''), h('Challenges'), b(''), h('Recommendations'), b(''),
        ]);
      case 'tpl-company-profile':
        return OrbitalDocument(id: id, title: 'Company Profile', createdAt: now, updatedAt: now, blocks: [
          h('Company Profile'), p('Ideas Into Impact.'),
          h('About Us'), p('A creative studio for a digital world.'),
          h('Our Services'), b('Graphic Design & Branding'), b('Product Advertising'),
          b('AI Video Creation'), b('Website Design'), b('Digital Office Solutions'),
          h('Contact'), p('@orbital.studio.3'),
        ]);
      default:
        return OrbitalDocument(id: id, title: 'Business Proposal', createdAt: now, updatedAt: now, blocks: [
          h('Business Proposal'), p('Prepared for: [Client Name]'),
          h('Introduction'), p('Thank you for considering ORBITAL.STUDIO.3.'),
          h('Scope of Work'), b('Deliverable 1'), b('Deliverable 2'),
          h('Timeline'), b('Milestone 1 — Week 1'), b('Milestone 2 — Week 2'),
          h('Investment'), p('Total: ₹'),
          h('Next Steps'), p('Approve this proposal to begin.'),
        ]);
    }
  }

  static SpreadsheetDoc buildSpreadsheet(String templateId, String id, DateTime now) {
    Map<String, String> header(List<String> cols) =>
        {for (var i = 0; i < cols.length; i++) '${String.fromCharCode(65 + i)}1': cols[i]};
    switch (templateId) {
      case 'tpl-expense-tracker':
        return SpreadsheetDoc(id: id, title: 'Expense Tracker', createdAt: now, updatedAt: now, cells: {
          ...header(['Date', 'Category', 'Description', 'Amount (₹)']),
          'A2': '01 Nov', 'B2': 'Travel', 'C2': 'Client visit', 'D2': '1200',
          'A3': '03 Nov', 'B3': 'Software', 'C3': 'Design tools', 'D3': '2499',
          'A4': '05 Nov', 'B4': 'Office', 'C4': 'Supplies', 'D4': '850',
          'C6': 'TOTAL', 'D6': '=SUM(D2:D4)',
        });
      case 'tpl-inventory-sheet':
        return SpreadsheetDoc(id: id, title: 'Inventory Sheet', createdAt: now, updatedAt: now, cells: {
          ...header(['Product', 'Stock', 'Reorder At', 'Status']),
          'A2': 'Notebook A5', 'B2': '42', 'C2': '10',
          'A3': 'Printer Ink', 'B3': '4', 'C3': '8',
          'D2': '=IF(B2<=C2,"REORDER","OK")', 'D3': '=IF(B3<=C3,"REORDER","OK")',
        });
      case 'tpl-attendance':
        return SpreadsheetDoc(id: id, title: 'Attendance Register', createdAt: now, updatedAt: now, cells: {
          ...header(['Name', 'Mon', 'Tue', 'Wed', 'Thu', 'Days Present']),
          'A2': 'Asha Verma', 'B2': '1', 'C2': '1', 'D2': '0', 'E2': '1', 'F2': '=SUM(B2:E2)',
          'A3': 'Rohit Kumar', 'B3': '1', 'C3': '1', 'D3': '1', 'E3': '1', 'F3': '=SUM(B3:E3)',
        });
      case 'tpl-salary':
        return SpreadsheetDoc(id: id, title: 'Salary Calculator', createdAt: now, updatedAt: now, cells: {
          ...header(['Employee', 'Basic (₹)', 'Allowances (₹)', 'Deductions (₹)', 'Net Pay (₹)']),
          'A2': 'A. Patil', 'B2': '25000', 'C2': '6000', 'D2': '1800', 'E2': '=B2+C2-D2',
          'A3': 'S. Khan', 'B3': '22000', 'C3': '4500', 'D3': '1500', 'E3': '=B3+C3-D3',
          'A5': 'TOTALS', 'E5': '=SUM(E2:E3)',
        });
      case 'tpl-budget':
        return SpreadsheetDoc(id: id, title: 'Monthly Budget', createdAt: now, updatedAt: now, cells: {
          ...header(['Category', 'Planned (₹)', 'Actual (₹)', 'Difference (₹)']),
          'A2': 'Rent', 'B2': '12000', 'C2': '12000',
          'A3': 'Groceries', 'B3': '8000', 'C3': '7350',
          'A4': 'Savings', 'B4': '10000', 'C4': '10000',
          'D2': '=B2-C2', 'D3': '=B3-C3', 'D4': '=B4-C4',
          'A6': 'TOTAL PLANNED', 'B6': '=SUM(B2:B4)', 'A7': 'TOTAL ACTUAL', 'C7': '=SUM(C2:C4)',
        });
      default:
        return SpreadsheetDoc(id: id, title: 'Sales Tracker', createdAt: now, updatedAt: now, cells: {
          ...header(['Date', 'Product', 'Units', 'Unit Price (₹)', 'Revenue (₹)']),
          'A2': '01 Nov', 'B2': 'Branding Package', 'C2': '2', 'D2': '15000', 'E2': '=C2*D2',
          'A3': '02 Nov', 'B3': 'Social Media Kit', 'C3': '5', 'D3': '4999', 'E3': '=C3*D3',
          'A4': '03 Nov', 'B4': 'Website Design', 'C4': '1', 'D4': '35000', 'E4': '=C4*D4',
          'D6': 'TOTAL REVENUE', 'E6': '=SUM(E2:E4)',
          'D7': 'AVERAGE ORDER', 'E7': '=AVERAGE(E2:E4)',
        });
    }
  }

  static PresentationDoc buildPresentation(String templateId, String id, DateTime now, String Function(String) newSlideId) {
    Slide s(String title, String body, [List<String> bullets = const [], int bg = 0xFFF5F0E5]) =>
        Slide(id: newSlideId(title), title: title, body: body, bullets: bullets, background: bg);
    switch (templateId) {
      case 'tpl-product-deck':
        return PresentationDoc(id: id, title: 'Product Presentation', createdAt: now, updatedAt: now, slides: [
          s('Our Product', 'Build Something Great.', [], 0xFF073D2D),
          s('Key Features', '', ['Fast and reliable', 'Beautiful design', 'Made for your workflow']),
          s('Pricing', 'Simple plans that grow with your business.'),
          s('Get Started', 'Contact @orbital.studio.3'),
        ]);
      case 'tpl-education':
        return PresentationDoc(id: id, title: 'Educational Slides', createdAt: now, updatedAt: now, slides: [
          s('Lesson Title', 'What we will learn today', [], 0xFFF5F0E5),
          s('Key Concepts', '', ['Concept one', 'Concept two', 'Concept three']),
          s('Summary', 'Recap the main points.'),
          s('Questions', 'Discussion and practice.'),
        ]);
      case 'tpl-project-deck':
        return PresentationDoc(id: id, title: 'Project Presentation', createdAt: now, updatedAt: now, slides: [
          s('Project Overview', 'Goals and scope', [], 0xFF073D2D),
          s('Progress', '', ['Completed milestones', 'Work in progress']),
          s('Next Steps', '', ['Upcoming deliverables', 'Deadlines']),
        ]);
      default:
        return PresentationDoc(id: id, title: 'Pitch Deck', createdAt: now, updatedAt: now, slides: [
          s('IDEAS INTO IMPACT.', 'ORBITAL.STUDIO.3 — A creative studio for a digital world.', [], 0xFF073D2D),
          s('The Problem', 'Describe the problem your audience faces.'),
          s('Our Solution', '', ['Creative design', 'Smart digital solutions', 'Measurable impact']),
          s('Market & Opportunity', 'Who it is for and why now.'),
          s('Let\'s Create Something Exceptional', 'Your Vision. Our Creativity.\n@orbital.studio.3', [], 0xFFD5A044),
        ]);
    }
  }
}

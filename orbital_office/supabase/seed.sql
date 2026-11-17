-- ORBITAL OFFICE seed data: public template catalogue rows.
-- App-side demo workspace content is generated locally by the Flutter app
-- (clearly labelled sample data) so it works fully offline; this seed only
-- provides the shared template registry for Supabase-backed deployments.

insert into public.templates (id, title, category, kind, description) values
  ('tpl-proposal', 'Business Proposal', 'Business', 'document', 'Client-ready proposal with scope, timeline and pricing sections.'),
  ('tpl-report', 'Business Report', 'Reports', 'document', 'Structured monthly business report with highlights and actions.'),
  ('tpl-company-profile', 'Company Profile', 'Business', 'document', 'Introduce your company, services and portfolio elegantly.'),
  ('tpl-letter', 'Official Letter', 'Office administration', 'document', 'Formal letterhead layout for official communication.'),
  ('tpl-minutes', 'Meeting Minutes', 'Office administration', 'document', 'Agenda, decisions and action items in a clean format.'),
  ('tpl-resume', 'Resume', 'Personal productivity', 'document', 'Minimal professional resume layout.'),
  ('tpl-sales-tracker', 'Sales Tracker', 'Finance', 'spreadsheet', 'Daily sales with automatic totals and averages (live formulas).'),
  ('tpl-expense-tracker', 'Expense Tracker', 'Finance', 'spreadsheet', 'Track spending by category with SUM formulas.'),
  ('tpl-inventory-sheet', 'Inventory Sheet', 'Business', 'spreadsheet', 'Stock levels and reorder checks with IF formulas.'),
  ('tpl-attendance', 'Attendance Register', 'Education', 'spreadsheet', 'Count present days automatically.'),
  ('tpl-salary', 'Salary Calculator', 'Finance', 'spreadsheet', 'Earnings, deductions and net pay calculations.'),
  ('tpl-budget', 'Monthly Budget', 'Personal productivity', 'spreadsheet', 'Plan income and expenses month by month.'),
  ('tpl-pitch', 'Pitch Deck', 'Presentations', 'presentation', 'Investor-ready pitch structure with ORBITAL styling.'),
  ('tpl-product-deck', 'Product Presentation', 'Marketing', 'presentation', 'Showcase features, benefits and pricing.'),
  ('tpl-education', 'Educational Slides', 'Education', 'presentation', 'Clear teaching slides with section breaks.'),
  ('tpl-project-deck', 'Project Presentation', 'Presentations', 'presentation', 'Status, milestones and next steps for project reviews.')
on conflict (id) do nothing;

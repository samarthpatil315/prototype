# ORBITAL OFFICE — Architecture

## Overview

```
┌────────────────────────────────────────────────────────────┐
│  Screens (features/*)  — ConsumerWidgets, GoRouter         │
├────────────────────────────────────────────────────────────┤
│  AppController (Riverpod StateNotifier) — single source    │
│  of truth: AppState with every collection + user session   │
├──────────────┬───────────────┬─────────────────────────────┤
│ LocalDatabase│ SyncService   │ Pure engines                │
│ (sqflite,    │ conflict rule │ FormulaEngine,              │
│  offline 1st)│ + Supabase    │ InvoiceCalculator           │
├──────────────┴───────────────┴─────────────────────────────┤
│  PDF (pdf/printing) • AI (Edge Function or demo) • CSV/XLSX│
└────────────────────────────────────────────────────────────┘
```

## Design decisions

1. **No code generation.** `drift`, `freezed`, `riverpod_generator` and
   `json_serializable` were intentionally avoided. Models are hand-written
   with `toJson/fromJson`; persistence uses **sqflite** directly. This makes
   a first `flutter pub get` deterministic and keeps the build working
   without `build_runner`. The normalised relational schema still exists —
   in Postgres (see below) and as the local `records` store's contract.

2. **Offline-first, single controller.** Every mutation in `AppController`
   updates in-memory state *and* writes the record to the on-device SQLite
   `records` table with `sync_status='pending'`. The UI never waits on the
   network. `SyncService` pushes pending records to Supabase when a backend
   is configured and signed in.

3. **Conflict rule (never silently lose data).** Before any upsert,
   `resolveConflict()` compares the local `updated_at` with the server's:
   - remote newer → local copy is *not* pushed (outcome `keptRemoteNewer`)
   - local newer / no remote → push
   This function is pure and unit-tested (`test/unit/core_logic_test.dart`).

4. **Demo mode is honest.** Without `--dart-define` credentials the app
   seeds fictional sample data, shows a gold **DEMO WORKSPACE** banner,
   and the AI assistant labels every output as an unverified offline draft.

5. **Secrets.** Only the Supabase **public anon key** may be compiled in.
   The service-role key and AI provider key exist exclusively as Edge
   Function secrets (`supabase/functions/ai_assistant`). RLS does the rest.

## Backend (Supabase)

`supabase/migrations/20260101000000_orbital_office_init.sql` creates all 25
tables from the specification (`profiles`, `workspaces`,
`workspace_members`, `documents`, `document_versions`, `spreadsheets`,
`spreadsheet_versions`, `presentations`, `presentation_slides`, `invoices`,
`invoice_items`, `quotations`, `quotation_items`, `customers`,
`customer_notes`, `products`, `inventory_movements`, `projects`, `tasks`,
`notifications`, `templates`, `folders`, `files`, `ai_conversations`,
`ai_messages`, `user_preferences`) with:

- UUID primary keys, `created_at`/`updated_at` (+ trigger-maintained)
- Foreign keys with cascade/set-null semantics, indexes on owner + status
- `owner_id = auth.uid()` **Row Level Security on every tenant table**
- A private `user-files` Storage bucket restricted to the user's folder
- Entity tables also carry a `payload jsonb` column that mirrors the
  app's local record format, so the sync upsert is a faithful copy while
  normalised columns remain available for server-side queries/reports

Workflow:

```bash
supabase link --project-ref YOUR_REF
supabase db push            # applies migrations
supabase db seed            # or psql < supabase/seed.sql
supabase functions deploy ai_assistant
supabase secrets set AI_PROVIDER_API_KEY=... AI_PROVIDER_MODEL=...
```

**Backup/recovery:** enable Supabase Point-in-Time Recovery (or scheduled
`pg_dump`) on the project; the on-device SQLite store additionally keeps
the latest local copy of every record, and Settings → *Export my data*
produces a full JSON export.

## Testing strategy

| Layer | Where | Covers |
|---|---|---|
| Unit | `test/unit/formula_engine_test.dart` | arithmetic, precedence, ranges, IF, errors, **circular references**, known-answer calculations |
| Unit | `test/unit/invoice_calculator_test.dart` | discounts, tax composition, payments, clamping, pipeline enum codes |
| Unit | `test/unit/core_logic_test.dart` | validators, sync conflict rule, demo AI labelling, CSV, model JSON round-trips, low stock |
| Widget | `test/widget/auth_screens_test.dart` | login/register rendering + validation |
| Integration | `test/integration/app_flow_test.dart` | real app boot to onboarding/login |

Responsive checks: layouts use `GridView`/`Wrap`/`ListView` with flexible
constraints and are intended to be verified at 320dp–430dp widths with
`flutter test` device matrices and on physical devices before release.

-- ORBITAL OFFICE — initial schema
-- Run with the Supabase CLI:  supabase db push
-- Security model: every tenant table carries owner_id = auth.users.id and
-- Row Level Security restricts all access to the owning user (plus explicit
-- workspace membership where noted). The service-role key is NEVER used in
-- the mobile app; it belongs only to Edge Functions / server jobs.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------- helpers
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------- profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null default '',
  full_name text not null default '',
  business_name text not null default '',
  phone text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, coalesce(new.email, ''), coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- --------------------------------------------------------------- workspaces
create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null default 'My Workspace',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workspace_members (
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member', 'viewer')),
  created_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

-- --------------------------------------------------------------- documents
create table if not exists public.folders (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  workspace_id uuid references public.workspaces (id) on delete set null,
  name text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  workspace_id uuid references public.workspaces (id) on delete set null,
  folder_id uuid references public.folders (id) on delete set null,
  title text not null default 'Untitled Document',
  blocks jsonb not null default '[]'::jsonb,
  payload jsonb not null default '{}'::jsonb,
  favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.document_versions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  document_id uuid not null references public.documents (id) on delete cascade,
  blocks jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------ spreadsheets
create table if not exists public.spreadsheets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  workspace_id uuid references public.workspaces (id) on delete set null,
  title text not null default 'Untitled Spreadsheet',
  cells jsonb not null default '{}'::jsonb,
  payload jsonb not null default '{}'::jsonb,
  favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.spreadsheet_versions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  spreadsheet_id uuid not null references public.spreadsheets (id) on delete cascade,
  cells jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------ presentations
create table if not exists public.presentations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  workspace_id uuid references public.workspaces (id) on delete set null,
  title text not null default 'Untitled Presentation',
  payload jsonb not null default '{}'::jsonb,
  favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.presentation_slides (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  presentation_id uuid not null references public.presentations (id) on delete cascade,
  position int not null default 0,
  title text not null default '',
  body text not null default '',
  background bigint not null default 0,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ----------------------------------------------------------------- billing
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  workspace_id uuid references public.workspaces (id) on delete set null,
  name text not null,
  business_name text not null default '',
  email text not null default '',
  phone text not null default '',
  address text not null default '',
  requirements text not null default '',
  notes text not null default '',
  lead_source text not null default '',
  lead_stage text not null default 'NEW'
    check (lead_stage in ('NEW','CONTACTED','INTERESTED','QUOTATION_SENT','CONVERTED','CLOSED')),
  follow_up_date date,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_notes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  customer_id uuid not null references public.customers (id) on delete cascade,
  note text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  workspace_id uuid references public.workspaces (id) on delete set null,
  customer_id uuid references public.customers (id) on delete set null,
  number text not null,
  business_name text not null default '',
  business_address text not null default '',
  customer_name text not null default '',
  customer_address text not null default '',
  issue_date date not null default current_date,
  due_date date,
  discount_percent numeric not null default 0,
  tax_percent numeric not null default 0,
  tax_label text not null default '',
  amount_paid numeric not null default 0,
  currency_symbol text not null default '₹',
  notes text not null default '',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, number)
);

create table if not exists public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  invoice_id uuid not null references public.invoices (id) on delete cascade,
  description text not null default '',
  quantity numeric not null default 1,
  unit_price numeric not null default 0,
  discount_percent numeric not null default 0,
  position int not null default 0
);

create table if not exists public.quotations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  workspace_id uuid references public.workspaces (id) on delete set null,
  customer_id uuid references public.customers (id) on delete set null,
  number text not null,
  business_name text not null default '',
  business_address text not null default '',
  customer_name text not null default '',
  customer_address text not null default '',
  issue_date date not null default current_date,
  due_date date,
  discount_percent numeric not null default 0,
  tax_percent numeric not null default 0,
  tax_label text not null default '',
  currency_symbol text not null default '₹',
  notes text not null default '',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, number)
);

create table if not exists public.quotation_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  quotation_id uuid not null references public.quotations (id) on delete cascade,
  description text not null default '',
  quantity numeric not null default 1,
  unit_price numeric not null default 0,
  discount_percent numeric not null default 0,
  position int not null default 0
);

-- ---------------------------------------------------------------- inventory
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  workspace_id uuid references public.workspaces (id) on delete set null,
  sku text not null default '',
  name text not null,
  category text not null default 'General',
  purchase_price numeric not null default 0,
  selling_price numeric not null default 0,
  stock int not null default 0,
  low_stock_threshold int not null default 5,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  change int not null,
  reason text not null default '',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------- projects/tasks
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  workspace_id uuid references public.workspaces (id) on delete set null,
  customer_id uuid references public.customers (id) on delete set null,
  title text not null,
  description text not null default '',
  deadline date,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  project_id uuid references public.projects (id) on delete cascade,
  title text not null,
  description text not null default '',
  priority text not null default 'MEDIUM' check (priority in ('LOW','MEDIUM','HIGH')),
  status text not null default 'TO_DO' check (status in ('TO_DO','IN_PROGRESS','COMPLETED')),
  due_date date,
  assignee text not null default '',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------------- misc
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  title text not null default '',
  body text not null default '',
  route text,
  read boolean not null default false,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.templates (
  id text primary key,
  title text not null,
  category text not null default 'Business',
  kind text not null default 'document',
  description text not null default '',
  definition jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.files (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  folder_id uuid references public.folders (id) on delete set null,
  name text not null,
  kind text not null default 'other',
  storage_path text,
  size_bytes bigint not null default 0,
  favorite boolean not null default false,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  title text not null default 'Conversation',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  conversation_id uuid not null references public.ai_conversations (id) on delete cascade,
  role text not null default 'user' check (role in ('user', 'assistant', 'system')),
  content text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  theme_mode text not null default 'system',
  favorite_templates text[] not null default '{}',
  recent_templates text[] not null default '{}',
  dashboard_order text[] not null default '{}',
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- ----------------------------------------------------------------- indexes
create index if not exists idx_documents_owner on public.documents (owner_id, updated_at desc);
create index if not exists idx_spreadsheets_owner on public.spreadsheets (owner_id, updated_at desc);
create index if not exists idx_presentations_owner on public.presentations (owner_id, updated_at desc);
create index if not exists idx_invoices_owner on public.invoices (owner_id, issue_date desc);
create index if not exists idx_quotations_owner on public.quotations (owner_id, issue_date desc);
create index if not exists idx_customers_owner on public.customers (owner_id, lead_stage);
create index if not exists idx_products_owner on public.products (owner_id, category);
create index if not exists idx_tasks_owner_status on public.tasks (owner_id, status, due_date);
create index if not exists idx_tasks_project on public.tasks (project_id);
create index if not exists idx_files_owner on public.files (owner_id, updated_at desc);

-- ------------------------------------------------------- updated_at triggers
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','workspaces','folders','documents','spreadsheets','presentations',
    'presentation_slides','customers','invoices','quotations','products',
    'projects','tasks','notifications','files','ai_conversations','user_preferences'
  ] loop
    execute format('drop trigger if exists trg_%s_updated on public.%s', t, t);
    execute format(
      'create trigger trg_%s_updated before update on public.%s for each row execute function public.set_updated_at()',
      t, t);
  end loop;
end;
$$;

-- ------------------------------------------------------------- RLS policies
-- Every tenant table: users can only see and modify their own rows.
do $$
declare t text;
begin
  foreach t in array array[
    'workspaces','folders','documents','document_versions','spreadsheets',
    'spreadsheet_versions','presentations','presentation_slides','customers',
    'customer_notes','invoices','invoice_items','quotations','quotation_items',
    'products','inventory_movements','projects','tasks','notifications',
    'files','ai_conversations','ai_messages'
  ] loop
    execute format('alter table public.%s enable row level security', t);
    execute format('drop policy if exists "%s_owner_all" on public.%s', t, t);
    execute format(
      'create policy "%s_owner_all" on public.%s for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid())',
      t, t);
  end loop;
end;
$$;

alter table public.profiles enable row level security;
drop policy if exists "profiles_self" on public.profiles;
create policy "profiles_self" on public.profiles
  for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

alter table public.workspace_members enable row level security;
drop policy if exists "workspace_members_visible" on public.workspace_members;
create policy "workspace_members_visible" on public.workspace_members
  for select to authenticated
  using (
    user_id = auth.uid()
    or workspace_id in (select id from public.workspaces where owner_id = auth.uid())
  );

alter table public.user_preferences enable row level security;
drop policy if exists "user_preferences_self" on public.user_preferences;
create policy "user_preferences_self" on public.user_preferences
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Templates are a public catalogue authored by ORBITAL (read-only for users).
alter table public.templates enable row level security;
drop policy if exists "templates_public_read" on public.templates;
create policy "templates_public_read" on public.templates
  for select to anon, authenticated using (true);

-- ------------------------------------------------------------------ storage
insert into storage.buckets (id, name, public)
values ('user-files', 'user-files', false)
on conflict (id) do nothing;

drop policy if exists "user_files_own_folder" on storage.objects;
create policy "user_files_own_folder" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'user-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'user-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

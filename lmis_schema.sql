-- LMIS: Legal Management Information System (Affordable Housing Board)
-- Run this whole file once in the Supabase SQL Editor.

create extension if not exists "pgcrypto";

-- USERS / ROLES -------------------------------------------------------
create table if not exists public.lmis_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  role text not null default 'viewer' check (role in ('admin','lawyer','viewer')),
  created_at timestamptz default now()
);

-- First user to sign up becomes admin, everyone after is a viewer until promoted
create or replace function public.lmis_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.lmis_profiles (id, full_name, email, role)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
          new.email,
          case when (select count(*) from public.lmis_profiles) = 0 then 'admin' else 'viewer' end);
  return new;
end $$;

drop trigger if exists lmis_on_signup on auth.users;
create trigger lmis_on_signup after insert on auth.users
for each row execute function public.lmis_new_user();

create or replace function public.lmis_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.lmis_profiles where id = auth.uid()
$$;

-- CORE TABLES ---------------------------------------------------------
create table if not exists public.lmis_projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  status text default 'ongoing' check (status in ('planning','ongoing','completed')),
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.lmis_lawyers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text default 'external' check (type in ('internal','external','state_law_office')),
  firm text,
  email text,
  phone text,
  created_at timestamptz default now()
);
alter table public.lmis_lawyers add column if not exists profile_image_path text;

-- which lawyer is on which project
create table if not exists public.lmis_assignments (
  id uuid primary key default gen_random_uuid(),
  lawyer_id uuid references public.lmis_lawyers(id) on delete cascade,
  project_id uuid references public.lmis_projects(id) on delete cascade,
  role text,
  created_at timestamptz default now()
);

-- projects currently signing agreements
create table if not exists public.lmis_agreements (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references public.lmis_projects(id) on delete cascade,
  title text not null,
  counterparty text,
  status text default 'drafting' check (status in ('drafting','signing','signed')),
  signing_date date,
  lawyer_id uuid references public.lmis_lawyers(id) on delete set null,
  created_at timestamptz default now()
);

-- litigation case tracker
create table if not exists public.lmis_cases (
  id uuid primary key default gen_random_uuid(),
  case_number text,
  title text not null,
  court text,
  project_id uuid references public.lmis_projects(id) on delete set null,
  lawyer_id uuid references public.lmis_lawyers(id) on delete set null,
  status text default 'active' check (status in ('active','pending','resolved')),
  date_filed date,
  next_hearing date,
  notes text,
  created_at timestamptz default now()
);
alter table public.lmis_cases add column if not exists profile_image_path text;

-- issue tracker (issues can sit under a case or stand alone)
create table if not exists public.lmis_issues (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  case_id uuid references public.lmis_cases(id) on delete set null,
  status text default 'pending' check (status in ('pending','resolved')),
  resolution_note text,
  resolved_at timestamptz,
  created_by uuid default auth.uid(),
  created_at timestamptz default now()
);

-- receipts of lawyers' spending
create table if not exists public.lmis_expenses (
  id uuid primary key default gen_random_uuid(),
  case_id uuid references public.lmis_cases(id) on delete set null,
  lawyer_id uuid references public.lmis_lawyers(id) on delete set null,
  description text not null,
  amount numeric(14,2) default 0,
  spent_on date default current_date,
  created_at timestamptz default now()
);

-- uploaded files for cases, issues, expenses, agreements
create table if not exists public.lmis_documents (
  id uuid primary key default gen_random_uuid(),
  parent_type text not null,
  parent_id uuid not null,
  name text not null,
  path text not null,
  uploaded_by uuid default auth.uid(),
  created_at timestamptz default now()
);

-- SECURITY (RLS) --------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['lmis_projects','lmis_lawyers','lmis_assignments','lmis_agreements',
                           'lmis_cases','lmis_issues','lmis_expenses','lmis_documents'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "read_%1$s" on public.%1$I', t);
    execute format('drop policy if exists "write_%1$s" on public.%1$I', t);
    execute format('create policy "read_%1$s" on public.%1$I for select to authenticated using (true)', t);
    execute format('create policy "write_%1$s" on public.%1$I for all to authenticated
                    using (public.lmis_role() in (''admin'',''lawyer''))
                    with check (public.lmis_role() in (''admin'',''lawyer''))', t);
  end loop;
end $$;

alter table public.lmis_profiles enable row level security;
drop policy if exists "read_profiles" on public.lmis_profiles;
drop policy if exists "admin_profiles" on public.lmis_profiles;
create policy "read_profiles" on public.lmis_profiles for select to authenticated using (true);
create policy "admin_profiles" on public.lmis_profiles for update to authenticated
  using (public.lmis_role() = 'admin') with check (public.lmis_role() = 'admin');

-- FILE STORAGE ----------------------------------------------------------
insert into storage.buckets (id, name, public) values ('lmis-docs','lmis-docs', false)
on conflict (id) do nothing;

drop policy if exists "lmis_docs_read" on storage.objects;
drop policy if exists "lmis_docs_write" on storage.objects;
create policy "lmis_docs_read" on storage.objects for select to authenticated
  using (bucket_id = 'lmis-docs');
create policy "lmis_docs_write" on storage.objects for all to authenticated
  using (bucket_id = 'lmis-docs' and public.lmis_role() in ('admin','lawyer'))
  with check (bucket_id = 'lmis-docs' and public.lmis_role() in ('admin','lawyer'));

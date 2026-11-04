-- 9090 CARGO cloud schema v1 (PostgreSQL / Supabase)
-- Preparation only: do NOT run against a production database without review.
-- Authentication: server-side username/password provider required.
-- Never store plaintext passwords or service-role keys in GitHub or browser.
create extension if not exists pgcrypto;

create table if not exists public.staff_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[A-Za-z0-9_-]{4,40}$'),
  display_name text not null,
  role text not null check (role in ('admin','ereen','umnugovi','accountant')),
  preferred_language text not null default 'mn' check (preferred_language in ('mn','zh')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create or replace function public.current_staff_role()
returns text language sql stable security definer set search_path=public
as $$ select role from public.staff_profiles where user_id=auth.uid() and active=true limit 1 $$;
revoke all on function public.current_staff_role() from public;
grant execute on function public.current_staff_role() to authenticated;

create table if not exists public.trips (
 id uuid primary key default gen_random_uuid(),
 trip_code text not null unique,
 truck_number text not null,
 status text not null default 'planning'
   check(status in ('planning','loading','departed','arrived','completed')),
 departed_at timestamptz,
 arrived_at timestamptz,
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);

create table if not exists public.shipments (
 id uuid primary key default gen_random_uuid(),
 shipment_code text not null unique,
 customer_label text,
 goods text not null,
 pieces numeric(12,2) not null default 0,
 weight_kg numeric(14,3) not null default 0,
 volume_m3 numeric(14,3) not null default 0,
 area_m2 numeric(14,3) not null default 0,
 destination text,
 status text not null default 'received'
   check(status in ('received','waiting','loaded','arrived','delivered')),
 fee_cny numeric(14,2) not null default 0,
 paid_cny numeric(14,2) not null default 0,
 trip_id uuid references public.trips(id),
 planned_trip_id uuid references public.trips(id),
 received_at timestamptz not null default now(),
 created_by uuid references auth.users(id),
 updated_at timestamptz not null default now(),
 check (fee_cny >= 0 and paid_cny >= 0 and paid_cny <= fee_cny)
);

create table if not exists public.shipment_events (
 id bigint generated always as identity primary key,
 shipment_id uuid not null references public.shipments(id) on delete cascade,
 action text not null,
 actor_id uuid references auth.users(id),
 occurred_at timestamptz not null default now(),
 details jsonb not null default '{}'::jsonb
);

create index if not exists shipments_fifo_idx on public.shipments(received_at)
 where trip_id is null;
create index if not exists shipments_trip_idx on public.shipments(trip_id);

alter table public.staff_profiles enable row level security;
alter table public.trips enable row level security;
alter table public.shipments enable row level security;
alter table public.shipment_events enable row level security;

create policy "active staff can read staff directory" on public.staff_profiles
 for select to authenticated using (public.current_staff_role() is not null);
create policy "admins manage staff" on public.staff_profiles
 for all to authenticated using (public.current_staff_role()='admin')
 with check (public.current_staff_role()='admin');

create policy "staff read trips" on public.trips
 for select to authenticated using (public.current_staff_role() is not null);
create policy "warehouse or admin manage trips" on public.trips
 for all to authenticated using (public.current_staff_role() in ('admin','ereen','umnugovi'))
 with check (public.current_staff_role() in ('admin','ereen','umnugovi'));

create policy "staff read shipments" on public.shipments
 for select to authenticated using (public.current_staff_role() is not null);
create policy "warehouse or admin manage shipments" on public.shipments
 for all to authenticated using (public.current_staff_role() in ('admin','ereen','umnugovi'))
 with check (public.current_staff_role() in ('admin','ereen','umnugovi'));

create policy "staff read events" on public.shipment_events
 for select to authenticated using (public.current_staff_role() is not null);
create policy "warehouse or admin add events" on public.shipment_events
 for insert to authenticated with check (
 public.current_staff_role() in ('admin','ereen','umnugovi') and actor_id=auth.uid());

-- Before production: enforce role-specific column updates and immutable audit events
-- via server-side RPC / triggers; current broad warehouse UPDATE policies are NOT
-- sufficient for financial fields or irreversible delivered/paid transitions.
-- Never expose shipment data to anon users. Customer portal needs separate scoped RLS.

-- =====================================================================
-- BIKE SHOP — Supabase schema
-- Run this whole file once in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- Safe to re-run (uses IF NOT EXISTS / OR REPLACE where possible).
-- =====================================================================

-- ---------- Owner accounts ----------
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.admins enable row level security;

create or replace function public.is_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

drop policy if exists "admins read own" on public.admins;
create policy "admins read own" on public.admins for select to authenticated using (user_id = auth.uid());
-- (No insert/update/delete policy on purpose: owners can only be added from the SQL editor.)

-- ---------- Bikes (public-readable, owner-writable) ----------
create table if not exists public.bikes (
  id uuid primary key default gen_random_uuid(),
  make text not null,
  model text not null,
  variant text not null default '',
  year int not null check (year between 2000 and 2030),
  price int not null check (price >= 10000),
  mileage int not null default 0,
  fuel text not null default 'Petrol',
  transmission text not null default 'Manual',
  body_type text not null default 'Commuter',
  owners text not null default '1st Owner',
  color text not null default '',
  rto text not null default '',
  insurance text not null default '',
  inspection_score int not null default 95 check (inspection_score between 0 and 100),
  status text not null default 'Available' check (status in ('Available','Reserved','Sold')),
  features text[] not null default '{}',
  description text not null default '',
  images text[] not null default '{}',
  views int not null default 0,
  wishlist_count int not null default 0,
  created_at timestamptz not null default now()
);
alter table public.bikes enable row level security;

drop policy if exists "bikes public read" on public.bikes;
drop policy if exists "bikes admin insert" on public.bikes;
drop policy if exists "bikes admin update" on public.bikes;
drop policy if exists "bikes admin delete" on public.bikes;
create policy "bikes public read"  on public.bikes for select to anon, authenticated using (true);
create policy "bikes admin insert" on public.bikes for insert to authenticated with check (public.is_admin());
create policy "bikes admin update" on public.bikes for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "bikes admin delete" on public.bikes for delete to authenticated using (public.is_admin());

-- ---------- Dealer costs (PRIVATE: only the owner can ever read this) ----------
create table if not exists public.bike_costs (
  bike_id uuid primary key references public.bikes(id) on delete cascade,
  cost_price int not null default 0,
  refurb_cost int not null default 0
);
alter table public.bike_costs enable row level security;
drop policy if exists "costs admin all" on public.bike_costs;
create policy "costs admin all" on public.bike_costs for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------- Customer profiles ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text not null default '',
  phone text not null default '',
  city text not null default '',
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
drop policy if exists "profiles read own or admin" on public.profiles;
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles read own or admin" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
create policy "profiles update own" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, name, phone, city)
  values (
    new.id, new.email,
    left(coalesce(new.raw_user_meta_data->>'name',''), 100),
    left(coalesce(new.raw_user_meta_data->>'phone',''), 20),
    left(coalesce(new.raw_user_meta_data->>'city',''), 60)
  )
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Wishlists ----------
create table if not exists public.wishlists (
  user_id uuid not null references auth.users(id) on delete cascade,
  bike_id uuid not null references public.bikes(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, bike_id)
);
alter table public.wishlists enable row level security;
drop policy if exists "wish read own or admin" on public.wishlists;
drop policy if exists "wish insert own" on public.wishlists;
drop policy if exists "wish delete own" on public.wishlists;
create policy "wish read own or admin" on public.wishlists for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy "wish insert own" on public.wishlists for insert to authenticated with check (user_id = auth.uid());
create policy "wish delete own" on public.wishlists for delete to authenticated using (user_id = auth.uid());

create or replace function public.sync_wishlist_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.bikes set wishlist_count = wishlist_count + 1 where id = new.bike_id;
  elsif tg_op = 'DELETE' then
    update public.bikes set wishlist_count = greatest(wishlist_count - 1, 0) where id = old.bike_id;
  end if;
  return null;
end $$;
drop trigger if exists wishlist_count_sync on public.wishlists;
create trigger wishlist_count_sync after insert or delete on public.wishlists
  for each row execute function public.sync_wishlist_count();

-- ---------- Leads (test-ride / offer inquiries) ----------
create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  bike_id uuid references public.bikes(id) on delete set null,
  bike_title text not null default '',
  customer_name text not null,
  customer_phone text not null,
  preferred_date date,
  note text not null default '',
  status text not null default 'New Inquiry',
  user_id uuid default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.leads enable row level security;
drop policy if exists "leads anyone insert" on public.leads;
drop policy if exists "leads admin read" on public.leads;
drop policy if exists "leads admin update" on public.leads;
drop policy if exists "leads admin delete" on public.leads;
create policy "leads anyone insert" on public.leads for insert to anon, authenticated
  with check (
    char_length(customer_name) between 1 and 100
    and char_length(customer_phone) between 5 and 25
    and char_length(note) <= 500
    and status = 'New Inquiry'
    and (user_id is null or user_id = auth.uid())
  );
create policy "leads admin read"   on public.leads for select to authenticated using (public.is_admin());
create policy "leads admin update" on public.leads for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "leads admin delete" on public.leads for delete to authenticated using (public.is_admin());

-- ---------- View counter (anyone may bump a bike's view count by 1) ----------
create or replace function public.increment_views(bike_id uuid)
returns void language sql security definer set search_path = public as $$
  update public.bikes set views = views + 1 where id = bike_id;
$$;
revoke all on function public.increment_views(uuid) from public;
grant execute on function public.increment_views(uuid) to anon, authenticated;

-- ---------- Photo storage bucket ----------
-- Each photo is limited to 1 MB server-side; the website also compresses every photo
-- (~120-250 KB full size + ~25 KB thumbnail), so 500 MB holds roughly 400-600 bikes.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('bike-photos', 'bike-photos', true, 1048576, array['image/webp','image/jpeg','image/png'])
on conflict (id) do update
  set public = true, file_size_limit = 1048576, allowed_mime_types = array['image/webp','image/jpeg','image/png'];

drop policy if exists "bike photos public read" on storage.objects;
drop policy if exists "bike photos admin insert" on storage.objects;
drop policy if exists "bike photos admin update" on storage.objects;
drop policy if exists "bike photos admin delete" on storage.objects;
create policy "bike photos public read"  on storage.objects for select using (bucket_id = 'bike-photos');
create policy "bike photos admin insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'bike-photos' and public.is_admin());
create policy "bike photos admin update" on storage.objects for update to authenticated
  using (bucket_id = 'bike-photos' and public.is_admin());
create policy "bike photos admin delete" on storage.objects for delete to authenticated
  using (bucket_id = 'bike-photos' and public.is_admin());

-- =====================================================================
-- LAST STEP (do this AFTER creating the owner user in Authentication -> Users):
-- replace the email below with the owner's email and run just this line.
--
--   insert into public.admins (user_id)
--   select id from auth.users where email = 'OWNER_EMAIL_HERE'
--   on conflict do nothing;
-- =====================================================================

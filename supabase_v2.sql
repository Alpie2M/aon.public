-- ============================================================
--  AON v2 — Supabase schema + security (RLS) + Storage
-- ============================================================

create extension if not exists pgcrypto;

-- 1) OFFICIAL MEMBER LIST
create table if not exists public.community_members (
  id                uuid primary key default gen_random_uuid(),
  membership_number text unique not null,
  first_name        text not null,
  last_name         text not null,
  email             text not null,
  is_active         boolean default true,
  member_type       text
);

alter table public.community_members
  add column if not exists membership_number text,
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists email text,
  add column if not exists is_active boolean default true,
  add column if not exists member_type text;

alter table public.community_members
  drop constraint if exists community_members_email_key;

alter table public.community_members
  alter column membership_number set not null,
  alter column first_name set not null,
  alter column last_name set not null,
  alter column email set not null,
  alter column is_active set default true;

create unique index if not exists community_members_membership_number_idx
  on public.community_members (membership_number);

create index if not exists community_members_email_idx
  on public.community_members (lower(trim(email)));

alter table public.community_members
  drop constraint if exists community_members_member_type_check;

alter table public.community_members
  add constraint community_members_member_type_check
  check (member_type is null or lower(member_type) in ('student', 'alumni'));

-- 2) ADMINS
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

-- 3) PROFILES + PRIVATE CONTACTS
create table if not exists public.candidate_profiles (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid unique references auth.users(id) on delete cascade,
  membership_number text,
  first_name        text,
  last_name         text,
  status            text check (status in ('ogrenci','mezun')),
  school            text,
  department        text,
  graduation_year   text,
  city              text,
  summary           text,
  skills            text[] default '{}',
  linkedin          text,
  portfolio         text,
  cv_path           text,
  created_at        timestamptz default now()
);

create table if not exists public.candidate_contacts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone   text,
  email   text
);

create table if not exists public.employer_profiles (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid unique references auth.users(id) on delete cascade,
  membership_number text,
  first_name        text,
  last_name         text,
  company_name      text,
  title             text,
  created_at        timestamptz default now()
);

create table if not exists public.employer_contacts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone   text,
  email   text
);

-- 4) JOB POSTS
create table if not exists public.job_posts (
  id               uuid primary key default gen_random_uuid(),
  employer_user_id uuid references auth.users(id) on delete cascade,
  title            text,
  company_name     text,
  position         text,
  work_type        text,
  city             text,
  description      text,
  qualifications   text,
  deadline         date,
  is_published     boolean default true,
  created_at       timestamptz default now()
);

-- 5) CONSENTS
create table if not exists public.consents (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid references auth.users(id) on delete cascade,
  membership_number       text,
  kvkk_approved           boolean,
  privacy_notice_approved boolean,
  approved_at             timestamptz default now()
);

-- 6) CONTACT REQUESTS
create table if not exists public.contact_requests (
  id         uuid primary key default gen_random_uuid(),
  from_user  uuid references auth.users(id) on delete cascade,
  to_user    uuid references auth.users(id) on delete cascade,
  context    text,
  status     text default 'pending' check (status in ('pending','approved','declined')),
  created_at timestamptz default now(),
  decided_at timestamptz
);

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
create or replace function public.is_member() returns boolean
language sql security definer stable set search_path = public as $$
  select exists(
    select 1
    from public.community_members m
    where lower(trim(m.email)) = lower(trim(coalesce(auth.jwt()->>'email','')))
      and m.is_active
  );
$$;

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists(
    select 1 from public.admins a where a.user_id = auth.uid()
  );
$$;

create or replace function public.has_approved_link(other uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists(
    select 1
    from public.contact_requests r
    where r.status = 'approved'
      and (
        (r.from_user = auth.uid() and r.to_user = other)
        or
        (r.to_user = auth.uid() and r.from_user = other)
      )
  );
$$;

-- ============================================================
-- RLS
-- ============================================================
alter table public.community_members enable row level security;
alter table public.admins enable row level security;
alter table public.candidate_profiles enable row level security;
alter table public.candidate_contacts enable row level security;
alter table public.employer_profiles enable row level security;
alter table public.employer_contacts enable row level security;
alter table public.job_posts enable row level security;
alter table public.consents enable row level security;
alter table public.contact_requests enable row level security;

drop policy if exists cm_read_own on public.community_members;
drop policy if exists cp_read on public.candidate_profiles;
drop policy if exists cp_insert on public.candidate_profiles;
drop policy if exists cp_update on public.candidate_profiles;
drop policy if exists cc_read on public.candidate_contacts;
drop policy if exists cc_insert on public.candidate_contacts;
drop policy if exists cc_update on public.candidate_contacts;
drop policy if exists ep_read on public.employer_profiles;
drop policy if exists ep_insert on public.employer_profiles;
drop policy if exists ep_update on public.employer_profiles;
drop policy if exists ec_read on public.employer_contacts;
drop policy if exists ec_insert on public.employer_contacts;
drop policy if exists ec_update on public.employer_contacts;
drop policy if exists jp_read on public.job_posts;
drop policy if exists jp_insert on public.job_posts;
drop policy if exists jp_manage on public.job_posts;
drop policy if exists jp_delete on public.job_posts;
drop policy if exists co_read on public.consents;
drop policy if exists co_insert on public.consents;
drop policy if exists cr_read on public.contact_requests;
drop policy if exists cr_insert on public.contact_requests;
drop policy if exists cr_decide on public.contact_requests;
drop policy if exists cv_upload on storage.objects;
drop policy if exists cv_read on storage.objects;

create policy cm_read_own on public.community_members
for select
using (
  lower(trim(email)) = lower(trim(coalesce(auth.jwt()->>'email','')))
  or public.is_admin()
);

create policy cp_read on public.candidate_profiles
for select
using (public.is_member());

create policy cp_insert on public.candidate_profiles
for insert
with check (public.is_member() and user_id = auth.uid());

create policy cp_update on public.candidate_profiles
for update
using (user_id = auth.uid() or public.is_admin());

create policy cc_read on public.candidate_contacts
for select
using (
  user_id = auth.uid()
  or public.is_admin()
  or public.has_approved_link(user_id)
);

create policy cc_insert on public.candidate_contacts
for insert
with check (user_id = auth.uid());

create policy cc_update on public.candidate_contacts
for update
using (user_id = auth.uid());

create policy ep_read on public.employer_profiles
for select
using (public.is_member());

create policy ep_insert on public.employer_profiles
for insert
with check (public.is_member() and user_id = auth.uid());

create policy ep_update on public.employer_profiles
for update
using (user_id = auth.uid() or public.is_admin());

create policy ec_read on public.employer_contacts
for select
using (
  user_id = auth.uid()
  or public.is_admin()
  or public.has_approved_link(user_id)
);

create policy ec_insert on public.employer_contacts
for insert
with check (user_id = auth.uid());

create policy ec_update on public.employer_contacts
for update
using (user_id = auth.uid());

create policy jp_read on public.job_posts
for select
using (public.is_member());

create policy jp_insert on public.job_posts
for insert
with check (public.is_member() and employer_user_id = auth.uid());

create policy jp_manage on public.job_posts
for update
using (employer_user_id = auth.uid() or public.is_admin());

create policy jp_delete on public.job_posts
for delete
using (employer_user_id = auth.uid() or public.is_admin());

create policy co_read on public.consents
for select
using (user_id = auth.uid() or public.is_admin());

create policy co_insert on public.consents
for insert
with check (user_id = auth.uid());

create policy cr_read on public.contact_requests
for select
using (
  from_user = auth.uid()
  or to_user = auth.uid()
  or public.is_admin()
);

create policy cr_insert on public.contact_requests
for insert
with check (public.is_member() and from_user = auth.uid());

create policy cr_decide on public.contact_requests
for update
using (to_user = auth.uid())
with check (to_user = auth.uid());

-- ============================================================
-- STORAGE (CV)
-- ============================================================
insert into storage.buckets (id, name, public)
values ('cvs', 'cvs', false)
on conflict (id) do nothing;

create policy cv_upload on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'cvs'
  and public.is_member()
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy cv_read on storage.objects
for select
to authenticated
using (
  bucket_id = 'cvs'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
    or public.has_approved_link(((storage.foldername(name))[1])::uuid)
  )
);

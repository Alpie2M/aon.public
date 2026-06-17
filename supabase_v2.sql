-- ============================================================
--  AON v2 — Supabase şema + güvenlik (RLS) + Storage
--  SQL Editor → New query → yapıştır → Run.  Bir kez çalıştır.
--  Üyelik allowlist + ilişki-bazlı gizli iletişim + CV.
-- ============================================================

-- 1) RESMİ ÜYE LİSTESİ (CSV'ni Table editor → Import ile buraya yükle)
create table if not exists public.community_members (
  id                uuid primary key default gen_random_uuid(),
  membership_number text unique not null,
  first_name        text not null,
  last_name         text not null,
  email             text unique not null,
  is_active         boolean default true
);

-- 2) ADMINLER (kendi auth user_id'ni buraya ekle; aşağıda not var)
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

-- 3) PROFİLLER (public alanlar) + GİZLİ İLETİŞİM (ayrı tablo)
create table if not exists public.candidate_profiles (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid unique references auth.users(id) on delete cascade,
  membership_number text,
  first_name text, last_name text,
  status            text check (status in ('ogrenci','mezun')),
  school text, department text, graduation_year text, city text,
  summary text, skills text[] default '{}',
  linkedin text, portfolio text,
  cv_path text,
  created_at        timestamptz default now()
);
create table if not exists public.candidate_contacts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone text, email text
);

create table if not exists public.employer_profiles (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid unique references auth.users(id) on delete cascade,
  membership_number text,
  first_name text, last_name text,
  company_name text, title text,
  created_at        timestamptz default now()
);
create table if not exists public.employer_contacts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone text, email text
);

-- 4) İLANLAR
create table if not exists public.job_posts (
  id               uuid primary key default gen_random_uuid(),
  employer_user_id uuid references auth.users(id) on delete cascade,
  title text, company_name text, position text, work_type text, city text,
  description text, qualifications text, deadline date,
  is_published boolean default true,
  created_at timestamptz default now()
);

-- 5) ONAYLAR (KVKK + aydınlatma)
create table if not exists public.consents (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid references auth.users(id) on delete cascade,
  membership_number text,
  kvkk_approved boolean, privacy_notice_approved boolean,
  approved_at timestamptz default now()
);

-- 6) İLETİŞİM İSTEKLERİ (onaylanınca iletişim açılır)
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
--  YARDIMCI FONKSİYONLAR (security definer => RLS recursion yok)
-- ============================================================
create or replace function public.is_member() returns boolean
language sql security definer stable set search_path = public as $$
  select exists(
    select 1 from public.community_members m
    where lower(m.email) = lower(coalesce(auth.jwt()->>'email','')) and m.is_active
  );
$$;

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists(select 1 from public.admins a where a.user_id = auth.uid());
$$;

-- iki kullanıcı arasında ONAYLI istek var mı?
create or replace function public.has_approved_link(other uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists(
    select 1 from public.contact_requests r where r.status='approved'
    and ((r.from_user=auth.uid() and r.to_user=other)
      or (r.to_user=auth.uid() and r.from_user=other))
  );
$$;

-- ============================================================
--  RLS
-- ============================================================
alter table public.community_members enable row level security;
alter table public.admins             enable row level security;
alter table public.candidate_profiles enable row level security;
alter table public.candidate_contacts enable row level security;
alter table public.employer_profiles  enable row level security;
alter table public.employer_contacts  enable row level security;
alter table public.job_posts          enable row level security;
alter table public.consents           enable row level security;
alter table public.contact_requests   enable row level security;

-- community_members: kişi sadece KENDİ satırını okur (liste harvest edilemez)
create policy cm_read_own on public.community_members for select
  using (lower(email)=lower(coalesce(auth.jwt()->>'email','')) or public.is_admin());

-- candidate_profiles: tüm üyeler public alanları görür; sahibi yazar
create policy cp_read   on public.candidate_profiles for select using (public.is_member());
create policy cp_insert on public.candidate_profiles for insert with check (public.is_member() and user_id=auth.uid());
create policy cp_update on public.candidate_profiles for update using (user_id=auth.uid() or public.is_admin());

-- candidate_contacts: sadece sahibi / onaylı bağlantı / admin görür
create policy cc_read   on public.candidate_contacts for select using (
  user_id=auth.uid() or public.is_admin() or public.has_approved_link(user_id));
create policy cc_insert on public.candidate_contacts for insert with check (user_id=auth.uid());
create policy cc_update on public.candidate_contacts for update using (user_id=auth.uid());

-- employer_profiles
create policy ep_read   on public.employer_profiles for select using (public.is_member());
create policy ep_insert on public.employer_profiles for insert with check (public.is_member() and user_id=auth.uid());
create policy ep_update on public.employer_profiles for update using (user_id=auth.uid() or public.is_admin());

-- employer_contacts
create policy ec_read   on public.employer_contacts for select using (
  user_id=auth.uid() or public.is_admin() or public.has_approved_link(user_id));
create policy ec_insert on public.employer_contacts for insert with check (user_id=auth.uid());
create policy ec_update on public.employer_contacts for update using (user_id=auth.uid());

-- job_posts: üyeler görür; sahibi yönetir
create policy jp_read   on public.job_posts for select using (public.is_member());
create policy jp_insert on public.job_posts for insert with check (public.is_member() and employer_user_id=auth.uid());
create policy jp_manage on public.job_posts for update using (employer_user_id=auth.uid() or public.is_admin());
create policy jp_delete on public.job_posts for delete using (employer_user_id=auth.uid() or public.is_admin());

-- consents: sahibi
create policy co_read   on public.consents for select using (user_id=auth.uid() or public.is_admin());
create policy co_insert on public.consents for insert with check (user_id=auth.uid());

-- contact_requests: tarafları görür; gönderen oluşturur; ALICI karar verir
create policy cr_read   on public.contact_requests for select using (from_user=auth.uid() or to_user=auth.uid() or public.is_admin());
create policy cr_insert on public.contact_requests for insert with check (public.is_member() and from_user=auth.uid());
create policy cr_decide on public.contact_requests for update using (to_user=auth.uid()) with check (to_user=auth.uid());

-- ============================================================
--  STORAGE (CV) — private bucket, ilişki-bazlı erişim
--  Yol kuralı: cvs/<user_id>/cv.pdf
-- ============================================================
insert into storage.buckets (id, name, public) values ('cvs','cvs', false)
  on conflict (id) do nothing;

create policy cv_upload on storage.objects for insert to authenticated with check (
  bucket_id='cvs' and public.is_member() and (storage.foldername(name))[1] = auth.uid()::text
);
create policy cv_read on storage.objects for select to authenticated using (
  bucket_id='cvs' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
    or public.has_approved_link(((storage.foldername(name))[1])::uuid)
  )
);

-- ============================================================
--  KENDİNİ ADMİN YAP (giriş yaptıktan SONRA):
--  Supabase → Authentication → Users → kendi user UID'ini kopyala,
--  sonra SQL Editor'da:
--    insert into public.admins (user_id) values ('BURAYA_UID');
-- ============================================================

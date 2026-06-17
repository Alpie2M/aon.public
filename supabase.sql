-- ============================================================
--  AON — Supabase kurulum SQL'i
--  Supabase panelinde:  SQL Editor → New query → bunu yapıştır → Run
--  (sadece BİR KEZ çalıştır — örnek kayıtlar tekrarlanmasın)
-- ============================================================

create table if not exists public.candidates (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  role       text not null,
  skills     text[] default '{}',
  bio        text,
  contact    text,
  created_at timestamptz default now()
);

create table if not exists public.opportunities (
  id          uuid primary key default gen_random_uuid(),
  company     text not null,
  role        text not null,
  location    text,
  type        text,
  skills      text[] default '{}',
  description text,
  created_at  timestamptz default now()
);

-- Row Level Security: herkes okuyabilir + ekleyebilir; silme yok (moderasyon panelden)
alter table public.candidates    enable row level security;
alter table public.opportunities enable row level security;

create policy "read all"   on public.candidates    for select using (true);
create policy "insert any" on public.candidates    for insert with check (true);
create policy "read all"   on public.opportunities for select using (true);
create policy "insert any" on public.opportunities for insert with check (true);

-- Örnek kayıtlar (istersen sil)
insert into public.candidates (name, role, skills, bio, contact) values
  ('Elif K.','Frontend Developer','{React,TypeScript,CSS,Figma}','2 yıl React deneyimi, remote startup arıyor.','@elifk'),
  ('Mert A.','Data / Finance Analyst','{Python,Excel,SQL,Finance}','İşletme mezunu, veri & finans. Werkstudent açık.','mert@mail.com');

insert into public.opportunities (company, role, location, type, skills, description) values
  ('Develey','Werkstudent Finance','München','Werkstudent','{Excel,SAP,Finance,Python}','Finans departmanı, 20s/hafta.'),
  ('ChainLabs','Junior Frontend Dev','Remote','Tam zamanlı','{React,TypeScript,CSS,Web3}','Web3 dashboard ekibi.');

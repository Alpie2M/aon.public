# AON v2 — kurulum & test kılavuzu

v1'in (basit site) canlı kalsın. v2'yi önce test et, çalışınca değiştir.

## 1) Veritabanı + güvenlik
- Supabase → SQL Editor → `supabase_v2.sql`'i yapıştır → **Run**. Hata yoksa tablolar + RLS + `cvs` bucket hazır.

## 2) Üye listesini yükle
- Table editor → `community_members` → **Insert → Import data from CSV**.
- CSV sütunlarını şunlara eşle: `membership_number`, `first_name`, `last_name`, `email`, `is_active` (hepsi true).
- E-postalar girişin anahtarı; doğru olmalı.

## 3) Giriş ayarı
- Authentication → Providers → **Email** açık (magic-link bununla çalışır).
- Authentication → URL Configuration → **Site URL** = test ettiğin Netlify adresi (örn `https://imtaon.netlify.app`). Linkler buraya döner.

## 4) Deploy
- `index.html` (+ `netlify`, `netlify.toml`, `.gitignore`) repodaki dosyaların yerine koy → push. Netlify otomatik yayınlar.
- (İstersen v1'i bozmamak için ayrı bir Netlify sitesi/branch ile test et.)

## 5) İlk test (sadece kendine)
- Siteyi aç → kendi üye e-postanı gir → gelen maildeki linke tıkla → giriş yap.
- Rol seç (Aday/İlan Veren) → formu doldur (Aday'da CV zorunlu) → kaydet.
- Fırsatlar/Adaylar listelerini, "İletişim iste" + "İstekler" onay akışını dene.
- Onaydan sonra iletişim bilgisinin açıldığını gör.

## 6) Kendini admin yap
- Authentication → Users → kendi **UID**'ini kopyala → SQL Editor:
  `insert into public.admins (user_id) values ('UID');`

## 7) E-posta (magic-link + bildirim) — domain sonrası
İlk testte Supabase'in yerleşik postası kendi adresine yeter. Gerçek üyelere göndermek için:
- **Resend** hesabı + alan adı doğrula (DNS kayıtları).
- Magic-link: Supabase → Authentication → SMTP Settings → Resend SMTP bilgileri.
- Bildirim fonksiyonu: Netlify → Site settings → Environment variables → ekle:
  `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (Supabase → Settings → API → service_role — GİZLİ), `RESEND_API_KEY`, `FROM_EMAIL` (örn `noreply@imtaon.com`), `SITE_URL`.

## Önemli notlar
- **KVKK / Aydınlatma metni**: formdaki onay kutuları placeholder. Gerçek, hukukçu onaylı metni eklemeden gerçek üye toplama. (Ben hukuki metin yazamam.)
- **CV'ler hassas kişisel veridir**: özel bucket + ilişki-bazlı erişim kuruldu; yine de saklama/silme politikası belirle.
- **service_role anahtarı** sadece Netlify env'de durur, tarayıcıya/koda asla girmez.
- Moderasyon (kayıt pasife alma, CV indirme, gizli iletişime erişim) şimdilik Supabase **Table editor** + admin yetkisiyle yapılır; ayrı admin paneli ileride.
- Domain: pilot öncesi alınacak (hatırlatacağım).

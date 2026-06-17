# AON — Canlıya çıkış kılavuzu

Tek dosyalık site + gerçek veritabanı. Stack: **Supabase** (ücretsiz Postgres DB) + **Netlify** (ücretsiz hosting). Toplam süre ~15 dk, kart/ücret gerekmez (free tier).

`index.html` **çift modda** çalışır:
- Anahtarları doldurmadan açarsan → **önizleme** (veri kaydolmaz, sadece görsel test).
- Supabase anahtarlarını doldurursan → **canlı** (çok kullanıcılı, kalıcı veri).

---

## BÖLÜM 1 — Veritabanı (Supabase)

1. https://supabase.com → **Start your project** → GitHub/e-posta ile giriş.
2. **New project**. İsim: `aon`. Bir **database password** belirle (bir yere not et). Region: *Frankfurt (eu-central)* seç. **Create**. (~1 dk kurulur.)
3. Sol menü → **SQL Editor** → **New query**. `supabase.sql` dosyasının içeriğini yapıştır → **Run**. "Success" görmelisin (tablolar + örnek kayıtlar oluştu).
4. Sol menü → **Settings → API**. Şu iki değeri kopyala:
   - **Project URL** (örn. `https://abcd1234.supabase.co`)
   - **anon public** anahtar (uzun `eyJ...` string)

> Not: `anon` anahtarın tarayıcıda görünmesi **normal ve güvenlidir** — RLS politikaları sayesinde sadece okuma + ekleme yapılabilir, silme yapılamaz.

---

## BÖLÜM 2 — Anahtarları siteye yaz

`index.html`'i bir metin düzenleyiciyle aç. En üstteki script bloğunda 3 satırı düzenle:

```js
const SUPABASE_URL  = "https://abcd1234.supabase.co";   // Bölüm 1'deki Project URL
const SUPABASE_ANON = "eyJhbGciOi...";                  // Bölüm 1'deki anon public anahtar
const AI_ENABLED    = false;                             // şimdilik false kalsın
```

Kaydet. Dosyayı tarayıcıda açarsan footer'da yeşil **"● canlı veri"** rozetini görmelisin. Bir ilan/aday ekle → Supabase **Table editor**'da satırın düştüğünü gör.

---

## BÖLÜM 3 — Yayına al (Netlify)

**En kolay yol (hesapsız, fonksiyonsuz):**
1. https://app.netlify.com/drop adresine git.
2. Düzenlenmiş `index.html`'i pencereye sürükle-bırak.
3. Saniyeler içinde canlı bir URL alırsın (örn. `https://parlak-kedi-123.netlify.app`). Bitti — paylaş.

**Kalıcı/güncellenebilir yol (önerilen):**
1. Bu klasörü bir **GitHub** reposuna yükle.
2. Netlify → **Add new site → Import from Git** → repoyu seç → **Deploy**.
3. Her `git push`'ta site otomatik güncellenir. (Bölüm 4 için bu yol gerekir.)

Özel alan adı istersen: Netlify → **Domain settings → Add custom domain**.

---

## BÖLÜM 4 — AI eşleşme (OPSİYONEL, sonra)

Match Score zaten AI'sız çalışıyor. "AI ile değerlendir" butonunu açmak için:

1. https://console.anthropic.com → bir **API key** oluştur.
2. Siteyi GitHub+Netlify ile deploy etmiş ol (Bölüm 3, ikinci yol). `netlify.toml` ve `netlify/functions/match-ai.js` zaten klasörde.
3. Netlify → **Site settings → Environment variables** → ekle:
   `ANTHROPIC_API_KEY = sk-ant-...`
4. `index.html`'de `AI_ENABLED = true` yap, push'la.
5. Anahtar yalnızca sunucuda durur, tarayıcıya sızmaz.

---

## Moderasyon

Spam/yanlış kayıt silme → Supabase **Table editor** → satırı sil. (Sitede herkese açık silme bilerek kapalı.)

## Maliyet
Supabase free: 500 MB DB + 50.000 aylık aktif kullanıcı. Netlify free: 100 GB trafik/ay. Anthropic: kullandıkça öde (sadece Bölüm 4'ü açarsan).

## Sıradaki (P2+) — gerçek ürün için
Giriş/yetki (Supabase Auth, magic link), moderatör onay sırası, form→DB doğrulama, bildirimler, arama/filtre.

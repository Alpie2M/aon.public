// ============================================================
//  AON — iletişim isteği bildirim e-postası (OPSİYONEL)
//  Gerekli Netlify env değişkenleri:
//    SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY, FROM_EMAIL, SITE_URL
//  Yalnızca fetch kullanır (npm bağımlılığı yok).
// ============================================================
export async function handler(event) {
  if (event.httpMethod !== "POST") return { statusCode: 405, body: "POST gerekli" };
  try {
    const { toUserId, fromName } = JSON.parse(event.body || "{}");
    if (!toUserId) return { statusCode: 400, body: JSON.stringify({ error: "toUserId yok" }) };

    const SB = process.env.SUPABASE_URL;
    const SR = process.env.SUPABASE_SERVICE_ROLE_KEY;
    const h = { apikey: SR, Authorization: "Bearer " + SR, "content-type": "application/json" };

    // 1) Alıcının (gizli) giriş e-postasını servis anahtarıyla bul
    const ures = await fetch(`${SB}/auth/v1/admin/users/${toUserId}`, { headers: h });
    const user = await ures.json();
    const toEmail = user?.email;
    if (!toEmail) return { statusCode: 404, body: JSON.stringify({ error: "kullanıcı yok" }) };

    // 2) Alıcıya özel tek-tık giriş linki üret (tıklayınca giriş + siteye düşer)
    const lres = await fetch(`${SB}/auth/v1/admin/generate_link`, {
      method: "POST", headers: h,
      body: JSON.stringify({ type: "magiclink", email: toEmail, redirect_to: process.env.SITE_URL }),
    });
    const link = (await lres.json());
    const action = link?.action_link || link?.properties?.action_link || process.env.SITE_URL;

    // 3) Resend ile bildirimi yolla (alıcının e-postası tarayıcıya hiç dönmez)
    const html = `
      <div style="font-family:sans-serif;max-width:480px;margin:auto">
        <h2 style="color:#15213B">Yeni iletişim isteği</h2>
        <p><b>${(fromName||"Bir üye")}</b> seninle AON üzerinden iletişime geçmek istiyor.</p>
        <p>Onaylarsan iletişim bilgileriniz karşılıklı açılır.</p>
        <p style="margin:24px 0">
          <a href="${action}" style="background:#EE9F2E;color:#3a2700;padding:12px 22px;border-radius:10px;text-decoration:none;font-weight:700">
            Girip İstekleri Gör
          </a>
        </p>
        <p style="color:#7A879C;font-size:12px">Bu bağlantı seni otomatik olarak giriş yapmış halde siteye götürür.</p>
      </div>`;
    const send = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: "Bearer " + process.env.RESEND_API_KEY, "content-type": "application/json" },
      body: JSON.stringify({ from: process.env.FROM_EMAIL, to: [toEmail], subject: "AON — yeni iletişim isteği", html }),
    });
    if (!send.ok) return { statusCode: 502, body: JSON.stringify({ error: await send.text() }) };
    return { statusCode: 200, body: JSON.stringify({ ok: true }) };
  } catch (e) {
    return { statusCode: 500, body: JSON.stringify({ error: String(e) }) };
  }
}

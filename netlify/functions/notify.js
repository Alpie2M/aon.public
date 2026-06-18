export async function handler(event) {
  if (event.httpMethod !== "POST") return { statusCode: 405, body: "POST gerekli" };
  try {
    const { toUserId, fromUserId, fromName, context } = JSON.parse(event.body || "{}");
    if (!toUserId) return { statusCode: 400, body: JSON.stringify({ error: "toUserId yok" }) };
    if (!fromUserId) return { statusCode: 400, body: JSON.stringify({ error: "fromUserId yok" }) };

    const SB = process.env.SUPABASE_URL;
    const SR = process.env.SUPABASE_SERVICE_ROLE_KEY;
    const h = { apikey: SR, Authorization: "Bearer " + SR, "content-type": "application/json" };

    const q = async (path) => {
      const res = await fetch(`${SB}/rest/v1/${path}`, { headers: h });
      if (!res.ok) throw new Error(`Supabase sorgu hatasi: ${path}`);
      return res.json();
    };

    const ures = await fetch(`${SB}/auth/v1/admin/users/${toUserId}`, { headers: h });
    const user = await ures.json();
    const toEmail = user?.email;
    if (!toEmail) return { statusCode: 404, body: JSON.stringify({ error: "kullanıcı yok" }) };

    const [candContacts, empContacts, candProfile, empProfile] = await Promise.all([
      q(`candidate_contacts?user_id=eq.${fromUserId}&select=phone,email&limit=1`),
      q(`employer_contacts?user_id=eq.${fromUserId}&select=phone,email&limit=1`),
      q(`candidate_profiles?user_id=eq.${fromUserId}&select=first_name,last_name&limit=1`),
      q(`employer_profiles?user_id=eq.${fromUserId}&select=first_name,last_name,company_name,title&limit=1`)
    ]);

    const senderName =
      fromName ||
      [candProfile?.[0]?.first_name, candProfile?.[0]?.last_name].filter(Boolean).join(" ") ||
      [empProfile?.[0]?.first_name, empProfile?.[0]?.last_name].filter(Boolean).join(" ") ||
      "Bir uye";

    const emailSet = new Set(
      [candContacts?.[0]?.email, empContacts?.[0]?.email].filter(Boolean).map((x) => String(x).trim())
    );
    const phoneSet = new Set(
      [candContacts?.[0]?.phone, empContacts?.[0]?.phone].filter(Boolean).map((x) => String(x).trim())
    );

    const emails = [...emailSet];
    const phones = [...phoneSet];
    const senderRoleLine = empProfile?.[0]?.company_name
      ? `${empProfile[0].company_name}${empProfile[0].title ? ` - ${empProfile[0].title}` : ""}`
      : (context === "aday" ? "Aday profili" : "Topluluk uyesi");
    const subject = context === "aday"
      ? "AON — yetenek havuzun için yeni iletişim"
      : "AON — yeni iletişim isteği";
    const introHtml = context === "aday"
      ? `<p><b>${senderName}</b> yetenek havuzundaki profilin hakkında daha fazla bilgi almak istiyor.</p>
         <p>Aşağıda paylaştığı iletişim bilgilerini bulabilirsin.</p>`
      : `<p><b>${senderName}</b> seninle AON üzerinden iletişime geçmek istiyor.</p>
         <p style="margin:0 0 12px;color:#52607a">${senderRoleLine}</p>`;

    const lres = await fetch(`${SB}/auth/v1/admin/generate_link`, {
      method: "POST", headers: h,
      body: JSON.stringify({ type: "magiclink", email: toEmail, redirect_to: process.env.SITE_URL }),
    });
    const link = (await lres.json());
    const action = link?.action_link || link?.properties?.action_link || process.env.SITE_URL;

    const html = `
      <div style="font-family:sans-serif;max-width:480px;margin:auto">
        <h2 style="color:#15213B">Yeni iletişim isteği</h2>
        ${introHtml}
        ${context === "aday" ? `<p style="margin:0 0 12px;color:#52607a">${senderRoleLine}</p>` : ""}
        <div style="background:#f6f8fb;border:1px solid #e6ebf2;border-radius:12px;padding:14px 16px;margin:16px 0">
          <div style="font-weight:700;margin-bottom:8px">İletişim bilgileri</div>
          <div>E-posta: ${emails.length ? emails.join(", ") : "Paylaşılmadı"}</div>
          <div>Telefon: ${phones.length ? phones.join(", ") : "Paylaşılmadı"}</div>
        </div>
        <p>İstersen sisteme girip istekleri de görüntüleyebilirsin.</p>
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
      body: JSON.stringify({ from: `IMT Kariyer <${process.env.FROM_EMAIL}>`, to: [toEmail], subject, html }),    });
    if (!send.ok) return { statusCode: 502, body: JSON.stringify({ error: await send.text() }) };
    return { statusCode: 200, body: JSON.stringify({ ok: true }) };
  } catch (e) {
    return { statusCode: 500, body: JSON.stringify({ error: String(e) }) };
  }
}

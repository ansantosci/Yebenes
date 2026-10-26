import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@10.1.7";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};


function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}


function escapeHtml(value: unknown) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function bodyToHtml(text: string) {
  return escapeHtml(text)
    .split(/\n{2,}/)
    .map((paragraph) => `<p style="margin:0 0 14px;line-height:1.6;">${paragraph.replaceAll("\n", "<br>")}</p>`)
    .join("");
}

function brandedEmailHtml(
  theme: any,
  seasonName: string,
  subject: string,
  body: string,
) {
  const clubName = theme?.nombre_club || "C.D. Los Yebenes San Bruno";
  const logoUrl = theme?.logo_url || "https://losyebenessanbruno.es/wp-content/uploads/2023/03/cvncvn.png";
  const primary = theme?.color_primario || "#c51230";
  const primaryDark = theme?.color_primario_oscuro || "#8f0c22";
  const accent = theme?.color_acento || "#f4c542";
  const background = theme?.color_fondo || "#f5f6f8";
  const card = theme?.color_tarjeta || "#ffffff";
  const ink = theme?.color_texto || "#20232a";

  return `<!doctype html>
<html lang="es">
  <body style="margin:0;padding:0;background:${background};font-family:Arial,Helvetica,sans-serif;color:${ink};">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:${background};padding:28px 12px;">
      <tr><td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:640px;background:${card};border-radius:20px;overflow:hidden;box-shadow:0 12px 30px rgba(0,0,0,.10);">
          <tr>
            <td style="background:${primary};padding:20px 24px;border-bottom:5px solid ${accent};">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                <tr>
                  <td width="72" valign="middle"><img src="${escapeHtml(logoUrl)}" width="58" height="58" alt="Escudo ${escapeHtml(clubName)}" style="display:block;object-fit:contain;border:0;"></td>
                  <td valign="middle" style="color:#ffffff;">
                    <div style="font-size:20px;font-weight:800;line-height:1.2;">${escapeHtml(clubName)}</div>
                    <div style="font-size:13px;opacity:.88;margin-top:4px;">Temporada ${escapeHtml(seasonName || "")}</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr><td style="padding:28px 28px 8px;">
            <div style="font-size:11px;letter-spacing:.12em;text-transform:uppercase;font-weight:800;color:${primary};margin-bottom:8px;">Comunicación del club</div>
            <h1 style="font-size:24px;line-height:1.25;margin:0 0 20px;color:${ink};">${escapeHtml(subject)}</h1>
            <div style="font-size:15px;line-height:1.6;color:${ink};">${bodyToHtml(body)}</div>
          </td></tr>
          <tr><td style="padding:10px 28px 28px;">
            <div style="border-radius:12px;background:${background};padding:14px 16px;font-size:12px;line-height:1.5;color:#6b7280;">
              Este mensaje se ha generado desde la plataforma de gestión del ${escapeHtml(clubName)}.
            </div>
          </td></tr>
          <tr><td style="height:8px;background:${primaryDark};font-size:0;line-height:0;">&nbsp;</td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
      (() => {
        try {
          return JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}").default;
        } catch {
          return undefined;
        }
      })();
    const mailTransport = (Deno.env.get("MAIL_TRANSPORT") || "smtp").toLowerCase();
    const mailHost = Deno.env.get("MAIL_HOST");
    const mailPort = Number(Deno.env.get("MAIL_PORT") || "587");
    const mailUsername = Deno.env.get("MAIL_USERNAME");
    const mailPassword = Deno.env.get("MAIL_PASSWORD");
    const mailScheme = (Deno.env.get("MAIL_SCHEME") || "smtp").toLowerCase();
    const mailRequireTls =
      (Deno.env.get("MAIL_REQUIRE_TLS") || "true").toLowerCase() !== "false";
    const mailEnvironment =
      (Deno.env.get("MAIL_ENVIRONMENT") || "UNKNOWN").trim().toUpperCase();
    const mailFrom = Deno.env.get("MAIL_FROM") || "no-reply@yebenes.test";
    const mailFromName =
      Deno.env.get("MAIL_FROM_NAME") || "C.D. Los Yebenes San Bruno";
    const cronSecret = Deno.env.get("CRON_SECRET");

    const missingMailConfig = [
      ["MAIL_HOST", mailHost],
      ["MAIL_USERNAME", mailUsername],
      ["MAIL_PASSWORD", mailPassword],
    ].filter(([, value]) => !value).map(([name]) => name);

    if (!supabaseUrl || !serviceRoleKey) {
      console.error("[procesar-notificaciones] Configuracion Supabase incompleta", {
        environment: mailEnvironment,
        has_supabase_url: !!supabaseUrl,
        has_service_role_key: !!serviceRoleKey,
      });
      return json({ error: "Faltan variables de entorno de Supabase" }, 500);
    }

    if (
      mailTransport !== "smtp" ||
      !Number.isFinite(mailPort) ||
      mailPort <= 0 ||
      missingMailConfig.length
    ) {
      console.error("[procesar-notificaciones] Configuracion SMTP invalida", {
        environment: mailEnvironment,
        transport: mailTransport,
        host_configured: !!mailHost,
        port: mailPort,
        username_configured: !!mailUsername,
        password_configured: !!mailPassword,
        missing: missingMailConfig,
      });
      return json(
        {
          error: "Configuracion SMTP incompleta o no soportada",
          missing: missingMailConfig,
        },
        500,
      );
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const smtpSecure = mailScheme === "smtps" || mailPort === 465;
    const transporter = nodemailer.createTransport({
      host: mailHost!,
      port: mailPort,
      secure: smtpSecure,
      requireTLS: !smtpSecure && mailRequireTls,
      auth: {
        user: mailUsername!,
        pass: mailPassword!,
      },
      connectionTimeout: 10000,
      greetingTimeout: 10000,
      socketTimeout: 20000,
      disableFileAccess: true,
      disableUrlAccess: true,
    });


    const { data: visualTheme } = await admin
      .from("configuracion_visual_club")
      .select(
        "nombre_club,logo_url,color_primario,color_primario_oscuro,color_acento,color_fondo,color_tarjeta,color_texto",
      )
      .eq("id", 1)
      .maybeSingle();

    const { data: activeSeason } = await admin
      .from("temporadas")
      .select("nombre")
      .eq("estado", "activa")
      .order("fecha_inicio", { ascending: false })
      .limit(1)
      .maybeSingle();

    const internalRequest =
      !!cronSecret && req.headers.get("x-cron-secret") === cronSecret;

    if (!internalRequest) {
      const authHeader = req.headers.get("Authorization") || "";
      const jwt = authHeader.startsWith("Bearer ")
        ? authHeader.slice(7)
        : "";

      if (!jwt) {
        return json({ error: "No autenticado" }, 401);
      }

      const { data: userData, error: userError } =
        await admin.auth.getUser(jwt);

      if (userError || !userData.user) {
        return json({ error: "Sesion no valida" }, 401);
      }

      const { data: persona, error: personaError } = await admin
        .from("personas")
        .select("id")
        .eq("auth_user_id", userData.user.id)
        .eq("activo", true)
        .maybeSingle();

      if (personaError || !persona) {
        return json({ error: "Persona no vinculada" }, 403);
      }

      const { data: roleRows, error: roleError } = await admin
        .from("persona_roles")
        .select(
          "activo,fecha_desde,fecha_hasta,roles!inner(codigo)",
        )
        .eq("persona_id", persona.id)
        .eq("activo", true);

      if (roleError) {
        throw roleError;
      }

      const today = new Date().toISOString().slice(0, 10);

      const allowed = (roleRows || []).some((role: any) => {
        const code = role.roles?.codigo;
        const inDate =
          (!role.fecha_desde || role.fecha_desde <= today) &&
          (!role.fecha_hasta || role.fecha_hasta >= today);

        return (
          inDate &&
          (code === "administrador" || code === "club")
        );
      });

      if (!allowed) {
        return json({ error: "No autorizado" }, 403);
      }
    }

    let body: any = {};

    try {
      body = await req.json();
    } catch {
      // El body es opcional.
    }

    const limit = Math.min(
      Math.max(Number(body?.limit || 20), 1),
      50,
    );
    const nowIso = new Date().toISOString();

    const { data: pending, error: pendingError } = await admin
      .from("notificaciones_salida")
      .select(
        [
          "id",
          "cita_id",
          "destinatario_email",
          "asunto",
          "cuerpo",
          "intentos",
          "created_at",
        ].join(","),
      )
      .eq("estado", "pendiente")
      .not("destinatario_email", "is", null)
      .lte("disponible_desde", nowIso)
      .order("created_at", { ascending: true })
      .limit(limit);

    if (pendingError) {
      throw pendingError;
    }

    let sent = 0;
    let failed = 0;
    let deferred = 0;
    const touchedCitas = new Set<string>();

    for (const notification of pending || []) {
      if (notification.cita_id) {
        touchedCitas.add(notification.cita_id);
      }

      try {
        const baseSubject =
          notification.asunto ||
          visualTheme?.nombre_club ||
          "C.D. Los Yebenes San Bruno";
        const subjectPrefix =
          mailEnvironment && mailEnvironment !== "PROD"
            ? `[${mailEnvironment}] `
            : "";
        const outboundSubject = `${subjectPrefix}${baseSubject}`;
        const outboundBody =
          notification.cuerpo || "Tienes una nueva notificacion.";

        const sendStartedAt = performance.now();
        const info = await transporter.sendMail({
          from: {
            address: mailFrom,
            name:
              mailFromName ||
              visualTheme?.nombre_club ||
              "C.D. Los Yebenes San Bruno",
          },
          to: notification.destinatario_email,
          subject: outboundSubject,
          text: outboundBody,
          html: brandedEmailHtml(
            visualTheme,
            activeSeason?.nombre || "",
            outboundSubject,
            outboundBody,
          ),
        });

        console.info("[procesar-notificaciones] SMTP enviado", {
          environment: mailEnvironment,
          notification_id: notification.id,
          cita_id: notification.cita_id || null,
          message_id: info.messageId || null,
          elapsed_ms: Math.round(performance.now() - sendStartedAt),
        });

        const { error: updateError } = await admin
          .from("notificaciones_salida")
          .update({
            estado: "enviado",
            enviado_at: new Date().toISOString(),
            ultimo_error: null,
            disponible_desde: new Date().toISOString(),
            intentos: Number(notification.intentos || 0) + 1,
          })
          .eq("id", notification.id);

        if (updateError) {
          throw updateError;
        }

        sent++;
      } catch (error) {
        failed++;

        const errorMessage = String((error as Error)?.message || error);
        console.error("[procesar-notificaciones] Error SMTP", {
          environment: mailEnvironment,
          notification_id: notification.id,
          cita_id: notification.cita_id || null,
          error: errorMessage,
        });

        await admin
          .from("notificaciones_salida")
          .update({
            estado: "error",
            ultimo_error: errorMessage.slice(0, 1500),
            intentos: Number(notification.intentos || 0) + 1,
          })
          .eq("id", notification.id);
      }
    }

    for (const citaId of touchedCitas) {
      const { data: states } = await admin
        .from("notificaciones_salida")
        .select("estado")
        .eq("cita_id", citaId);

      const relevant = (states || []).filter(
        (row: any) => row.estado !== "cancelado",
      );

      if (
        relevant.length &&
        relevant.every((row: any) => row.estado === "enviado")
      ) {
        await admin
          .from("citas_reconocimiento_medico")
          .update({
            comunicada_at: new Date().toISOString(),
          })
          .eq("id", citaId);
      }
    }

    return json({
      ok: failed === 0,
      processed: (pending || []).length,
      sent,
      deferred,
      failed,
      internal: internalRequest,
      environment: mailEnvironment,
      transport: mailTransport,
    });
  } catch (error) {
    const errorMessage = String((error as Error)?.message || error);
    console.error("[procesar-notificaciones] Error no controlado", {
      error: errorMessage,
    });
    return json(
      {
        error: errorMessage,
      },
      500,
    );
  }
});

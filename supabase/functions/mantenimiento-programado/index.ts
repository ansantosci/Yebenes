import { createClient } from "npm:@supabase/supabase-js@2";

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get(
      "SUPABASE_SERVICE_ROLE_KEY",
    );
    const cronSecret = Deno.env.get("CRON_SECRET");

    if (!supabaseUrl || !serviceRoleKey || !cronSecret) {
      return json(
        {
          error: "Faltan variables de entorno",
        },
        500,
      );
    }

    if (req.headers.get("x-cron-secret") !== cronSecret) {
      return json(
        {
          error: "No autorizado",
        },
        401,
      );
    }

    const admin = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      },
    );

    // 1. Genera avisos previos de mayoría de edad.
    const preparationResult = await admin.rpc(
      "procesar_preparacion_mayoria_edad",
    );

    // 2. Ejecuta las transiciones de jugadores que ya
    //    han alcanzado la mayoría de edad.
    const adultResult = await admin.rpc(
      "procesar_mayorias_edad",
    );

    // 3. Vacía la cola de notificaciones sin depender
    //    del login o navegación de un usuario.
    const mailResponse = await fetch(
      `${supabaseUrl}/functions/v1/procesar-notificaciones`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-cron-secret": cronSecret,
        },
        body: JSON.stringify({
          limit: 50,
        }),
      },
    );

    const mailBody = await mailResponse
      .json()
      .catch(() => ({}));

    const errors = [
      preparationResult.error?.message,
      adultResult.error?.message,
    ].filter(Boolean);

    return json({
      ok:
        !preparationResult.error &&
        !adultResult.error &&
        mailResponse.ok,
      preparacion: preparationResult.data,
      mayorias: adultResult.data,
      correo: mailBody,
      errors,
    });
  } catch (error) {
    return json(
      {
        error: String((error as Error)?.message || error),
      },
      500,
    );
  }
});

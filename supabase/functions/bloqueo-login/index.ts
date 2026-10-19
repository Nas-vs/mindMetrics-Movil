import { createClient } from "npm:@supabase/supabase-js@2";

const cabeceras = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function responder(estado: number, cuerpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(cuerpo), { status: estado, headers: cabeceras });
}

// Estas variables las pone Supabase automáticamente (local y en la nube).
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const sinSesionGuardada = { auth: { persistSession: false, autoRefreshToken: false } };

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cabeceras });
  if (req.method !== "POST") return responder(405, { error: "metodo_no_permitido" });

  // ---------- Leer y validar la petición ----------
  let datos: { correo?: unknown; contrasena?: unknown; dispositivo_id?: unknown };
  try {
    datos = await req.json();
  } catch {
    return responder(400, { error: "peticion_invalida" });
  }

  const correo = String(datos.correo ?? "").trim().toLowerCase();
  const contrasena = String(datos.contrasena ?? "");
  const dispositivoId = String(datos.dispositivo_id ?? "");

  if (!correo || !contrasena || dispositivoId.length < 8) {
    return responder(400, { error: "peticion_invalida" });
  }

  // admin: llama a las funciones protegidas de la base (salta RLS).
  // publico: hace el login igual que lo haría la app.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, sinSesionGuardada);
  const publico = createClient(SUPABASE_URL, ANON_KEY, sinSesionGuardada);

  try {
    // ---------- 1. ¿Está bloqueado? (RF-04 CA-7) ----------
    const { data: bloqueadoHasta, error: errorBloqueo } = await admin.rpc(
      "estado_bloqueo",
      { p_correo: correo },
    );
    if (errorBloqueo) throw errorBloqueo;
    if (bloqueadoHasta) {
      return responder(423, { error: "bloqueado", bloqueado_hasta: bloqueadoHasta });
    }

    // ---------- 2. Verificar correo y contraseña ----------
    const { data: login, error: errorLogin } = await publico.auth.signInWithPassword({
      email: correo,
      password: contrasena,
    });

    if (errorLogin) {
      // La cuenta existe pero nunca verificó el correo (RF-05 CA-1)
      if (errorLogin.code === "email_not_confirmed") {
        return responder(403, { error: "correo_no_verificado" });
      }

      if (errorLogin.code === "invalid_credentials") {
        // ---------- 3. Sumar intento fallido (RF-04 CA-6 / CA-7) ----------
        // Se cuenta igual exista o no el correo, para no revelar cuáles
        // correos están registrados.
        const { data: resultado, error: errorIntento } = await admin.rpc(
          "registrar_intento_fallido",
          { p_correo: correo },
        );
        if (errorIntento) throw errorIntento;

        if (resultado.bloqueado_hasta) {
          return responder(423, {
            error: "bloqueado",
            bloqueado_hasta: resultado.bloqueado_hasta,
          });
        }
        return responder(401, {
          error: "credenciales_invalidas",
          intentos_restantes: resultado.intentos_restantes,
        });
      }

      throw errorLogin;
    }

    // Login correcto: se olvidan los fallos anteriores
    const { error: errorLimpiar } = await admin.rpc("limpiar_intentos", { p_correo: correo });
    if (errorLimpiar) throw errorLimpiar;

    // ---------- 4. ¿Celular conocido? (RF-04 CA-4) ----------
    const { data: esConocido, error: errorDispositivo } = await admin.rpc(
      "dispositivo_es_confiable",
      { p_usuario_id: login.user.id, p_dispositivo_id: dispositivoId },
    );
    if (errorDispositivo) throw errorDispositivo;

    if (esConocido) {
      return responder(200, {
        requiere_2fa: false,
        sesion: {
          access_token: login.session.access_token,
          refresh_token: login.session.refresh_token,
          expires_at: login.session.expires_at,
        },
      });
    }

    // ---------- 5. Celular nuevo: pedir código (RF-04 CA-5, RF-05) ----------
    // Se cierra la sesión recién creada (solo esta, no las de otros
    // celulares) y se envía un código de 6 dígitos al correo.
    await publico.auth.signOut({ scope: "local" });

    const { error: errorCodigo } = await publico.auth.signInWithOtp({
      email: correo,
      options: { shouldCreateUser: false },
    });
    if (errorCodigo) {
      if (errorCodigo.status === 429) {
        return responder(429, { error: "demasiados_correos" });
      }
      throw errorCodigo;
    }

    return responder(200, { requiere_2fa: true });
  } catch (error) {
    console.error("bloqueo-login:", error);
    return responder(500, { error: "servidor" });
  }
});

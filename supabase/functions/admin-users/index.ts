// ============================================================
// Módulo 1: Usuarios y accesos
// Edge Function "admin-users"
//
// Realiza operaciones privilegiadas sobre los usuarios usando la
// clave de servicio (service_role). Esa clave NUNCA vive en la app.
//
// Solo un administrador activo puede invocarla. Se valida el JWT del
// invocador y se comprueba su perfil antes de ejecutar cualquier acción.
//
// Acciones (campo "action" del cuerpo JSON):
//   create          -> { email, nombre, telefono, rol, metodo, password?, redirectTo? }
//   update          -> { id, nombre, telefono, rol, email? }
//   set-active      -> { id, activo }
//   reset-password  -> { id, password }
// ============================================================

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ROLES = ["admin", "chofer"] as const;
type Rol = (typeof ROLES)[number];

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PASSWORD_RE = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;
const BAN_FOREVER = "876000h"; // ~100 años

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function fail(message: string, status = 400): Response {
  return json({ ok: false, error: message }, status);
}

function cleanText(value: unknown): string | undefined {
  if (value === undefined || value === null) return undefined;
  const text = String(value).trim();
  return text.length === 0 ? undefined : text;
}

function isRol(value: unknown): value is Rol {
  return typeof value === "string" && (ROLES as readonly string[]).includes(value);
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return fail("Método no permitido.", 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !serviceKey || !anonKey) {
    return fail("Configuración del servidor incompleta.", 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return fail("No autenticado.", 401);
  }

  // Cliente con el JWT del invocador para identificar quién llama.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await callerClient.auth.getUser(token);
  if (userError || !userData?.user) {
    return fail("Sesión inválida.", 401);
  }

  const admin: SupabaseClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Verificar que el invocador sea administrador activo.
  const { data: callerProfile, error: profileError } = await admin
    .from("profiles")
    .select("id, rol, activo")
    .eq("id", userData.user.id)
    .maybeSingle();

  if (profileError) {
    return fail("No se pudo verificar el perfil del invocador.", 500);
  }
  if (!callerProfile || callerProfile.rol !== "admin" || !callerProfile.activo) {
    return fail("Se requiere un administrador activo.", 403);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return fail("Cuerpo JSON inválido.");
  }

  const action = String(payload.action ?? "");

  try {
    switch (action) {
      case "create":
        return await createUser(admin, payload);
      case "update":
        return await updateUser(admin, payload);
      case "set-active":
        return await setActive(admin, payload);
      case "reset-password":
        return await resetPassword(admin, payload);
      default:
        return fail(`Acción desconocida: "${action}".`);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Error inesperado.";
    return fail(message, 500);
  }
});

// ------------------------------------------------------------
// Crear usuario (invitación por correo o contraseña temporal).
// ------------------------------------------------------------
async function createUser(
  admin: SupabaseClient,
  payload: Record<string, unknown>,
): Promise<Response> {
  const email = cleanText(payload.email)?.toLowerCase();
  const nombre = cleanText(payload.nombre) ?? "";
  const telefono = cleanText(payload.telefono) ?? null;
  const rol = payload.rol;
  const metodo = payload.metodo === "password" ? "password" : "invite";
  const redirectTo = cleanText(payload.redirectTo);

  if (!email || !EMAIL_RE.test(email)) {
    return fail("Correo electrónico inválido.");
  }
  if (!isRol(rol)) {
    return fail("Rol inválido.");
  }

  const userMetadata = { nombre, telefono: telefono ?? "" };

  let uid: string;

  if (metodo === "password") {
    const password = cleanText(payload.password);
    if (!password || !PASSWORD_RE.test(password)) {
      return fail(
        "La contraseña debe tener al menos 8 caracteres, con mayúscula, minúscula y número.",
      );
    }
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      app_metadata: { rol },
      user_metadata: userMetadata,
    });
    if (error) return fail(traducirErrorAuth(error.message));
    uid = data.user!.id;
  } else {
    const options: Record<string, unknown> = { data: userMetadata };
    if (redirectTo) options.redirectTo = redirectTo;
    const { data, error } = await admin.auth.admin.inviteUserByEmail(email, options);
    if (error) return fail(traducirErrorAuth(error.message));
    uid = data.user!.id;
    // El rol debe quedar en app_metadata (no editable por el usuario).
    await admin.auth.admin.updateUserById(uid, { app_metadata: { rol } });
  }

  // El trigger de Auth ya creó el perfil; se asegura rol y datos.
  const { error: upsertError } = await admin
    .from("profiles")
    .upsert({ id: uid, email, nombre, telefono, rol, activo: true });

  if (upsertError) {
    return fail("El usuario se creó pero no se pudo guardar el perfil: " + upsertError.message, 500);
  }

  return json({ ok: true, id: uid });
}

// ------------------------------------------------------------
// Editar nombre, teléfono, rol y (opcionalmente) correo.
// ------------------------------------------------------------
async function updateUser(
  admin: SupabaseClient,
  payload: Record<string, unknown>,
): Promise<Response> {
  const id = cleanText(payload.id);
  if (!id) return fail("Falta el identificador del usuario.");

  const nombre = cleanText(payload.nombre);
  const telefono = payload.telefono === null ? null : cleanText(payload.telefono) ?? null;
  const rol = payload.rol;
  const email = cleanText(payload.email)?.toLowerCase();

  if (!isRol(rol)) return fail("Rol inválido.");
  if (email && !EMAIL_RE.test(email)) return fail("Correo electrónico inválido.");

  const { data: current, error: getError } = await admin.auth.admin.getUserById(id);
  if (getError || !current?.user) return fail("Usuario no encontrado.", 404);

  // Correo único (considerando al propio usuario).
  if (email && email !== current.user.email) {
    const { data: duplicado } = await admin
      .from("profiles")
      .select("id")
      .ilike("email", email)
      .neq("id", id)
      .maybeSingle();
    if (duplicado) return fail("Ese correo ya está registrado por otro usuario.", 409);

    const { error: authError } = await admin.auth.admin.updateUserById(id, {
      email,
      email_confirm: true,
    });
    if (authError) return fail(traducirErrorAuth(authError.message));
  }

  // Actualizar app_metadata.rol conservando el resto.
  const appMetadata = { ...(current.user.app_metadata ?? {}), rol };
  const { error: metaError } = await admin.auth.admin.updateUserById(id, {
    app_metadata: appMetadata,
  });
  if (metaError) return fail(traducirErrorAuth(metaError.message));

  const updates: Record<string, unknown> = {
    nombre: nombre ?? "",
    telefono,
    rol,
  };
  if (email) updates.email = email;

  const { error: updateError } = await admin
    .from("profiles")
    .update(updates)
    .eq("id", id);

  if (updateError) return fail(updateError.message, 500);

  return json({ ok: true, id });
}

// ------------------------------------------------------------
// Desactivar / reactivar (baja lógica + bloqueo de acceso).
// ------------------------------------------------------------
async function setActive(
  admin: SupabaseClient,
  payload: Record<string, unknown>,
): Promise<Response> {
  const id = cleanText(payload.id);
  const activo = payload.activo;
  if (!id) return fail("Falta el identificador del usuario.");
  if (typeof activo !== "boolean") return fail("El campo 'activo' debe ser booleano.");

  const { error: profileError } = await admin
    .from("profiles")
    .update({ activo })
    .eq("id", id);
  if (profileError) return fail(profileError.message, 500);

  const { error: authError } = await admin.auth.admin.updateUserById(id, {
    ban_duration: activo ? "none" : BAN_FOREVER,
  });
  if (authError) return fail(traducirErrorAuth(authError.message), 500);

  return json({ ok: true, id, activo });
}

// ------------------------------------------------------------
// Restablecer contraseña (el admin define una contraseña temporal).
// ------------------------------------------------------------
async function resetPassword(
  admin: SupabaseClient,
  payload: Record<string, unknown>,
): Promise<Response> {
  const id = cleanText(payload.id);
  const password = cleanText(payload.password);
  if (!id) return fail("Falta el identificador del usuario.");
  if (!password || !PASSWORD_RE.test(password)) {
    return fail(
      "La contraseña debe tener al menos 8 caracteres, con mayúscula, minúscula y número.",
    );
  }

  const { error } = await admin.auth.admin.updateUserById(id, { password });
  if (error) return fail(traducirErrorAuth(error.message));

  return json({ ok: true, id });
}

function traducirErrorAuth(message: string): string {
  const lower = message.toLowerCase();
  if (lower.includes("already been registered") || lower.includes("already registered")) {
    return "Ese correo ya está registrado.";
  }
  if (lower.includes("invalid email")) {
    return "Correo electrónico inválido.";
  }
  if (lower.includes("password")) {
    return "La contraseña no cumple la política mínima de seguridad.";
  }
  return message;
}

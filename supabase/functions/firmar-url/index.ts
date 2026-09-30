// ============================================================
// Módulo 3: Almacenamiento y modo offline
// Edge Function "firmar-url"
//
// Emite URLs firmadas de corta vida para archivos en los buckets
// privados (manifiestos, firmas, extras) y permite operaciones
// privilegiadas (subir/eliminar) usando la clave de servicio, que
// NUNCA vive en la app.
//
// Acceso:
//   * Un administrador activo puede operar sobre cualquier archivo.
//   * Un chofer activo solo sobre archivos dentro de su carpeta
//     ({uid}/...).
//
// Acciones (campo "action" del cuerpo JSON):
//   sign        -> { bucket, path, expiresIn? }        -> { ok, url }
//   upload      -> { bucket, path, tipo?, base64 }     -> { ok, path, id }
//   remove      -> { bucket, path }                    -> { ok }
// ============================================================

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const BUCKETS = ["manifiestos", "firmas", "extras"] as const;
const TIPOS = ["bol", "firma", "recibo", "extra", "otro"] as const;
type Tipo = (typeof TIPOS)[number];

const SIGNED_URL_TTL = 60; // segundos
const MAX_TTL = 300;

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

function isBucket(value: unknown): value is (typeof BUCKETS)[number] {
  return typeof value === "string" && (BUCKETS as readonly string[]).includes(value);
}

function isTipo(value: unknown): value is Tipo {
  return typeof value === "string" && (TIPOS as readonly string[]).includes(value);
}

// Normaliza y valida el path: sin "..", sin absolutos, sin barras dobles.
function limpiarPath(value: unknown): string | undefined {
  const raw = cleanText(value);
  if (!raw) return undefined;
  const path = raw.replace(/\\/g, "/").replace(/^\/+/, "");
  if (path.split("/").some((p) => p === ".." || p === ".")) return undefined;
  if (path.length === 0 || path.length > 512) return undefined;
  return path;
}

// ¿El path vive dentro de la carpeta del usuario?
function esDeUsuario(path: string, uid: string): boolean {
  return path.split("/")[0] === uid;
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

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await callerClient.auth.getUser(token);
  if (userError || !userData?.user) {
    return fail("Sesión inválida.", 401);
  }

  const uid = userData.user.id;

  const admin: SupabaseClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Perfil del invocador: debe existir y estar activo.
  const { data: perfil, error: perfilError } = await admin
    .from("profiles")
    .select("id, rol, activo")
    .eq("id", uid)
    .maybeSingle();

  if (perfilError) {
    return fail("No se pudo verificar el perfil del invocador.", 500);
  }
  if (!perfil || !perfil.activo) {
    return fail("Se requiere un usuario activo.", 403);
  }

  const esAdmin = perfil.rol === "admin";

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return fail("Cuerpo JSON inválido.");
  }

  const action = String(payload.action ?? "");
  const bucket = payload.bucket;
  const path = limpiarPath(payload.path);

  if (!isBucket(bucket)) {
    return fail("Bucket inválido.");
  }
  if (!path) {
    return fail("Ruta de archivo inválida.");
  }
  // Autorización por carpeta: el chofer solo su carpeta; el admin todo.
  if (!esAdmin && !esDeUsuario(path, uid)) {
    return fail("No tienes permiso sobre ese archivo.", 403);
  }

  try {
    switch (action) {
      case "sign":
        return await signFile(admin, bucket, path, payload.expiresIn);
      case "upload":
        return await uploadFile(admin, bucket, path, uid, payload);
      case "remove":
        return await removeFile(admin, bucket, path);
      default:
        return fail(`Acción desconocida: "${action}".`);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Error inesperado.";
    return fail(message, 500);
  }
});

// ------------------------------------------------------------
// URL firmada de corta vida.
// ------------------------------------------------------------
async function signFile(
  admin: SupabaseClient,
  bucket: string,
  path: string,
  expiresIn: unknown,
): Promise<Response> {
  let ttl = SIGNED_URL_TTL;
  if (typeof expiresIn === "number" && Number.isFinite(expiresIn)) {
    ttl = Math.min(Math.max(Math.trunc(expiresIn), 10), MAX_TTL);
  }

  const { data, error } = await admin.storage.from(bucket).createSignedUrl(path, ttl);
  if (error || !data?.signedUrl) {
    return fail("No se pudo firmar la URL: " + (error?.message ?? "desconocido"), 500);
  }

  return json({ ok: true, url: data.signedUrl, expiresIn: ttl });
}

// ------------------------------------------------------------
// Subida privilegiada (base64) + registro en public.evidencias.
// ------------------------------------------------------------
async function uploadFile(
  admin: SupabaseClient,
  bucket: string,
  path: string,
  uid: string,
  payload: Record<string, unknown>,
): Promise<Response> {
  const base64 = cleanText(payload.base64);
  if (!base64) {
    return fail("Falta el contenido del archivo (base64).");
  }

  const tipo: Tipo = isTipo(payload.tipo) ? payload.tipo : "otro";

  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
  } catch {
    return fail("El contenido no es un base64 válido.");
  }

  const contentType = cleanText(payload.contentType) ?? "application/octet-stream";

  const { error: upError } = await admin.storage.from(bucket).upload(path, bytes, {
    contentType,
    upsert: true,
  });
  if (upError) {
    return fail("No se pudo subir el archivo: " + upError.message, 500);
  }

  const hash = await sha256Hex(bytes);
  const { data, error: dbError } = await admin
    .from("evidencias")
    .upsert(
      {
        usuario_id: uid,
        tipo,
        bucket,
        path,
        hash_sha256: hash,
        tamano_bytes: bytes.byteLength,
      },
      { onConflict: "bucket,path" },
    )
    .select("id")
    .maybeSingle();

  if (dbError) {
    return fail("El archivo subió pero no se registró: " + dbError.message, 500);
  }

  return json({ ok: true, path, id: data?.id ?? null });
}

// ------------------------------------------------------------
// Borrado privilegiado + baja del registro.
// ------------------------------------------------------------
async function removeFile(
  admin: SupabaseClient,
  bucket: string,
  path: string,
): Promise<Response> {
  const { error: rmError } = await admin.storage.from(bucket).remove([path]);
  if (rmError) {
    return fail("No se pudo eliminar el archivo: " + rmError.message, 500);
  }

  const { error: dbError } = await admin
    .from("evidencias")
    .delete()
    .eq("bucket", bucket)
    .eq("path", path);
  if (dbError) {
    return fail("El archivo se eliminó pero no su registro: " + dbError.message, 500);
  }

  return json({ ok: true, path });
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const buffer = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

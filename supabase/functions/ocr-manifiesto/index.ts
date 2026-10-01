// ============================================================
// Módulo 4: Manifiestos
// Edge Function "ocr-manifiesto"
//
// Extrae del BOL (foto del manifiesto) el número PRO, la fecha y el
// cliente usando un modelo de visión de OpenAI con salida estructurada.
//
// La clave de OpenAI vive en el secreto OPENAI_API_KEY de la Edge
// Function; NUNCA se incluye en la aplicación.
//
// Solo un usuario activo (chofer o administrador) puede invocarla.
//
// Cuerpo JSON:
//   { base64: string, contentType?: string }
// ============================================================

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MODELO = "gpt-4o-mini";
const MAX_BYTES = 8 * 1024 * 1024; // 8 MB

// Esquema estricto de la respuesta del modelo.
const ESQUEMA = {
  name: "manifiesto",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    properties: {
      fecha: { type: "string" },
      confianza: { type: "number" },
      documentos: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          properties: {
            tipo: { type: "string", enum: ["pro", "factura"] },
            numero: { type: "string" },
            cliente: { type: "string" },
          },
          required: ["tipo", "numero", "cliente"],
        },
      },
    },
    required: ["fecha", "confianza", "documentos"],
  },
} as const;

const INSTRUCCIONES =
  `Eres un sistema de extracción documental de manifiestos o guías de carga (Bill of Lading).
Lee la imagen y extrae:
- fecha: la fecha del documento en formato YYYY-MM-DD. Si no es legible, devuelve cadena vacía.
- documentos: TODAS las líneas de documento que aparezcan (pueden ser una o muchas).
  Para cada una:
    * tipo: "pro" si es un PRO/folio/manifiesto; "factura" si es un número de factura.
    * numero: el número o folio del documento, sin texto adicional.
    * cliente: el nombre del cliente o destinatario de esa línea (cadena vacía si no aparece).
- confianza: tu confianza global de 0 a 1 en la extracción.
Si un campo no aparece o es ilegible, devuélvelo como cadena vacía (o 0 en confianza). No inventes datos.`;


function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function fail(message: string, status = 400): Response {
  return json({ ok: false, error: message }, status);
}

function limpiarBase64(valor: unknown): string {
  const texto = typeof valor === "string" ? valor.trim() : "";
  const coma = texto.indexOf(",");
  // Acepta tanto base64 puro como data URI ("data:image/jpeg;base64,...").
  return texto.startsWith("data:") && coma >= 0 ? texto.slice(coma + 1) : texto;
}

function normalizarFecha(valor: unknown): string | null {
  const texto = typeof valor === "string" ? valor.trim() : "";
  if (!/^\d{4}-\d{2}-\d{2}$/.test(texto)) return null;
  const fecha = new Date(`${texto}T00:00:00Z`);
  return Number.isNaN(fecha.getTime()) ? null : texto;
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
  const openaiKey = Deno.env.get("OPENAI_API_KEY");

  if (!supabaseUrl || !serviceKey || !anonKey) {
    return fail("Configuración del servidor incompleta.", 500);
  }
  if (!openaiKey) {
    return fail("OCR no configurado. Falta la clave de OpenAI.", 503);
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

  const admin: SupabaseClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // El invocador debe tener un perfil activo (chofer o administrador).
  const { data: callerProfile, error: profileError } = await admin
    .from("profiles")
    .select("id, rol, activo")
    .eq("id", userData.user.id)
    .maybeSingle();

  if (profileError) {
    return fail("No se pudo verificar el perfil del invocador.", 500);
  }
  if (!callerProfile || !callerProfile.activo) {
    return fail("Se requiere un usuario activo.", 403);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return fail("Cuerpo JSON inválido.");
  }

  const base64 = limpiarBase64(payload.base64);
  if (!base64) {
    return fail("Falta la imagen del manifiesto.");
  }
  if (base64.length > MAX_BYTES) {
    return fail("La imagen es demasiado grande.", 413);
  }

  const contentType = typeof payload.contentType === "string" &&
      payload.contentType.trim().length > 0
    ? payload.contentType.trim()
    : "image/jpeg";

  let respuesta: Response;
  try {
    respuesta = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openaiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: MODELO,
        temperature: 0,
        response_format: { type: "json_schema", json_schema: ESQUEMA },
        messages: [
          {
            role: "user",
            content: [
              { type: "text", text: INSTRUCCIONES },
              {
                type: "image_url",
                image_url: { url: `data:${contentType};base64,${base64}` },
              },
            ],
          },
        ],
      }),
    });
  } catch {
    return fail("No se pudo contactar al servicio de OCR.", 502);
  }

  if (!respuesta.ok) {
    const detalle = await respuesta.text();
    return fail(
      `El servicio de OCR no respondió (estado ${respuesta.status}). ${detalle.slice(0, 200)}`,
      502,
    );
  }

  let contenido: string;
  try {
    const data = await respuesta.json();
    contenido = data?.choices?.[0]?.message?.content ?? "";
  } catch {
    return fail("Respuesta del OCR ilegible.", 502);
  }

  let extraido: Record<string, unknown>;
  try {
    extraido = JSON.parse(contenido);
  } catch {
    return fail("El OCR no devolvió un JSON válido.", 502);
  }

  const confianza = typeof extraido.confianza === "number"
    ? Math.min(1, Math.max(0, extraido.confianza))
    : 0;

  const documentosBrutos = Array.isArray(extraido.documentos)
    ? extraido.documentos
    : [];
  const documentos = documentosBrutos
    .map((d) => {
      if (!d || typeof d !== "object") return null;
      const item = d as Record<string, unknown>;
      const numero = typeof item.numero === "string" ? item.numero.trim() : "";
      if (!numero) return null;
      const tipo = item.tipo === "factura" ? "factura" : "pro";
      const cliente = typeof item.cliente === "string" ? item.cliente.trim() : "";
      return { tipo, numero, cliente };
    })
    .filter((d) => d !== null);

  return json({
    ok: true,
    fecha: normalizarFecha(extraido.fecha),
    confianza,
    documentos,
  });
});

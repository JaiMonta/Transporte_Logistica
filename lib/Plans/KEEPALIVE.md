# Keep-alive de Supabase (evitar pausa por inactividad)

Supabase pausa los proyectos del plan Free tras ~7 días sin **actividad de base
de datos**. Un ping a `/auth/v1/health` responde 200 pero **no ejecuta SQL**, así
que no evita la pausa. El ping debe llegar a **PostgREST/Postgres**.

## 1. Migración

**Aplicada** (`supabase/migrations/20261112000000_keepalive.sql`). Crea:

- `public.keepalive`: una sola fila (`id = 1`, `pinged_at`).
- Política RLS de lectura para `anon` (solo esta tabla, sin datos de negocio).
- `grant select` a `anon`.

## 2. Monitor externo (UptimeRobot)

Crear una cuenta gratuita en <https://uptimerobot.com> y un monitor **HTTP(s)**:

- **Nombre:** Supabase keep-alive
- **URL:**

  ```
  https://fmwwablhluztdvspujwj.supabase.co/rest/v1/keepalive?select=pinged_at&apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtd3dhYmxobHV6dGR2c3B1andqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3MDAyMTksImV4cCI6MjEwNjI3NjIxOX0.4On59eAIcMFmX5WqjJ4rVTsbGo993an7W6gwPiY88mg
  ```

- **Intervalo:** 5 minutos (plan gratuito).
- **Keyword (opcional):** `pinged_at`, para verificar que la base respondió.

La `apikey` es la clave **anónima** (pública por diseño; la misma que usa la app
Web). No uses la `service_role`.

> El monitor externo no se desactiva por inactividad del repositorio, a
> diferencia de un cron de GitHub Actions en un repo público (se desactiva tras
> 60 días sin actividad).

## 3. Verificación manual

```powershell
curl.exe "https://fmwwablhluztdvspujwj.supabase.co/rest/v1/keepalive?select=pinged_at&apikey=<ANON_KEY>"
```

Debe devolver `[{"pinged_at":"..."}]`.

Para probar que **escribe** (opcional), el mismo proyecto puede exponer una RPC
`keepalive_ping()`; con un monitor que solo hace GET basta la lectura, que ya
ejecuta SQL y RLS.

## 4. Restauración

Si aun así se pausa, el proyecto se puede restaurar hasta **1 año** después
desde el dashboard (Project → Resume project).

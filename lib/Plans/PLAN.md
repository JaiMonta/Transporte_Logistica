# Plan de desarrollo — Sistema de gestión logística y de flota

Stack: Flutter (Web = panel admin, Android/iOS = app de campo), Riverpod, go_router,
Supabase (Postgres, Auth, Storage, Realtime), sqflite offline, flutter_map,
Google Vision/Maps/Routes.

Arquitectura *feature-first*:

```
lib/main.dart
lib/core/{env,supabase_client,router,theme}.dart
lib/features/{auth,rutas,manifiesto,entregas,gps,pagos,reportes}
lib/shared/{widgets,models,services/{offline_manager,sync_engine,gps_tracker}.dart}
lib/admin/{dashboard_screen,mapa_screen,reportes_screen}.dart
```

Regla transversal: **RLS en todas las tablas** con pruebas por rol; **ninguna
llave de servicio en la app** (operaciones privilegiadas en Edge Functions);
buckets privados con URLs firmadas; horas/estados críticos por servidor; bajas
lógicas; interfaz responsive (tarjetas en móvil, tabla en pantalla ancha);
offline con subida automática; fotos comprimidas.

Regla dura: **no incluir nombres de empresa/persona/propietario** en código,
comentarios, carpetas ni textos de la interfaz. El sistema debe ser genérico.

---

## Módulo 1 — Usuarios y accesos (CRUD)  ✅ COMPLETADO

1. Proyecto Supabase y proyecto Flutter en español con ID `com.transportelogistica.app`.
2. Tabla `profiles` enlazada a `auth.users` (mismo id), roles `admin` y `chofer`,
   campo `activo` y trigger que la llena al crear un usuario en Auth.
3. Rol guardado en `app_metadata` (no en `user_metadata`, editable por el usuario).
4. Login y cierre de sesión con la sesión guardada en `flutter_secure_storage`.
5. Alta de usuarios desde el panel admin vía Edge Function con `service_role`
   (esa llave nunca está en la app).
6. Listado con búsqueda y filtro por rol y estado: tarjetas en móvil, tabla en
   pantalla ancha.
7. Edición de nombre, teléfono y rol, con validación de formato y correo único.
8. Desactivar y reactivar en lugar de borrar (conserva historial).
9. Recuperar y restablecer contraseña con política mínima.
10. Políticas RLS: el chofer solo ve y edita su propio perfil; el admin gestiona todos.
11. Redirección por rol con go_router (admin → panel; chofer → vista móvil).
12. Pruebas: lectura/modificación de perfiles ajenos bloqueada y usuario inactivo
    sin acceso.

### Estado de implementación

- **Supabase (remoto `fmwwablhluztdvspujwj`)**: migraciones aplicadas
  (`profiles`, enum `rol_usuario`, triggers de alta/sync, RLS, protección de
  campos) y Edge Function `admin-users` desplegada.
- **App Flutter**: `flutter analyze` limpio y 12 pruebas unitarias en verde.
- **Pruebas E2E/RLS**: todas en verde (chofer no ve ni modifica perfiles ajenos;
  no puede cambiar su rol/estado/correo; usuario inactivo bloqueado en login).

### Acceso de administrador (entorno de desarrollo)

- Correo: `jaimemonta@gmail.com`
- Contraseña: `Jaime5221`

---

## Módulo 2 — Clientes  ✅ COMPLETADO

Catálogo de clientes con baja lógica y selector reutilizable. El administrador
crea/edita/desactiva; el chofer solo ve los clientes activos.

### Esquema (Supabase)

- Migración `supabase/migrations/20260930130000_module2_clientes.sql` aplicada:
  `public.clientes` (id, nombre, nombre_contacto, telefono, email, direccion,
  lat, lng, activo, created_at, updated_at), índice único `lower(email)` con
  correo no nulo, índice por nombre, trigger `updated_at` reutilizando
  `public.set_updated_at()`.
- RLS: `clientes_select_active_or_admin` (chofer solo activos, admin todo);
  insert/update/delete solo `public.is_admin()`. Grants a `authenticated`
  (select/insert/update/delete) y `service_role` (all).

### Flutter (feature `clientes`)

- `models/cliente.dart` (lat/lng, `tieneUbicacion`, `nombreVisible`, `iniciales`).
- `data/clientes_repository.dart`: listar (búsqueda + filtro activo), obtener,
  `existeCorreo`, crear, actualizar, cambiarActivo — todo por PostgREST (RLS).
- `providers/clientes_providers.dart`: `FiltroClientes`, `clientesProvider`,
  `clienteProvider(id)` y `clientesActivosProvider` (reutilizable en Módulos 4/5/6).
- `presentation/clientes_screen.dart` (búsqueda + filtro activos/inactivos,
  tarjetas en móvil / tabla en pantalla ancha, activar/desactivar) y
  `presentation/cliente_form_screen.dart` (alta/edición con validaciones).
- Widgets: `cliente_card.dart`, `cliente_tabla.dart`, `cliente_selector.dart`.
- Rutas: `adminClientes`, `adminClienteNuevo`, `adminClienteEditar(id)`; entrada
  "Clientes" en `AdminShell`.

### Ubicación en el mapa (decisión del usuario)

En vez de geocodificación por servicio externo (Nominatim bloqueaba las IPs
compartidas de Supabase Edge), se implementó un **selector de mapa modal**:
`lib/shared/widgets/selector_mapa.dart` abre un diálogo con `flutter_map` y
OpenStreetMap; el administrador toca el punto exacto y la app toma latitud y
longitud. Se eliminó la Edge Function `geocodificar`, su migración de caché y el
secreto `NOMINATIM_USER_AGENT`; la tabla `geocodificaciones` fue eliminada.

### Pruebas

- Unitarias: `test/modulo2_test.dart` (Cliente.fromMap, coordenadas fuera de
  rango, `FiltroClientes.copyWith`), total del proyecto 21 en verde.
- RLS en remoto (todas en verde): el chofer solo ve activos y no puede
  crear/editar; el administrador gestiona todo.
- `flutter analyze` limpio; `flutter test` 21/21.

---

## Módulo 3 — Almacenamiento y modo offline  ✅ COMPLETADO

Infraestructura **reutilizable** de evidencias y cola offline (sin pantallas de
operación). La cola funciona **solo en móvil** (Android/iOS); en Web la app es
online-only y todo el servicio local queda como no-op.

### Esquema (Supabase)

- Migración `20260930140000_module3_storage.sql` aplicada:
  - Enums `evidencia_tipo` (bol, firma, recibo, extra, otro), `sync_estado`
    (pendiente, subiendo, fallido, completado), `sync_accion` (crear, actualizar,
    eliminar).
  - `public.evidencias` (id, usuario_id→profiles, tipo, bucket, path, hash_sha256,
    tamano_bytes, subido_en, created_at; único `(bucket, path)`).
  - `public.sync_events` (id, usuario_id, entidad, entidad_id, accion, payload
    jsonb, estado, intentos, ultimo_error, timestamps; único
    `(usuario_id, entidad, entidad_id, accion)` para idempotencia).
  - RLS: el chofer solo ve/sube lo suyo (sin borrar); el admin gestiona todo.
- Migración `20260930140100_module3_storage_buckets.sql` aplicada: tres buckets
  **privados** (`manifiestos`, `firmas`, `extras`) y políticas sobre
  `storage.objects` — el chofer opera solo dentro de su carpeta `{uid}/…`; el
  admin en todas.

### Edge Function

- `firmar-url` desplegada: valida el JWT, exige usuario activo, restringe al dueño
  del `path` (o admin), valida bucket/path (`..`, rutas absolutas) y firma URLs de
  corta vida (60 s, máx 300). Acciones `sign`, `upload`, `remove`.

### Flutter (`lib/shared/services/`)

- `offline_manager.dart`: base local `sqflite` (`offline_queue`, `gps_buffer`) que
  **solo se inicializa fuera de Web**; `encolar` idempotente, pendientes, contador.
- `sync_engine.dart`: escucha `connectivity_plus`, vacía la cola a Supabase con
  **espera creciente** (`esperaReintento`, tope 5 min), espeja en `sync_events` y
  marca estados pendiente→subiendo→completado/fallido. Providers `syncEngineProvider`
  y `pendientesProvider`.
- `almacenamiento_repository.dart`: comprime con `image` (JPEG q70, máx 1600 px),
  calcula SHA-256 (`crypto`), sube con `storage.uploadBinary` y registra en
  `evidencias`; obtiene URL firmada vía Edge Function.
- `gps_tracker.dart`: buffer local de posiciones (base para el módulo GPS).
- `offline_banner.dart`: ahora muestra también "N pendiente(s) de sincronizar".

### Pruebas

- Unitarias: `test/modulo3_test.dart` (backoff, `hayConexion`, serialización de
  `ElementoCola`/`PuntoGps`); total del proyecto **30 en verde**.
- RLS/E2E remoto (todas en verde): el chofer sube/lee solo su carpeta, no puede
  escribir ni borrar lo ajeno; el admin gestiona todo; `firmar-url` 403 para carpeta
  ajena, 400 para path/bucket inválidos, 401 sin token; evidencias/sync_events con
  RLS propia. Datos de prueba eliminados.
- `flutter analyze` limpio; `flutter test` 30/30.

---

## Módulo 4 — Manifiestos  ✅ COMPLETADO

Alta de manifiestos/guías de carga con foto del BOL. Un manifiesto tiene una
**cabecera** (fecha única, foto, capturista) y **N líneas de documento**
(PRO o factura, sin límite), cada una con su número y cliente (de catálogo o
texto libre). El chofer captura desde móvil; el OCR propone las líneas; el
chofer las revisa y corrige antes de guardar. El administrador lista, busca y
audita.

### Reconciliación de esquema (importante)

El proyecto remoto tenía un **esquema previo** (`usuarios`, `rutas`,
`manifiestos`, `entregas`, `camiones`, `extras_servicio`, `pagos_choferes`,
`ubicaciones_gps`) del diseño original, vacío y **no enlazado a `auth.users`**.
Se acordó: (1) alinear al plan, (2) eliminar lo no usado, (3) añadir políticas.
Migración `20260930145000_reconciliacion_esquema.sql` elimina esas tablas.
La fuente de verdad de usuarios es `public.profiles` (Módulo 1).

### Esquema (Supabase)

- Migración `20260930150000_module4_manifiestos.sql`: enum `cotejo_estado`.
- Migración `20260930160000_module4_manifiestos_lineas.sql` (**v2: cabecera +
  líneas, reemplaza el modelo de 1 fila**):
  - enum `documento_tipo` (`pro`, `factura`).
  - `public.manifiestos` (cabecera): id, fecha, capturado_por→profiles, bucket,
    path, hash_sha256, ocr_confianza, cotejo, timestamps.
  - `public.manifiesto_lineas`: id, manifiesto_id→manifiestos (on delete
    cascade), tipo, numero, cliente_id→clientes (nullable), cliente_texto
    (nullable), orden, timestamps.
  - Índices por manifiesto, número y cliente. **Sin índice único** (la unicidad
    tipo+número+fecha se valida en la app).
  - RLS: cabecera como antes (chofer ve/crea lo suyo; admin todo). Líneas:
    visibles/creables si el manifiesto es del chofer o admin (vía `exists`);
    update/delete solo admin. Triggers `updated_at`.
- Migración `20260930150200_module4_pro_unique_nulls.sql` (del modelo v1,
  se conserva por historial).

### Edge Function

- `ocr-manifiesto` desplegada: valida JWT y usuario activo; llama a OpenAI
  `gpt-4o-mini` con Structured Outputs y devuelve `{fecha, confianza,
  documentos:[{tipo, numero, cliente}]}` (array, puede haber varias líneas).
  La clave vive en el secreto `OPENAI_API_KEY` (aún sin saldo).
- Se usa como OCR **en Web**. En **móvil** el OCR es on-device con **ML Kit**
  (ver `lib/Plans/OCR_OPCIONES.md`).

### Flutter (feature `manifiesto`)

- `models/manifiesto.dart`: `Manifiesto` (cabecera + `List<ManifiestoLinea>`),
  `ManifiestoLinea`, enums `TipoDocumento` y `CotejoEstado`.
- `data/manifiestos_repository.dart` (listar con búsqueda por número de
  documento + rango de fechas, obtener con join, `existeDocumento`, `crear`
  con cabecera + líneas).
- **OCR por plataforma** (`data/`):
  - `ocr_repository.dart`: punto único; elige estrategia por plataforma.
  - `ocr_mlkit.dart` (import condicional) → `ocr_mlkit_movil.dart` (ML Kit) /
    `ocr_mlkit_web.dart` (no-op).
  - `parser_manifiesto.dart`: función pura que extrae la fecha y **varias**
    líneas (tipo/número/cliente) del texto (regex + heurística, best-effort).
  - `ocr_openai.dart`: OpenAI (Web) + `resultadoDesdeTexto`.
- `providers/manifiestos_providers.dart` (`FiltroManifiestos`, `manifiestosProvider`,
  `manifiestoProvider`).
- `presentation/captura_manifiesto_screen.dart` (cámara en vivo en móvil;
  selección de archivo en Web): sube al bucket `manifiestos`, OCR, **fecha única
  + editor de líneas** (`widgets/lineas_editor.dart`) y revisión humana.
- `widgets/selector_cliente_hibrido.dart` (catálogo o texto libre).
- `presentation/manifiestos_screen.dart` (admin: tarjetas/tabla, búsqueda y rango
  de fechas), `presentation/mis_manifiestos_screen.dart` (chofer) y
  `presentation/manifiesto_detalle_screen.dart` (foto BOL por URL firmada +
  tabla de líneas).
- Rutas nuevas en `router.dart` (admin y chofer) y entrada "Manifiestos" en
  `AdminShell`; el home del chofer pasa a menú.
- Permiso de cámara: `AndroidManifest.xml` (`CAMERA`) e iOS `Info.plist`
  (`NSCameraUsageDescription`).

### Pruebas

- Unitarias: `test/modulo4_test.dart` y `test/parser_manifiesto_test.dart`
  (incluye multi-línea); total del proyecto **54 en verde**.
- RLS/E2E remoto (todas en verde): el chofer crea cabecera y líneas propias y no
  puede editarlas; el admin ve y gestiona todo; borrado en cascada de líneas;
  `ocr-manifiesto` sin token → 401 y sin clave → 503. Datos de prueba eliminados.
- `flutter analyze` limpio; `flutter test` 54/54.
- Compila Web (`flutter build web`) y Android (`flutter build apk`).

### OCR — decisión (ver `lib/Plans/OCR_OPCIONES.md`)

- **Móvil: Google ML Kit** (on-device, offline, sin costo; modelo *bundled*).
  Requisitos: Android `minSdk` 24 + `com.google.mlkit:text-recognition:16.0.1` +
  `proguard-rules.pro`; iOS `IPHONEOS_DEPLOYMENT_TARGET = 15.5` + `ios/Podfile`.
- **Web: OpenAI** (Edge Function) o captura manual.
- **Tesseract OCR: evaluado y descartado** para móvil (calidad y setup iOS
  frágiles). Anotado como opción futura **solo si** se quiere OCR offline en Web.
- **Extracción multi-línea:** ambos OCR intentan proponer **varias líneas**
  (tipo/número/cliente). OpenAI (web) devuelve un array explícito; ML Kit (móvil)
  usa el parser `parser_manifiesto.dart` (best-effort, revisión humana).

### Pendiente para cerrar el OCR (OpenAI / Web)

- Configurar saldo/secreto `OPENAI_API_KEY`:
  `supabase secrets set OPENAI_API_KEY=... --project-ref fmwwablhluztdvspujwj`.

---

## Módulos pendientes

- **Módulo 5 — Entregas**: ligada a manifiesto, estado y secuencia, foto del
  recibo firmado, hora del servidor (`now()`), lista del día, alerta de trabajo
  programado si falta foto, estado visible en admin.
- **Módulo 6 — Pickups / Delivery**: asignados solo por admin con hora estimada;
  el chofer marca "En camino" con hora del servidor; notificaciones.
- **Módulo 7 — Jornadas y vista semanal**: tabla de jornadas, pestaña Semana,
  vistas por semana reutilizables en pagos y reportes.
- **Módulo 8 — Extras**: tipo, monto, evidencia opcional; el chofer reporta, el
  admin aprueba/rechaza; solo aprobados cuentan para pago.
- **Módulo 9 — Pagos semanales y acumulados**: `pagos_semanales` con columna
  generada del total, estados borrador/aprobado/pagado + comprobante; acumulado
  mensual/anual 1099; RLS: el chofer ve los suyos; exportación anual 1099.
- **Módulo 10 — Expediente y reportes**: expediente por secuencia, PDF con
  `printing` y compartir; reportes semanales (admin) con filtros semana/cliente.
- **Módulo 11 — Panel admin y navegación móvil**: menú web responsive; nav
  inferior móvil (Manifiesto, Entregas, Delivery, Semana, Equipo); tema único de
  alto contraste.
- **Módulo 12 — QA, seguridad y publicación**: revisión RLS tabla por tabla con
  pruebas por rol; pruebas Android/iOS reales con señal débil/sin señal/app
  cerrada a medias; sin llaves ni secretos en la app; respaldos y producción;
  publicación en tiendas y capacitación.

---

## Plan del día — Vista inicial (Bienvenida + Login)  ✅ COMPLETADO

Objetivo: pantalla inicial con la imagen de bienvenida a mitad de pantalla,
el lema "LOGÍSTICA DE TRANSPORTE" en letras grandes, un logotipo generado y,
en la otra mitad, el inicio de sesión.

- [x] Declarar `assets/` en `pubspec.yaml` y mover la imagen a
  `assets/bienvenida_transporte.jfif`.
- [x] Generar `assets/logo.png` (camión + barras de ruta, PNG transparente con
  azul `#3C5AA0` y ámbar `#865223`). Script reproducible en
  `tool/generar_logo.dart` (dependencia `image`).
- [x] Extrar el formulario a `widgets/formulario_login.dart` (reutilizable).
- [x] Nueva `features/auth/presentation/bienvenida_screen.dart`:
  - Ancho (≥900px): `Row` mitad imagen (overlay + logo + lema en `displayLarge`
    60px) / mitad login.
  - Estrecho: apilado (imagen ~45% arriba, login abajo).
- [x] Ruta `/login` ahora apunta a `PantallaBienvenida` (se eliminó
  `login_screen.dart`); redirección por rol intacta.
- [x] `flutter analyze` limpio y `flutter test` (12 pruebas) en verde.

---

## Registro del día  ✅ COMPLETADO

Resumen de lo trabajado en la jornada (además del Módulo 4, detallado arriba):

### Reglas de contexto del agente (DCP)

- Se configuraron las reglas de poda de contexto (plugin DCP) en
  `~/.config/opencode`: `dcp.jsonc` (perfil equilibrado: `protectUserMessages`,
  `protectTags`, límites 50%–78%, `turnProtection` 5, patrones de archivo
  protegidos) y los prompts en español en `dcp-prompts/overrides/`.

### Reconciliación de esquema Supabase (hallazgo clave)

- El proyecto remoto tenía un **esquema previo** (`usuarios`, `rutas`,
  `manifiestos`, `entregas`, `camiones`, `extras_servicio`, `pagos_choferes`,
  `ubicaciones_gps`) vacío y **no enlazado a `auth.users`**. Se acordó alinear al
  plan, eliminar lo no usado y añadir políticas.
- Migración `20260930145000_reconciliacion_esquema.sql`: elimina esas tablas.
- **Decisión:** `public.profiles` es la única fuente de verdad de usuarios.
- Estado final del remoto: `profiles`, `clientes`, `evidencias`, `sync_events`,
  `manifiestos`.

### Módulo 4 — Manifiestos (ver sección propia)

- Captura con cámara en vivo en móvil y **por archivo en Web** (para pruebas
  desde la web móvil), OCR y revisión humana antes de guardar.
- **OCR por plataforma:** ML Kit on-device en móvil y OpenAI (Edge Function
  `ocr-manifiesto`) en Web. Análisis y decisión en `lib/Plans/OCR_OPCIONES.md`
  (incluye Tesseract, evaluado y descartado).
- Secreto `OPENAI_API_KEY` configurado. La función alcanza OpenAI; para operar
  falta saldo en la cuenta de OpenAI (respondió 429 "no credits remaining").
- **Recomendación:** rotar la API key (quedó expuesta al pegarla en el chat).

### Datos de desarrollo

- Chofer de prueba: `chofer.test@example.com` / `Test1234*` (contraseña
  actualizada). Admin: `jaimemonta@gmail.com` / `Jaime5221`.

### Limpieza

- Se eliminó `lib/dataconnect_generated/` (andamio de ejemplo de Firebase Data
  Connect, "movies/reviews", no referenciado y que rompía `flutter analyze`).

### Despliegue web en Firebase Hosting

- Proyecto Firebase: `transporte-logistica-fabab` (cuenta `jaimemonta@gmail.com`).
- `firebase.json` sirve `build/web` con rewrite SPA (`**` → `/index.html`).
- URL en vivo: **https://transporte-logistica-fabab.web.app** (HTTP 200; rewrite
  SPA verificado en `/admin/manifiestos`).
- Se eliminaron andamios de ejemplo de `firebase init` no usados (`dataconnect/`,
  `functions/`, `firestore.rules`, `firestore.indexes.json`, `"same as default/"`).
- `.firebase/` (caché de despliegue) añadido a `.gitignore`.

---

## Despliegue

### Web (Firebase Hosting)

```
flutter build web --dart-define-from-file=env.json
firebase deploy --only hosting --project transporte-logistica-fabab
```

### Backend (Supabase)

```
# Aplicar migraciones (vía Management API con el PAT de .supabase_token).
# Desplegar Edge Functions:
supabase functions deploy admin-users --project-ref fmwwablhluztdvspujwj
supabase functions deploy firmar-url   --project-ref fmwwablhluztdvspujwj
supabase functions deploy ocr-manifiesto --project-ref fmwwablhluztdvspujwj

# Secretos:
supabase secrets set OPENAI_API_KEY=<clave> --project-ref fmwwablhluztdvspujwj
```

### App móvil (APK de prueba)

```
flutter build apk --release --dart-define-from-file=env.json
# Salida: build\app\outputs\flutter-apk\app-release.apk
```

- El App ID es **`com.transportelogistica.app`** (Android `namespace`/`applicationId`,
  iOS `PRODUCT_BUNDLE_IDENTIFIER` y `userAgentPackageName` del mapa).
- Hoy el `build.gradle.kts` firma *release* con las claves *debug*, así que el APK
  se instala directamente en el teléfono (activando orígenes desconocidos).
  Antes de distribuir formalmente: crear un keystore propio, `android/key.properties`
  (en `.gitignore`) y un `signingConfigs.release`.
- APK de prueba de referencia: `app-release.apk` (~71 MB), paquete
  `com.transportelogistica.app`, versión 1.0.0 (versionCode 1).

---

## Comandos de desarrollo

```
flutter pub get
flutter run -d web-server --web-port 8080
flutter analyze
flutter test
```

Notas de configuración:
- `env.json` (y `.supabase_token`) están en `.gitignore` y no se suben al repo.
- La URL y la clave anónima de Supabase tienen valores por defecto en
  `lib/core/env.dart` (la anon key es pública por diseño). Se pueden sobreescribir
  con `--dart-define-from-file=env.json`.
- La clave `service_role` nunca se incluye en la app.

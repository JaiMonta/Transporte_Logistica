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

**Estado: RETIRADO (jornada actual).** Se eliminó **Google ML Kit** y se
**despublicó** la Edge Function `ocr-manifiesto`. La captura del manifiesto es
ahora **manual** (nº PRO/FACTURA, fecha y cliente por líneas). Se conserva
`parser_manifiesto.dart` (+ test) por si se retoma el OCR.

- **(Histórico) Móvil: Google ML Kit** (on-device, offline, sin costo).
- **(Histórico) Web: OpenAI** (Edge Function) o captura manual.
- **Tesseract OCR: evaluado y descartado** para móvil.

### Login persistente (recordar usuario y contraseña)

- `data/credenciales_service.dart`: guarda las credenciales recordadas en
  `flutter_secure_storage` (Keychain/Keystore). La **contraseña** solo se
  recuerda en **móvil** (nunca en Web); el **correo** también en Web.
- `formulario_login.dart`: precarga correo y contraseña al abrir; interruptor
  **"Recordar usuario y contraseña"** (activado por defecto en móvil). Al
  iniciar sesión se guarda según el interruptor.
- **Al cerrar sesión** se borran las credenciales recordadas (hay que teclear de
  nuevo); la sesión activa sí se conserva (reapertura de app / token vigente).
- Pruebas: `test/credenciales_test.dart` (lógica guardar/olvidar con storage
  falso). Total del proyecto: **60 en verde**.
- **Futuro:** opción de desbloqueo por biometría (`local_auth`) en lugar de
  prellenar la contraseña.

### Importación de clientes desde Excel

- Script reutilizable `tool/importar_clientes_excel.ps1`: migra la hoja
  (CLIENTE→nombre, COD→cod_cli, CONTACTO→nombre_contacto, TELEFONO→telefono,
  EMAIL→email, DIRECCION→direccion, LAT→lat, LONG→lng; `activo=true`).
- Solo importa filas con **DIRECCION y REGION** válidas; `#N/D`→null; email en
  minúsculas (duplicados: solo el primero lo conserva); corrige latitudes sin
  punto decimal; idempotente por `cod_cli`; soporta `-DryRun`.
- Uso:
  `powershell -ExecutionPolicy Bypass -File .\tool\importar_clientes_excel.ps1 -Archivo RUTA.xlsx -Hoja 1 -AdminEmail ... -AdminPassword ...`
- Carga realizada: `C:\Desarrollo\Coordenadas.xlsx` (Hoja1) → **254 clientes**
  (de 258 filas válidas; 4 con `cod_cli` duplicado). Estado: 254 total, 222 con
  email, 252 con coordenadas.

### Retención y purga

- Migración `20260930170000_module4_purga_manifiestos.sql`: tabla
  `public.configuracion` (clave `manifiestos_retencion_dias`, por defecto 90) y
  función `public.purgar_manifiestos_antiguos(p_dias, p_dry_run)`.
- Borra **cabecera + líneas** de manifiestos **validados** (`cotejo='ok'`) más
  antiguos que la retención; **no** toca pendientes ni "requiere revisión".
- Se invoca a mano o por `pg_cron`; solo administradores. En el panel admin hay
  un botón "Purgar antiguos" (con confirmación y conteo previo).

### Pendiente para cerrar el OCR (OpenAI / Web)

- Configurar saldo/secreto `OPENAI_API_KEY`:
  `supabase secrets set OPENAI_API_KEY=... --project-ref fmwwablhluztdvspujwj`.

---

## Módulo 5 — Entregas + tracking GPS  ✅ COMPLETADO

Una entrega por cada línea del manifiesto (cliente/sucursal). El chofer ve su
lista del día, marca **"Entregado"** (foto del recibo **opcional** + hora del
servidor) y avanza a la siguiente. Mapa de puntos de entrega en el panel admin y
en el móvil del chofer. **GPS cada 20 min** en primer plano, reflejado en el
panel (refresco manual; Realtime queda para después).

### Esquema (Supabase)

- Migración `20260930190000_module5_entregas.sql`:
  - enum `entrega_estado` (`pendiente`, `entregado`, `fallido`).
  - `public.entregas`: `manifiesto_id`, `linea_id`, `cliente_id`/`cliente_texto`,
    `direccion`, `lat`, `lng`, `orden`, `estado`, `bucket`/`path`/`hash_sha256`
    (recibo), `entregado_en` (hora del servidor), `entregado_por`, `notas`,
    timestamps.
  - `public.ubicaciones_gps`: `usuario_id`, `manifiesto_id`, `lat`, `lng`,
    `precision`, `capturado_en`.
  - RLS: el chofer ve/actualiza solo las entregas de **sus** manifiestos y sus
    propias ubicaciones; el admin ve y gestiona todo.

### Flutter

- Feature `entregas`: `models/entrega.dart` (`Entrega`, `EstadoEntrega`),
  `data/entregas_repository.dart` (del día, por manifiesto, `marcarEntregado`,
  `marcarFallido`), `providers/entregas_providers.dart`.
- `presentation/entregas_dia_screen.dart` (chofer): lista del día, botón
  "Entregado" (foto del recibo opcional con aviso), arranque **automático del
  GPS** al abrir; `presentation/entregas_admin_screen.dart` (admin),
  `entrega_mapa_screen.dart` (mapa de puntos y ruta en orden),
  `chofer_mapa_selector_screen.dart`.
- Feature `gps`: `data/ubicaciones_repository.dart` y
  `services/seguimiento_gps.dart` (temporizador de **20 min** reutilizando
  `GpsTracker`); `presentation/gps_admin_screen.dart` (última posición por
  chofer, refresco manual).
- **Generación de entregas en la app**: al crear el manifiesto, cada línea
  produce su entrega heredando cliente y coordenadas del catálogo.
- Rutas y navegación: entradas "Entregas" y "GPS" en `AdminShell`; accesos en
  el home del chofer.
- Permisos: Android `ACCESS_FINE/COARSE_LOCATION`; iOS
  `NSLocationWhenInUseUsageDescription`.

### Pruebas

- Unitarias: `test/modulo5_test.dart` (Entrega, EstadoEntrega). Total del
  proyecto **67 en verde**.
- RLS/E2E remoto (todas en verde): el chofer crea/ve/marca sus entregas; el admin
  ve todas; el chofer inserta su GPS pero **403** a nombre de otro; el admin lee
  todas las ubicaciones; borrado en cascada. Datos de prueba eliminados.
- `flutter analyze` limpio; `flutter test` 67/67; build web y APK (101.5 MB).

### Notas

- **GPS en primer plano**: si el teléfono se bloquea o se sale de la app, el
  envío se detiene. El **background real** (con servicio en primer plano/plugin)
  queda como mejora futura.
- Entregas de clientes sin coordenadas no se pintan en el mapa (se avisa).
- **Realtime** del panel se verá más adelante (hoy refresco manual).

---

## Módulo: Consumo de combustible  ✅ COMPLETADO

Al capturar el manifiesto el chofer registra los **litros iniciales** del tanque
(+odómetro opcional): eso crea la **jornada de combustible** y, al guardar, se
navega a **Entregas del día** (arranca el GPS). Durante el recorrido puede
registrar **N recargas** (litros + monto/foto opcional). Al terminar, **cierra
la jornada** con los **litros finales**. El administrador **valida o corrige**
las cantidades iniciales/finales.

### Cálculo
- **km**: suma de distancias (Haversine) entre los puntos GPS del manifiesto.
- **Consumo teórico** = `km × rendimiento` (0,32 lt/km, **configurable** en
  `configuracion.combustible_rendimiento_lt_km`).
- **Consumo real** = `litros iniciales + recargas − litros finales`.
- Se usan las cantidades **validadas** por el admin si existen.

### Esquema (Supabase)

- Migración `20260930200000_combustible.sql`:
  - config `combustible_rendimiento_lt_km = 0.32`.
  - enum `combustible_estado` (`iniciada`, `en_recorrido`, `cerrada`, `validada`).
  - `public.combustible_jornadas` (única por manifiesto): litros iniciales/finales
    (+validados), validaciones, odómetro, km, consumo teórico/real, rendimiento,
    estado, timestamps.
  - `public.combustible_recargas`: litros, monto, foto (bucket `extras`), fecha.
  - RLS: chofer solo el combustible de sus manifiestos; admin todo.

### Flutter (feature `combustible`)

- `models/combustible_jornada.dart` (`CombustibleJornada`, `CombustibleRecarga`,
  `EstadoCombustible`, `CalculoCombustible` con Haversine + consumo).
- `data/combustible_repository.dart`, `providers/combustible_providers.dart`.
- Chofer: `dialogo_combustible.dart` (litros iniciales/finales), integrado en la
  captura del manifiesto; `combustible_jornada_screen.dart` (recargas + cerrar
  jornada); `chofer_combustible_selector_screen.dart`.
- Admin: `combustible_admin_screen.dart` (lista + detalle con corregir inicial/
  final y marcar validada).
- Navegación: "Combustible" en `AdminShell` y en el home del chofer.

### Pruebas

- Unitarias: `test/combustible_test.dart` (Haversine, km, consumo teórico/real,
  modelos). Total del proyecto **76 en verde**.
- RLS/E2E remoto (todas en verde): el chofer inicia/recarga/cierra su jornada; el
  admin corrige y valida; chofer **403** con manifiesto ajeno; cascada. Datos de
  prueba eliminados.
- `flutter analyze` limpio; `flutter test` 76/76; build web y APK (101.7 MB).

### Notas

- El **odómetro** es opcional (respaldo del km calculado por GPS).
- El km por GPS es aproximado (segmentos entre puntos cada 20 min).

---

## Mejoras transversales (UX/visual)  ✅ COMPLETADO

1. **Flecha "atrás":** las navegaciones a subpantallas (formularios, detalles,
   mapas, combustible, selectores) usan `context.push` y las pantallas del panel
   incluyen `leading` de retroceso (`context.pop()`; si no hay pila, a la raíz).
2. **Manifiestos pendientes en Entregas:** la lista incluye filtro **Pendientes /
   Hoy / Todas** (por defecto **Pendientes**, que trae las entregas pendientes
   **sin fecha límite**). El admin ve todas; el chofer solo las suyas (RLS).
3. **Búsqueda de cliente por nombre:** `SelectorClienteBusqueda` reemplaza al
   desplegable; filtra el catálogo por nombre y permite "texto libre".
4. **Mapa de rutas pendientes (admin):** `EntregasMapaAgregadoScreen` dibuja
   todas las rutas pendientes con un color por manifiesto; accesible desde
   Entregas y GPS (aunque no haya señales GPS).
5. **Ruta desde la 1.ª fila:** las entregas/ruta se ordenan por `orden`
   (la primera fila del manifiesto es el punto 1).
6. **Mapas unificados:** widget `MapaVista` (capa **OpenStreetMap**, sin API) con
   **encuadre automático** (`CameraFit.bounds`) y atribución OSM, usado en todos
   los mapas (entrega, agregado, GPS y selector) → mismo aspecto siempre.

- Verificación: `flutter analyze` limpio, `flutter test` **76/76**, web
  redeployada y APK reconstruido.

---

## Módulo: Camiones  ✅ COMPLETADO

Catálogo de camiones en el panel admin (registrar, editar,
**desactivar/reactivar**). El chofer solo lee los activos.

### Datos
Marca, placa (**única**), modelo, año, capacidad (kg), volumen (m³) y **chofer
asignado (obligatorio)**.

### Esquema (Supabase)

- Migración `20260930210000_camiones.sql`: `public.camiones` con índice único
  `lower(placa)`, `chofer_id → profiles (on delete restrict)`, `activo` (baja
  lógica) y trigger `updated_at`.
- RLS: chofer ve solo activos; insert/update/delete solo admin.

### Flutter (feature `camiones`)

- `models/camion.dart`, `data/camiones_repository.dart`
  (listar/buscar, obtener, `existePlaca`, crear, actualizar, cambiarActivo),
  `providers/camiones_providers.dart` (+ `choferesActivosProvider`).
- Pantallas: `camiones_screen.dart` (búsqueda + filtro activos/inactivos;
  tarjetas/tabla), `camion_form_screen.dart` (con **selector de chofer activo**
  obligatorio), `widgets/camion_card.dart`, `widgets/camion_tabla.dart`.
- Navegación: entrada "Camiones" en `AdminShell` (rail + barra inferior) con
  acción "Nuevo camión"; rutas `adminCamiones`/`adminCamionNuevo`/`adminCamionEditar`.

### Pruebas

- Unitarias: `test/camiones_test.dart` (Camion, FiltroCamiones). Total del
  proyecto **84 en verde**.
- RLS/E2E remoto (todas en verde): chofer ve solo activos y no crea (403); admin
  gestiona; placa duplicada → 409. Datos de prueba eliminados.
- `flutter analyze` limpio; `flutter test` 84/84; build web y APK (101.9 MB).

### Enlace camión ↔ manifiesto y flete (provisionado)

- Migración `20260930220000_manifiesto_camion.sql`: `manifiestos` incorpora
  `camion_id → camiones (on delete set null)`, `localidad_mas_lejana` y
  `costo_flete` (provisionado; se calculará con la tabla de fletes:
  capacidad × localidad).
- **Chofer:** al capturar el manifiesto elige **su camión asignado**
  (`camionesDelChoferProvider`); el admin puede elegir cualquier camión activo.
  El detalle del manifiesto y las tarjetas muestran el camión.
- **Admin:** en el detalle del manifiesto puede fijar la **localidad más lejana**
  (hoy manual; luego podría derivarse del punto más lejano por geocodificación).
- **Pendiente:** tabla de fletes (capacidad del camión × localidad) y cálculo
  automático de `costo_flete`.

---

## Módulo: Fletes (Fase 1)  ✅ COMPLETADO

Tabulador de fletes (precio por localidad y capacidad) + flete base del
manifiesto. El **motor de extras** será la Fase 2.

### Datos (Excel `Tabulador.xlsx`)
- Hoja **TABULADOR**: 101 localidades con KM y precios USD por capacidad
  (tiers: 1,2 / 2,5 / 3,5 / 5 / 6 / 7,5 / 10 / 12 / 15 / 30 T).
- Hoja **EXTRAS**: parámetros por capacidad (caleta, mora, reparto, desvío,
  fin de semana) — solo referencia por ahora.

### Esquema (Supabase)

- Migración `20260930230000_fletes.sql`:
  - `public.fletes_tabulador` (region, localidad única, km, 10 precios) con RLS
    (lectura autenticada; escritura solo admin).
  - `public.fletes_extras` (capacidad_t única + parámetros) misma RLS.
  - `manifiestos.fletes_tabulador_id → fletes_tabulador`.

### Importación

- Script `tool/importar_tabulador_excel.ps1` (idempotente por localidad; params
  como el de clientes; `-DryRun`). Cargó **101 localidades + 11 extras**.

### Flutter (feature `fletes`)

- `models/tabulador_flete.dart` (`TabuladorFlete`, enum `TierCapacidad`).
- `services/calculo_flete.dart` (puro): `tierDeCapacidadKg` (**tier inmediato
  superior**; >30 T → 30 T; sin capacidad → null) y `precioFlete`.
- `data/fletes_repository.dart`, `providers/fletes_providers.dart`.
- **Admin editable**: `fletes_screen` (búsqueda localidad/región) y
  `flete_form_screen` (editar los 10 precios); entrada "Fletes" en `AdminShell`.
- **Manifiesto (detalle):** selector de localidad del tabulador
  (`SelectorLocalidadFlete`); al elegir, guarda `localidad_mas_lejana` +
  `fletes_tabulador_id` y calcula `costo_flete` según el tier del camión.

### Pruebas

- `test/fletes_test.dart` (tiers, precios, modelo). Total del proyecto
  **95 en verde**; `flutter analyze` limpio.
- E2E remoto: camión 8 T + VALENCIA → tier 10 T → **191.77 USD**; chofer lee
  (200) pero no escribe (403). Datos de prueba limpiados.
- Web redeployada y APK (101.9 MB).

### Pendiente (Fase 2)

- Motor de extras (caleta ×2/guía, reparto por clientes, desvío por distancia,
  retorno/devolución, fin de semana +5%, mora, picking especial genérico) y su
  aprobación; nomenclatura genérica de plantas ("Planta acopio/Warehouse",
  "Despacho") según la regla §1.

---

## Módulo: Fletes (Fase 2 — motor de extras)  ✅ COMPLETADO

Los extras **se suman aparte** del flete base y se **desglosan por ítem**. El
chofer **avisa** (devolución/mora) y el **administrador aprueba/rechaza/edita**.

### Reglas

- **Caleta:** 2 × tarifa por manifiesto.
- **Reparto:** 1 por cliente entregado; clientes a **≤10 km** entre sí cuentan
  como **1 reparto** (clustering por distancia).
- **Desvío** (entregas marcadas "otra localidad"): `≤3 t=$6` · `>3 y ≤6 t=$12` ·
  `>6 t=20%` del flete base.
- **Retorno:** parcial (≤20% cap.)=+15% · completa=60%.
- **Mora:** tarifa por capacidad.
- **Fin de semana:** +5%.
- **Picking:** fijo $119.

### Esquema (Supabase)

- Migración `20260930240000_fletes_extras_motor.sql`:
  - enums `extra_tipo` (caleta, reparto, desvio, retorno, mora, fin_semana,
    picking) y `extra_estado` (sugerido, aprobado, rechazado).
  - `public.manifiesto_extras` (manifiesto_id, tipo, descripcion, base, monto,
    porcentaje, estado, origen, aprobado_por/en, notas, timestamps).
  - `manifiestos.es_fin_semana`; `entregas.es_otra_localidad`.
  - parámetros en `configuracion` (radio reparto, tramos de desvío, retorno,
    fin de semana, picking).
  - RLS: chofer ve/crea (avisa) lo suyo; admin gestiona y aprueba.

### Flutter

- `services/calculo_extras.dart` (puro): `repartos` (clustering ≤10 km),
  `desvio` (tramos), `retorno`, `finDeSemana`, `caleta`, `distanciaKm`.
- `models/extra.dart`, `data/extras_repository.dart`, providers
  (`extrasRepositoryProvider`, `extrasDeManifiestoProvider`).
- **Admin (detalle del manifiesto):** `BloqueExtras` con desglose por ítem,
  botón **"Calcular sugeridos"** (según entregas, capacidad y tarifas),
  aprobar/rechazar/editar/eliminar, y resumen **Flete base + Extras aprobados =
  Total**. Incluye interruptor **fin de semana** y checklist de entregas
  **"otra localidad"** (desvío).
- **Chofer (entrega):** botón **"Avisar"** → devolución/retorno o mora (crea un
  extra `sugerido`).

### Pruebas

- `test/calculo_extras_test.dart` (repartos por proximidad, tramos de desvío,
  retorno, fin de semana, caleta, distancia). Total del proyecto **109 en verde**.
- E2E/RLS remoto: el chofer avisa (sugerido) pero **no** aprueba; el admin
  aprueba y fija monto; limpieza en cascada.
- `flutter analyze` limpio; build web y APK (102.5 MB).

### Pendiente

- Panel de **Facturación semanal** (Módulo 9) que consolide flete + extras.

### Correcciones posteriores (jornada)

- **Facturación en cero:** un manifiesto sin `costo_flete`, sin `camion_id` y sin
  `localidad_mas_lejana` daba total 0. La facturación ahora **recalcula el flete**
  (tabulador × capacidad del camión) cuando `costo_flete` está vacío.
- **Detalle del manifiesto (admin):** nuevo botón **"Editar camión"** que asigna
  el camión y recalcula el flete con la localidad ya elegida. Permite completar
  manifiestos antiguos para poder facturarlos.
- Dato de prueba preparado: manifiesto `21c6af79` con camión 7.5 t + CARACAS →
  flete 260.05 USD (factura del 28-09 al 04-10 verificada con monto).

---

## Módulo: Facturación semanal  ✅ COMPLETADO

Agrupa las entregas finalizadas (`estado = 'entregado'`) de una semana
(lunes→domingo, por **fecha de entrega**) de **todos** los choferes y
manifiestos. Calcula el flete base por manifiesto (localidad × capacidad) más
los **extras aprobados**, y guarda **una factura por semana** con el detalle
**por ítem** (y desglose por chofer). Visible solo para el administrador.

### Esquema (Supabase)

- Migración `20260930250000_facturacion_semanal.sql`:
  - enum `factura_estado` (`emitida`, `pendiente`, `cancelada`).
  - `public.facturas` (periodo_inicio/fin únicos, subtotales, total, estado,
    notas, timestamps).
  - `public.factura_items` (factura_id, manifiesto_id, usuario_id, concepto,
    tipo, descripcion, base, porcentaje, monto, orden).
  - RLS **solo admin** (select/insert/update/delete).

### Flutter (feature `facturacion`)

- `services/calculo_factura_semanal.dart` (puro): `SemanaRange`
  (lunes→domingo, `vencida`), `ManifiestoFacturable`, y `calcular` que arma
  ítems (flete + extras `aprobado`) y totales por chofer.
- `models/factura.dart` (`Factura`, `FacturaItem`, `EstadoFactura`).
- `data/facturacion_repository.dart`: `generarSemana` (selecciona manifiestos
  con entregas entregadas del período, upsert de cabecera por semana y
  **rehace** los ítems), `listarPorLapso`, `obtener`, `cambiarEstado`.
- `presentation/facturacion_screen.dart` (búsqueda por **lapso**, generar
  semana actual u otra, lista de facturas) y `factura_detalle_screen.dart`
  (desglose por chofer e ítem; acciones **Rehacer / Marcar pendiente /
  Anular**).
- **Menú:** grupo nuevo **"Finanzas"** en `AdminShell` con la entrada
  "Facturación" (preparado para pagos futuros).

### Reglas de estado

- Al generar: **emitida**. Transición a **pendiente** tras una semana (al vuelo
  en UI) o manual. **Pagada** = la factura quedó saldada. **Anulada** = no
  válida (no se elimina por trazabilidad).

### Pruebas

- `test/facturacion_test.dart` (SemanaRange, selección, ítems/totales,
  desglose por chofer). Total del proyecto **115 en verde**.
- E2E/RLS remoto: el admin gestiona facturas e ítems; el chofer **no** ve
  facturas ni puede crearlas (403). Datos de prueba limpiados.
- `flutter analyze` limpio; build web y APK (103.0 MB).

---

## Módulos pendientes

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

## Registro del día (jornada actual)  ✅ COMPLETADO

Resumen de la jornada. Cada punto tiene su sección detallada arriba y su commit.

### Commits de la jornada

| Commit | Resumen |
| --- | --- |
| `2b36e43` | Login persistente en móvil: recordar usuario y contraseña (secure storage) |
| `7aae567` | Módulo 5: entregas ligadas a manifiesto + tracking GPS cada 20 min |
| `b14794c` | Módulo combustible: litros iniciales/finales, recargas y cálculo lt/km |
| `7f3a781` | Mejoras UX: flecha atrás, pendientes en entregas, búsqueda de cliente, mapa agregado y mapas unificados |
| `659af45` | Agregar PDF de firma en `Estructura` |
| `299b675` | Módulo camiones: catálogo CRUD con chofer asignado y placa única |
| `c56c31e` | Enlace camión↔manifiesto + localidad más lejana y costo de flete provisionado |
| `25393b8` | Módulo fletes Fase 1: tabulador por localidad/capacidad + importador Excel |

### 1. Login persistente (móvil)

- `CredencialesService` guarda usuario/contraseña en `flutter_secure_storage`
  (contraseña solo en móvil; en Web solo el correo). Interruptor "Recordar
  usuario y contraseña" (activado por defecto); al cerrar sesión se olvidan.
- Pruebas: `test/credenciales_test.dart`.

### 2. Módulo 5 — Entregas + GPS

- Una entrega por línea del manifiesto; el chofer marca "Entregado" (foto del
  recibo opcional + hora del servidor); mapa de puntos y ruta; GPS cada 20 min
  en primer plano. Esquema: `entregas`, `ubicaciones_gps`, enum `entrega_estado`.

### 3. Módulo combustible

- Al capturar el manifiesto el chofer registra litros iniciales (inicia la
  jornada y arranca el GPS); recargas durante el recorrido; cierre con litros
  finales; cálculo km (Haversine) y consumo teórico/real; el admin valida o
  corrige. Esquema: `combustible_jornadas`, `combustible_recargas`, config
  `combustible_rendimiento_lt_km`.

### 4. Mejoras transversales (UX/visual)

- Flecha atrás (`context.push` + `leading`), filtro Pendientes/Hoy/Todas en
  Entregas, búsqueda de cliente por nombre, mapa agregado de rutas pendientes y
  widget `MapaVista` unificado (OpenStreetMap con encuadre automático).

### 5. Módulo camiones

- Catálogo CRUD con marca, placa única, modelo, año, capacidad (kg), volumen
  (m³) y **chofer obligatorio**; baja lógica. Esquema `camiones`.

### 6. Enlace camión ↔ manifiesto

- `manifiestos.camion_id`; el chofer elige su camión al capturar. Campos
  `localidad_mas_lejana` y `costo_flete`.

### 7. Módulo fletes (Fase 1)

- Tabulador (101 localidades × 10 tiers) importado desde `Tabulador.xlsx` con
  `tool/importar_tabulador_excel.ps1`; catálogo editable en el panel; cálculo de
  `costo_flete` por localidad y capacidad (tier inmediato superior). El motor de
  extras queda para la Fase 2.

### Verificación y despliegue

- `flutter analyze` limpio y `flutter test` **95/95** al cierre de la jornada.
- Web: **https://transporte-logistica-fabab.web.app** (redeploy al final).
- APK: `build\app\outputs\flutter-apk\app-release.apk` (~101.9 MB).

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

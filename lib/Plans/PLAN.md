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

1. Proyecto Supabase y proyecto Flutter en español con ID `com.armando1735.app`.
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

## Módulos pendientes

- **Módulo 2 — Clientes**: catálogo; admin escribe, chofer solo lee activos; baja
  lógica; selector reutilizable.
- **Módulo 3 — Almacenamiento y modo offline**: buckets privados (BOL/recibos),
  URLs firmadas cortas, compresión de fotos, cola `sqflite` con estados
  pendiente/subiendo/fallido/completado, `connectivity_plus`, reintento con espera
  creciente, indicador de pendientes.
- **Módulo 4 — Manifiestos**: nº PRO, cliente, fecha, foto BOL, quién capturó;
  PRO único por cliente y fecha; captura ~30s; búsqueda por PRO/fecha (admin);
  RLS: el chofer ve los suyos.
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

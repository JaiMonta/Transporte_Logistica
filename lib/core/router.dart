import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin/admin_shell.dart';
import '../admin/dashboard_screen.dart';
import '../features/auth/models/profile.dart';
import '../features/auth/presentation/bienvenida_screen.dart';
import '../features/auth/presentation/loading_screen.dart';
import '../features/auth/presentation/recuperar_password_screen.dart';
import '../features/auth/presentation/restablecer_password_screen.dart';
import '../features/auth/presentation/usuario_form_screen.dart';
import '../features/auth/presentation/usuarios_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/clientes/presentation/cliente_form_screen.dart';
import '../features/clientes/presentation/clientes_screen.dart';
import '../features/manifiesto/presentation/captura_manifiesto_screen.dart';
import '../features/manifiesto/presentation/manifiesto_detalle_screen.dart';
import '../features/manifiesto/presentation/manifiestos_screen.dart';
import '../features/manifiesto/presentation/mis_manifiestos_screen.dart';
import 'supabase_client.dart';

/// Rutas de la aplicación.
class Rutas {
  const Rutas._();

  static const String cargando = '/cargando';
  static const String login = '/login';
  static const String recuperar = '/recuperar';
  static const String restablecer = '/restablecer';

  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsuarios = '/admin/usuarios';
  static const String adminUsuarioNuevo = '/admin/usuarios/nuevo';
  static String adminUsuarioEditar(String id) => '/admin/usuarios/$id';

  static const String adminClientes = '/admin/clientes';
  static const String adminClienteNuevo = '/admin/clientes/nuevo';
  static String adminClienteEditar(String id) => '/admin/clientes/$id';

  static const String adminManifiestos = '/admin/manifiestos';
  static String adminManifiestoDetalle(String id) => '/admin/manifiestos/$id';

  static const String choferHome = '/chofer/home';
  static const String choferManifiestos = '/chofer/manifiestos';
  static const String choferCapturaManifiesto = '/chofer/manifiestos/capturar';
  static String choferManifiestoDetalle(String id) => '/chofer/manifiestos/$id';

  static const Set<String> publicas = {login, recuperar, restablecer};
}

class _RefreshEscucha extends ChangeNotifier {
  _RefreshEscucha(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentProfileProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final escucha = _RefreshEscucha(ref);
  ref.onDispose(escucha.dispose);

  return GoRouter(
    initialLocation: Rutas.cargando,
    refreshListenable: escucha,
    redirect: (context, state) => _redirigir(ref, state),
    routes: [
      GoRoute(
        path: Rutas.cargando,
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: Rutas.login,
        builder: (context, state) => const PantallaBienvenida(),
      ),
      GoRoute(
        path: Rutas.recuperar,
        builder: (context, state) => const RecuperarPasswordScreen(),
      ),
      GoRoute(
        path: Rutas.restablecer,
        builder: (context, state) => const RestablecerPasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(ubicacion: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: Rutas.adminDashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: Rutas.adminUsuarios,
            builder: (context, state) => const UsuariosScreen(),
            routes: [
              GoRoute(
                path: 'nuevo',
                builder: (context, state) => const UsuarioFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => UsuarioFormScreen(
                  usuarioId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: Rutas.adminClientes,
            builder: (context, state) => const ClientesScreen(),
            routes: [
              GoRoute(
                path: 'nuevo',
                builder: (context, state) => const ClienteFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => ClienteFormScreen(
                  clienteId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: Rutas.adminManifiestos,
            builder: (context, state) => const ManifiestosScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => ManifiestoDetalleScreen(
                  manifiestoId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Rutas.choferHome,
        builder: (context, state) => const _ChoferHomeScreen(),
      ),
      GoRoute(
        path: Rutas.choferManifiestos,
        builder: (context, state) => const MisManifiestosScreen(),
        routes: [
          GoRoute(
            path: 'capturar',
            builder: (context, state) => const CapturaManifiestoScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => ManifiestoDetalleScreen(
              manifiestoId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _PantallaError(
      mensaje: 'No se encontró la ruta: ${state.matchedLocation}',
    ),
  );
});

String? _redirigir(Ref ref, GoRouterState state) {
  final ubicacion = state.matchedLocation;
  final sesion = ref.read(supabaseProvider).auth.currentSession;
  final autenticado = sesion != null;

  if (!autenticado) {
    return Rutas.publicas.contains(ubicacion) ? null : Rutas.login;
  }

  // En recuperación de contraseña el usuario debe poder cambiar su clave.
  if (ubicacion == Rutas.restablecer) return null;

  final perfilAsync = ref.read(currentProfileProvider);
  final perfil = perfilAsync.value;

  if (perfil == null) {
    return ubicacion == Rutas.cargando ? null : Rutas.cargando;
  }

  final esAdmin = perfil.rol == Rol.admin;

  if (Rutas.publicas.contains(ubicacion) ||
      ubicacion == Rutas.cargando ||
      ubicacion == '/') {
    return esAdmin ? Rutas.adminDashboard : Rutas.choferHome;
  }

  if (!esAdmin && ubicacion.startsWith('/admin')) {
    return Rutas.choferHome;
  }
  if (esAdmin && ubicacion.startsWith('/chofer')) {
    return Rutas.adminDashboard;
  }
  return null;
}

class _ChoferHomeScreen extends ConsumerWidget {
  const _ChoferHomeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(currentProfileProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi espacio'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).cerrarSesion(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Bienvenido, ${perfil?.nombreVisible ?? ''}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Gestiona tus manifiestos y entregas del día.'),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.add_a_photo_outlined),
              title: const Text('Capturar manifiesto'),
              subtitle: const Text('Foto del BOL y reconocimiento de datos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Rutas.choferCapturaManifiesto),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Mis manifiestos'),
              subtitle: const Text('Consulta los manifiestos capturados'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Rutas.choferManifiestos),
            ),
          ),
        ],
      ),
    );
  }
}

class _PantallaError extends StatelessWidget {
  const _PantallaError({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(mensaje, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(Rutas.login),
                child: const Text('Ir al inicio de sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../features/auth/providers/auth_providers.dart';
import '../shared/widgets/offline_banner.dart';

/// Contenedor del panel de administración: navegación lateral en pantalla
/// ancha y barra inferior en móvil.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.ubicacion, required this.child});

  final String ubicacion;
  final Widget child;

  static const double _breakpointAncho = 900;

  int get _indice => ubicacion.startsWith(Rutas.adminUsuarios) ? 1 : 0;

  String get _titulo => _indice == 1 ? 'Usuarios y accesos' : 'Panel';

  bool get _enListaUsuarios => ubicacion == Rutas.adminUsuarios;

  Future<void> _salir(BuildContext context, WidgetRef ref) =>
      ref.read(authControllerProvider.notifier).cerrarSesion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ancho = MediaQuery.sizeOf(context).width >= _breakpointAncho;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo),
        actions: [
          if (_enListaUsuarios)
            IconButton(
              tooltip: 'Nuevo usuario',
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () => context.go(Rutas.adminUsuarioNuevo),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _salir(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ancho
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _indice,
                        onDestinationSelected: (i) => context.go(
                          i == 1 ? Rutas.adminUsuarios : Rutas.adminDashboard,
                        ),
                        labelType: NavigationRailLabelType.all,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.dashboard_outlined),
                            selectedIcon: Icon(Icons.dashboard),
                            label: Text('Panel'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.people_outline),
                            selectedIcon: Icon(Icons.people),
                            label: Text('Usuarios'),
                          ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: child),
                    ],
                  )
                : child,
          ),
        ],
      ),
      bottomNavigationBar: ancho
          ? null
          : NavigationBar(
              selectedIndex: _indice,
              onDestinationSelected: (i) => context.go(
                i == 1 ? Rutas.adminUsuarios : Rutas.adminDashboard,
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Panel',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Usuarios',
                ),
              ],
            ),
    );
  }
}

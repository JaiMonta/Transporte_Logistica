import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../features/auth/providers/auth_providers.dart';
import '../shared/widgets/offline_banner.dart';

/// Contenedor del panel de administraciÃ³n: navegaciÃ³n lateral en pantalla
/// ancha y barra inferior en mÃ³vil.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.ubicacion, required this.child});

  final String ubicacion;
  final Widget child;

  static const double _breakpointAncho = 900;

  static const List<String> _rutas = [
    Rutas.adminDashboard,
    Rutas.adminUsuarios,
    Rutas.adminClientes,
    Rutas.adminManifiestos,
    Rutas.adminEntregas,
    Rutas.adminGps,
    Rutas.adminCombustible,
    Rutas.adminCamiones,
  ];

  int get _indice {
    for (var i = _rutas.length - 1; i >= 0; i--) {
      if (ubicacion.startsWith(_rutas[i])) return i;
    }
    return 0;
  }

  String get _titulo => switch (_indice) {
        1 => 'Usuarios y accesos',
        2 => 'Clientes',
        3 => 'Manifiestos',
        4 => 'Entregas',
        5 => 'Monitoreo GPS',
        6 => 'Combustible',
        7 => 'Camiones',
        _ => 'Panel',
      };

  bool get _enListaUsuarios => ubicacion == Rutas.adminUsuarios;

  bool get _enListaClientes => ubicacion == Rutas.adminClientes;

  bool get _enListaManifiestos => ubicacion == Rutas.adminManifiestos;

  bool get _enListaCamiones => ubicacion == Rutas.adminCamiones;

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
              onPressed: () => context.push(Rutas.adminUsuarioNuevo),
            ),
          if (_enListaClientes)
            IconButton(
              tooltip: 'Nuevo cliente',
              icon: const Icon(Icons.add_business),
              onPressed: () => context.push(Rutas.adminClienteNuevo),
            ),
          if (_enListaManifiestos)
            IconButton(
              tooltip: 'Subir manifiesto',
              icon: const Icon(Icons.upload_file),
              onPressed: () => context.push(Rutas.adminManifiestoNuevo),
            ),
          if (_enListaCamiones)
            IconButton(
              tooltip: 'Nuevo camión',
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () => context.push(Rutas.adminCamionNuevo),
            ),
          IconButton(
            tooltip: 'Cerrar sesiÃ³n',
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
                        onDestinationSelected: (i) => context.go(_rutas[i]),
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
                          NavigationRailDestination(
                            icon: Icon(Icons.business_outlined),
                            selectedIcon: Icon(Icons.business),
                            label: Text('Clientes'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.description_outlined),
                            selectedIcon: Icon(Icons.description),
                            label: Text('Manifiestos'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.local_shipping_outlined),
                            selectedIcon: Icon(Icons.local_shipping),
                            label: Text('Entregas'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.gps_fixed),
                            selectedIcon: Icon(Icons.gps_fixed),
                            label: Text('GPS'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.local_gas_station_outlined),
                            selectedIcon: Icon(Icons.local_gas_station),
                            label: Text('Combustible'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.local_shipping_outlined),
                            selectedIcon: Icon(Icons.local_shipping),
                            label: Text('Camiones'),
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
              onDestinationSelected: (i) => context.go(_rutas[i]),
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
                NavigationDestination(
                  icon: Icon(Icons.business_outlined),
                  selectedIcon: Icon(Icons.business),
                  label: 'Clientes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.description_outlined),
                  selectedIcon: Icon(Icons.description),
                  label: 'Manifiestos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_shipping_outlined),
                  selectedIcon: Icon(Icons.local_shipping),
                  label: 'Entregas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.gps_fixed),
                  selectedIcon: Icon(Icons.gps_fixed),
                  label: 'GPS',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_gas_station_outlined),
                  selectedIcon: Icon(Icons.local_gas_station),
                  label: 'Combustible',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_shipping_outlined),
                  selectedIcon: Icon(Icons.local_shipping),
                  label: 'Camiones',
                ),
              ],
            ),
    );
  }
}

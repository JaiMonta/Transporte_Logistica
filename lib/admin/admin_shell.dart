import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../features/auth/providers/auth_providers.dart';
import '../shared/widgets/offline_banner.dart';

/// Opción de navegación del panel.
class _Opcion {
  const _Opcion({
    required this.titulo,
    required this.ruta,
    required this.icono,
    required this.iconoActivo,
  });

  final String titulo;
  final String ruta;
  final IconData icono;
  final IconData iconoActivo;
}

/// Grupo de navegación (p. ej. Despachos, Configuración).
class _Grupo {
  const _Grupo({
    required this.titulo,
    required this.icono,
    required this.opciones,
  });

  final String titulo;
  final IconData icono;
  final List<_Opcion> opciones;
}

/// Contenedor del panel de administración: navegación lateral agrupada en
/// pantalla ancha y barra inferior con grupos en móvil.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.ubicacion, required this.child});

  final String ubicacion;
  final Widget child;

  static const double _breakpointAncho = 1050;

  static const _panel = _Opcion(
    titulo: 'Panel',
    ruta: Rutas.adminDashboard,
    icono: Icons.dashboard_outlined,
    iconoActivo: Icons.dashboard,
  );

  static const List<_Grupo> _grupos = [
    _Grupo(
      titulo: 'Despachos',
      icono: Icons.local_shipping_outlined,
      opciones: [
        _Opcion(
          titulo: 'Manifiestos',
          ruta: Rutas.adminManifiestos,
          icono: Icons.description_outlined,
          iconoActivo: Icons.description,
        ),
        _Opcion(
          titulo: 'Entregas',
          ruta: Rutas.adminEntregas,
          icono: Icons.local_shipping_outlined,
          iconoActivo: Icons.local_shipping,
        ),
        _Opcion(
          titulo: 'GPS',
          ruta: Rutas.adminGps,
          icono: Icons.gps_fixed,
          iconoActivo: Icons.gps_fixed,
        ),
      ],
    ),
    _Grupo(
      titulo: 'Configuración',
      icono: Icons.settings_outlined,
      opciones: [
        _Opcion(
          titulo: 'Usuarios',
          ruta: Rutas.adminUsuarios,
          icono: Icons.people_outline,
          iconoActivo: Icons.people,
        ),
        _Opcion(
          titulo: 'Clientes',
          ruta: Rutas.adminClientes,
          icono: Icons.business_outlined,
          iconoActivo: Icons.business,
        ),
        _Opcion(
          titulo: 'Camiones',
          ruta: Rutas.adminCamiones,
          icono: Icons.local_shipping_outlined,
          iconoActivo: Icons.local_shipping,
        ),
        _Opcion(
          titulo: 'Fletes',
          ruta: Rutas.adminFletes,
          icono: Icons.request_quote_outlined,
          iconoActivo: Icons.request_quote,
        ),
        _Opcion(
          titulo: 'Combustible',
          ruta: Rutas.adminCombustible,
          icono: Icons.local_gas_station_outlined,
          iconoActivo: Icons.local_gas_station,
        ),
      ],
    ),
  ];

  static List<_Opcion> get _todas =>
      [_panel, for (final g in _grupos) ...g.opciones];

  _Opcion? get _actual {
    for (final o in _todas) {
      if (ubicacion.startsWith(o.ruta)) return o;
    }
    return null;
  }

  /// Índice del grupo que contiene la ubicación actual (o -1 si es Panel).
  int get _grupoActual {
    for (var i = 0; i < _grupos.length; i++) {
      if (_grupos[i].opciones.any((o) => ubicacion.startsWith(o.ruta))) return i;
    }
    return -1;
  }

  String get _titulo => _actual?.titulo ?? 'Panel';

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
                      _Rail(
                        actual: _actual,
                        grupoActual: _grupoActual,
                        onIr: (ruta) => context.go(ruta),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: child),
                    ],
                  )
                : child,
          ),
        ],
      ),
      bottomNavigationBar:
          ancho ? null : _barraInferior(context, ref),
    );
  }

  Widget _barraInferior(BuildContext context, WidgetRef ref) {
    final grupo = _grupoActual;
    return NavigationBar(
      selectedIndex: grupo < 0 ? 0 : grupo + 1,
      onDestinationSelected: (i) {
        if (i == 0) {
          context.go(Rutas.adminDashboard);
          return;
        }
        _abrirGrupo(context, _grupos[i - 1]);
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Panel',
        ),
        for (final g in _grupos)
          NavigationDestination(
            icon: Icon(g.icono),
            selectedIcon: Icon(g.icono),
            label: g.titulo,
          ),
      ],
    );
  }

  Future<void> _abrirGrupo(BuildContext context, _Grupo grupo) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  grupo.titulo,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final o in grupo.opciones)
                ListTile(
                  leading: Icon(o.icono),
                  title: Text(o.titulo),
                  selected: ubicacion.startsWith(o.ruta),
                  onTap: () {
                    Navigator.pop(context);
                    context.go(o.ruta);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.actual,
    required this.grupoActual,
    required this.onIr,
  });

  final _Opcion? actual;
  final int grupoActual;
  final ValueChanged<String> onIr;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SingleChildScrollView(
      child: IntrinsicHeight(
        child: NavigationRail(
          selectedIndex: null,
          labelType: NavigationRailLabelType.none,
          onDestinationSelected: (_) {},
          destinations: const [],
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _destino(context, AdminShell._panel, actual),
          ),
          trailing: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < AdminShell._grupos.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      AdminShell._grupos[i].titulo.toUpperCase(),
                      style: tema.textTheme.labelSmall?.copyWith(
                        color: colorGrupo,
                      ),
                    ),
                  ),
                  for (final o in AdminShell._grupos[i].opciones)
                    _destino(context, o, actual),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _destino(BuildContext context, _Opcion o, _Opcion? actual) {
    final seleccionado = actual?.ruta == o.ruta;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: TextButton.icon(
        onPressed: () => onIr(o.ruta),
        icon: Icon(seleccionado ? o.iconoActivo : o.icono, size: 20),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(o.titulo),
        ),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor:
              seleccionado ? Theme.of(context).colorScheme.primary : null,
          backgroundColor: seleccionado
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

/// Color de las cabeceras de grupo en el rail.
const Color colorGrupo = Color(0xFF747782);

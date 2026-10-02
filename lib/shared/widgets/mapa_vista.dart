import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';

/// Vista de mapa unificada de la aplicación.
///
/// Usa siempre la capa **OpenStreetMap** (sin API keys) y encuadra
/// automáticamente todos los puntos para que se vean carreteras y ciudades,
/// con el mismo aspecto en todas las pantallas.
///
/// Si [puntos] está vacío, muestra [centroPorDefecto] con [zoomPorDefecto].
class MapaVista extends StatelessWidget {
  const MapaVista({
    super.key,
    required this.marcadores,
    this.polilineas = const [],
    this.centroPorDefecto = const LatLng(10.4806, -66.9036),
    this.zoomPorDefecto = 12,
    this.onTap,
  });

  final List<Marker> marcadores;
  final List<Polyline> polilineas;
  final LatLng centroPorDefecto;
  final double zoomPorDefecto;
  final void Function(LatLng)? onTap;

  static const String _tiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context) {
    final puntos = <LatLng>[
      ...marcadores.map((m) => m.point),
      for (final p in polilineas)
        for (final punto in p.points) punto,
    ];

    final options = puntos.isEmpty
        ? MapOptions(
            initialCenter: centroPorDefecto,
            initialZoom: zoomPorDefecto,
            onTap: (_, punto) => onTap?.call(punto),
          )
        : MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(puntos),
              padding: const EdgeInsets.all(40),
            ),
            onTap: (_, punto) => onTap?.call(punto),
          );

    return FlutterMap(
      options: options,
      children: [
        TileLayer(
          urlTemplate: _tiles,
          userAgentPackageName: 'com.transportelogistica.app',
        ),
        if (polilineas.isNotEmpty) PolylineLayer(polylines: polilineas),
        if (marcadores.isNotEmpty) MarkerLayer(markers: marcadores),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}

/// Paleta de colores para distinguir rutas (mapa agregado).
const List<Color> paletaRutas = [
  AppColors.primary,
  AppColors.secondary,
  AppColors.tertiary,
  AppColors.peligro,
  Color(0xFF7B1FA2),
  Color(0xFF00838F),
  Color(0xFFEF6C00),
  Color(0xFF2E7D32),
];

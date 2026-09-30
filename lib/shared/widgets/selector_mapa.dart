import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';

/// Resultado de la selección de un punto en el mapa.
class PuntoSeleccionado {
  const PuntoSeleccionado(this.lat, this.lng);

  final double lat;
  final double lng;
}

/// Centro por defecto del mapa cuando aún no hay coordenadas
/// (centro aproximado de Venezuela).
const LatLng _centroPorDefecto = LatLng(10.4806, -66.9036);

/// Abre una ventana modal con un mapa de la zona donde el administrador
/// toca para elegir un punto y obtener latitud/longitud.
///
/// Devuelve el punto elegido o `null` si se cancela.
Future<PuntoSeleccionado?> mostrarSelectorMapa(
  BuildContext context, {
  double? lat,
  double? lng,
}) {
  return showDialog<PuntoSeleccionado>(
    context: context,
    builder: (_) => _DialogoMapa(latInicial: lat, lngInicial: lng),
  );
}

class _DialogoMapa extends StatefulWidget {
  const _DialogoMapa({this.latInicial, this.lngInicial});

  final double? latInicial;
  final double? lngInicial;

  @override
  State<_DialogoMapa> createState() => _DialogoMapaState();
}

class _DialogoMapaState extends State<_DialogoMapa> {
  late LatLng _seleccion;
  final MapController _mapa = MapController();

  @override
  void initState() {
    super.initState();
    final tieneInicial = widget.latInicial != null && widget.lngInicial != null;
    _seleccion = tieneInicial
        ? LatLng(widget.latInicial!, widget.lngInicial!)
        : _centroPorDefecto;
  }

  @override
  void dispose() {
    _mapa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Ubicar en el mapa',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FlutterMap(
                mapController: _mapa,
                options: MapOptions(
                  initialCenter: _seleccion,
                  initialZoom: (widget.latInicial != null) ? 15 : 6,
                  onTap: (_, punto) => setState(() => _seleccion = punto),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.transportelogistica.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _seleccion,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_pin,
                          size: 44,
                          color: AppColors.peligro,
                        ),
                      ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Toca el mapa para mover el marcador.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Lat: ${_seleccion.latitude.toStringAsFixed(6)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Lng: ${_seleccion.longitude.toStringAsFixed(6)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Usar este punto'),
                        onPressed: () => Navigator.of(context).pop(
                          PuntoSeleccionado(
                            _seleccion.latitude,
                            _seleccion.longitude,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

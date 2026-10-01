import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../gps/services/seguimiento_gps.dart';

/// Mapa GPS del panel: última posición conocida por chofer.
///
/// Refresco manual (botón) por ahora; Realtime se verá más adelante.
class GpsAdminScreen extends ConsumerStatefulWidget {
  const GpsAdminScreen({super.key});

  @override
  ConsumerState<GpsAdminScreen> createState() => _GpsAdminScreenState();
}

class _GpsAdminScreenState extends ConsumerState<GpsAdminScreen> {
  Future<void> _recargar() async {
    ref.invalidate(ubicacionesRecientesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ubicacionesRecientesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo GPS'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _recargar,
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(mensajeError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (ultimas) {
          if (ultimas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('Aún no hay ubicaciones reportadas.'),
              ),
            );
          }
          final puntos = ultimas.values
              .map((u) => LatLng(u.lat, u.lng))
              .toList(growable: false);
          return FlutterMap(
            options: MapOptions(
              initialCenter: puntos.first,
              initialZoom: 11,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.transportelogistica.app',
              ),
              MarkerLayer(
                markers: [
                  for (final u in ultimas.values)
                    Marker(
                      point: LatLng(u.lat, u.lng),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.local_shipping,
                          color: AppColors.primary, size: 32),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

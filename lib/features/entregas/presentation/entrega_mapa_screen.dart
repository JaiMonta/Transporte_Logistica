import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../models/entrega.dart';
import '../providers/entregas_providers.dart';
import 'widgets/entrega_card.dart';

/// Mapa con los puntos de entrega de un manifiesto.
///
/// Reutilizable por el panel admin y por el chofer.
class EntregaMapaScreen extends ConsumerWidget {
  const EntregaMapaScreen({
    super.key,
    required this.manifiestoId,
    this.titulo = 'Mapa de la ruta',
  });

  final String manifiestoId;
  final String titulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(entregasDeManifiestoProvider(manifiestoId));
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(mensajeError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (entregas) => _Mapa(entregas: entregas),
      ),
    );
  }
}

class _Mapa extends StatelessWidget {
  const _Mapa({required this.entregas});

  final List<Entrega> entregas;

  static const LatLng _centroPorDefecto = LatLng(10.4806, -66.9036);

  @override
  Widget build(BuildContext context) {
    final conPuntos = entregas.where((e) => e.tieneUbicacion).toList();
    if (conPuntos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined,
                  size: 56, color: AppColors.onSurfaceVariant),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Ningún cliente de este manifiesto tiene coordenadas.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Asigna latitud/longitud a los clientes para verlos en el mapa.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    final puntos = conPuntos
        .map((e) => LatLng(e.lat!, e.lng!))
        .toList(growable: false);
    final centro = puntos.isEmpty
        ? _centroPorDefecto
        : LatLng(
            puntos.map((p) => p.latitude).reduce((a, b) => a + b) /
                puntos.length,
            puntos.map((p) => p.longitude).reduce((a, b) => a + b) /
                puntos.length,
          );

    return FlutterMap(
      options: MapOptions(initialCenter: centro, initialZoom: 12),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.transportelogistica.app',
        ),
        // Línea de la ruta en el orden de entrega.
        PolylineLayer(
          polylines: [
            Polyline(
              points: puntos,
              strokeWidth: 3,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < conPuntos.length; i++)
              Marker(
                point: LatLng(conPuntos[i].lat!, conPuntos[i].lng!),
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: _Marcador(
                  orden: conPuntos[i].orden + 1,
                  estado: conPuntos[i].estado,
                ),
              ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}

class _Marcador extends StatelessWidget {
  const _Marcador({required this.orden, required this.estado});

  final int orden;
  final EstadoEntrega estado;

  @override
  Widget build(BuildContext context) {
    final color = colorEstadoEntrega(estado);
    return Column(
      children: [
        Icon(Icons.location_pin, size: 34, color: color),
        Text(
          '$orden',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

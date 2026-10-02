import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/mapa_vista.dart';
import '../models/entrega.dart';
import '../providers/entregas_providers.dart';

/// Mapa agregado con las rutas de todas las entregas pendientes.
///
/// Cada manifiesto se dibuja con un color distinto. No requiere GPS.
class EntregasMapaAgregadoScreen extends ConsumerWidget {
  const EntregasMapaAgregadoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(entregasPendientesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas pendientes')),
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

  @override
  Widget build(BuildContext context) {
    final conPuntos = entregas.where((e) => e.tieneUbicacion).toList();
    if (conPuntos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No hay entregas pendientes con coordenadas.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    // Agrupa por manifiesto para pintar cada ruta de un color.
    final porManifiesto = <String, List<Entrega>>{};
    for (final e in conPuntos) {
      porManifiesto.putIfAbsent(e.manifiestoId, () => []).add(e);
    }

    final polilineas = <Polyline>[];
    final marcadores = <Marker>[];
    var indice = 0;
    for (final lista in porManifiesto.values) {
      lista.sort((a, b) => a.orden.compareTo(b.orden));
      final color = paletaRutas[indice % paletaRutas.length];
      polilineas.add(Polyline(
        points: lista.map((e) => LatLng(e.lat!, e.lng!)).toList(),
        strokeWidth: 3,
        color: color.withValues(alpha: 0.75),
      ));
      for (final e in lista) {
        marcadores.add(Marker(
          point: LatLng(e.lat!, e.lng!),
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: Icon(Icons.location_pin, size: 32, color: color),
        ));
      }
      indice++;
    }

    return MapaVista(
      polilineas: polilineas,
      marcadores: marcadores,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/mapa_vista.dart';
import '../../gps/services/seguimiento_gps.dart';

/// Mapa GPS del panel: última posición conocida por chofer.
///
/// Refresco manual (botón) por ahora; Realtime se verá más adelante.
class GpsAdminScreen extends ConsumerWidget {
  const GpsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ubicacionesRecientesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoreo GPS')),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_off,
                        size: 56, color: AppColors.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Aún no hay ubicaciones reportadas.'),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () =>
                          context.push(Rutas.adminEntregasMapa),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Ver rutas pendientes'),
                    ),
                  ],
                ),
              ),
            );
          }
          return MapaVista(
            marcadores: [
              for (final u in ultimas.values)
                Marker(
                  point: LatLng(u.lat, u.lng),
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.local_shipping,
                      color: AppColors.primary, size: 32),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.invalidate(ubicacionesRecientesProvider);
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Actualizar'),
      ),
    );
  }
}

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../services/sync_engine.dart';

/// Aviso superior cuando el dispositivo pierde la conexión o cuando hay
/// operaciones pendientes de sincronizar (solo móvil).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendientesAsync = ref.watch(pendientesProvider);
    final pendientes = pendientesAsync.value ?? 0;

    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final resultados = snapshot.data;
        final sinConexion = resultados != null &&
            resultados.isNotEmpty &&
            resultados.every((r) => r == ConnectivityResult.none);
        if (!sinConexion && pendientes == 0) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: AppColors.secondaryContainer,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                sinConexion ? Icons.cloud_off : Icons.cloud_upload_outlined,
                size: 18,
                color: AppColors.secondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  sinConexion
                      ? 'Sin conexión. Los cambios se sincronizarán automáticamente.'
                      : '$pendientes pendiente${pendientes == 1 ? '' : 's'} de sincronizar.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

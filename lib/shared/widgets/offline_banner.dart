import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Aviso superior cuando el dispositivo pierde la conexión.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final resultados = snapshot.data;
        final sinConexion = resultados != null &&
            resultados.isNotEmpty &&
            resultados.every((r) => r == ConnectivityResult.none);
        if (!sinConexion) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: AppColors.secondaryContainer,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, size: 18, color: AppColors.secondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Sin conexión. Los cambios se sincronizarán automáticamente.',
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

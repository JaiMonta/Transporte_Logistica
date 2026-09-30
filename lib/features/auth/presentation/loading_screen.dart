import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../providers/auth_providers.dart';

/// Pantalla de espera mientras se restaura la sesión y se carga el perfil.
class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentProfileProvider, (anterior, siguiente) {
      final perfil = siguiente.value;
      if (perfil != null && !perfil.activo) {
        ref.read(authControllerProvider.notifier).cerrarSesion();
      }
    });

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping, size: 56, color: AppColors.primary),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: AppSpacing.md),
            Text('Cargando…'),
          ],
        ),
      ),
    );
  }
}

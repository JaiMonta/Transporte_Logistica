import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../models/profile.dart';

/// Tarjeta de usuario para pantallas angostas (teléfono).
class UsuarioCard extends StatelessWidget {
  const UsuarioCard({
    super.key,
    required this.usuario,
    required this.onEditar,
    required this.onAlternarActivo,
    this.onRestablecer,
  });

  final Profile usuario;
  final ValueChanged<Profile> onEditar;
  final ValueChanged<Profile> onAlternarActivo;
  final ValueChanged<Profile>? onRestablecer;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    usuario.iniciales,
                    style: tema.textTheme.titleMedium
                        ?.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(usuario.nombreVisible,
                          style: tema.textTheme.titleMedium),
                      if (usuario.email != null) ...[
                        const SizedBox(height: 2),
                        Text(usuario.email!,
                            style: tema.textTheme.bodySmall),
                      ],
                      if (usuario.telefono != null &&
                          usuario.telefono!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined,
                                size: 14, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(usuario.telefono!,
                                style: tema.textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                StatusPill.rol(usuario.rol),
                StatusPill.activo(usuario.activo),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => onEditar(usuario),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
                const Spacer(),
                if (onRestablecer != null)
                  IconButton(
                    tooltip: 'Restablecer contraseña',
                    icon: const Icon(Icons.key_outlined),
                    onPressed: () => onRestablecer!(usuario),
                  ),
                TextButton.icon(
                  onPressed: () => onAlternarActivo(usuario),
                  icon: Icon(
                    usuario.activo
                        ? Icons.block_outlined
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(usuario.activo ? 'Desactivar' : 'Reactivar'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        usuario.activo ? AppColors.peligro : AppColors.exito,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

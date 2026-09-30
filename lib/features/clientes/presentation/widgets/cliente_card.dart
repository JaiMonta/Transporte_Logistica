import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../models/cliente.dart';

/// Tarjeta de cliente para pantallas angostas (teléfono).
class ClienteCard extends StatelessWidget {
  const ClienteCard({
    super.key,
    required this.cliente,
    required this.onEditar,
    required this.onAlternarActivo,
  });

  final Cliente cliente;
  final ValueChanged<Cliente> onEditar;
  final ValueChanged<Cliente> onAlternarActivo;

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
                    cliente.iniciales,
                    style: tema.textTheme.titleMedium
                        ?.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cliente.nombreVisible,
                          style: tema.textTheme.titleMedium),
                      if (cliente.nombreContacto != null &&
                          cliente.nombreContacto!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Contacto: ${cliente.nombreContacto}',
                            style: tema.textTheme.bodySmall),
                      ],
                      if (cliente.telefono != null &&
                          cliente.telefono!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined,
                                size: 14, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(cliente.telefono!,
                                style: tema.textTheme.bodySmall),
                          ],
                        ),
                      ],
                      if (cliente.direccion != null &&
                          cliente.direccion!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              cliente.tieneUbicacion
                                  ? Icons.location_on
                                  : Icons.location_off_outlined,
                              size: 14,
                              color: cliente.tieneUbicacion
                                  ? AppColors.tertiary
                                  : AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                cliente.direccion!,
                                style: tema.textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            StatusPill.activo(cliente.activo),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => onEditar(cliente),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => onAlternarActivo(cliente),
                  icon: Icon(
                    cliente.activo
                        ? Icons.block_outlined
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(cliente.activo ? 'Desactivar' : 'Reactivar'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        cliente.activo ? AppColors.peligro : AppColors.exito,
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

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../models/pickup.dart';

/// Color del estado de un pickup.
Color colorEstadoPickup(EstadoPickup estado) => switch (estado) {
  EstadoPickup.pendiente => AppColors.secondary,
  EstadoPickup.enCamino => AppColors.primary,
  EstadoPickup.completado => AppColors.exito,
  EstadoPickup.cancelado => AppColors.peligro,
};

/// Tarjeta de pickup para pantallas angostas (teléfono).
class PickupCard extends StatelessWidget {
  const PickupCard({
    super.key,
    required this.pickup,
    this.esAdmin = false,
    this.onEditar,
    this.onCancelar,
    this.onCambiarEstado,
  });

  final Pickup pickup;
  final bool esAdmin;
  final ValueChanged<Pickup>? onEditar;
  final ValueChanged<Pickup>? onCancelar;
  final void Function(Pickup pickup, EstadoPickup estado)? onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = colorEstadoPickup(pickup.estado);
    final finalizado =
        pickup.estado == EstadoPickup.completado ||
        pickup.estado == EstadoPickup.cancelado;

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
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(Icons.inventory_2_outlined, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickup.clienteVisible,
                        style: tema.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              pickup.cuandoTexto,
                              style: tema.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      if (pickup.direccion != null &&
                          pickup.direccion!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              pickup.tieneUbicacion
                                  ? Icons.location_on
                                  : Icons.location_off_outlined,
                              size: 14,
                              color: pickup.tieneUbicacion
                                  ? AppColors.tertiary
                                  : AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                pickup.direccion!,
                                style: tema.textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (esAdmin && pickup.choferNombre != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Chofer: ${pickup.choferNombre}',
                          style: tema.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (pickup.notas != null && pickup.notas!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(pickup.notas!, style: tema.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                StatusPill(texto: pickup.estado.etiqueta, color: color),
                if (pickup.camionPlaca != null)
                  StatusPill(
                    texto: pickup.camionPlaca!,
                    color: AppColors.onSurfaceVariant,
                  ),
              ],
            ),
            if (!finalizado) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (esAdmin && onEditar != null)
                    TextButton.icon(
                      onPressed: () => onEditar!(pickup),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                    ),
                  if (esAdmin && onCancelar != null)
                    TextButton.icon(
                      onPressed: () => onCancelar!(pickup),
                      icon: const Icon(Icons.block_outlined, size: 18),
                      label: const Text('Cancelar'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.peligro,
                      ),
                    ),
                  if (!esAdmin && onCambiarEstado != null) ...[
                    if (pickup.estado == EstadoPickup.pendiente)
                      FilledButton.icon(
                        onPressed: () =>
                            onCambiarEstado!(pickup, EstadoPickup.enCamino),
                        icon: const Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                        ),
                        label: const Text('En camino'),
                      ),
                    if (pickup.estado == EstadoPickup.pendiente ||
                        pickup.estado == EstadoPickup.enCamino)
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            onCambiarEstado!(pickup, EstadoPickup.completado),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Completado'),
                      ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../models/entrega.dart';

/// Color del estado de una entrega.
Color colorEstadoEntrega(EstadoEntrega estado) => switch (estado) {
      EstadoEntrega.entregado => AppColors.exito,
      EstadoEntrega.fallido => AppColors.peligro,
      EstadoEntrega.pendiente => AppColors.secondary,
    };

/// Tarjeta de entrega para pantallas angostas (teléfono).
class EntregaCard extends StatelessWidget {
  const EntregaCard({
    super.key,
    required this.entrega,
    required this.onEntregar,
    required this.onVerMapa,
    this.onAvisar,
    this.habilitado = true,
  });

  final Entrega entrega;
  final ValueChanged<Entrega> onEntregar;
  final ValueChanged<Entrega> onVerMapa;
  final ValueChanged<Entrega>? onAvisar;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final pendiente = entrega.estado == EstadoEntrega.pendiente;
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
                  backgroundColor: colorEstadoEntrega(entrega.estado)
                      .withValues(alpha: 0.14),
                  child: Text(
                    '${entrega.orden + 1}',
                    style: tema.textTheme.titleMedium
                        ?.copyWith(color: colorEstadoEntrega(entrega.estado)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entrega.clienteVisible,
                          style: tema.textTheme.titleMedium),
                      if (entrega.direccion != null &&
                          entrega.direccion!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              entrega.tieneUbicacion
                                  ? Icons.location_on
                                  : Icons.location_off_outlined,
                              size: 14,
                              color: entrega.tieneUbicacion
                                  ? AppColors.tertiary
                                  : AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                entrega.direccion!,
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
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                StatusPill(
                  texto: entrega.estado.etiqueta,
                  color: colorEstadoEntrega(entrega.estado),
                ),
                if (entrega.tieneFoto)
                  const StatusPill(
                      texto: 'Con recibo', color: AppColors.tertiary),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                if (entrega.tieneUbicacion)
                  TextButton.icon(
                    onPressed: () => onVerMapa(entrega),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Mapa'),
                  ),
                const Spacer(),
                if (onAvisar != null)
                  TextButton.icon(
                    onPressed: () => onAvisar!(entrega),
                    icon: const Icon(Icons.campaign_outlined, size: 18),
                    label: const Text('Avisar'),
                  ),
                if (pendiente && habilitado)
                  FilledButton.icon(
                    onPressed: () => onEntregar(entrega),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Entregado'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

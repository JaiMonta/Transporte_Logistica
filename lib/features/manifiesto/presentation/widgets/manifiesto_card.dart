import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../models/manifiesto.dart';

/// Tarjeta de manifiesto para pantallas angostas (teléfono).
class ManifiestoCard extends StatelessWidget {
  const ManifiestoCard({
    super.key,
    required this.manifiesto,
    required this.onVerDetalle,
  });

  final Manifiesto manifiesto;
  final ValueChanged<Manifiesto> onVerDetalle;

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
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: const Icon(Icons.description_outlined,
                      color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${manifiesto.totalDocumentos} documento(s)',
                        style: tema.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Primer doc.: ${manifiesto.primerDocumento}',
                        style: tema.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.event_outlined,
                              size: 14, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(_fechaTexto(manifiesto.fecha),
                              style: tema.textTheme.bodySmall),
                          if (manifiesto.tieneFoto) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(Icons.image_outlined,
                                size: 14, color: AppColors.tertiary),
                          ],
                        ],
                      ),
                      if (manifiesto.camionId != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined,
                                size: 14, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                manifiesto.camionVisible,
                                style: tema.textTheme.bodySmall,
                                maxLines: 1,
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
                _PillCotejo(estado: manifiesto.cotejo),
                if (manifiesto.confianzaPorcentaje != null)
                  StatusPill(
                    texto: 'OCR ${manifiesto.confianzaPorcentaje}%',
                    color: AppColors.primary,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onVerDetalle(manifiesto),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Ver detalle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillCotejo extends StatelessWidget {
  const _PillCotejo({required this.estado});

  final CotejoEstado estado;

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      CotejoEstado.ok => AppColors.exito,
      CotejoEstado.revision => AppColors.peligro,
      CotejoEstado.pendiente => AppColors.secondary,
    };
    return StatusPill(texto: estado.etiqueta, color: color);
  }
}

String _fechaTexto(DateTime fecha) {
  final mes = fecha.month.toString().padLeft(2, '0');
  final dia = fecha.day.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

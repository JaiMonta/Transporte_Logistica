import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../models/camion.dart';

/// Tarjeta de camión para pantallas angostas (teléfono).
class CamionCard extends StatelessWidget {
  const CamionCard({
    super.key,
    required this.camion,
    required this.onEditar,
    required this.onAlternarActivo,
  });

  final Camion camion;
  final ValueChanged<Camion> onEditar;
  final ValueChanged<Camion> onAlternarActivo;

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
                  child: const Icon(Icons.local_shipping,
                      color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(camion.marcaVisible,
                          style: tema.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('Placa: ${camion.placa}',
                          style: tema.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text('Chofer: ${camion.choferVisible}',
                          style: tema.textTheme.bodySmall),
                      Text(
                        '${camion.modelo ?? '—'}'
                        '${camion.anio == null ? '' : ' (${camion.anio})'} · '
                        '${_num(camion.capacidadKg)} kg · '
                        '${_num(camion.volumenM3)} m³',
                        style: tema.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            StatusPill.activo(camion.activo),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => onEditar(camion),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => onAlternarActivo(camion),
                  icon: Icon(
                    camion.activo
                        ? Icons.block_outlined
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(camion.activo ? 'Desactivar' : 'Reactivar'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        camion.activo ? AppColors.peligro : AppColors.exito,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _num(double? v) => v == null ? '—' : v.toStringAsFixed(2);
}

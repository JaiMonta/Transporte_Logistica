import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../models/pickup.dart';
import 'pickup_card.dart' show colorEstadoPickup;

/// Tabla de pickups para pantallas anchas.
class PickupTabla extends StatelessWidget {
  const PickupTabla({
    super.key,
    required this.pickups,
    this.esAdmin = false,
    this.onEditar,
    this.onCancelar,
    this.onCambiarEstado,
  });

  final List<Pickup> pickups;
  final bool esAdmin;
  final ValueChanged<Pickup>? onEditar;
  final ValueChanged<Pickup>? onCancelar;
  final void Function(Pickup pickup, EstadoPickup estado)? onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Cliente')),
          DataColumn(label: Text('Dirección')),
          DataColumn(label: Text('Chofer')),
          DataColumn(label: Text('Estimado')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: pickups.map((p) {
          final finalizado =
              p.estado == EstadoPickup.completado ||
              p.estado == EstadoPickup.cancelado;
          return DataRow(
            cells: [
              DataCell(Text(p.clienteVisible)),
              DataCell(
                Text(
                  (p.direccion == null || p.direccion!.isEmpty)
                      ? '—'
                      : p.direccion!,
                ),
              ),
              DataCell(Text(p.choferNombre ?? '—')),
              DataCell(Text(p.cuandoTexto)),
              DataCell(
                StatusPill(
                  texto: p.estado.etiqueta,
                  color: colorEstadoPickup(p.estado),
                ),
              ),
              DataCell(
                Row(
                  children: [
                    if (!finalizado) ...[
                      if (esAdmin && onEditar != null)
                        IconButton(
                          tooltip: 'Editar',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => onEditar!(p),
                        ),
                      if (esAdmin && onCancelar != null)
                        IconButton(
                          tooltip: 'Cancelar',
                          icon: const Icon(Icons.block_outlined),
                          color: AppColors.peligro,
                          onPressed: () => onCancelar!(p),
                        ),
                      if (!esAdmin && onCambiarEstado != null) ...[
                        if (p.estado == EstadoPickup.pendiente)
                          TextButton.icon(
                            onPressed: () =>
                                onCambiarEstado!(p, EstadoPickup.enCamino),
                            icon: const Icon(
                              Icons.local_shipping_outlined,
                              size: 18,
                            ),
                            label: const Text('En camino'),
                          ),
                        if (p.estado == EstadoPickup.pendiente ||
                            p.estado == EstadoPickup.enCamino)
                          TextButton.icon(
                            onPressed: () =>
                                onCambiarEstado!(p, EstadoPickup.completado),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                            ),
                            label: const Text('Completado'),
                          ),
                      ],
                    ] else
                      const Text('—'),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

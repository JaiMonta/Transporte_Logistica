import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../models/camion.dart';

/// Tabla de camiones para pantallas anchas.
class CamionTabla extends StatelessWidget {
  const CamionTabla({
    super.key,
    required this.camiones,
    required this.onEditar,
    required this.onAlternarActivo,
  });

  final List<Camion> camiones;
  final ValueChanged<Camion> onEditar;
  final ValueChanged<Camion> onAlternarActivo;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Marca')),
          DataColumn(label: Text('Placa')),
          DataColumn(label: Text('Modelo')),
          DataColumn(label: Text('Año')),
          DataColumn(label: Text('Capacidad')),
          DataColumn(label: Text('Volumen')),
          DataColumn(label: Text('Chofer')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: camiones.map((c) {
          return DataRow(
            cells: [
              DataCell(Text(c.marcaVisible)),
              DataCell(Text(c.placa)),
              DataCell(Text(
                (c.modelo == null || c.modelo!.isEmpty) ? '—' : c.modelo!,
              )),
              DataCell(Text(c.anio?.toString() ?? '—')),
              DataCell(Text(c.capacidadKg == null
                  ? '—'
                  : '${c.capacidadKg!.toStringAsFixed(0)} kg')),
              DataCell(Text(c.volumenM3 == null
                  ? '—'
                  : '${c.volumenM3!.toStringAsFixed(2)} m³')),
              DataCell(Text(c.choferVisible)),
              DataCell(StatusPill.activo(c.activo)),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEditar(c),
                    ),
                    IconButton(
                      tooltip: c.activo ? 'Desactivar' : 'Reactivar',
                      icon: Icon(
                        c.activo
                            ? Icons.block_outlined
                            : Icons.check_circle_outline,
                        color: c.activo ? AppColors.peligro : AppColors.exito,
                      ),
                      onPressed: () => onAlternarActivo(c),
                    ),
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

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../models/manifiesto.dart';

/// Tabla de manifiestos para pantallas anchas.
class ManifiestoTabla extends StatelessWidget {
  const ManifiestoTabla({
    super.key,
    required this.manifiestos,
    required this.onVerDetalle,
  });

  final List<Manifiesto> manifiestos;
  final ValueChanged<Manifiesto> onVerDetalle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Documentos')),
          DataColumn(label: Text('Primer doc.')),
          DataColumn(label: Text('Fecha')),
          DataColumn(label: Text('Capturó')),
          DataColumn(label: Text('OCR')),
          DataColumn(label: Text('Cotejo')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: manifiestos.map((m) {
          return DataRow(
            cells: [
              DataCell(Text('${m.totalDocumentos}')),
              DataCell(Text(m.primerDocumento)),
              DataCell(Text(_fechaTexto(m.fecha))),
              DataCell(Text(
                (m.capturadoPorNombre == null ||
                        m.capturadoPorNombre!.isEmpty)
                    ? '—'
                    : m.capturadoPorNombre!,
              )),
              DataCell(
                m.confianzaPorcentaje == null
                    ? const Text('—')
                    : Text('${m.confianzaPorcentaje}%'),
              ),
              DataCell(_EtiquetaCotejo(estado: m.cotejo)),
              DataCell(
                IconButton(
                  tooltip: 'Ver detalle',
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: () => onVerDetalle(m),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _EtiquetaCotejo extends StatelessWidget {
  const _EtiquetaCotejo({required this.estado});

  final CotejoEstado estado;

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      CotejoEstado.ok => AppColors.exito,
      CotejoEstado.revision => AppColors.peligro,
      CotejoEstado.pendiente => AppColors.secondary,
    };
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(estado.etiqueta),
      ],
    );
  }
}

String _fechaTexto(DateTime fecha) {
  final mes = fecha.month.toString().padLeft(2, '0');
  final dia = fecha.day.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

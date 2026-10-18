import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../entregas/models/entrega.dart';
import '../../models/bitacora.dart';
import '../../services/export_bitacora.dart';

Color colorEstadoBitacora(EstadoEntrega estado) => switch (estado) {
  EstadoEntrega.entregado => AppColors.exito,
  EstadoEntrega.fallido => AppColors.peligro,
  EstadoEntrega.pendiente => AppColors.secondary,
};

const List<String> _diasSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

String fechaCorta(DateTime f) {
  final dia = f.day.toString().padLeft(2, '0');
  final mes = f.month.toString().padLeft(2, '0');
  return '$dia/$mes/${f.year}';
}

String diaConNombre(DateTime f) =>
    '${_diasSemana[f.weekday - 1]}, ${fechaCorta(f)}';

String dinero(double? v) => v == null ? '—' : '\$ ${v.toStringAsFixed(2)}';

/// Vista agrupada (día → manifiesto → entregas) para pantallas angostas.
class BitacoraDias extends StatelessWidget {
  const BitacoraDias({super.key, required this.resumen});

  final BitacoraResumen resumen;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: resumen.dias.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (context, i) => _DiaVista(dia: resumen.dias[i]),
    );
  }
}

class _DiaVista extends StatelessWidget {
  const _DiaVista({required this.dia});

  final DiaBitacora dia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                diaConNombre(dia.fecha),
                style: tema.textTheme.titleLarge,
              ),
            ),
            Text(
              '${dia.manifiestos.length} viaje(s) · '
              '${dia.totalEntregas} entrega(s) · ${dinero(dia.totalFlete)}',
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final m in dia.manifiestos) ...[
          _ManifiestoVista(manifiesto: m),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ManifiestoVista extends StatelessWidget {
  const _ManifiestoVista({required this.manifiesto});

  final ManifiestoBitacora manifiesto;

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
                Expanded(
                  child: Text(
                    'Guía(s): ${manifiesto.guiasTexto}',
                    style: tema.textTheme.titleMedium,
                  ),
                ),
                Text(
                  dinero(manifiesto.fleteBase),
                  style: tema.textTheme.titleMedium?.copyWith(
                    color: AppColors.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Chofer: ${manifiesto.choferVisible} · '
              'Camión: ${manifiesto.camionPlaca ?? '—'} '
              '(${manifiesto.capacidadTexto})',
              style: tema.textTheme.bodySmall,
            ),
            const Divider(height: AppSpacing.md),
            for (final e in manifiesto.entregas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.cliente, style: tema.textTheme.bodyMedium),
                          Text(
                            '${e.destinoVisible} · ${e.regionVisible}',
                            style: tema.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      texto: e.estado.etiqueta,
                      color: colorEstadoBitacora(e.estado),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tabla plana (una fila por entrega) para pantallas anchas.
class BitacoraTabla extends StatelessWidget {
  const BitacoraTabla({super.key, required this.resumen});

  final BitacoraResumen resumen;

  @override
  Widget build(BuildContext context) {
    final filas = ExportBitacora.filas(resumen);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Chofer')),
            DataColumn(label: Text('N° Guía(s)')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Destino')),
            DataColumn(label: Text('Región')),
            DataColumn(label: Text('Cap.')),
            DataColumn(label: Text('Base de flete')),
          ],
          rows: [
            for (final f in filas)
              DataRow(
                cells: [
                  DataCell(Text(f.fecha)),
                  DataCell(Text(f.chofer)),
                  DataCell(Text(f.guias)),
                  DataCell(Text(f.cliente)),
                  DataCell(Text(f.destino)),
                  DataCell(Text(f.region)),
                  DataCell(Text(f.capacidad)),
                  DataCell(Text(dinero(f.flete))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Barra de totales.
class BitacoraTotales extends StatelessWidget {
  const BitacoraTotales({super.key, required this.resumen});

  final BitacoraResumen resumen;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        children: [
          Text(
            'Manifiestos: ${resumen.totalManifiestos}',
            style: tema.textTheme.labelLarge,
          ),
          Text(
            'Entregas: ${resumen.totalEntregas}',
            style: tema.textTheme.labelLarge,
          ),
          Text(
            'Total flete: ${dinero(resumen.totalFlete)}',
            style: tema.textTheme.labelLarge?.copyWith(
              color: AppColors.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

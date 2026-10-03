import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../models/factura.dart';
import '../providers/facturacion_providers.dart';

/// Detalle de una factura semanal con desglose por chofer e ítem.
class FacturaDetalleScreen extends ConsumerStatefulWidget {
  const FacturaDetalleScreen({super.key, required this.facturaId});

  final String facturaId;

  @override
  ConsumerState<FacturaDetalleScreen> createState() =>
      _FacturaDetalleScreenState();
}

class _FacturaDetalleScreenState extends ConsumerState<FacturaDetalleScreen> {
  bool _ocupado = false;

  void _refrescar() => ref.invalidate(facturaProvider(widget.facturaId));

  Future<void> _cambiarEstado(EstadoFactura estado) async {
    setState(() => _ocupado = true);
    try {
      await ref
          .read(facturacionRepositoryProvider)
          .cambiarEstado(id: widget.facturaId, estado: estado);
      if (!mounted) return;
      _refrescar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Factura marcada como ${estado.etiqueta}.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _rehacer(Factura f) async {
    setState(() => _ocupado = true);
    try {
      await ref
          .read(facturacionRepositoryProvider)
          .generarSemana(f.periodoInicio);
      if (!mounted) return;
      _refrescar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura rehecha.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(facturaProvider(widget.facturaId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de factura')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(mensajeError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (f) => f == null
            ? const Center(child: Text('No se encontró la factura.'))
            : _contenido(context, f),
      ),
    );
  }

  Widget _contenido(BuildContext context, Factura f) {
    final tema = Theme.of(context);
    // Desglose por chofer a partir de los ítems.
    final porChofer = <String, double>{};
    for (final it in f.items) {
      final k = it.usuarioId ?? 'sin-chofer';
      porChofer[k] = (porChofer[k] ?? 0) + it.monto;
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Semana ${f.periodoTexto}', style: tema.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text('Estado: ${f.estado.etiqueta}', style: tema.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        _resumen('Flete base', f.subtotalFlete),
        _resumen('Extras', f.subtotalExtras),
        _resumen('Total', f.total, destacar: true),
        const SizedBox(height: AppSpacing.lg),
        Text('Desglose por chofer', style: tema.textTheme.labelLarge),
        for (final e in porChofer.entries)
          _resumen(e.key == 'sin-chofer' ? 'Sin chofer' : e.key, e.value),
        const SizedBox(height: AppSpacing.lg),
        Text('Ítems (${f.items.length})', style: tema.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Concepto')),
              DataColumn(label: Text('Descripción')),
              DataColumn(label: Text('Monto')),
            ],
            rows: [
              for (final it in f.items)
                DataRow(cells: [
                  DataCell(Text(it.tipo?.etiqueta ?? _cap(it.concepto))),
                  DataCell(Text(it.descripcion ?? '—')),
                  DataCell(Text('\$${it.monto.toStringAsFixed(2)}')),
                ]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: _ocupado ? null : () => _rehacer(f),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Rehacer'),
            ),
            if (f.estado != EstadoFactura.pendiente)
              OutlinedButton.icon(
                onPressed: _ocupado
                    ? null
                    : () => _cambiarEstado(EstadoFactura.pendiente),
                icon: const Icon(Icons.hourglass_empty, size: 18),
                label: const Text('Marcar pendiente'),
              ),
            OutlinedButton.icon(
              onPressed: _ocupado
                  ? null
                  : () => _cambiarEstado(EstadoFactura.pagada),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.exito,
              ),
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Marcar pagada'),
            ),
            OutlinedButton.icon(
              onPressed: _ocupado
                  ? null
                  : () => _cambiarEstado(EstadoFactura.anulada),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.peligro,
              ),
              icon: const Icon(Icons.block, size: 18),
              label: const Text('Anular'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resumen(String etiqueta, double valor, {bool destacar = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(etiqueta,
                  style: TextStyle(
                    fontWeight: destacar ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
            Text('\$${valor.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: destacar ? FontWeight.w700 : FontWeight.w500,
                )),
          ],
        ),
      );

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

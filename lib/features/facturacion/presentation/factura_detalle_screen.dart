import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../fletes/models/extra.dart';
import '../models/factura.dart';
import '../providers/facturacion_providers.dart';

/// Detalle de una factura por empresa con desglose por producto y concepto.
class FacturaDetalleScreen extends ConsumerStatefulWidget {
  const FacturaDetalleScreen({super.key, required this.facturaId});

  final String facturaId;

  @override
  ConsumerState<FacturaDetalleScreen> createState() =>
      _FacturaDetalleScreenState();
}

class _FacturaDetalleScreenState extends ConsumerState<FacturaDetalleScreen> {
  bool _ocupado = false;

  void _refrescar() {
    ref.invalidate(facturaProvider(widget.facturaId));
    ref.invalidate(tasaUsdBsProvider);
  }

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
          .generar(f.periodoInicio, f.periodoFin);
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
    final tasa = ref.watch(tasaUsdBsProvider).value ?? 0;

    // Agrupa ítems por producto.
    final porProducto = <String, List<FacturaItem>>{};
    for (final it in f.items) {
      final k = (it.productoNombre?.trim().isNotEmpty ?? false)
          ? it.productoNombre!.trim()
          : 'Sin producto';
      porProducto.putIfAbsent(k, () => []).add(it);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(f.empresaVisible, style: tema.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text('Periodo ${f.periodoTexto}', style: tema.textTheme.bodyMedium),
        Text('Estado: ${f.estado.etiqueta}', style: tema.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        _resumen('Flete base', f.subtotalFlete, tasa: tasa),
        _resumen('Extras', f.subtotalExtras, tasa: tasa),
        _resumen('Total', f.total, destacar: true, tasa: tasa),
        const SizedBox(height: AppSpacing.lg),
        Text('Desglose por producto', style: tema.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        for (final entrada in porProducto.entries) ...[
          _ProductoBloque(
            producto: entrada.key,
            items: entrada.value,
            tasa: tasa,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.md),
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

  Widget _resumen(String etiqueta, double valor,
          {bool destacar = false, double tasa = 0}) =>
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${valor.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: destacar ? FontWeight.w700 : FontWeight.w500,
                    )),
                if (tasa > 0)
                  Text('Bs ${(valor * tasa).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      );
}

class _ProductoBloque extends StatelessWidget {
  const _ProductoBloque({
    required this.producto,
    required this.items,
    required this.tasa,
  });

  final String producto;
  final List<FacturaItem> items;
  final double tasa;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final total = items.fold<double>(0, (a, b) => a + b.monto);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(producto,
                      style: tema.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${total.toStringAsFixed(2)}',
                        style: tema.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (tasa > 0)
                      Text('Bs ${(total * tasa).toStringAsFixed(2)}',
                          style: tema.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            const Divider(height: AppSpacing.md),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _concepto(it),
                        style: tema.textTheme.bodyMedium,
                      ),
                    ),
                    Text('\$${it.monto.toStringAsFixed(2)}',
                        style: tema.textTheme.bodyMedium),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _concepto(FacturaItem it) {
    if (it.tipo == TipoExtra.caleta) return 'Flete secundario';
    return it.tipo?.etiqueta ?? _cap(it.concepto);
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

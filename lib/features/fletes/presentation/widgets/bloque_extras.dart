import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme.dart';
import '../../../../shared/errors/mensajes_error.dart';
import '../../models/extra.dart';
import '../../providers/fletes_providers.dart';

/// Bloque de extras de un manifiesto (panel admin).
///
/// Muestra el desglose por ítem, permite calcular sugeridos (según entregas),
/// aprobar/rechazar y editar montos. El total = flete base + extras aprobados.
class BloqueExtras extends ConsumerStatefulWidget {
  const BloqueExtras({
    super.key,
    required this.manifiestoId,
    required this.fleteBase,
    required this.onCalcularSugeridos,
  });

  final String manifiestoId;
  final double? fleteBase;
  final Future<void> Function() onCalcularSugeridos;

  @override
  ConsumerState<BloqueExtras> createState() => _BloqueExtrasState();
}

class _BloqueExtrasState extends ConsumerState<BloqueExtras> {
  bool _ocupado = false;

  void _refrescar() =>
      ref.invalidate(extrasDeManifiestoProvider(widget.manifiestoId));

  Future<void> _calcular() async {
    setState(() => _ocupado = true);
    try {
      await widget.onCalcularSugeridos();
      if (!mounted) return;
      _refrescar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cambiarEstado(Extra e, EstadoExtra estado) async {
    try {
      await ref
          .read(extrasRepositoryProvider)
          .cambiarEstado(id: e.id, estado: estado);
      if (!mounted) return;
      _refrescar();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(err))));
      }
    }
  }

  Future<void> _editarMonto(Extra e) async {
    final controller = TextEditingController(text: e.monto.toStringAsFixed(2));
    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Monto de ${e.tipo.etiqueta}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monto (USD)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (guardar != true) {
      controller.dispose();
      return;
    }
    try {
      final monto = double.tryParse(controller.text.replaceAll(',', '.'));
      if (monto != null) {
        await ref.read(extrasRepositoryProvider).actualizarMonto(
              id: e.id,
              monto: monto,
            );
      }
      if (!mounted) return;
      _refrescar();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(err))));
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _eliminar(Extra e) async {
    try {
      await ref.read(extrasRepositoryProvider).eliminar(e.id);
      if (!mounted) return;
      _refrescar();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(err))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final async = ref.watch(extrasDeManifiestoProvider(widget.manifiestoId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(mensajeError(e)),
      data: (extras) {
        final totalExtras = extras
            .where((e) => e.estado == EstadoExtra.aprobado)
            .fold(0.0, (a, e) => a + e.monto);
        final base = widget.fleteBase ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Extras (${extras.length})',
                    style: tema.textTheme.labelLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: _ocupado ? null : _calcular,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Calcular sugeridos'),
                ),
              ],
            ),
            if (extras.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text('Sin extras.'),
              ),
            for (final e in extras) _fila(tema, e),
            const Divider(),
            _resumen('Flete base', base),
            _resumen('Extras aprobados', totalExtras),
            _resumen('Total', base + totalExtras, destacar: true),
          ],
        );
      },
    );
  }

  Widget _fila(ThemeData tema, Extra e) {
    final color = switch (e.estado) {
      EstadoExtra.aprobado => AppColors.exito,
      EstadoExtra.rechazado => AppColors.peligro,
      EstadoExtra.sugerido => AppColors.secondary,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${e.tipo.etiqueta} · \$${e.monto.toStringAsFixed(2)}',
                    style: tema.textTheme.titleSmall),
              ),
              Text(e.estado.etiqueta,
                  style: tema.textTheme.labelSmall?.copyWith(color: color)),
            ],
          ),
          if (e.descripcion != null && e.descripcion!.isNotEmpty)
            Text(e.descripcion!, style: tema.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              if (e.estado != EstadoExtra.aprobado)
                TextButton(
                  onPressed: () => _cambiarEstado(e, EstadoExtra.aprobado),
                  child: const Text('Aprobar'),
                ),
              if (e.estado != EstadoExtra.rechazado)
                TextButton(
                  onPressed: () => _cambiarEstado(e, EstadoExtra.rechazado),
                  child: const Text('Rechazar'),
                ),
              TextButton(
                onPressed: () => _editarMonto(e),
                child: const Text('Editar'),
              ),
              TextButton(
                onPressed: () => _eliminar(e),
                style: TextButton.styleFrom(foregroundColor: AppColors.peligro),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ],
      ),
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
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../models/factura.dart';
import '../providers/facturacion_providers.dart';
import '../services/calculo_factura_semanal.dart';

/// Facturación semanal (panel admin): búsqueda por lapso y generación.
class FacturacionScreen extends ConsumerStatefulWidget {
  const FacturacionScreen({super.key});

  @override
  ConsumerState<FacturacionScreen> createState() => _FacturacionScreenState();
}

class _FacturacionScreenState extends ConsumerState<FacturacionScreen> {
  late FiltroFacturacion _filtro;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _filtro = FiltroFacturacion(
      desde: DateTime(hoy.year, hoy.month, 1),
      hasta: DateTime(hoy.year, hoy.month, 28),
    );
  }

  void _refrescar() => ref.invalidate(facturasProvider(_filtro));

  Future<void> _elegirLapso() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _filtro.desde, end: _filtro.hasta),
      helpText: 'Lapso',
      saveText: 'Aplicar',
    );
    if (rango == null) return;
    setState(() {
      _filtro = FiltroFacturacion(
        desde: rango.start,
        hasta: rango.end,
      );
    });
  }

  Future<void> _generarSemana() async {
    final semana = SemanaRange.deFecha(DateTime.now());
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar factura de la semana'),
        content: Text(
          'Se generará (o rehará) la factura del período '
          '${_f(semana.inicio)} – ${_f(semana.fin)} con los manifiestos '
          'que tengan entregas finalizadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _ocupado = true);
    try {
      await ref.read(facturacionRepositoryProvider).generarSemana(DateTime.now());
      if (!mounted) return;
      _refrescar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura de la semana generada.')),
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

  Future<void> _elegirFechaSemana() async {
    final fecha = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: 'Elige un día de la semana a facturar',
    );
    if (fecha == null) return;
    setState(() => _ocupado = true);
    try {
      await ref.read(facturacionRepositoryProvider).generarSemana(fecha);
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(facturasProvider(_filtro));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _elegirLapso,
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text('${_f(_filtro.desde)} – ${_f(_filtro.hasta)}'),
              ),
              FilledButton.icon(
                onPressed: _ocupado ? null : _generarSemana,
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Generar semana actual'),
              ),
              TextButton.icon(
                onPressed: _ocupado ? null : _elegirFechaSemana,
                icon: const Icon(Icons.event, size: 18),
                label: const Text('Otra semana…'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(mensajeError(e), textAlign: TextAlign.center),
              ),
            ),
            data: (facturas) => RefreshIndicator(
              onRefresh: () async => _refrescar(),
              child: facturas.isEmpty
                  ? const _VacioVista()
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: facturas.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => _FacturaCard(
                        factura: facturas[i],
                        onVer: () => context
                            .push(Rutas.adminFacturaDetalle(facturas[i].id)),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  static String _f(DateTime x) =>
      '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
}

class _FacturaCard extends StatelessWidget {
  const _FacturaCard({required this.factura, required this.onVer});

  final Factura factura;
  final VoidCallback onVer;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = switch (factura.estado) {
      EstadoFactura.emitida => AppColors.primary,
      EstadoFactura.pendiente => AppColors.secondary,
      EstadoFactura.cancelada => AppColors.peligro,
    };
    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text('Semana ${factura.periodoTexto}'),
        subtitle: Text(
          'Flete \$${factura.subtotalFlete.toStringAsFixed(2)} · '
          'Extras \$${factura.subtotalExtras.toStringAsFixed(2)}',
          style: tema.textTheme.bodySmall,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('\$${factura.total.toStringAsFixed(2)}',
                style: tema.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(factura.estado.etiqueta,
                style: tema.textTheme.labelSmall?.copyWith(color: color)),
          ],
        ),
        onTap: onVer,
      ),
    );
  }
}

class _VacioVista extends StatelessWidget {
  const _VacioVista();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.receipt_long_outlined,
            size: 56, color: AppColors.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text('No hay facturas en el lapso.',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text('Genera la factura semanal para verla aquí.',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

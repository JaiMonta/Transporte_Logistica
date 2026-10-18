import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../facturacion/services/semana_range.dart' show SemanaRange;
import '../models/bitacora.dart';
import '../providers/bitacora_providers.dart';
import '../services/export_bitacora.dart';
import 'widgets/bitacora_widgets.dart';

/// Bitácora (administrador): entregas por manifiesto de cada chofer por día.
class BitacoraScreen extends ConsumerStatefulWidget {
  const BitacoraScreen({super.key});

  @override
  ConsumerState<BitacoraScreen> createState() => _BitacoraScreenState();
}

class _BitacoraScreenState extends ConsumerState<BitacoraScreen> {
  late FiltroBitacora _filtro;

  @override
  void initState() {
    super.initState();
    final semana = SemanaRange.deFecha(DateTime.now());
    _filtro = FiltroBitacora(desde: semana.inicio, hasta: semana.fin);
  }

  void _snack(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  void _moverSemana(int delta) {
    final base = SemanaRange.deFecha(_filtro.desde);
    final inicio = base.inicio.add(Duration(days: 7 * delta));
    setState(() {
      _filtro = _filtro.copyWith(
        desde: inicio,
        hasta: inicio.add(const Duration(days: 6)),
      );
    });
  }

  Future<void> _elegirRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _filtro.desde, end: _filtro.hasta),
    );
    if (rango == null) return;
    setState(
      () => _filtro = _filtro.copyWith(desde: rango.start, hasta: rango.end),
    );
  }

  Future<void> _exportarPdf(BitacoraResumen resumen) async {
    try {
      await ExportBitacora.compartirPdf(resumen);
    } catch (e) {
      _snack(mensajeError(e));
    }
  }

  void _exportarCsv(BitacoraResumen resumen) {
    final ok = ExportBitacora.descargarCsv(resumen);
    if (!ok) {
      _snack('El CSV se descarga desde la versión web. En móvil usa el PDF.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bitacoraProvider(_filtro));
    final resumen = async.value;

    return Column(
      children: [
        _controles(resumen),
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorVista(
              mensaje: mensajeError(e),
              onReintentar: () => ref.invalidate(bitacoraProvider(_filtro)),
            ),
            data: (r) => r.vacio
                ? const _VacioVista()
                : Column(
                    children: [
                      Expanded(
                        child: ResponsiveLayout(
                          breakpoint: 900,
                          movil: BitacoraDias(resumen: r),
                          ancho: BitacoraTabla(resumen: r),
                        ),
                      ),
                      BitacoraTotales(resumen: r),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _controles(BitacoraResumen? resumen) {
    final hay = resumen != null && !resumen.vacio;
    final choferes = ref.watch(
      choferesBitacoraProvider((desde: _filtro.desde, hasta: _filtro.hasta)),
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Semana anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _moverSemana(-1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'DESDE ${fechaCorta(_filtro.desde)}   '
                      'HASTA ${fechaCorta(_filtro.hasta)}',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Semana siguiente',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _moverSemana(1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _elegirRango,
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: const Text('Rango'),
              ),
              _SelectorChofer(
                valor: _filtro.choferId,
                choferes: choferes.value ?? const [],
                onCambio: (v) =>
                    setState(() => _filtro = _filtro.copyWith(choferId: v)),
              ),
              FilledButton.tonalIcon(
                onPressed: hay ? () => _exportarPdf(resumen) : null,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('PDF'),
              ),
              FilledButton.tonalIcon(
                onPressed: hay ? () => _exportarCsv(resumen) : null,
                icon: const Icon(Icons.table_view_outlined, size: 18),
                label: const Text('CSV'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectorChofer extends StatelessWidget {
  const _SelectorChofer({
    required this.valor,
    required this.choferes,
    required this.onCambio,
  });

  final String? valor;
  final List<({String id, String nombre})> choferes;
  final ValueChanged<String?> onCambio;

  @override
  Widget build(BuildContext context) {
    final valido = choferes.any((c) => c.id == valor) ? valor : null;
    return SizedBox(
      width: 240,
      child: DropdownButtonFormField<String?>(
        initialValue: valido,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Chofer'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Todos los choferes'),
          ),
          ...choferes.map(
            (c) => DropdownMenuItem<String?>(
              value: c.id,
              child: Text(c.nombre, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: onCambio,
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
        const Icon(
          Icons.menu_book_outlined,
          size: 56,
          color: AppColors.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            'No hay movimientos en este lapso.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            'Ajusta el lapso o el chofer.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ErrorVista extends StatelessWidget {
  const _ErrorVista({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../models/manifiesto.dart';
import '../providers/manifiestos_providers.dart';
import 'widgets/manifiesto_card.dart';
import 'widgets/manifiesto_tabla.dart';

/// Lista de manifiestos con búsqueda por nº PRO y rango de fechas.
/// Tarjetas en teléfono, tabla en pantalla ancha.
class ManifiestosScreen extends ConsumerStatefulWidget {
  const ManifiestosScreen({super.key});

  @override
  ConsumerState<ManifiestosScreen> createState() => _ManifiestosScreenState();
}

class _ManifiestosScreenState extends ConsumerState<ManifiestosScreen> {
  final _busqueda = TextEditingController();
  Timer? _debounce;
  FiltroManifiestos _filtro = const FiltroManifiestos();

  @override
  void dispose() {
    _debounce?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  void _onBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _filtro = _filtro.copyWith(busqueda: texto));
    });
  }

  void _refrescar() => ref.invalidate(manifiestosProvider(_filtro));

  void _verDetalle(Manifiesto m) =>
      context.push(Rutas.adminManifiestoDetalle(m.id));

  Future<void> _elegirRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: (_filtro.desde != null && _filtro.hasta != null)
          ? DateTimeRange(start: _filtro.desde!, end: _filtro.hasta!)
          : null,
      helpText: 'Rango de fechas',
      saveText: 'Aplicar',
    );
    if (rango == null) return;
    setState(() {
      _filtro = _filtro.copyWith(desde: rango.start, hasta: rango.end);
    });
  }

  void _limpiarRango() {
    setState(() => _filtro = _filtro.copyWith(desde: null, hasta: null));
  }

  Future<void> _purgarAntiguos() async {
    final repo = ref.read(manifiestosRepositoryProvider);
    try {
      final conteo = await repo.purgarAntiguos(dryRun: true);
      if (!mounted) return;
      if (conteo == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay manifiestos validados para purgar.'),
          ),
        );
        return;
      }
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Purgar manifiestos antiguos'),
          content: Text(
            'Se eliminarán $conteo manifiesto(s) validados con más de 3 meses '
            '(y sus líneas y fotos). Esta acción no se puede deshacer.\n\n'
            'No se tocan los pendientes ni los de revisión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Purgar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;

      final borrados = await repo.purgarAntiguos(dryRun: false);
      if (!mounted) return;
      _refrescar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se purgaron $borrados manifiesto(s).')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(manifiestosProvider(_filtro));
    final tieneRango = _filtro.desde != null || _filtro.hasta != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _busqueda,
                label: 'Buscar',
                hint: 'Número PRO',
                icono: Icons.search,
                onChanged: _onBuscar,
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
                    label: Text(_textoRango()),
                  ),
                  if (tieneRango)
                    TextButton.icon(
                      onPressed: _limpiarRango,
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Limpiar fechas'),
                    ),
                  TextButton.icon(
                    onPressed: _purgarAntiguos,
                    icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                    label: const Text('Purgar antiguos'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorVista(
              mensaje: mensajeError(e),
              onReintentar: _refrescar,
            ),
            data: (manifiestos) => RefreshIndicator(
              onRefresh: () async => _refrescar(),
              child: manifiestos.isEmpty
                  ? const _VacioVista()
                  : ResponsiveLayout(
                      breakpoint: 820,
                      movil: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: manifiestos.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) => ManifiestoCard(
                          manifiesto: manifiestos[i],
                          onVerDetalle: _verDetalle,
                        ),
                      ),
                      ancho: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: ManifiestoTabla(
                          manifiestos: manifiestos,
                          onVerDetalle: _verDetalle,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  String _textoRango() {
    if (_filtro.desde == null && _filtro.hasta == null) return 'Todas las fechas';
    final d = _filtro.desde;
    final h = _filtro.hasta;
    String f(DateTime? x) => x == null ? '…' : _fechaCorta(x);
    return '${f(d)} – ${f(h)}';
  }

  static String _fechaCorta(DateTime x) {
    final mes = x.month.toString().padLeft(2, '0');
    final dia = x.day.toString().padLeft(2, '0');
    return '$dia/$mes/${x.year}';
  }
}

class _VacioVista extends StatelessWidget {
  const _VacioVista();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.description_outlined,
            size: 56, color: AppColors.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text('No se encontraron manifiestos.',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text('Ajusta la búsqueda o el rango de fechas.',
              style: Theme.of(context).textTheme.bodySmall),
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

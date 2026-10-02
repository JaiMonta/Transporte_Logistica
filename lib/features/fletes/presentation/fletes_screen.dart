import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/tabulador_flete.dart';
import '../providers/fletes_providers.dart';

/// Catálogo de fletes (tabulador) con búsqueda por localidad/región.
class FletesScreen extends ConsumerStatefulWidget {
  const FletesScreen({super.key});

  @override
  ConsumerState<FletesScreen> createState() => _FletesScreenState();
}

class _FletesScreenState extends ConsumerState<FletesScreen> {
  final _busqueda = TextEditingController();
  Timer? _debounce;
  FiltroFletes _filtro = const FiltroFletes();

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

  void _editar(TabuladorFlete f) =>
      context.push(Rutas.adminFleteEditar(f.id));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tabuladorProvider(_filtro));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppTextField(
            controller: _busqueda,
            label: 'Buscar',
            hint: 'Localidad o región',
            icono: Icons.search,
            onChanged: _onBuscar,
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
            data: (fletes) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(tabuladorProvider(_filtro)),
              child: fletes.isEmpty
                  ? const _VacioVista()
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: fletes.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => _FleteCard(
                        flete: fletes[i],
                        onEditar: _editar,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FleteCard extends StatelessWidget {
  const _FleteCard({required this.flete, required this.onEditar});

  final TabuladorFlete flete;
  final ValueChanged<TabuladorFlete> onEditar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_shipping_outlined),
        title: Text(flete.localidadVisible),
        subtitle: Text(
          '${flete.region ?? '—'} · KM ${flete.km?.toStringAsFixed(0) ?? '—'}',
          style: tema.textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => onEditar(flete),
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
        const Icon(Icons.request_quote_outlined,
            size: 56, color: AppColors.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text('No se encontraron localidades.',
              style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

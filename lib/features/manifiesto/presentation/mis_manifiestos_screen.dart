import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../models/manifiesto.dart';
import '../providers/manifiestos_providers.dart';
import 'widgets/manifiesto_card.dart';
import 'widgets/manifiesto_tabla.dart';

/// Lista de manifiestos del chofer ("Mis manifiestos").
///
/// La RLS ya limita las filas a las del usuario; solo se filtra por fecha.
class MisManifiestosScreen extends ConsumerStatefulWidget {
  const MisManifiestosScreen({super.key});

  @override
  ConsumerState<MisManifiestosScreen> createState() =>
      _MisManifiestosScreenState();
}

class _MisManifiestosScreenState extends ConsumerState<MisManifiestosScreen> {
  final FiltroManifiestos _filtro = const FiltroManifiestos();

  void _verDetalle(Manifiesto m) =>
      context.push(Rutas.choferManifiestoDetalle(m.id));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(manifiestosProvider(_filtro));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis manifiestos'),
        leading: IconButton(
          tooltip: 'Atrás',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Rutas.choferHome),
        ),
        actions: [
          IconButton(
            tooltip: 'Capturar manifiesto',
            icon: const Icon(Icons.add_a_photo_outlined),
            onPressed: () => context.push(Rutas.choferCapturaManifiesto),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(mensajeError(e), textAlign: TextAlign.center),
                ),
              ),
              data: (manifiestos) => RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(manifiestosProvider(_filtro)),
                child: manifiestos.isEmpty
                    ? const _VacioVista()
                    : ResponsiveLayout(
                        breakpoint: 760,
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Rutas.choferCapturaManifiesto),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Capturar'),
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
        const Icon(Icons.description_outlined,
            size: 56, color: AppColors.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text('Aún no has capturado manifiestos.',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text('Usa el botón para capturar el primero.',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

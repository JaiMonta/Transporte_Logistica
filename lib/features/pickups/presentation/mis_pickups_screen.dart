import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../models/pickup.dart';
import '../providers/pickups_providers.dart';
import 'widgets/pickup_card.dart';

/// Modo de la lista de pickups del chofer.
enum _Modo { pendientes, hoy, todas }

/// Pickups del chofer (lista en vivo + "En camino" / "Completado").
class MisPickupsScreen extends ConsumerStatefulWidget {
  const MisPickupsScreen({super.key});

  @override
  ConsumerState<MisPickupsScreen> createState() => _MisPickupsScreenState();
}

class _MisPickupsScreenState extends ConsumerState<MisPickupsScreen> {
  _Modo _modo = _Modo.pendientes;

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _cambiarEstado(Pickup pickup, EstadoPickup estado) async {
    try {
      await ref
          .read(pickupsRepositoryProvider)
          .cambiarEstado(id: pickup.id, estado: estado);
      _avisar(
        estado == EstadoPickup.enCamino
            ? 'Marcado "En camino".'
            : 'Pickup completado.',
      );
    } catch (e) {
      _avisar(mensajeError(e));
    }
  }

  List<Pickup> _filtrar(List<Pickup> pickups) {
    final hoy = DateTime.now();
    return pickups.where((p) {
      switch (_modo) {
        case _Modo.pendientes:
          return p.estado == EstadoPickup.pendiente ||
              p.estado == EstadoPickup.enCamino;
        case _Modo.hoy:
          final f = p.fechaEstimada;
          return f != null &&
              f.year == hoy.year &&
              f.month == hoy.month &&
              f.day == hoy.day;
        case _Modo.todas:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pickupsRealtimeProvider, (prev, next) {
      final antes = prev?.value ?? const <Pickup>[];
      final ahora = next.value ?? const <Pickup>[];
      final ids = {for (final p in antes) p.id};
      for (final p in ahora) {
        if (!ids.contains(p.id) && p.estado == EstadoPickup.pendiente) {
          _avisar('Nuevo pickup asignado: ${p.clienteVisible}.');
        }
      }
    });

    final async = ref.watch(pickupsRealtimeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickups'),
        leading: IconButton(
          tooltip: 'Atrás',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Rutas.choferHome),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                _chip('Pendientes', _Modo.pendientes),
                _chip('Hoy', _Modo.hoy),
                _chip('Todas', _Modo.todas),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(mensajeError(e), textAlign: TextAlign.center),
                ),
              ),
              data: (todos) {
                final pickups = _filtrar(todos);
                if (pickups.isEmpty) return const _VacioVista();
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(pickupsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: pickups.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => PickupCard(
                      pickup: pickups[i],
                      esAdmin: false,
                      onCambiarEstado: _cambiarEstado,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String texto, _Modo modo) => ChoiceChip(
    label: Text(texto),
    selected: _modo == modo,
    onSelected: (_) => setState(() => _modo = modo),
  );
}

class _VacioVista extends StatelessWidget {
  const _VacioVista();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.inventory_2_outlined,
          size: 56,
          color: AppColors.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            'No tienes pickups en este lapso.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            'El administrador te asignará los pickups.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

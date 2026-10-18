import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../models/pickup.dart';
import '../providers/pickups_providers.dart';
import 'widgets/pickup_card.dart';
import 'widgets/pickup_tabla.dart';

/// Panel admin de pickups: crea/asigna, ve el estado en vivo y cancela.
class PickupsAdminScreen extends ConsumerStatefulWidget {
  const PickupsAdminScreen({super.key});

  @override
  ConsumerState<PickupsAdminScreen> createState() => _PickupsAdminScreenState();
}

class _PickupsAdminScreenState extends ConsumerState<PickupsAdminScreen> {
  EstadoPickup? _estado;
  bool _soloHoy = false;

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  List<Pickup> _filtrar(List<Pickup> pickups) {
    final hoy = DateTime.now();
    return pickups.where((p) {
      if (_estado != null && p.estado != _estado) return false;
      if (_soloHoy) {
        final f = p.fechaEstimada;
        if (f == null ||
            f.year != hoy.year ||
            f.month != hoy.month ||
            f.day != hoy.day) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _cancelar(Pickup pickup) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar pickup?'),
        content: Text(
          'Se cancelará el pickup de "${pickup.clienteVisible}". '
          'Se conserva por trazabilidad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ref
          .read(pickupsRepositoryProvider)
          .cambiarEstado(id: pickup.id, estado: EstadoPickup.cancelado);
      _avisar('Pickup cancelado.');
    } catch (e) {
      _avisar(mensajeError(e));
    }
  }

  void _editar(Pickup pickup) =>
      context.push(Rutas.adminPickupEditar(pickup.id));

  @override
  Widget build(BuildContext context) {
    ref.listen(pickupsRealtimeProvider, (prev, next) {
      final antes = prev?.value ?? const <Pickup>[];
      final ahora = next.value ?? const <Pickup>[];
      final mapa = {for (final p in antes) p.id: p};
      for (final p in ahora) {
        final a = mapa[p.id];
        if (a == null || a.estado == p.estado) continue;
        if (p.estado == EstadoPickup.enCamino) {
          _avisar('${p.clienteVisible} marcó "En camino".');
        } else if (p.estado == EstadoPickup.completado) {
          _avisar('${p.clienteVisible} fue completado.');
        }
      }
    });

    final async = ref.watch(pickupsRealtimeProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _chipEstado('Todos', null),
              _chipEstado('Pendientes', EstadoPickup.pendiente),
              _chipEstado('En camino', EstadoPickup.enCamino),
              _chipEstado('Completados', EstadoPickup.completado),
              FilterChip(
                label: const Text('Solo hoy'),
                selected: _soloHoy,
                onSelected: (v) => setState(() => _soloHoy = v),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorVista(mensaje: mensajeError(e)),
            data: (todos) {
              final pickups = _filtrar(todos);
              if (pickups.isEmpty) return const _VacioVista();
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(pickupsProvider),
                child: ResponsiveLayout(
                  breakpoint: 820,
                  movil: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: pickups.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => PickupCard(
                      pickup: pickups[i],
                      esAdmin: true,
                      onEditar: _editar,
                      onCancelar: _cancelar,
                    ),
                  ),
                  ancho: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: PickupTabla(
                      pickups: pickups,
                      esAdmin: true,
                      onEditar: _editar,
                      onCancelar: _cancelar,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chipEstado(String texto, EstadoPickup? estado) => ChoiceChip(
    label: Text(texto),
    selected: _estado == estado,
    onSelected: (_) => setState(() => _estado = estado),
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
            'No hay pickups para mostrar.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            'Crea un pickup para asignarlo a un chofer.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ErrorVista extends StatelessWidget {
  const _ErrorVista({required this.mensaje});

  final String mensaje;

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
          ],
        ),
      ),
    );
  }
}

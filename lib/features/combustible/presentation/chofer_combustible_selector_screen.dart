import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../manifiesto/providers/manifiestos_providers.dart';

/// Selector de manifiesto para ver/cerrar su jornada de combustible.
class ChoferCombustibleSelectorScreen extends ConsumerWidget {
  const ChoferCombustibleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(manifiestosProvider(const FiltroManifiestos()));
    return Scaffold(
      appBar: AppBar(title: const Text('Combustible')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(mensajeError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (manifiestos) => manifiestos.isEmpty
            ? const Center(child: Text('No hay manifiestos.'))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: manifiestos.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final m = manifiestos[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_gas_station_outlined),
                      title: Text('${m.totalDocumentos} documento(s)'),
                      subtitle: Text(
                        '${m.fecha.day.toString().padLeft(2, '0')}/'
                        '${m.fecha.month.toString().padLeft(2, '0')}/${m.fecha.year}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.go(Rutas.choferCombustible(m.id)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

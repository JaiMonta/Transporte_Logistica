import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../manifiesto/providers/manifiestos_providers.dart';

/// Selector de manifiesto del dÃ­a para ver su mapa de entregas (chofer).
class ChoferMapaSelectorScreen extends ConsumerWidget {
  const ChoferMapaSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(manifiestosProvider(const FiltroManifiestos()));
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de la ruta')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(mensajeError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (manifiestos) => manifiestos.isEmpty
            ? const Center(child: Text('No hay manifiestos para mostrar.'))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: manifiestos.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final m = manifiestos[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text('${m.totalDocumentos} documento(s)'),
                      subtitle: Text(
                        '${m.fecha.day.toString().padLeft(2, '0')}/'
                        '${m.fecha.month.toString().padLeft(2, '0')}/${m.fecha.year}',
                      ),
                      trailing: const Icon(Icons.map_outlined),
                      onTap: () =>
                          context.push(Rutas.choferEntregaMapa(m.id)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

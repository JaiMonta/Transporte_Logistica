import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cliente.dart';
import '../../providers/clientes_providers.dart';

/// Selector reutilizable de clientes activos (Módulos 4, 5 y 6).
class ClienteSelector extends ConsumerWidget {
  const ClienteSelector({
    super.key,
    required this.valor,
    required this.onCambio,
    this.habilitado = true,
  });

  final String? valor;
  final ValueChanged<String?> onCambio;
  final bool habilitado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientesActivosProvider);
    return async.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(labelText: 'Cliente'),
        child: SizedBox(
          height: 24,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (e, _) => InputDecorator(
        decoration: const InputDecoration(labelText: 'Cliente'),
        child: Text('No se pudieron cargar los clientes: $e'),
      ),
      data: (clientes) {
        final valorValido =
            clientes.any((c) => c.id == valor) ? valor : null;
        return DropdownButtonFormField<String>(
          initialValue: valorValido,
          decoration: const InputDecoration(labelText: 'Cliente'),
          items: clientes
              .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.nombreVisible, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: habilitado ? onCambio : null,
        );
      },
    );
  }
}

/// Utilidad para construir un selector a partir de una lista ya cargada.
List<DropdownMenuItem<String>> itemsDeClientes(List<Cliente> clientes) =>
    clientes
        .map((c) => DropdownMenuItem(
              value: c.id,
              child: Text(c.nombreVisible, overflow: TextOverflow.ellipsis),
            ))
        .toList();

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/clientes_repository.dart';
import '../models/cliente.dart';

final clientesRepositoryProvider = Provider<ClientesRepository>(
  (ref) => ClientesRepository(ref.watch(supabaseProvider)),
);

/// Filtro de búsqueda de la lista de clientes.
class FiltroClientes {
  const FiltroClientes({this.busqueda = '', this.activo});

  final String busqueda;
  final bool? activo;

  FiltroClientes copyWith({
    String? busqueda,
    Object? activo = _sinCambio,
  }) =>
      FiltroClientes(
        busqueda: busqueda ?? this.busqueda,
        activo: activo == _sinCambio ? this.activo : activo as bool?,
      );

  static const Object _sinCambio = Object();

  @override
  bool operator ==(Object other) =>
      other is FiltroClientes &&
      other.busqueda == busqueda &&
      other.activo == activo;

  @override
  int get hashCode => Object.hash(busqueda, activo);
}

/// Lista de clientes según el filtro.
final clientesProvider =
    FutureProvider.autoDispose.family<List<Cliente>, FiltroClientes>(
  (ref, filtro) => ref.watch(clientesRepositoryProvider).listar(
        busqueda: filtro.busqueda,
        activo: filtro.activo,
      ),
);

/// Un cliente por id (para la pantalla de edición).
final clienteProvider =
    FutureProvider.autoDispose.family<Cliente?, String>((ref, id) {
  return ref.watch(clientesRepositoryProvider).obtener(id);
});

/// Clientes activos para selectores reutilizables (Módulos 4, 5, 6).
final clientesActivosProvider =
    FutureProvider.autoDispose<List<Cliente>>((ref) {
  return ref.watch(clientesRepositoryProvider).listar(activo: true);
});

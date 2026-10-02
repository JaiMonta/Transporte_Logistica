import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/camiones_repository.dart';
import '../models/camion.dart';

final camionesRepositoryProvider = Provider<CamionesRepository>(
  (ref) => CamionesRepository(ref.watch(supabaseProvider)),
);

/// Filtro de búsqueda de la lista de camiones.
class FiltroCamiones {
  const FiltroCamiones({this.busqueda = '', this.activo});

  final String busqueda;
  final bool? activo;

  FiltroCamiones copyWith({
    String? busqueda,
    Object? activo = _sinCambio,
  }) =>
      FiltroCamiones(
        busqueda: busqueda ?? this.busqueda,
        activo: activo == _sinCambio ? this.activo : activo as bool?,
      );

  static const Object _sinCambio = Object();

  @override
  bool operator ==(Object other) =>
      other is FiltroCamiones &&
      other.busqueda == busqueda &&
      other.activo == activo;

  @override
  int get hashCode => Object.hash(busqueda, activo);
}

/// Lista de camiones según el filtro.
final camionesProvider =
    FutureProvider.autoDispose.family<List<Camion>, FiltroCamiones>(
  (ref, filtro) => ref.watch(camionesRepositoryProvider).listar(
        busqueda: filtro.busqueda,
        activo: filtro.activo,
      ),
);

/// Un camión por id (para la pantalla de edición).
final camionProvider =
    FutureProvider.autoDispose.family<Camion?, String>((ref, id) {
  return ref.watch(camionesRepositoryProvider).obtener(id);
});

/// Camiones activos para selectores reutilizables.
final camionesActivosProvider =
    FutureProvider.autoDispose<List<Camion>>((ref) {
  return ref.watch(camionesRepositoryProvider).listar(activo: true);
});

/// Choferes activos para asignar a un camión.
final choferesActivosProvider =
    FutureProvider.autoDispose<List<({String id, String nombre})>>((ref) async {
  final data = await ref
      .watch(supabaseProvider)
      .from('profiles')
      .select('id, nombre, email')
      .eq('rol', 'chofer')
      .eq('activo', true)
      .order('nombre', ascending: true) as List<dynamic>;
  return data.map((e) {
    final m = Map<String, dynamic>.from(e as Map);
    final nombre = (m['nombre'] as String?)?.trim();
    return (
      id: m['id'] as String,
      nombre: (nombre == null || nombre.isEmpty)
          ? (m['email'] as String? ?? 'Chofer')
          : nombre,
    );
  }).toList();
});

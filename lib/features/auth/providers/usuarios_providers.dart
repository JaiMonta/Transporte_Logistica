import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/usuarios_repository.dart';
import '../models/profile.dart';

final usuariosRepositoryProvider = Provider<UsuariosRepository>(
  (ref) => UsuariosRepository(ref.watch(supabaseProvider)),
);

/// Filtro de búsqueda de la lista de usuarios.
class FiltroUsuarios {
  const FiltroUsuarios({this.busqueda = '', this.rol, this.activo});

  final String busqueda;
  final Rol? rol;
  final bool? activo;

  FiltroUsuarios copyWith({
    String? busqueda,
    Object? rol = _sinCambio,
    Object? activo = _sinCambio,
  }) =>
      FiltroUsuarios(
        busqueda: busqueda ?? this.busqueda,
        rol: rol == _sinCambio ? this.rol : rol as Rol?,
        activo: activo == _sinCambio ? this.activo : activo as bool?,
      );

  static const Object _sinCambio = Object();

  @override
  bool operator ==(Object other) =>
      other is FiltroUsuarios &&
      other.busqueda == busqueda &&
      other.rol == rol &&
      other.activo == activo;

  @override
  int get hashCode => Object.hash(busqueda, rol, activo);
}

/// Lista de usuarios según el filtro (con búsqueda y filtros por rol/estado).
final usuariosProvider =
    FutureProvider.autoDispose.family<List<Profile>, FiltroUsuarios>(
  (ref, filtro) => ref.watch(usuariosRepositoryProvider).listar(
        busqueda: filtro.busqueda,
        rol: filtro.rol,
        activo: filtro.activo,
      ),
);

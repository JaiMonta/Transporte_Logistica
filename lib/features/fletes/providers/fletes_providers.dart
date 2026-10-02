import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/fletes_repository.dart';
import '../models/tabulador_flete.dart';

final fletesRepositoryProvider = Provider<FletesRepository>(
  (ref) => FletesRepository(ref.watch(supabaseProvider)),
);

/// Filtro de búsqueda del tabulador.
class FiltroFletes {
  const FiltroFletes({this.busqueda = ''});

  final String busqueda;

  FiltroFletes copyWith({String? busqueda}) =>
      FiltroFletes(busqueda: busqueda ?? this.busqueda);

  @override
  bool operator ==(Object other) =>
      other is FiltroFletes && other.busqueda == busqueda;

  @override
  int get hashCode => busqueda.hashCode;
}

/// Lista del tabulador según el filtro.
final tabuladorProvider =
    FutureProvider.autoDispose.family<List<TabuladorFlete>, FiltroFletes>(
  (ref, filtro) =>
      ref.watch(fletesRepositoryProvider).listar(busqueda: filtro.busqueda),
);

/// Un flete (localidad) por id.
final fleteProvider =
    FutureProvider.autoDispose.family<TabuladorFlete?, String>((ref, id) {
  return ref.watch(fletesRepositoryProvider).obtener(id);
});

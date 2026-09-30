import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/manifiestos_repository.dart';
import '../data/ocr_repository.dart';
import '../models/manifiesto.dart';

final manifiestosRepositoryProvider = Provider<ManifiestosRepository>(
  (ref) => ManifiestosRepository(ref.watch(supabaseProvider)),
);

final ocrRepositoryProvider = Provider<OcrRepository>(
  (ref) => OcrRepository(ref.watch(supabaseProvider)),
);

/// Filtro de búsqueda de manifiestos (nº PRO y rango de fechas).
class FiltroManifiestos {
  const FiltroManifiestos({this.busqueda = '', this.desde, this.hasta});

  final String busqueda;
  final DateTime? desde;
  final DateTime? hasta;

  FiltroManifiestos copyWith({
    String? busqueda,
    Object? desde = _sinCambio,
    Object? hasta = _sinCambio,
  }) =>
      FiltroManifiestos(
        busqueda: busqueda ?? this.busqueda,
        desde: desde == _sinCambio ? this.desde : desde as DateTime?,
        hasta: hasta == _sinCambio ? this.hasta : hasta as DateTime?,
      );

  static const Object _sinCambio = Object();

  @override
  bool operator ==(Object other) =>
      other is FiltroManifiestos &&
      other.busqueda == busqueda &&
      other.desde == desde &&
      other.hasta == hasta;

  @override
  int get hashCode => Object.hash(busqueda, desde, hasta);
}

/// Lista de manifiestos según el filtro.
final manifiestosProvider =
    FutureProvider.autoDispose.family<List<Manifiesto>, FiltroManifiestos>(
  (ref, filtro) => ref.watch(manifiestosRepositoryProvider).listar(
        busqueda: filtro.busqueda,
        desde: filtro.desde,
        hasta: filtro.hasta,
      ),
);

/// Un manifiesto por id (para la pantalla de detalle).
final manifiestoProvider =
    FutureProvider.autoDispose.family<Manifiesto?, String>((ref, id) {
  return ref.watch(manifiestosRepositoryProvider).obtener(id);
});

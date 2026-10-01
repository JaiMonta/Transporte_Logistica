import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/entregas_repository.dart';
import '../models/entrega.dart';

final entregasRepositoryProvider = Provider<EntregasRepository>(
  (ref) => EntregasRepository(ref.watch(supabaseProvider)),
);

/// Filtro por fecha (día) para la lista de entregas.
class FiltroEntregas {
  const FiltroEntregas({required this.dia});

  final DateTime dia;

  @override
  bool operator ==(Object other) =>
      other is FiltroEntregas &&
      other.dia.year == dia.year &&
      other.dia.month == dia.month &&
      other.dia.day == dia.day;

  @override
  int get hashCode => Object.hash(dia.year, dia.month, dia.day);
}

/// Entregas del día.
final entregasDelDiaProvider =
    FutureProvider.autoDispose.family<List<Entrega>, FiltroEntregas>(
  (ref, filtro) => ref.watch(entregasRepositoryProvider).delDia(filtro.dia),
);

/// Entregas de un manifiesto.
final entregasDeManifiestoProvider =
    FutureProvider.autoDispose.family<List<Entrega>, String>(
  (ref, manifiestoId) =>
      ref.watch(entregasRepositoryProvider).porManifiesto(manifiestoId),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/combustible_repository.dart';
import '../models/combustible_jornada.dart';

final combustibleRepositoryProvider = Provider<CombustibleRepository>(
  (ref) => CombustibleRepository(ref.watch(supabaseProvider)),
);

/// Jornada de combustible de un manifiesto.
final combustibleDeManifiestoProvider = FutureProvider.autoDispose
    .family<CombustibleJornada?, String>(
  (ref, manifiestoId) =>
      ref.watch(combustibleRepositoryProvider).porManifiesto(manifiestoId),
);

/// Lista de jornadas de combustible (panel admin).
final combustibleListaProvider =
    FutureProvider.autoDispose<List<CombustibleJornada>>(
  (ref) => ref.watch(combustibleRepositoryProvider).listar(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/entregas_repository.dart';
import '../models/entrega.dart';

final entregasRepositoryProvider = Provider<EntregasRepository>(
  (ref) => EntregasRepository(ref.watch(supabaseProvider)),
);

/// Modo de la lista de entregas.
enum ModoEntregas { hoy, pendientes, todas }

/// Filtro de la lista de entregas (modo + día de referencia).
class FiltroEntregas {
  const FiltroEntregas({
    required this.dia,
    this.modo = ModoEntregas.pendientes,
  });

  final DateTime dia;
  final ModoEntregas modo;

  FiltroEntregas copyWith({DateTime? dia, ModoEntregas? modo}) => FiltroEntregas(
        dia: dia ?? this.dia,
        modo: modo ?? this.modo,
      );

  @override
  bool operator ==(Object other) =>
      other is FiltroEntregas &&
      other.dia.year == dia.year &&
      other.dia.month == dia.month &&
      other.dia.day == dia.day &&
      other.modo == modo;

  @override
  int get hashCode => Object.hash(dia.year, dia.month, dia.day, modo);
}

/// Entregas según el filtro (modo + día).
final entregasDelDiaProvider =
    FutureProvider.autoDispose.family<List<Entrega>, FiltroEntregas>(
  (ref, filtro) {
    final repo = ref.watch(entregasRepositoryProvider);
    return switch (filtro.modo) {
      ModoEntregas.hoy => repo.delDia(filtro.dia),
      ModoEntregas.pendientes => repo.pendientes(),
      ModoEntregas.todas => repo.todas(),
    };
  },
);

/// Entregas de un manifiesto.
final entregasDeManifiestoProvider =
    FutureProvider.autoDispose.family<List<Entrega>, String>(
  (ref, manifiestoId) =>
      ref.watch(entregasRepositoryProvider).porManifiesto(manifiestoId),
);

/// Entregas pendientes agregadas (mapa del panel).
final entregasPendientesProvider =
    FutureProvider.autoDispose<List<Entrega>>(
  (ref) => ref.watch(entregasRepositoryProvider).pendientes(),
);

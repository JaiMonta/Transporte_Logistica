import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/bitacora_repository.dart';
import '../models/bitacora.dart';

final bitacoraRepositoryProvider = Provider<BitacoraRepository>(
  (ref) => BitacoraRepository(ref.watch(supabaseProvider)),
);

/// Filtro de la Bitácora (lapso + chofer opcional).
class FiltroBitacora {
  const FiltroBitacora({
    required this.desde,
    required this.hasta,
    this.choferId,
  });

  final DateTime desde;
  final DateTime hasta;
  final String? choferId;

  FiltroBitacora copyWith({
    DateTime? desde,
    DateTime? hasta,
    Object? choferId = _sinCambio,
  }) => FiltroBitacora(
    desde: desde ?? this.desde,
    hasta: hasta ?? this.hasta,
    choferId: choferId == _sinCambio ? this.choferId : choferId as String?,
  );

  static const Object _sinCambio = Object();

  @override
  bool operator ==(Object other) =>
      other is FiltroBitacora &&
      other.desde == desde &&
      other.hasta == hasta &&
      other.choferId == choferId;

  @override
  int get hashCode => Object.hash(desde, hasta, choferId);
}

/// Bitácora del lapso (agrupada por día).
final bitacoraProvider = FutureProvider.autoDispose
    .family<BitacoraResumen, FiltroBitacora>(
      (ref, filtro) => ref
          .watch(bitacoraRepositoryProvider)
          .cargar(
            desde: filtro.desde,
            hasta: filtro.hasta,
            choferId: filtro.choferId,
          ),
    );

/// Choferes con manifiestos en el lapso (para el filtro).
final choferesBitacoraProvider = FutureProvider.autoDispose
    .family<
      List<({String id, String nombre})>,
      ({DateTime desde, DateTime hasta})
    >(
      (ref, rango) => ref
          .watch(bitacoraRepositoryProvider)
          .choferesDelLapso(rango.desde, rango.hasta),
    );

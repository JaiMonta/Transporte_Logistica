import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/pickups_repository.dart';
import '../models/pickup.dart';

final pickupsRepositoryProvider = Provider<PickupsRepository>(
  (ref) => PickupsRepository(ref.watch(supabaseProvider)),
);

/// Filtro de la lista de pickups.
class FiltroPickups {
  const FiltroPickups({this.choferId, this.estado, this.fecha});

  final String? choferId;
  final EstadoPickup? estado;
  final DateTime? fecha;

  FiltroPickups copyWith({
    Object? choferId = _sinCambio,
    Object? estado = _sinCambio,
    Object? fecha = _sinCambio,
  }) => FiltroPickups(
    choferId: choferId == _sinCambio ? this.choferId : choferId as String?,
    estado: estado == _sinCambio ? this.estado : estado as EstadoPickup?,
    fecha: fecha == _sinCambio ? this.fecha : fecha as DateTime?,
  );

  static const Object _sinCambio = Object();

  @override
  bool operator ==(Object other) =>
      other is FiltroPickups &&
      other.choferId == choferId &&
      other.estado == estado &&
      other.fecha?.year == fecha?.year &&
      other.fecha?.month == fecha?.month &&
      other.fecha?.day == fecha?.day;

  @override
  int get hashCode => Object.hash(
    choferId,
    estado,
    fecha == null ? null : DateTime(fecha!.year, fecha!.month, fecha!.day),
  );
}

/// Lista de pickups según el filtro.
final pickupsProvider = FutureProvider.autoDispose
    .family<List<Pickup>, FiltroPickups>(
      (ref, filtro) => ref
          .watch(pickupsRepositoryProvider)
          .listar(
            choferId: filtro.choferId,
            estado: filtro.estado,
            fecha: filtro.fecha,
          ),
    );

/// Un pickup por id (para la pantalla de edición).
final pickupProvider = FutureProvider.autoDispose.family<Pickup?, String>((
  ref,
  id,
) {
  return ref.watch(pickupsRepositoryProvider).obtener(id);
});

/// Flujo en vivo (Realtime) de pickups para el usuario (RLS).
final pickupsRealtimeProvider = StreamProvider.autoDispose<List<Pickup>>(
  (ref) => ref.watch(pickupsRepositoryProvider).stream(),
);

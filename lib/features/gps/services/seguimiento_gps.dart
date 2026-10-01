import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ubicaciones_repository.dart';
import '../../../shared/services/gps_tracker.dart';
import '../../../shared/services/offline_manager.dart' show PuntoGps;
import '../../../core/supabase_client.dart';

/// Envío periódico de ubicación (primer plano).
///
/// Cada [intervalo] (20 min por defecto) toma una posición con [GpsTracker]
/// y la envía a `ubicaciones_gps`. Si falla (sin red), se agenda el siguiente
/// ciclo (el búfer local del Módulo 3 queda disponible para reintentos).
class SeguimientoGps {
  SeguimientoGps(this._tracker, this._repo);

  final GpsTracker _tracker;
  final UbicacionesRepository _repo;

  static const Duration intervalo = Duration(minutes: 20);

  Timer? _temporizador;
  bool _activo = false;
  String? _manifiestoId;

  bool get activo => _activo;

  /// Inicia el seguimiento. Envía una posición de inmediato y luego cada
  /// [intervalo].
  Future<bool> iniciar({String? manifiestoId}) async {
    if (_activo) return true;
    _manifiestoId = manifiestoId;

    // Primer envío inmediato (si hay permiso).
    final ok = await _tracker.capturarUnaVez();
    if (ok == null) return false;
    await _enviar(ok);

    _temporizador?.cancel();
    _temporizador = Timer.periodic(intervalo, (_) => _ciclo());
    _activo = true;
    return true;
  }

  Future<void> _ciclo() async {
    final punto = await _tracker.capturarUnaVez();
    if (punto != null) await _enviar(punto);
  }

  Future<void> _enviar(PuntoGps punto) async {
    try {
      await _repo.registrar(
        lat: punto.lat,
        lng: punto.lng,
        precision: punto.precision,
        manifiestoId: _manifiestoId,
        capturadoEn: punto.capturadoEn,
      );
    } catch (_) {
      // Sin conexión: se ignora; el siguiente ciclo reintenta.
    }
  }

  void detener() {
    _temporizador?.cancel();
    _temporizador = null;
    _activo = false;
    _manifiestoId = null;
  }
}

final ubicacionesRepositoryProvider = Provider<UbicacionesRepository>(
  (ref) => UbicacionesRepository(ref.watch(supabaseProvider)),
);

/// Última posición conocida por usuario (para el mapa del panel).
final ubicacionesRecientesProvider = FutureProvider.autoDispose<
    Map<String, ({double lat, double lng, DateTime? cuando})>>(
  (ref) => ref.watch(ubicacionesRepositoryProvider).ultimasPorUsuario(),
);

final seguimientoGpsProvider = Provider<SeguimientoGps>((ref) {
  final servicio = SeguimientoGps(
    ref.watch(gpsTrackerProvider),
    ref.watch(ubicacionesRepositoryProvider),
  );
  ref.onDispose(servicio.detener);
  return servicio;
});

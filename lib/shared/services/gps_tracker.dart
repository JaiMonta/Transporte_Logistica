import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'offline_manager.dart';
import 'sync_engine.dart';

/// Resultado de intentar capturar una posición.
enum EstadoCaptura { ok, sinPermiso, servicioApagado, noDisponible, error }

/// Captura de una posición con su estado (motivo si no se pudo).
class ResultadoCaptura {
  const ResultadoCaptura(this.estado, [this.punto]);

  final EstadoCaptura estado;
  final PuntoGps? punto;

  bool get ok => estado == EstadoCaptura.ok && punto != null;
}

/// Servicio de geolocalización con búfer local.
///
/// Captura posiciones y las guarda en el búfer local (solo móvil) para
/// enviarlas cuando haya conexión. El tracking en vivo en segundo plano
/// se implementará en un módulo posterior.
class GpsTracker {
  GpsTracker(this._manager);

  final OfflineManager _manager;

  StreamSubscription<Position>? _suscripcion;
  bool _activo = false;

  bool get activo => _activo;
  bool get disponible => _manager.disponible;

  /// Pide permisos y comienza a capturar posiciones.
  Future<bool> iniciar({
    LocationAccuracy precision = LocationAccuracy.high,
    int distanciaMetros = 10,
  }) async {
    if (!disponible || _activo) return _activo;

    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      return false;
    }

    _suscripcion = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: precision,
        distanceFilter: distanciaMetros,
      ),
    ).listen((posicion) async {
      await _manager.guardarPunto(
        PuntoGps(
          lat: posicion.latitude,
          lng: posicion.longitude,
          precision: posicion.accuracy,
          capturadoEn: posicion.timestamp,
        ),
      );
    });

    _activo = true;
    return true;
  }

  /// Toma una única posición y la guarda en el búfer.
  ///
  /// Verifica el servicio de ubicación y **pide el permiso** si hace falta;
  /// ante un timeout usa la última posición conocida.
  Future<ResultadoCaptura> capturar() async {
    if (!disponible) {
      return const ResultadoCaptura(EstadoCaptura.noDisponible);
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const ResultadoCaptura(EstadoCaptura.servicioApagado);
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return const ResultadoCaptura(EstadoCaptura.sinPermiso);
      }

      Position? posicion;
      try {
        posicion = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 30),
          ),
        );
      } on TimeoutException {
        posicion = await Geolocator.getLastKnownPosition();
      }
      if (posicion == null) {
        return const ResultadoCaptura(EstadoCaptura.error);
      }

      final punto = PuntoGps(
        lat: posicion.latitude,
        lng: posicion.longitude,
        precision: posicion.accuracy,
        capturadoEn: posicion.timestamp,
      );
      await _manager.guardarPunto(punto);
      return ResultadoCaptura(EstadoCaptura.ok, punto);
    } catch (_) {
      return const ResultadoCaptura(EstadoCaptura.error);
    }
  }

  void detener() {
    _suscripcion?.cancel();
    _suscripcion = null;
    _activo = false;
  }
}

final gpsTrackerProvider = Provider<GpsTracker>((ref) {
  final tracker = GpsTracker(ref.watch(offlineManagerProvider));
  ref.onDispose(tracker.detener);
  return tracker;
});

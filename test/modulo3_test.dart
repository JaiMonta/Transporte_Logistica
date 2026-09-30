import 'package:app_logistica/shared/services/offline_manager.dart';
import 'package:app_logistica/shared/services/sync_engine.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('esperaReintento (backoff exponencial)', () {
    test('crece con el número de intentos', () {
      expect(esperaReintento(0), const Duration(seconds: 2));
      expect(esperaReintento(1), const Duration(seconds: 4));
      expect(esperaReintento(2), const Duration(seconds: 8));
      expect(esperaReintento(3), const Duration(seconds: 16));
    });

    test('tiene un tope máximo de 5 minutos', () {
      expect(esperaReintento(20).inMinutes, 5);
      expect(esperaReintento(100).inMinutes, 5);
    });

    test('nunca es negativa', () {
      expect(esperaReintento(-5).inSeconds, greaterThan(0));
    });
  });

  group('hayConexion', () {
    test('false cuando es "none" o vacío', () {
      expect(hayConexion(const []), isFalse);
      expect(
        hayConexion(const [ConnectivityResult.none]),
        isFalse,
      );
    });

    test('true cuando hay alguna conexión distinta de "none"', () {
      expect(
        hayConexion(const [ConnectivityResult.wifi]),
        isTrue,
      );
      expect(
        hayConexion(const [ConnectivityResult.none, ConnectivityResult.mobile]),
        isTrue,
      );
    });
  });

  group('ElementoCola', () {
    test('clave de idempotencia estable', () {
      const elemento = ElementoCola(
        entidad: 'entregas',
        entidadId: 'abc',
        accion: AccionSync.crear,
      );
      expect(elemento.claveIdempotencia, 'entregas|abc|crear');
    });

    test('serializa y recupera el payload', () {
      final elemento = ElementoCola(
        entidad: 'entregas',
        entidadId: 'abc',
        accion: AccionSync.actualizar,
        payload: const {'estado': 'entregado', 'secuencia': 3},
      );
      final recuperado = ElementoCola.desdeFila(elemento.aFila());
      expect(recuperado.entidad, 'entregas');
      expect(recuperado.entidadId, 'abc');
      expect(recuperado.accion, AccionSync.actualizar);
      expect(recuperado.payload['estado'], 'entregado');
      expect(recuperado.payload['secuencia'], 3);
    });

    test('copyWith conserva valores y actualiza estado', () {
      const elemento = ElementoCola(
        id: 1,
        entidad: 'entregas',
        entidadId: 'abc',
        accion: AccionSync.crear,
      );
      final fallido = elemento.copyWith(
        estado: EstadoCola.fallido,
        intentos: 2,
        ultimoError: 'timeout',
      );
      expect(fallido.id, 1);
      expect(fallido.entidad, 'entregas');
      expect(fallido.estado, EstadoCola.fallido);
      expect(fallido.intentos, 2);
      expect(fallido.ultimoError, 'timeout');
    });
  });

  group('PuntoGps', () {
    test('serializa y recupera coordenadas', () {
      final punto = PuntoGps(
        lat: 10.4806,
        lng: -66.9036,
        precision: 5.5,
        capturadoEn: DateTime(2026, 9, 30, 12),
      );
      final recuperado = PuntoGps.desdeFila(punto.aFila());
      expect(recuperado.lat, 10.4806);
      expect(recuperado.lng, -66.9036);
      expect(recuperado.precision, 5.5);
      expect(recuperado.enviado, isFalse);
    });
  });
}

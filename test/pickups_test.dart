import 'package:app_logistica/features/pickups/models/pickup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EstadoPickup', () {
    test('desde mapea los valores guardados y por defecto', () {
      expect(EstadoPickup.desde('pendiente'), EstadoPickup.pendiente);
      expect(EstadoPickup.desde('en_camino'), EstadoPickup.enCamino);
      expect(EstadoPickup.desde('completado'), EstadoPickup.completado);
      expect(EstadoPickup.desde('cancelado'), EstadoPickup.cancelado);
      expect(EstadoPickup.desde(null), EstadoPickup.pendiente);
      expect(EstadoPickup.desde('x'), EstadoPickup.pendiente);
    });

    test('valor serializa en_camino con guion bajo', () {
      expect(EstadoPickup.enCamino.valor, 'en_camino');
      expect(EstadoPickup.pendiente.valor, 'pendiente');
    });

    test('cada estado tiene etiqueta', () {
      for (final e in EstadoPickup.values) {
        expect(e.etiqueta, isNotEmpty);
      }
    });
  });

  group('Pickup', () {
    test('fromMap interpreta joins de cliente, chofer y camión', () {
      final p = Pickup.fromMap({
        'id': 'p1',
        'chofer_id': 'u1',
        'cliente_id': 'c1',
        'direccion': 'Av. Bolívar, Valencia',
        'lat': 10.17,
        'lng': -68.0,
        'fecha_estimada': '2026-10-18',
        'hora_estimada': '09:30:00',
        'estado': 'en_camino',
        'clientes': {'nombre': 'Distribuidora del Centro'},
        'profiles': {'nombre': 'Pedro Pérez', 'email': 'p@x.com'},
        'camiones': {'placa': 'ABC123'},
      });
      expect(p.choferId, 'u1');
      expect(p.choferNombre, 'Pedro Pérez');
      expect(p.clienteVisible, 'Distribuidora del Centro');
      expect(p.camionPlaca, 'ABC123');
      expect(p.estado, EstadoPickup.enCamino);
      expect(p.tieneUbicacion, isTrue);
      expect(p.horaTexto, '09:30');
      expect(p.cuandoTexto, '18/10/2026 09:30');
    });

    test('clienteVisible cae al texto libre', () {
      const p = Pickup(
        id: 'p2',
        choferId: 'u1',
        clienteTexto: 'Cliente de la guía',
      );
      expect(p.clienteVisible, 'Cliente de la guía');
    });

    test('cuandoTexto sin fecha ni hora usa texto por defecto', () {
      const p = Pickup(id: 'p3', choferId: 'u1');
      expect(p.cuandoTexto, 'Sin hora estimada');
      expect(p.horaTexto, isNull);
    });

    test('tieneUbicacion es falso sin coords o fuera de rango', () {
      const sin = Pickup(id: 'p4', choferId: 'u1');
      expect(sin.tieneUbicacion, isFalse);
      const fuera = Pickup(id: 'p5', choferId: 'u1', lat: 120, lng: 0);
      expect(fuera.tieneUbicacion, isFalse);
    });

    test('copyWith conserva id y cambia el estado', () {
      const base = Pickup(id: 'p6', choferId: 'u1');
      final copia = base.copyWith(estado: EstadoPickup.completado);
      expect(copia.id, 'p6');
      expect(copia.choferId, 'u1');
      expect(copia.estado, EstadoPickup.completado);
    });

    test('choferNombre cae al email cuando no hay nombre', () {
      final p = Pickup.fromMap({
        'id': 'p7',
        'chofer_id': 'u1',
        'profiles': {'email': 'p@x.com'},
      });
      expect(p.choferNombre, 'p@x.com');
    });
  });
}

import 'package:app_logistica/features/entregas/models/entrega.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Entrega', () {
    test('fromMap interpreta campos y cliente del catálogo', () {
      final e = Entrega.fromMap({
        'id': 'e1',
        'manifiesto_id': 'm1',
        'linea_id': 'l1',
        'cliente_id': 'c1',
        'direccion': 'Av. Bolívar, Caracas',
        'lat': 10.48,
        'lng': -66.90,
        'orden': 2,
        'estado': 'entregado',
        'clientes': {'nombre': 'Distribuidora del Centro'},
      });
      expect(e.manifiestoId, 'm1');
      expect(e.clienteVisible, 'Distribuidora del Centro');
      expect(e.tieneUbicacion, isTrue);
      expect(e.estado, EstadoEntrega.entregado);
      expect(e.orden, 2);
    });

    test('clienteVisible cae al texto libre', () {
      const e = Entrega(
        id: 'e2',
        manifiestoId: 'm1',
        clienteTexto: 'Cliente de la guía',
      );
      expect(e.clienteVisible, 'Cliente de la guía');
    });

    test('tieneUbicacion es falso sin coords o fuera de rango', () {
      const sin = Entrega(id: 'e3', manifiestoId: 'm1');
      expect(sin.tieneUbicacion, isFalse);

      const fuera = Entrega(
          id: 'e4', manifiestoId: 'm1', lat: 120, lng: 0);
      expect(fuera.tieneUbicacion, isFalse);
    });

    test('estado desconocido cae a pendiente', () {
      final e = Entrega.fromMap({
        'id': 'e5',
        'manifiesto_id': 'm1',
        'estado': 'x',
      });
      expect(e.estado, EstadoEntrega.pendiente);
    });

    test('copyWith conserva id y manifiesto', () {
      const base = Entrega(id: 'e6', manifiestoId: 'm1');
      final copia = base.copyWith(estado: EstadoEntrega.fallido);
      expect(copia.id, 'e6');
      expect(copia.manifiestoId, 'm1');
      expect(copia.estado, EstadoEntrega.fallido);
    });
  });

  group('EstadoEntrega', () {
    test('desde mapea valores conocidos y por defecto', () {
      expect(EstadoEntrega.desde('entregado'), EstadoEntrega.entregado);
      expect(EstadoEntrega.desde('fallido'), EstadoEntrega.fallido);
      expect(EstadoEntrega.desde(null), EstadoEntrega.pendiente);
    });

    test('cada estado tiene etiqueta', () {
      for (final e in EstadoEntrega.values) {
        expect(e.etiqueta, isNotEmpty);
      }
    });
  });
}

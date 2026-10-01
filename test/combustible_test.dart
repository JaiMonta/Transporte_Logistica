import 'package:app_logistica/features/combustible/models/combustible_jornada.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalculoCombustible.distanciaKm', () {
    test('dos puntos iguales dan 0', () {
      expect(CalculoCombustible.distanciaKm(10.0, -66.0, 10.0, -66.0), 0);
    });

    test('distancia conocida aproximada (Caracas->Valencia ~ 150 km)', () {
      // Aproximación geográfica; se valida un rango amplio.
      final d = CalculoCombustible.distanciaKm(10.4806, -66.9036, 10.1620, -68.0077);
      expect(d, greaterThan(120));
      expect(d, lessThan(180));
    });

    test('kmDeRuta suma segmentos', () {
      final km = CalculoCombustible.kmDeRuta([
        (lat: 10.0, lng: -66.0),
        (lat: 10.0, lng: -66.1),
        (lat: 10.0, lng: -66.2),
      ]);
      final segmento = CalculoCombustible.distanciaKm(10.0, -66.0, 10.0, -66.1);
      expect(km, closeTo(segmento * 2, 0.001));
    });

    test('kmDeRuta con menos de 2 puntos es 0', () {
      expect(CalculoCombustible.kmDeRuta([]), 0);
      expect(CalculoCombustible.kmDeRuta([(lat: 1.0, lng: 1.0)]), 0);
    });
  });

  group('CalculoCombustible consumo', () {
    test('teórico = km * rendimiento', () {
      expect(CalculoCombustible.consumoTeorico(100), closeTo(32.0, 0.0001));
      expect(
        CalculoCombustible.consumoTeorico(100, rendimiento: 0.5),
        closeTo(50.0, 0.0001),
      );
    });

    test('real = inicial + recargas - final', () {
      expect(
        CalculoCombustible.consumoReal(
          litrosIniciales: 100,
          recargas: 50,
          litrosFinales: 30,
        ),
        closeTo(120.0, 0.0001),
      );
    });
  });

  group('CombustibleJornada', () {
    test('fromMap interpreta campos y recargas', () {
      final j = CombustibleJornada.fromMap({
        'id': 'j1',
        'manifiesto_id': 'm1',
        'usuario_id': 'u1',
        'litros_iniciales': 200,
        'litros_finales': 40,
        'estado': 'cerrada',
        'km_recorridos': 150,
        'combustible_recargas': [
          {'id': 'r1', 'jornada_id': 'j1', 'litros': 30},
          {'id': 'r2', 'jornada_id': 'j1', 'litros': 20},
        ],
      });
      expect(j.estado, EstadoCombustible.cerrada);
      expect(j.litrosIniciales, 200);
      expect(j.kmRecorridos, 150);
      expect(j.recargas.length, 2);
      expect(j.totalRecargasLt, 50);
    });

    test('inicialEfectivo usa el validado si existe', () {
      const j = CombustibleJornada(
        id: 'j2',
        manifiestoId: 'm1',
        usuarioId: 'u1',
        litrosIniciales: 100,
        litrosInicialesValidados: 95,
      );
      expect(j.inicialEfectivo, 95);
    });

    test('estado desconocido cae a iniciada', () {
      final j = CombustibleJornada.fromMap({
        'id': 'j3',
        'manifiesto_id': 'm1',
        'usuario_id': 'u1',
        'estado': 'x',
      });
      expect(j.estado, EstadoCombustible.iniciada);
    });
  });
}

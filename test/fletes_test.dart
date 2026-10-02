import 'package:app_logistica/features/fletes/models/tabulador_flete.dart';
import 'package:app_logistica/features/fletes/services/calculo_flete.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalculoFlete.tierDeCapacidadKg', () {
    test('toma el tier inmediato superior', () {
      expect(CalculoFlete.tierDeCapacidadKg(1200), TierCapacidad.t1_2);
      expect(CalculoFlete.tierDeCapacidadKg(1500), TierCapacidad.t2_5);
      expect(CalculoFlete.tierDeCapacidadKg(8000), TierCapacidad.t10);
      expect(CalculoFlete.tierDeCapacidadKg(6000), TierCapacidad.t6);
      expect(CalculoFlete.tierDeCapacidadKg(6001), TierCapacidad.t7_5);
    });

    test('más de 30 t usa 30 t', () {
      expect(CalculoFlete.tierDeCapacidadKg(31000), TierCapacidad.t30);
      expect(CalculoFlete.tierDeCapacidadKg(100000), TierCapacidad.t30);
    });

    test('sin capacidad o <= 0 devuelve null', () {
      expect(CalculoFlete.tierDeCapacidadKg(null), isNull);
      expect(CalculoFlete.tierDeCapacidadKg(0), isNull);
      expect(CalculoFlete.tierDeCapacidadKg(-5), isNull);
    });
  });

  group('CalculoFlete.precioFlete', () {
    const tab = TabuladorFlete(
      id: 'f1',
      localidad: 'VALENCIA',
      precio2_5: 118.23,
      precio10: 191.77,
    );

    test('precio por tier inmediato superior', () {
      expect(CalculoFlete.precioFlete(tabulador: tab, capacidadKg: 2000),
          118.23);
      expect(CalculoFlete.precioFlete(tabulador: tab, capacidadKg: 8000),
          191.77);
    });

    test('null si no hay tabulador o capacidad', () {
      expect(CalculoFlete.precioFlete(tabulador: null, capacidadKg: 5000),
          isNull);
      expect(CalculoFlete.precioFlete(tabulador: tab, capacidadKg: null),
          isNull);
    });

    test('null si el tier no tiene precio definido', () {
      expect(CalculoFlete.precioFlete(tabulador: tab, capacidadKg: 500),
          isNull);
    });
  });

  group('TabuladorFlete', () {
    test('fromMap interpreta precios y km', () {
      final f = TabuladorFlete.fromMap({
        'id': 'l1',
        'localidad': 'MARACAY',
        'region': 'Región Central',
        'km': 10,
        'precio_1_2': '39.48',
        'precio_30': 183.5,
      });
      expect(f.localidad, 'MARACAY');
      expect(f.region, 'Región Central');
      expect(f.km, 10);
      expect(f.precioPara(TierCapacidad.t1_2), 39.48);
      expect(f.precioPara(TierCapacidad.t30), 183.5);
      expect(f.precioPara(TierCapacidad.t5), isNull);
    });

    test('localidadVisible cae al texto por defecto', () {
      const f = TabuladorFlete(id: 'x', localidad: '  ');
      expect(f.localidadVisible, 'Sin localidad');
    });

    test('aCuerpo arma el mapa completo', () {
      const f = TabuladorFlete(
        id: 'l2',
        localidad: ' CAGUA ',
        region: 'R',
        km: 15,
        precio6: 130.75,
      );
      final c = f.aCuerpo();
      expect(c['localidad'], 'CAGUA');
      expect(c['precio_6'], 130.75);
      expect(c['km'], 15);
    });
  });
}

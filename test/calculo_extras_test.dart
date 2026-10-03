import 'package:app_logistica/features/fletes/services/calculo_extras.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalculoExtras.repartos', () {
    test('un grupo dentro del radio = 1 reparto', () {
      final puntos = [
        const PuntoEntrega(id: 'a', lat: 10.24, lng: -67.59),
        const PuntoEntrega(id: 'b', lat: 10.25, lng: -67.60),
        const PuntoEntrega(id: 'c', lat: 10.26, lng: -67.58),
      ];
      expect(CalculoExtras.repartos(puntos), 1);
    });

    test('grupos lejanos cuentan por separado', () {
      final puntos = [
        const PuntoEntrega(id: 'a', lat: 10.24, lng: -67.59),
        const PuntoEntrega(id: 'b', lat: 10.25, lng: -67.60),
        // Valen ~150 km de distancia.
        const PuntoEntrega(id: 'c', lat: 10.16, lng: -68.00),
      ];
      expect(CalculoExtras.repartos(puntos), 2);
    });

    test('sin ubicación cuenta como reparto propio', () {
      final puntos = [
        const PuntoEntrega(id: 'a', lat: 10.24, lng: -67.59),
        const PuntoEntrega(id: 'b'),
      ];
      expect(CalculoExtras.repartos(puntos), 2);
    });

    test('lista vacía = 0 repartos', () {
      expect(CalculoExtras.repartos([]), 0);
    });
  });

  group('CalculoExtras.desvio', () {
    test('camión <=3 t usa tarifa fija baja', () {
      expect(CalculoExtras.desvio(2500, 100, 1), 6);
      expect(CalculoExtras.desvio(2500, 100, 3), 18);
    });

    test('camión >3 t y <=6 t usa 12 USD', () {
      expect(CalculoExtras.desvio(5000, 100, 1), 12);
    });

    test('camión >6 t usa 20% del flete base', () {
      expect(CalculoExtras.desvio(10000, 200, 1), 40);
    });

    test('sin cantidad = 0', () {
      expect(CalculoExtras.desvio(5000, 100, 0), 0);
    });
  });

  group('CalculoExtras.retorno', () {
    test('parcial 15%', () => expect(CalculoExtras.retorno(200, completa: false), 30));
    test('completa 60%', () => expect(CalculoExtras.retorno(200, completa: true), 120));
  });

  group('CalculoExtras.finDeSemana', () {
    test('5% del flete', () => expect(CalculoExtras.finDeSemana(200), 10));
  });

  group('CalculoExtras.caleta', () {
    test('2 por manifiesto', () => expect(CalculoExtras.caleta(15), 30));
  });

  group('CalculoExtras.distanciaKm', () {
    test('mismo punto = 0', () {
      expect(CalculoExtras.distanciaKm(10, -66, 10, -66), 0);
    });
    test('distancia razonable', () {
      final d = CalculoExtras.distanciaKm(10.24, -67.59, 10.16, -68.00);
      expect(d, greaterThan(40));
      expect(d, lessThan(70));
    });
  });

  group('CalculoExtras.localidadMasCercana', () {
    const locales = [
      LocalidadPunto(id: '1', localidad: 'A', lat: 10.24, lng: -67.59),
      LocalidadPunto(id: '2', localidad: 'B', lat: 10.16, lng: -68.00),
    ];
    test('elige la más cercana', () {
      final r = CalculoExtras.localidadMasCercana(10.25, -67.60, locales);
      expect(r?.localidad, 'A');
    });
    test('null sin coords', () {
      expect(CalculoExtras.localidadMasCercana(null, null, locales), isNull);
    });
  });

  group('CalculoExtras.localidadMasLejana', () {
    const locales = [
      LocalidadPunto(id: '1', localidad: 'GUACARA', lat: 10.24, lng: -67.58),
      LocalidadPunto(id: '2', localidad: 'VALENCIA', lat: 10.16, lng: -68.00),
      LocalidadPunto(id: '3', localidad: 'SIN', lat: null, lng: null),
    ];
    test('elige la más lejana del origen', () {
      final r = CalculoExtras.localidadMasLejana(
        locales,
        origenLat: 10.24,
        origenLng: -67.59,
      );
      expect(r?.localidad, 'VALENCIA');
    });
    test('null si no hay coords', () {
      final r = CalculoExtras.localidadMasLejana(
        const [LocalidadPunto(id: 'x', localidad: 'X')],
        origenLat: 10,
        origenLng: -66,
      );
      expect(r, isNull);
    });
  });
}

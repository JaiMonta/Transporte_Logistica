import 'package:app_logistica/features/fletes/models/tabulador_flete.dart';
import 'package:app_logistica/features/manifiesto/models/manifiesto.dart';
import 'package:app_logistica/features/manifiesto/services/calculo_destino.dart';
import 'package:flutter_test/flutter_test.dart';

const _origenLat = 10.2469;
const _origenLng = -67.5958;

List<TabuladorFlete> _tabulador() => const [
      TabuladorFlete(
        id: 'maracay',
        localidad: 'MARACAY',
        km: 10,
        lat: 10.2469,
        lng: -67.5958,
      ),
      TabuladorFlete(
        id: 'valencia',
        localidad: 'VALENCIA',
        km: 49,
        lat: 10.1700,
        lng: -68.0004,
      ),
    ];

void main() {
  group('CalculoDestino', () {
    test('elige la localidad más lejana al origen como destino', () {
      final r = CalculoDestino.calcular(
        puntos: const [
          PuntoCliente(id: 'a', lat: 10.2460, lng: -67.5960),
          PuntoCliente(id: 'b', lat: 10.1710, lng: -68.0010),
        ],
        tabulador: _tabulador(),
        origenLat: _origenLat,
        origenLng: _origenLng,
      );
      expect(r.destino, 'VALENCIA');
      expect(r.destinoKm, 49);
      expect(r.sinCalcular, isFalse);

      final maracay = r.entregas.firstWhere((e) => e.id == 'a');
      final valencia = r.entregas.firstWhere((e) => e.id == 'b');
      expect(maracay.localidad, 'MARACAY');
      expect(maracay.esOtraLocalidad, isTrue);
      expect(valencia.localidad, 'VALENCIA');
      expect(valencia.esOtraLocalidad, isFalse);
    });

    test('sin coordenadas de clientes no calcula', () {
      final r = CalculoDestino.calcular(
        puntos: const [PuntoCliente(id: 'a')],
        tabulador: _tabulador(),
        origenLat: _origenLat,
        origenLng: _origenLng,
      );
      expect(r.sinCalcular, isTrue);
      expect(r.destino, isNull);
      expect(r.entregas.single.localidad, isNull);
    });

    test('sin localidades con coordenadas no calcula', () {
      final r = CalculoDestino.calcular(
        puntos: const [PuntoCliente(id: 'a', lat: 10.2, lng: -67.6)],
        tabulador: const [
          TabuladorFlete(id: 'x', localidad: 'SIN COORDENADAS', km: 20),
        ],
        origenLat: _origenLat,
        origenLng: _origenLng,
      );
      expect(r.sinCalcular, isTrue);
    });

    test('sin entregas no calcula', () {
      final r = CalculoDestino.calcular(
        puntos: const [],
        tabulador: _tabulador(),
        origenLat: _origenLat,
        origenLng: _origenLng,
      );
      expect(r.sinCalcular, isTrue);
    });
  });

  group('Manifiesto.destino', () {
    test('destinoVisible prioriza el aprobado', () {
      final m = Manifiesto(
        id: 'm1',
        fecha: DateTime(2026, 10, 20),
        destinoCalculado: 'VALENCIA',
        destinoAprobado: 'MARACAY',
        destinoEstado: DestinoEstado.aprobado,
      );
      expect(m.destinoVisible, 'MARACAY');
      expect(m.esFacturable, isTrue);
    });

    test('estado pendiente no es facturable', () {
      final m = Manifiesto(
        id: 'm1',
        fecha: DateTime(2026, 10, 20),
        destinoCalculado: 'VALENCIA',
        destinoEstado: DestinoEstado.pendiente,
      );
      expect(m.destinoVisible, 'VALENCIA');
      expect(m.esFacturable, isFalse);
    });

    test('fromMap interpreta destino y estado', () {
      final m = Manifiesto.fromMap({
        'id': 'm1',
        'fecha': '2026-10-20',
        'destino_calculado': 'VALENCIA',
        'destino_calculado_km': 49,
        'destino_aprobado': 'VALENCIA',
        'destino_estado': 'corregido',
      });
      expect(m.destinoCalculado, 'VALENCIA');
      expect(m.destinoCalculadoKm, 49);
      expect(m.destinoEstado, DestinoEstado.corregido);
      expect(m.esFacturable, isTrue);
    });
  });
}

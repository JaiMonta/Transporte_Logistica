import '../../fletes/models/tabulador_flete.dart';
import '../../fletes/services/calculo_extras.dart';

/// Punto de entrega (cliente) para el cálculo del destino.
class PuntoCliente {
  const PuntoCliente({required this.id, this.lat, this.lng});

  final String id;
  final double? lat;
  final double? lng;

  bool get tieneUbicacion => lat != null && lng != null;
}

/// Destino asignado a una entrega (localidad del tabulador más cercana).
class DestinoEntrega {
  const DestinoEntrega({
    required this.id,
    this.localidad,
    this.distanciaKm,
    this.esOtraLocalidad = false,
  });

  final String id;
  final String? localidad;
  final double? distanciaKm;
  final bool esOtraLocalidad;
}

/// Resultado del cálculo del destino de un manifiesto.
class ResultadoDestino {
  const ResultadoDestino({
    this.destino,
    this.destinoKm,
    this.sinCalcular = false,
    this.entregas = const [],
  });

  /// Localidad de destino (la más lejana al origen), o null.
  final String? destino;

  /// Distancia de la localidad de destino al origen (km).
  final double? destinoKm;

  /// No se pudo calcular (faltan coordenadas o localidades).
  final bool sinCalcular;

  /// Destino calculado para cada entrega.
  final List<DestinoEntrega> entregas;

  bool get calculado => destino != null;
}

/// Cálculo puro del destino de un manifiesto por geolocalización.
///
/// Asigna a cada entrega la localidad del tabulador más cercana a su cliente
/// y define el destino como la localidad más lejana al origen de carga. Las
/// entregas en una localidad distinta al destino se marcan como desvío.
class CalculoDestino {
  const CalculoDestino._();

  static ResultadoDestino calcular({
    required List<PuntoCliente> puntos,
    required List<TabuladorFlete> tabulador,
    required double origenLat,
    required double origenLng,
  }) {
    final sinDestino = ResultadoDestino(
      sinCalcular: true,
      entregas: [for (final p in puntos) DestinoEntrega(id: p.id)],
    );

    final conUbicacion = [
      for (final l in tabulador)
        if (l.tieneUbicacion) l,
    ];
    if (puntos.isEmpty || conUbicacion.isEmpty) return sinDestino;

    final puntosLocalidad = [
      for (final l in conUbicacion)
        LocalidadPunto(
          id: l.id,
          localidad: l.localidad,
          lat: l.lat,
          lng: l.lng,
        ),
    ];

    final asignadas = <String, TabuladorFlete>{};
    final asignacionPorPunto = <String, TabuladorFlete?>{};
    for (final p in puntos) {
      final cercana =
          CalculoExtras.localidadMasCercana(p.lat, p.lng, puntosLocalidad);
      TabuladorFlete? fila;
      if (cercana != null) {
        for (final l in conUbicacion) {
          if (l.id == cercana.id) {
            fila = l;
            break;
          }
        }
      }
      if (fila != null) asignadas[fila.id] = fila;
      asignacionPorPunto[p.id] = fila;
    }

    if (asignadas.isEmpty) return sinDestino;

    final listaAsignadas = [
      for (final l in asignadas.values)
        LocalidadPunto(
          id: l.id,
          localidad: l.localidad,
          lat: l.lat,
          lng: l.lng,
        ),
    ];
    final masLejana = CalculoExtras.localidadMasLejana(
      listaAsignadas,
      origenLat: origenLat,
      origenLng: origenLng,
    );
    final destino = masLejana == null ? null : asignadas[masLejana.id];

    // Localidad de origen (la más cercana al punto de salida). Las entregas en
    // el origen no son desvío.
    final origen = CalculoExtras.localidadMasCercana(
      origenLat,
      origenLng,
      puntosLocalidad,
    );

    return ResultadoDestino(
      destino: destino?.localidad,
      destinoKm: destino?.km,
      entregas: [
        for (final p in puntos)
          DestinoEntrega(
            id: p.id,
            localidad: asignacionPorPunto[p.id]?.localidad,
            distanciaKm: asignacionPorPunto[p.id]?.km,
            esOtraLocalidad: destino != null &&
                asignacionPorPunto[p.id] != null &&
                asignacionPorPunto[p.id]!.id != destino.id &&
                (origen == null || asignacionPorPunto[p.id]!.id != origen.id),
          ),
      ],
    );
  }
}

import '../../entregas/models/entrega.dart' show EstadoEntrega;

/// Una entrega (cliente) dentro de la Bitácora.
class EntregaBitacora {
  const EntregaBitacora({
    required this.cliente,
    this.direccion,
    this.destino,
    this.region,
    this.estado = EstadoEntrega.pendiente,
    this.entregadoEn,
    this.esMasLejana = false,
    this.lat,
    this.lng,
  });

  final String cliente;
  final String? direccion;

  /// Localidad de destino (del tabulador). Se usa para el flete.
  final String? destino;

  /// Región de la localidad (del tabulador).
  final String? region;

  final EstadoEntrega estado;
  final DateTime? entregadoEn;
  final bool esMasLejana;
  final double? lat;
  final double? lng;

  String get destinoVisible =>
      (destino?.trim().isNotEmpty ?? false) ? destino!.trim() : '—';

  String get regionVisible =>
      (region?.trim().isNotEmpty ?? false) ? region!.trim() : '—';
}

/// Un manifiesto (viaje) dentro de la Bitácora, con sus guías y entregas.
class ManifiestoBitacora {
  const ManifiestoBitacora({
    required this.id,
    required this.fecha,
    this.choferId,
    this.choferNombre,
    this.camionPlaca,
    this.capacidadKg,
    this.guias = const [],
    this.fleteBase,
    this.entregas = const [],
  });

  final String id;
  final DateTime fecha;
  final String? choferId;
  final String? choferNombre;
  final String? camionPlaca;
  final double? capacidadKg;

  /// Números de guía del manifiesto (sus líneas), en orden.
  final List<String> guias;
  final double? fleteBase;
  final List<EntregaBitacora> entregas;

  String get choferVisible =>
      (choferNombre?.trim().isNotEmpty ?? false) ? choferNombre!.trim() : '—';

  String get guiasTexto => guias.isEmpty ? '—' : guias.join(' / ');

  String get capacidadTexto => capacidadKg == null
      ? '—'
      : '${(capacidadKg! / 1000).toStringAsFixed(1)} T';

  int get totalEntregas => entregas.length;
}

/// Un día de la Bitácora con sus manifiestos.
class DiaBitacora {
  const DiaBitacora({required this.fecha, required this.manifiestos});

  final DateTime fecha;
  final List<ManifiestoBitacora> manifiestos;

  int get totalEntregas => manifiestos.fold(0, (s, m) => s + m.totalEntregas);

  double get totalFlete =>
      manifiestos.fold(0.0, (s, m) => s + (m.fleteBase ?? 0));
}

/// Resultado completo de la Bitácora para un lapso.
class BitacoraResumen {
  const BitacoraResumen({
    required this.desde,
    required this.hasta,
    required this.dias,
  });

  final DateTime desde;
  final DateTime hasta;
  final List<DiaBitacora> dias;

  bool get vacio => dias.isEmpty;

  int get totalManifiestos => dias.fold(0, (s, d) => s + d.manifiestos.length);

  int get totalEntregas => dias.fold(0, (s, d) => s + d.totalEntregas);

  double get totalFlete => dias.fold(0.0, (s, d) => s + d.totalFlete);
}

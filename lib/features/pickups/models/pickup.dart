/// Estado de un pickup.
enum EstadoPickup {
  pendiente,
  enCamino,
  completado,
  cancelado;

  /// El valor tal como se guarda en la base (`en_camino`).
  String get valor => switch (this) {
    EstadoPickup.pendiente => 'pendiente',
    EstadoPickup.enCamino => 'en_camino',
    EstadoPickup.completado => 'completado',
    EstadoPickup.cancelado => 'cancelado',
  };

  String get etiqueta => switch (this) {
    EstadoPickup.pendiente => 'Pendiente',
    EstadoPickup.enCamino => 'En camino',
    EstadoPickup.completado => 'Completado',
    EstadoPickup.cancelado => 'Cancelado',
  };

  static EstadoPickup desde(String? valor) => EstadoPickup.values.firstWhere(
    (e) => e.valor == valor,
    orElse: () => EstadoPickup.pendiente,
  );
}

/// Pickup asignado por el administrador a un chofer (tabla `pickups`).
class Pickup {
  const Pickup({
    required this.id,
    required this.choferId,
    this.choferNombre,
    this.clienteId,
    this.clienteTexto,
    this.clienteNombre,
    this.direccion,
    this.lat,
    this.lng,
    this.camionId,
    this.camionPlaca,
    this.fechaEstimada,
    this.horaEstimada,
    this.notas,
    this.estado = EstadoPickup.pendiente,
    this.asignadoPor,
    this.asignadoEn,
    this.enCaminoEn,
    this.completadoEn,
    this.canceladoEn,
    this.creadoEn,
    this.actualizadoEn,
  });

  final String id;
  final String choferId;
  final String? choferNombre;
  final String? clienteId;
  final String? clienteTexto;
  final String? clienteNombre;
  final String? direccion;
  final double? lat;
  final double? lng;
  final String? camionId;
  final String? camionPlaca;

  /// Fecha estimada (solo día).
  final DateTime? fechaEstimada;

  /// Hora estimada en formato `HH:MM:SS` (tal como la devuelve Postgres).
  final String? horaEstimada;

  final String? notas;
  final EstadoPickup estado;
  final String? asignadoPor;
  final DateTime? asignadoEn;
  final DateTime? enCaminoEn;
  final DateTime? completadoEn;
  final DateTime? canceladoEn;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  String get clienteVisible {
    if (clienteNombre != null && clienteNombre!.trim().isNotEmpty) {
      return clienteNombre!.trim();
    }
    if (clienteTexto != null && clienteTexto!.trim().isNotEmpty) {
      return clienteTexto!.trim();
    }
    return 'Cliente sin nombre';
  }

  bool get tieneUbicacion =>
      lat != null &&
      lng != null &&
      lat! >= -90 &&
      lat! <= 90 &&
      lng! >= -180 &&
      lng! <= 180;

  /// Hora estimada sin segundos (`HH:MM`).
  String? get horaTexto {
    final h = horaEstimada;
    if (h == null || h.isEmpty) return null;
    return h.length >= 5 ? h.substring(0, 5) : h;
  }

  /// Fecha y hora estimadas para mostrar (p. ej. `18/10/2026 09:00`).
  String get cuandoTexto {
    final fecha = fechaEstimada;
    final hora = horaTexto;
    final f = fecha == null ? null : _fechaTexto(fecha);
    if (f == null && hora == null) return 'Sin hora estimada';
    if (f == null) return hora!;
    if (hora == null) return f;
    return '$f $hora';
  }

  factory Pickup.fromMap(Map<String, dynamic> mapa) {
    final clienteMap = mapa['clientes'];
    final choferMap = mapa['profiles'];
    final camionMap = mapa['camiones'];

    return Pickup(
      id: mapa['id'] as String,
      choferId: mapa['chofer_id'] as String,
      choferNombre: choferMap is Map
          ? ((choferMap['nombre'] as String?) ??
                (choferMap['email'] as String?))
          : null,
      clienteId: mapa['cliente_id'] as String?,
      clienteTexto: mapa['cliente_texto'] as String?,
      clienteNombre: clienteMap is Map ? clienteMap['nombre'] as String? : null,
      direccion: mapa['direccion'] as String?,
      lat: _doble(mapa['lat']),
      lng: _doble(mapa['lng']),
      camionId: mapa['camion_id'] as String?,
      camionPlaca: camionMap is Map ? camionMap['placa'] as String? : null,
      fechaEstimada: _fecha(mapa['fecha_estimada']),
      horaEstimada: mapa['hora_estimada'] as String?,
      notas: mapa['notas'] as String?,
      estado: EstadoPickup.desde(mapa['estado'] as String?),
      asignadoPor: mapa['asignado_por'] as String?,
      asignadoEn: _fecha(mapa['asignado_en']),
      enCaminoEn: _fecha(mapa['en_camino_en']),
      completadoEn: _fecha(mapa['completado_en']),
      canceladoEn: _fecha(mapa['cancelado_en']),
      creadoEn: _fecha(mapa['created_at']),
      actualizadoEn: _fecha(mapa['updated_at']),
    );
  }

  Pickup copyWith({EstadoPickup? estado}) => Pickup(
    id: id,
    choferId: choferId,
    choferNombre: choferNombre,
    clienteId: clienteId,
    clienteTexto: clienteTexto,
    clienteNombre: clienteNombre,
    direccion: direccion,
    lat: lat,
    lng: lng,
    camionId: camionId,
    camionPlaca: camionPlaca,
    fechaEstimada: fechaEstimada,
    horaEstimada: horaEstimada,
    notas: notas,
    estado: estado ?? this.estado,
    asignadoPor: asignadoPor,
    asignadoEn: asignadoEn,
    enCaminoEn: enCaminoEn,
    completadoEn: completadoEn,
    canceladoEn: canceladoEn,
    creadoEn: creadoEn,
    actualizadoEn: actualizadoEn,
  );

  static String _fechaTexto(DateTime f) {
    final dia = f.day.toString().padLeft(2, '0');
    final mes = f.month.toString().padLeft(2, '0');
    return '$dia/$mes/${f.year}';
  }

  static double? _doble(Object? valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString());
  }

  static DateTime? _fecha(Object? valor) =>
      valor == null ? null : DateTime.tryParse(valor.toString());
}

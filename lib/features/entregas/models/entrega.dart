/// Estado de una entrega.
enum EstadoEntrega {
  pendiente,
  entregado,
  fallido;

  static EstadoEntrega desde(String? valor) => EstadoEntrega.values.firstWhere(
        (e) => e.name == valor,
        orElse: () => EstadoEntrega.pendiente,
      );

  String get valor => name;

  String get etiqueta => switch (this) {
        EstadoEntrega.pendiente => 'Pendiente',
        EstadoEntrega.entregado => 'Entregado',
        EstadoEntrega.fallido => 'Fallido',
      };
}

/// Entrega de un cliente/sucursal de un manifiesto (tabla `entregas`).
class Entrega {
  const Entrega({
    required this.id,
    required this.manifiestoId,
    this.lineaId,
    this.clienteId,
    this.clienteTexto,
    this.clienteNombre,
    this.direccion,
    this.lat,
    this.lng,
    this.orden = 0,
    this.estado = EstadoEntrega.pendiente,
    this.bucket,
    this.path,
    this.hashSha256,
    this.entregadoEn,
    this.entregadoPor,
    this.notas,
    this.esOtraLocalidad = false,
    this.creadoEn,
    this.actualizadoEn,
  });

  final String id;
  final String manifiestoId;
  final String? lineaId;
  final String? clienteId;
  final String? clienteTexto;
  final String? clienteNombre;
  final String? direccion;
  final double? lat;
  final double? lng;
  final int orden;
  final EstadoEntrega estado;
  final String? bucket;
  final String? path;
  final String? hashSha256;
  final DateTime? entregadoEn;
  final String? entregadoPor;
  final String? notas;
  final bool esOtraLocalidad;
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

  bool get tieneFoto =>
      (bucket?.isNotEmpty ?? false) && (path?.isNotEmpty ?? false);

  factory Entrega.fromMap(Map<String, dynamic> mapa) {
    final clienteMap = mapa['clientes'];
    String? clienteNombre;
    if (clienteMap is Map) {
      clienteNombre = clienteMap['nombre'] as String?;
    }

    return Entrega(
      id: mapa['id'] as String,
      manifiestoId: mapa['manifiesto_id'] as String,
      lineaId: mapa['linea_id'] as String?,
      clienteId: mapa['cliente_id'] as String?,
      clienteTexto: mapa['cliente_texto'] as String?,
      clienteNombre: clienteNombre,
      direccion: mapa['direccion'] as String?,
      lat: _doble(mapa['lat']),
      lng: _doble(mapa['lng']),
      orden: (mapa['orden'] as num?)?.toInt() ?? 0,
      estado: EstadoEntrega.desde(mapa['estado'] as String?),
      bucket: mapa['bucket'] as String?,
      path: mapa['path'] as String?,
      hashSha256: mapa['hash_sha256'] as String?,
      entregadoEn: _fecha(mapa['entregado_en']),
      entregadoPor: mapa['entregado_por'] as String?,
      notas: mapa['notas'] as String?,
      esOtraLocalidad: (mapa['es_otra_localidad'] as bool?) ?? false,
      creadoEn: _fecha(mapa['created_at']),
      actualizadoEn: _fecha(mapa['updated_at']),
    );
  }

  Entrega copyWith({
    EstadoEntrega? estado,
    String? bucket,
    String? path,
    String? hashSha256,
    DateTime? entregadoEn,
    String? entregadoPor,
    String? notas,
    bool? esOtraLocalidad,
  }) =>
      Entrega(
        id: id,
        manifiestoId: manifiestoId,
        lineaId: lineaId,
        clienteId: clienteId,
        clienteTexto: clienteTexto,
        clienteNombre: clienteNombre,
        direccion: direccion,
        lat: lat,
        lng: lng,
        orden: orden,
        estado: estado ?? this.estado,
        bucket: bucket ?? this.bucket,
        path: path ?? this.path,
        hashSha256: hashSha256 ?? this.hashSha256,
        entregadoEn: entregadoEn ?? this.entregadoEn,
        entregadoPor: entregadoPor ?? this.entregadoPor,
        notas: notas ?? this.notas,
        esOtraLocalidad: esOtraLocalidad ?? this.esOtraLocalidad,
        creadoEn: creadoEn,
        actualizadoEn: actualizadoEn,
      );

  static double? _doble(Object? valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString());
  }

  static DateTime? _fecha(Object? valor) =>
      valor == null ? null : DateTime.tryParse(valor.toString());
}

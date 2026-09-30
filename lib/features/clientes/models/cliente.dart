/// Cliente del catálogo (tabla `clientes`).
class Cliente {
  const Cliente({
    required this.id,
    required this.nombre,
    this.nombreContacto,
    this.telefono,
    this.email,
    this.direccion,
    this.lat,
    this.lng,
    this.activo = true,
    this.creadoEn,
    this.actualizadoEn,
  });

  final String id;
  final String nombre;
  final String? nombreContacto;
  final String? telefono;
  final String? email;
  final String? direccion;
  final double? lat;
  final double? lng;
  final bool activo;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  String get nombreVisible =>
      nombre.trim().isNotEmpty ? nombre.trim() : 'Cliente sin nombre';

  /// ¿Tiene coordenadas válidas para mostrar en el mapa?
  bool get tieneUbicacion =>
      lat != null &&
      lng != null &&
      lat! >= -90 &&
      lat! <= 90 &&
      lng! >= -180 &&
      lng! <= 180;

  /// Iniciales para el avatar.
  String get iniciales {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1))
        .toUpperCase();
  }

  factory Cliente.fromMap(Map<String, dynamic> mapa) => Cliente(
        id: mapa['id'] as String,
        nombre: (mapa['nombre'] as String?) ?? '',
        nombreContacto: mapa['nombre_contacto'] as String?,
        telefono: mapa['telefono'] as String?,
        email: mapa['email'] as String?,
        direccion: mapa['direccion'] as String?,
        lat: _doble(mapa['lat']),
        lng: _doble(mapa['lng']),
        activo: (mapa['activo'] as bool?) ?? true,
        creadoEn: _fecha(mapa['created_at']),
        actualizadoEn: _fecha(mapa['updated_at']),
      );

  Cliente copyWith({
    String? nombre,
    String? nombreContacto,
    String? telefono,
    String? email,
    String? direccion,
    double? lat,
    double? lng,
    bool? activo,
  }) =>
      Cliente(
        id: id,
        nombre: nombre ?? this.nombre,
        nombreContacto: nombreContacto ?? this.nombreContacto,
        telefono: telefono ?? this.telefono,
        email: email ?? this.email,
        direccion: direccion ?? this.direccion,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        activo: activo ?? this.activo,
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

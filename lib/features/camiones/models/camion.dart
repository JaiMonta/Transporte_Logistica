/// Camión del catálogo (tabla `camiones`).
class Camion {
  const Camion({
    required this.id,
    required this.marca,
    required this.placa,
    required this.choferId,
    this.modelo,
    this.anio,
    this.capacidadKg,
    this.volumenM3,
    this.choferNombre,
    this.activo = true,
    this.creadoEn,
    this.actualizadoEn,
  });

  final String id;
  final String marca;
  final String placa;
  final String? modelo;
  final int? anio;
  final double? capacidadKg;
  final double? volumenM3;
  final String choferId;
  final String? choferNombre;
  final bool activo;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  String get marcaVisible =>
      marca.trim().isNotEmpty ? marca.trim() : 'Camión sin marca';

  String get choferVisible =>
      (choferNombre?.trim().isNotEmpty ?? false)
          ? choferNombre!.trim()
          : 'Sin chofer';

  factory Camion.fromMap(Map<String, dynamic> mapa) {
    final perfilMap = mapa['profiles'];
    String? choferNombre;
    if (perfilMap is Map) {
      choferNombre =
          (perfilMap['nombre'] as String?) ?? (perfilMap['email'] as String?);
    }

    return Camion(
      id: mapa['id'] as String,
      marca: (mapa['marca'] as String?) ?? '',
      placa: (mapa['placa'] as String?) ?? '',
      modelo: mapa['modelo'] as String?,
      anio: (mapa['anio'] as num?)?.toInt(),
      capacidadKg: _doble(mapa['capacidad_kg']),
      volumenM3: _doble(mapa['volumen_m3']),
      choferId: mapa['chofer_id'] as String,
      choferNombre: choferNombre,
      activo: (mapa['activo'] as bool?) ?? true,
      creadoEn: _fecha(mapa['created_at']),
      actualizadoEn: _fecha(mapa['updated_at']),
    );
  }

  Camion copyWith({
    String? marca,
    String? placa,
    String? modelo,
    int? anio,
    double? capacidadKg,
    double? volumenM3,
    String? choferId,
    bool? activo,
  }) =>
      Camion(
        id: id,
        marca: marca ?? this.marca,
        placa: placa ?? this.placa,
        modelo: modelo ?? this.modelo,
        anio: anio ?? this.anio,
        capacidadKg: capacidadKg ?? this.capacidadKg,
        volumenM3: volumenM3 ?? this.volumenM3,
        choferId: choferId ?? this.choferId,
        choferNombre: choferNombre,
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

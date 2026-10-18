/// Empresa facturada (tabla `empresas`).
class Empresa {
  const Empresa({
    required this.id,
    required this.nombre,
    this.rif,
    this.activo = true,
    this.creadoEn,
    this.actualizadoEn,
  });

  final String id;
  final String nombre;
  final String? rif;
  final bool activo;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  String get nombreVisible =>
      nombre.trim().isNotEmpty ? nombre.trim() : 'Empresa sin nombre';

  factory Empresa.fromMap(Map<String, dynamic> mapa) => Empresa(
        id: mapa['id'] as String,
        nombre: (mapa['nombre'] as String?) ?? '',
        rif: mapa['rif'] as String?,
        activo: (mapa['activo'] as bool?) ?? true,
        creadoEn: _fecha(mapa['created_at']),
        actualizadoEn: _fecha(mapa['updated_at']),
      );

  Empresa copyWith({String? nombre, String? rif, bool? activo}) => Empresa(
        id: id,
        nombre: nombre ?? this.nombre,
        rif: rif ?? this.rif,
        activo: activo ?? this.activo,
        creadoEn: creadoEn,
        actualizadoEn: actualizadoEn,
      );

  static DateTime? _fecha(Object? valor) =>
      valor == null ? null : DateTime.tryParse(valor.toString());
}

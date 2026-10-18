/// Producto del catálogo (tabla `productos`). Cada producto pertenece a una
/// empresa facturada.
class Producto {
  const Producto({
    required this.id,
    required this.nombre,
    this.empresaId,
    this.empresaNombre,
    this.orden = 0,
    this.activo = true,
  });

  final String id;
  final String nombre;
  final String? empresaId;
  final String? empresaNombre;
  final int orden;
  final bool activo;

  String get nombreVisible =>
      nombre.trim().isNotEmpty ? nombre.trim() : 'Producto sin nombre';

  String get empresaVisible =>
      (empresaNombre?.trim().isNotEmpty ?? false)
          ? empresaNombre!.trim()
          : 'Sin empresa';

  factory Producto.fromMap(Map<String, dynamic> mapa) {
    final empresaMap = mapa['empresas'];
    String? empresaNombre;
    if (empresaMap is Map) {
      empresaNombre = empresaMap['nombre'] as String?;
    }
    return Producto(
      id: mapa['id'] as String,
      nombre: (mapa['nombre'] as String?) ?? '',
      empresaId: mapa['empresa_id'] as String?,
      empresaNombre: empresaNombre,
      orden: (mapa['orden'] as num?)?.toInt() ?? 0,
      activo: (mapa['activo'] as bool?) ?? true,
    );
  }

  Producto copyWith({
    String? nombre,
    Object? empresaId = _sinCambio,
    int? orden,
    bool? activo,
  }) =>
      Producto(
        id: id,
        nombre: nombre ?? this.nombre,
        empresaId:
            empresaId == _sinCambio ? this.empresaId : empresaId as String?,
        empresaNombre: empresaNombre,
        orden: orden ?? this.orden,
        activo: activo ?? this.activo,
      );

  static const Object _sinCambio = Object();
}

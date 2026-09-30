/// Roles de usuario del sistema.
enum Rol { admin, chofer }

extension RolX on Rol {
  /// Valor tal como se guarda en la base de datos.
  String get valor => name;

  /// Etiqueta legible para mostrar en la interfaz.
  String get etiqueta => this == Rol.admin ? 'Administrador' : 'Chofer';

  static Rol desde(String? valor) =>
      valor == 'admin' ? Rol.admin : Rol.chofer;
}

/// Perfil de usuario (tabla `profiles`, enlazada 1:1 con `auth.users`).
class Profile {
  const Profile({
    required this.id,
    required this.rol,
    required this.activo,
    this.email,
    this.nombre = '',
    this.telefono,
    this.creadoEn,
    this.actualizadoEn,
  });

  final String id;
  final String? email;
  final String nombre;
  final String? telefono;
  final Rol rol;
  final bool activo;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  bool get esAdmin => rol == Rol.admin;

  /// Nombre a mostrar; si no hay nombre, cae al correo.
  String get nombreVisible =>
      nombre.trim().isNotEmpty ? nombre.trim() : (email ?? 'Sin nombre');

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

  factory Profile.fromMap(Map<String, dynamic> mapa) => Profile(
        id: mapa['id'] as String,
        email: mapa['email'] as String?,
        nombre: (mapa['nombre'] as String?) ?? '',
        telefono: mapa['telefono'] as String?,
        rol: RolX.desde(mapa['rol'] as String?),
        activo: (mapa['activo'] as bool?) ?? true,
        creadoEn: _fecha(mapa['created_at']),
        actualizadoEn: _fecha(mapa['updated_at']),
      );

  Profile copyWith({
    String? email,
    String? nombre,
    String? telefono,
    Rol? rol,
    bool? activo,
  }) =>
      Profile(
        id: id,
        email: email ?? this.email,
        nombre: nombre ?? this.nombre,
        telefono: telefono ?? this.telefono,
        rol: rol ?? this.rol,
        activo: activo ?? this.activo,
        creadoEn: creadoEn,
        actualizadoEn: actualizadoEn,
      );

  static DateTime? _fecha(Object? valor) =>
      valor == null ? null : DateTime.tryParse(valor.toString());
}

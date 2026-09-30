/// Validaciones de formato reutilizables en formularios.
class Validador {
  const Validador._();

  static final RegExp _correo = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  static final RegExp _telefono = RegExp(r'^[0-9+\-\s()]{7,20}$');
  static final RegExp _contrasena =
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');

  static String? nombre(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa el nombre.';
    if (v.length < 3) return 'El nombre es demasiado corto.';
    return null;
  }

  static String? correo(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa el correo.';
    if (!_correo.hasMatch(v)) return 'El correo no tiene un formato válido.';
    return null;
  }

  /// Teléfono opcional: si viene, debe tener formato válido.
  static String? telefono(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!_telefono.hasMatch(v)) return 'El teléfono no tiene un formato válido.';
    return null;
  }

  static String? telefonoObligatorio(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa el teléfono.';
    return telefono(v);
  }

  static String? contrasena(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Ingresa la contraseña.';
    if (!_contrasena.hasMatch(v)) {
      return 'Mínimo 8 caracteres, con mayúscula, minúscula y número.';
    }
    return null;
  }

  static String? confirmarContrasena(String? valor, String original) {
    if ((valor ?? '').isEmpty) return 'Confirma la contraseña.';
    if (valor != original) return 'Las contraseñas no coinciden.';
    return null;
  }
}

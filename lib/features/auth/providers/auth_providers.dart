import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../data/auth_repository.dart';
import '../data/credenciales_service.dart';
import '../models/profile.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);

/// Servicio de credenciales recordadas (usuario y contraseña).
final credencialesProvider = Provider<CredencialesService>(
  (ref) => CredencialesService(),
);

/// Estado de autenticación de Supabase (se reemite en cada cambio de sesión).
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseProvider).auth.onAuthStateChange,
);

/// Perfil del usuario autenticado. Se recalcula cuando cambia la sesión.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).perfilActual();
});

/// Acciones de autenticación (iniciar/cerrar sesión y contraseña).
class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<Profile> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final res = await repo.iniciarSesion(
        correo: correo,
        contrasena: contrasena,
      );
      final usuario = res.user;
      if (usuario == null) {
        throw Exception('No se pudo iniciar sesión.');
      }
      final perfil = await repo.perfilDeUsuario(usuario.id);
      if (perfil == null) {
        await repo.cerrarSesion();
        throw Exception('No se encontró el perfil del usuario.');
      }
      if (!perfil.activo) {
        await repo.cerrarSesion();
        throw Exception('La cuenta está inactiva. Contacta al administrador.');
      }
      state = const AsyncData(null);
      ref.invalidate(currentProfileProvider);
      return perfil;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> cerrarSesion() async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).cerrarSesion();
      // Al cerrar sesión se olvidan las credenciales recordadas.
      await ref.read(credencialesProvider).olvidarTodo();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> recuperarContrasena(String correo, {String? redireccion}) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(authRepositoryProvider)
          .recuperarContrasena(correo, redireccion: redireccion);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> actualizarContrasena(String nueva) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).actualizarContrasena(nueva);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);

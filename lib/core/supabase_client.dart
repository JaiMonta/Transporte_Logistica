import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Persistencia de la sesión respaldada por almacenamiento seguro
/// (Keychain en iOS, Keystore/EncryptedSharedPreferences en Android,
/// WebCrypto en web).
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({
    FlutterSecureStorage? storage,
    this.clave = 'sb-sesion',
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final String clave;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      (await _storage.read(key: clave)) != null;

  @override
  Future<String?> accessToken() => _storage.read(key: clave);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: clave, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: clave);
}

/// Inicializa el cliente de Supabase una sola vez al arrancar la app.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(),
    ),
  );
}

/// Cliente de Supabase compartido.
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

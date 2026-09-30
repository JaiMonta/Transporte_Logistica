/// Variables de entorno de la aplicación.
///
/// Los valores por defecto permiten ejecutar sin flags:
///   flutter run -d web-server --web-port 8080
///
/// También se pueden sobreescribir en tiempo de compilación/ejecución con:
///   flutter run --dart-define-from-file=env.json
///
/// La clave anónima es pública por diseño; la clave de servicio
/// (service_role) NUNCA debe incluirse aquí.
class Env {
  const Env._();

  static const String _urlPorDefecto =
      'https://fmwwablhluztdvspujwj.supabase.co';
  static const String _anonKeyPorDefecto =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtd3dhYmxobHV6dGR2c3B1andqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3MDAyMTksImV4cCI6MjEwNjI3NjIxOX0.4On59eAIcMFmX5WqjJ4rVTsbGo993an7W6gwPiY88mg';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _urlPorDefecto,
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _anonKeyPorDefecto,
  );

  static bool get estaConfigurado =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

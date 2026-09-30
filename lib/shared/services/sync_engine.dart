import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'offline_manager.dart';

/// Calcula la espera creciente (backoff) entre reintentos.
///
/// Base 2 s, tope 5 min: 2s, 4s, 8s, 16s, ... hasta el máximo.
Duration esperaReintento(int intentos) {
  const base = Duration(seconds: 2);
  const tope = Duration(minutes: 5);
  final segundos = base.inSeconds * (1 << intentos.clamp(0, 20));
  final espera = Duration(seconds: segundos);
  return espera > tope ? tope : espera;
}

/// ¿Hay conexión según la lista de resultados?
bool hayConexion(List<ConnectivityResult> resultados) {
  return resultados.isNotEmpty &&
      resultados.any((r) => r != ConnectivityResult.none);
}

/// Motor de sincronización: vacía la cola local contra Supabase cuando
/// vuelve la conexión, con reintentos de espera creciente.
class SyncEngine {
  SyncEngine(this._ref, this._manager);

  final Ref _ref;
  final OfflineManager _manager;

  StreamSubscription<List<ConnectivityResult>>? _suscripcion;
  bool _sincronizando = false;

  /// Aplica una operación a PostgREST. Devuelve true si tuvo éxito.
  Future<bool> _aplicar(ElementoCola elemento, SupabaseClient cliente) async {
    final tabla = cliente.from(elemento.entidad);
    switch (elemento.accion) {
      case AccionSync.crear:
        await tabla.upsert(elemento.payload);
      case AccionSync.actualizar:
        final payload = Map<String, dynamic>.from(elemento.payload);
        final id = payload.remove('id');
        if (id == null) return false;
        await tabla.update(payload).eq('id', id);
      case AccionSync.eliminar:
        await tabla.delete().eq('id', elemento.entidadId);
    }
    return true;
  }

  /// Registra el espejo del evento en la tabla sync_events del servidor.
  Future<void> _espejarEvento(
    ElementoCola elemento,
    SupabaseClient cliente,
    EstadoCola estado, {
    String? error,
  }) async {
    try {
      await cliente.from('sync_events').upsert(
        {
          'usuario_id': cliente.auth.currentUser?.id,
          'entidad': elemento.entidad,
          'entidad_id': elemento.entidadId,
          'accion': elemento.accion.valor,
          'payload': elemento.payload,
          'estado': estado.valor,
          'intentos': elemento.intentos,
          'ultimo_error': error,
        },
        onConflict: 'usuario_id,entidad,entidad_id,accion',
      );
    } catch (_) {
      // El espejo es informativo; no debe romper la sincronización.
    }
  }

  /// Procesa toda la cola pendiente una vez.
  Future<void> sincronizar() async {
    if (!_manager.disponible || _sincronizando) return;
    _sincronizando = true;
    try {
      final cliente = _ref.read(supabaseProvider);
      if (cliente.auth.currentUser == null) return;

      final elementos = await _manager.pendientes();
      for (final elemento in elementos) {
        if (elemento.id == null) continue;
        await _manager.marcarEstado(elemento.id!, EstadoCola.subiendo);
        try {
          final ok = await _aplicar(elemento, cliente);
          if (!ok) {
            await _marcarFallo(elemento, cliente, 'Datos incompletos.');
            continue;
          }
          await _manager.eliminarElemento(elemento.id!);
          await _espejarEvento(elemento, cliente, EstadoCola.completado);
        } on PostgrestException catch (e) {
          await _marcarFallo(elemento, cliente, e.message);
        } catch (e) {
          await _marcarFallo(elemento, cliente, e.toString());
        }
      }
    } finally {
      _sincronizando = false;
      _ref.invalidate(pendientesProvider);
    }
  }

  Future<void> _marcarFallo(
    ElementoCola elemento,
    SupabaseClient cliente,
    String error,
  ) async {
    final intentos = elemento.intentos + 1;
    await _manager.marcarEstado(
      elemento.id!,
      EstadoCola.fallido,
      intentos: intentos,
      ultimoError: error,
    );
    await _espejarEvento(
      elemento.copyWith(intentos: intentos),
      cliente,
      EstadoCola.fallido,
      error: error,
    );
    final espera = esperaReintento(intentos);
    Future.delayed(espera, () {
      if (_ref.read(mantenerSyncProvider)) sincronizar();
    });
  }

  /// Empieza a escuchar cambios de conectividad.
  void iniciar() {
    if (!_manager.disponible) return;
    _suscripcion?.cancel();
    _suscripcion = Connectivity().onConnectivityChanged.listen((resultados) {
      if (hayConexion(resultados)) sincronizar();
    });
    sincronizar();
  }

  void detener() {
    _suscripcion?.cancel();
    _suscripcion = null;
  }
}

/// Indica si el motor debe seguir reintentando (lo apaga el cierre de sesión).
class MantenerSync extends Notifier<bool> {
  @override
  bool build() => true;

  void establecer(bool valor) => state = valor;
}

final mantenerSyncProvider = NotifierProvider<MantenerSync, bool>(MantenerSync.new);

final offlineManagerProvider = Provider<OfflineManager>((ref) {
  final manager = OfflineManager();
  ref.onDispose(manager.cerrar);
  return manager;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(ref, ref.watch(offlineManagerProvider));
});

/// Contador reactivo de pendientes (para el indicador en pantalla).
final pendientesProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(offlineManagerProvider).contadorPendientes();
});

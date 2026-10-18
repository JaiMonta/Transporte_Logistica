import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pickup.dart';

/// Acceso a los pickups (PostgREST, protegido por RLS) y su flujo en vivo.
class PickupsRepository {
  PickupsRepository(this._client);

  final SupabaseClient _client;

  static const String _seleccion =
      '*, clientes(nombre), profiles(nombre, email), camiones(placa)';

  /// Lista de pickups. El RLS limita al chofer a los suyos; el admin ve todos.
  Future<List<Pickup>> listar({
    String? choferId,
    EstadoPickup? estado,
    DateTime? fecha,
  }) async {
    dynamic query = _client.from('pickups').select(_seleccion);
    if (choferId != null) query = query.eq('chofer_id', choferId);
    if (estado != null) query = query.eq('estado', estado.valor);
    if (fecha != null) query = query.eq('fecha_estimada', _fechaTexto(fecha));

    final data =
        await query
                .order('fecha_estimada', ascending: true, nullsFirst: false)
                .order('hora_estimada', ascending: true, nullsFirst: false)
                .order('created_at', ascending: true)
            as List<dynamic>;
    return data
        .map((e) => Pickup.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Pickup?> obtener(String id) async {
    final data = await _client
        .from('pickups')
        .select(_seleccion)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Pickup.fromMap(Map<String, dynamic>.from(data));
  }

  Future<Pickup> crear({
    required String choferId,
    String? clienteId,
    String? clienteTexto,
    String? direccion,
    double? lat,
    double? lng,
    String? camionId,
    DateTime? fechaEstimada,
    String? horaEstimada,
    String? notas,
  }) async {
    final data = await _client
        .from('pickups')
        .insert({
          'chofer_id': choferId,
          ..._cuerpo(
            clienteId: clienteId,
            clienteTexto: clienteTexto,
            direccion: direccion,
            lat: lat,
            lng: lng,
            camionId: camionId,
            fechaEstimada: fechaEstimada,
            horaEstimada: horaEstimada,
            notas: notas,
          ),
        })
        .select(_seleccion)
        .single();
    return Pickup.fromMap(Map<String, dynamic>.from(data));
  }

  Future<Pickup> actualizar({
    required String id,
    required String choferId,
    String? clienteId,
    String? clienteTexto,
    String? direccion,
    double? lat,
    double? lng,
    String? camionId,
    DateTime? fechaEstimada,
    String? horaEstimada,
    String? notas,
  }) async {
    final data = await _client
        .from('pickups')
        .update({
          'chofer_id': choferId,
          ..._cuerpo(
            clienteId: clienteId,
            clienteTexto: clienteTexto,
            direccion: direccion,
            lat: lat,
            lng: lng,
            camionId: camionId,
            fechaEstimada: fechaEstimada,
            horaEstimada: horaEstimada,
            notas: notas,
          ),
        })
        .eq('id', id)
        .select(_seleccion)
        .single();
    return Pickup.fromMap(Map<String, dynamic>.from(data));
  }

  /// Cambia el estado (el chofer solo puede mover el estado; hora del servidor).
  Future<Pickup> cambiarEstado({
    required String id,
    required EstadoPickup estado,
  }) async {
    final data = await _client
        .from('pickups')
        .update({'estado': estado.valor})
        .eq('id', id)
        .select(_seleccion)
        .single();
    return Pickup.fromMap(Map<String, dynamic>.from(data));
  }

  /// Flujo en vivo (Realtime) de pickups. Respeta el RLS del usuario.
  Stream<List<Pickup>> stream() => _client
      .from('pickups')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: true)
      .map(
        (rows) => rows
            .map((e) => Pickup.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> _cuerpo({
    required String? clienteId,
    required String? clienteTexto,
    required String? direccion,
    required double? lat,
    required double? lng,
    required String? camionId,
    required DateTime? fechaEstimada,
    required String? horaEstimada,
    required String? notas,
  }) => {
    'cliente_id': clienteId,
    'cliente_texto': _texto(clienteTexto),
    'direccion': _texto(direccion),
    'lat': lat,
    'lng': lng,
    'camion_id': camionId,
    'fecha_estimada': fechaEstimada == null ? null : _fechaTexto(fechaEstimada),
    'hora_estimada': _texto(horaEstimada),
    'notas': _texto(notas),
  };

  static String _fechaTexto(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }

  static String? _texto(String? valor) {
    final t = valor?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}

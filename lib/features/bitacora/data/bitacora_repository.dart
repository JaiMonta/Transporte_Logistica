import 'package:supabase_flutter/supabase_flutter.dart';

import '../../entregas/models/entrega.dart';
import '../../fletes/models/tabulador_flete.dart';
import '../models/bitacora.dart';
import '../services/calculo_bitacora.dart';

/// Bitácora (solo lectura): entregas por manifiesto de cada chofer por día.
///
/// Reutiliza los datos existentes (manifiestos, líneas, entregas, tabulador);
/// no crea tablas ni vistas nuevas.
class BitacoraRepository {
  BitacoraRepository(this._client);

  final SupabaseClient _client;

  static const String _seleccionManifiesto =
      'id, fecha, capturado_por, camion_id, localidad_mas_lejana, costo_flete, '
      'profiles(nombre, email), camiones(marca, placa, capacidad_kg), '
      'manifiesto_lineas(numero, orden)';

  static const String _seleccionEntrega =
      'manifiesto_id, cliente_id, cliente_texto, direccion, localidad, '
      'estado, entregado_en, es_mas_lejana, lat, lng, clientes(nombre)';

  Future<BitacoraResumen> cargar({
    required DateTime desde,
    required DateTime hasta,
    String? choferId,
  }) async {
    dynamic query = _client.from('manifiestos').select(_seleccionManifiesto);
    query = query
        .gte('fecha', _fechaTexto(desde))
        .lte('fecha', _fechaTexto(hasta));
    if (choferId != null) query = query.eq('capturado_por', choferId);

    final manis = await query.order('fecha', ascending: true) as List<dynamic>;
    if (manis.isEmpty) {
      return CalculoBitacora.agrupar(
        desde: desde,
        hasta: hasta,
        manifiestos: const [],
      );
    }

    final ids = [for (final m in manis) (m as Map)['id'] as String];

    final entregas =
        await _client
                .from('entregas')
                .select(_seleccionEntrega)
                .inFilter('manifiesto_id', ids)
                .order('orden', ascending: true)
            as List<dynamic>;

    final tabulador = await _tabuladorPorLocalidad();

    final entregasPorManifiesto = <String, List<Map<String, dynamic>>>{};
    for (final e in entregas) {
      final map = Map<String, dynamic>.from(e as Map);
      final mid = map['manifiesto_id'] as String?;
      if (mid != null) {
        entregasPorManifiesto.putIfAbsent(mid, () => []).add(map);
      }
    }

    final manifiestos = <ManifiestoBitacora>[];
    for (final m in manis) {
      final map = Map<String, dynamic>.from(m as Map);
      final id = map['id'] as String;
      final ents = entregasPorManifiesto[id] ?? const [];

      final entregasBitacora = [
        for (final e in ents)
          EntregaBitacora(
            cliente: _cliente(e),
            direccion: e['direccion'] as String?,
            destino: e['localidad'] as String?,
            region: CalculoBitacora.regionDe(
              e['localidad'] as String?,
              tabulador,
            ),
            estado: EstadoEntrega.desde(e['estado'] as String?),
            entregadoEn: _fecha(e['entregado_en']),
            esMasLejana: (e['es_mas_lejana'] as bool?) ?? false,
            lat: _doble(e['lat']),
            lng: _doble(e['lng']),
          ),
      ];

      final camion = map['camiones'];
      double? capacidad;
      String? placa;
      if (camion is Map) {
        capacidad = _doble(camion['capacidad_kg']);
        placa = camion['placa'] as String?;
      }
      final perfil = map['profiles'];
      String? choferNombre;
      if (perfil is Map) {
        choferNombre =
            (perfil['nombre'] as String?) ?? (perfil['email'] as String?);
      }

      final lineas = map['manifiesto_lineas'];
      final guias = <String>[];
      if (lineas is List) {
        final ordenadas =
            lineas
                .whereType<Map>()
                .map((l) => Map<String, dynamic>.from(l))
                .toList()
              ..sort((a, b) => _int(a['orden']).compareTo(_int(b['orden'])));
        for (final l in ordenadas) {
          final numero = (l['numero'] as String?)?.trim();
          if (numero != null && numero.isNotEmpty) guias.add(numero);
        }
      }

      manifiestos.add(
        ManifiestoBitacora(
          id: id,
          fecha: _fecha(map['fecha']) ?? desde,
          choferId: map['capturado_por'] as String?,
          choferNombre: choferNombre,
          camionPlaca: placa,
          capacidadKg: capacidad,
          guias: guias,
          fleteBase: CalculoBitacora.fleteBaseDeEntregas(
            entregas: entregasBitacora,
            capacidadKg: capacidad,
            tabulador: tabulador,
            costoFleteGuardado: _doble(map['costo_flete']),
          ),
          entregas: entregasBitacora,
        ),
      );
    }

    return CalculoBitacora.agrupar(
      desde: desde,
      hasta: hasta,
      manifiestos: manifiestos,
    );
  }

  /// Choferes que tienen manifiestos en el lapso (para el filtro).
  Future<List<({String id, String nombre})>> choferesDelLapso(
    DateTime desde,
    DateTime hasta,
  ) async {
    final data =
        await _client
                .from('manifiestos')
                .select('capturado_por, profiles(nombre, email)')
                .gte('fecha', _fechaTexto(desde))
                .lte('fecha', _fechaTexto(hasta))
            as List<dynamic>;
    final mapa = <String, String>{};
    for (final m in data) {
      final map = Map<String, dynamic>.from(m as Map);
      final id = map['capturado_por'] as String?;
      if (id == null) continue;
      final perfil = map['profiles'];
      final nombre = perfil is Map
          ? ((perfil['nombre'] as String?) ?? (perfil['email'] as String?))
          : null;
      mapa[id] = (nombre?.trim().isNotEmpty ?? false)
          ? nombre!.trim()
          : 'Chofer';
    }
    final lista = mapa.entries.map((e) => (id: e.key, nombre: e.value)).toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    return lista;
  }

  static String _cliente(Map<String, dynamic> e) {
    final cliente = e['clientes'];
    if (cliente is Map) {
      final nombre = (cliente['nombre'] as String?)?.trim();
      if (nombre != null && nombre.isNotEmpty) return nombre;
    }
    final texto = (e['cliente_texto'] as String?)?.trim();
    if (texto != null && texto.isNotEmpty) return texto;
    return 'Cliente sin nombre';
  }

  Future<Map<String, TabuladorFlete>> _tabuladorPorLocalidad() async {
    final data =
        await _client.from('fletes_tabulador').select() as List<dynamic>;
    final mapa = <String, TabuladorFlete>{};
    for (final e in data) {
      final f = TabuladorFlete.fromMap(Map<String, dynamic>.from(e as Map));
      mapa[f.localidad.toUpperCase()] = f;
    }
    return mapa;
  }

  static double? _doble(Object? valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString());
  }

  static int _int(Object? valor) {
    if (valor == null) return 0;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString()) ?? 0;
  }

  static DateTime? _fecha(Object? valor) =>
      valor == null ? null : DateTime.tryParse(valor.toString());

  static String _fechaTexto(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }
}

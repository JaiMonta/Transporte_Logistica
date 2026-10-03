import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fletes/models/extra.dart';
import '../../fletes/models/tabulador_flete.dart';
import '../../fletes/services/calculo_flete.dart';
import '../services/calculo_factura_semanal.dart';
import '../models/factura.dart';

/// Acceso y generación de la facturación semanal (PostgREST, RLS solo admin).
class FacturacionRepository {
  FacturacionRepository(this._client);

  final SupabaseClient _client;

  static const String _seleccion = '*, factura_items(*)';

  Future<List<Factura>> listarPorLapso(DateTime desde, DateTime hasta) async {
    final data = await _client
        .from('facturas')
        .select(_seleccion)
        .gte('periodo_inicio', _fechaTexto(desde))
        .lte('periodo_inicio', _fechaTexto(hasta))
        .order('periodo_inicio', ascending: false) as List<dynamic>;
    return data
        .map((e) => Factura.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Factura?> obtener(String id) async {
    final data = await _client
        .from('facturas')
        .select(_seleccion)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Factura.fromMap(Map<String, dynamic>.from(data));
  }

  /// Genera (o rehace) la factura de la semana que contiene [dia].
  Future<Factura> generarSemana(DateTime dia) async {
    final semana = SemanaRange.deFecha(dia);

    // Manifiestos con al menos una entrega 'entregado' en el período,
    // identificados por la fecha de entrega.
    final entregas = await _client
        .from('entregas')
        .select('manifiesto_id, entregado_en')
        .eq('estado', 'entregado')
        .gte('entregado_en', '${_fechaTexto(semana.inicio)}T00:00:00')
        .lte('entregado_en', '${_fechaTexto(semana.fin)}T23:59:59') as List<dynamic>;

    final idsManifiestos = <String>{};
    for (final e in entregas) {
      final mid = (e as Map)['manifiesto_id'] as String?;
      if (mid != null) idsManifiestos.add(mid);
    }

    final resumen = await _resumenDeManifiestos(idsManifiestos.toList());

    // Upsert de la cabecera del período.
    final facturaRow = await _client
        .from('facturas')
        .upsert({
          'periodo_inicio': _fechaTexto(semana.inicio),
          'periodo_fin': _fechaTexto(semana.fin),
          'subtotal_flete': resumen.subtotalFlete,
          'subtotal_extras': resumen.subtotalExtras,
          'total': resumen.total,
          'estado': 'emitida',
        }, onConflict: 'periodo_inicio,periodo_fin')
        .select('id')
        .single();

    final facturaId = facturaRow['id'] as String;

    // Rehacer: eliminar los ítems previos y volver a insertarlos.
    await _client.from('factura_items').delete().eq('factura_id', facturaId);

    if (resumen.items.isNotEmpty) {
      await _client.from('factura_items').insert([
        for (final it in resumen.items)
          {
            'factura_id': facturaId,
            'manifiesto_id': it.manifiestoId,
            'usuario_id': it.usuarioId,
            'concepto': it.concepto,
            'tipo': it.tipo?.valor,
            'descripcion': it.descripcion,
            'base': it.base,
            'porcentaje': it.porcentaje,
            'monto': it.monto,
            'orden': it.orden,
          },
      ]);
    }

    return (await obtener(facturaId))!;
  }

  Future<ResumenFactura> _resumenDeManifiestos(List<String> ids) async {
    if (ids.isEmpty) {
      return CalculoFacturaSemanal.calcular(const []);
    }
    // Manifiestos con flete, chofer, camión y localidad del tabulador.
    final manis = await _client
        .from('manifiestos')
        .select(
          'id, capturado_por, costo_flete, camion_id, fletes_tabulador_id',
        )
        .inFilter('id', ids) as List<dynamic>;
    // Extras aprobados de esos manifiestos.
    final extras = await _client
        .from('manifiesto_extras')
        .select()
        .inFilter('manifiesto_id', ids) as List<dynamic>;

    final extrasPorManifiesto = <String, List<Extra>>{};
    for (final e in extras) {
      final extra = Extra.fromMap(Map<String, dynamic>.from(e as Map));
      extrasPorManifiesto.putIfAbsent(extra.manifiestoId, () => []).add(extra);
    }

    // Cachés para calcular el flete base cuando esté vacío.
    final tabuladores = <String, TabuladorFlete?>{};
    final capacidadesCamion = <String, double?>{};

    final facturables = <ManifiestoFacturable>[];
    for (final m in manis) {
      final map = Map<String, dynamic>.from(m as Map);
      final id = map['id'] as String;

      var fleteBase = (map['costo_flete'] as num?)?.toDouble();
      if (fleteBase == null || fleteBase <= 0) {
        // Recalcular: tabulador (localidad) × capacidad del camión.
        final tabId = map['fletes_tabulador_id'] as String?;
        final camId = map['camion_id'] as String?;
        TabuladorFlete? tab;
        if (tabId != null) {
          tab = tabuladores.containsKey(tabId)
              ? tabuladores[tabId]
              : tabuladores[tabId] = await _obtenerTabulador(tabId);
        }
        double? capacidad;
        if (camId != null) {
          capacidad = capacidadesCamion.containsKey(camId)
              ? capacidadesCamion[camId]
              : capacidadesCamion[camId] = await _capacidadCamion(camId);
        }
        fleteBase = CalculoFlete.precioFlete(
              tabulador: tab,
              capacidadKg: capacidad,
            ) ??
            0;
      }

      facturables.add(ManifiestoFacturable(
        manifiestoId: id,
        usuarioId: map['capturado_por'] as String?,
        fleteBase: fleteBase,
        extras: extrasPorManifiesto[id] ?? const [],
      ));
    }
    return CalculoFacturaSemanal.calcular(facturables);
  }

  Future<TabuladorFlete?> _obtenerTabulador(String id) async {
    final data = await _client
        .from('fletes_tabulador')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return TabuladorFlete.fromMap(Map<String, dynamic>.from(data));
  }

  Future<double?> _capacidadCamion(String id) async {
    final data = await _client
        .from('camiones')
        .select('capacidad_kg')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return (data['capacidad_kg'] as num?)?.toDouble();
  }

  Future<void> cambiarEstado({
    required String id,
    required EstadoFactura estado,
  }) async {
    await _client.from('facturas').update({'estado': estado.valor}).eq('id', id);
  }

  static String _fechaTexto(DateTime fecha) {
    final f = DateTime(fecha.year, fecha.month, fecha.day);
    final mes = f.month.toString().padLeft(2, '0');
    final dia = f.day.toString().padLeft(2, '0');
    return '${f.year}-$mes-$dia';
  }
}

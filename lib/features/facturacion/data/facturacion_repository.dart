import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fletes/models/extra.dart';
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
    // Manifiestos con flete y chofer.
    final manis = await _client
        .from('manifiestos')
        .select('id, capturado_por, costo_flete')
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

    final facturables = <ManifiestoFacturable>[];
    for (final m in manis) {
      final map = Map<String, dynamic>.from(m as Map);
      final id = map['id'] as String;
      facturables.add(ManifiestoFacturable(
        manifiestoId: id,
        usuarioId: map['capturado_por'] as String?,
        fleteBase: (map['costo_flete'] as num?)?.toDouble() ?? 0,
        extras: extrasPorManifiesto[id] ?? const [],
      ));
    }
    return CalculoFacturaSemanal.calcular(facturables);
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

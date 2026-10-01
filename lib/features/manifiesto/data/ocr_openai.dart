import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'parser_manifiesto.dart';

/// Resultado del OCR de un manifiesto.
class ResultadoOcr {
  const ResultadoOcr({
    required this.numeroPro,
    required this.fecha,
    required this.cliente,
    required this.confianza,
  });

  final String numeroPro;
  final DateTime? fecha;
  final String cliente;
  final double confianza;

  int? get confianzaPorcentaje => (confianza * 100).round();
}

/// Extracción de campos vía la Edge Function `ocr-manifiesto` (OpenAI).
///
/// Se usa en Web, donde ML Kit (on-device) no está disponible. La clave del
/// proveedor vive como secreto del servidor; la app nunca la conoce.
class OcrOpenAi {
  OcrOpenAi(this._client);

  final SupabaseClient _client;

  static const String _funcion = 'ocr-manifiesto';

  Future<ResultadoOcr> extraer(Uint8List bytes, {String? contentType}) async {
    try {
      final respuesta = await _client.functions.invoke(
        _funcion,
        body: {
          'base64': base64Encode(bytes),
          'contentType': contentType ?? 'image/jpeg',
        },
      );
      final data = respuesta.data;
      if (data is! Map || data['ok'] != true) {
        throw Exception(_mensaje(data));
      }
      return ResultadoOcr(
        numeroPro: (data['numero_pro'] as String?) ?? '',
        fecha: _fecha(data['fecha']),
        cliente: (data['cliente'] as String?) ?? '',
        confianza: _doble(data['confianza']) ?? 0,
      );
    } on FunctionException catch (e) {
      throw Exception(_desdeFuncion(e));
    }
  }

  static String _mensaje(Object? data) {
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'No se pudieron reconocer los datos del manifiesto.';
  }

  static String _desdeFuncion(FunctionException e) {
    final detalles = e.details;
    if (detalles is Map && detalles['error'] != null) {
      return detalles['error'].toString();
    }
    return 'No se pudo procesar la imagen del manifiesto.';
  }

  static DateTime? _fecha(Object? valor) =>
      valor == null ? null : DateTime.tryParse(valor.toString());

  static double? _doble(Object? valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString());
  }
}

/// Convierte el texto crudo del OCR (on-device) en [ResultadoOcr].
///
/// La confianza de ML Kit no es un score global por documento, por lo que se
/// reporta 0 (la revisión humana es obligatoria de todos modos).
ResultadoOcr resultadoDesdeTexto(String texto) {
  final parseo = ParserManifiesto.parsear(texto);
  return ResultadoOcr(
    numeroPro: parseo.numeroPro,
    fecha: parseo.fecha,
    cliente: parseo.cliente,
    confianza: parseo.tieneAlgo ? 0.5 : 0,
  );
}

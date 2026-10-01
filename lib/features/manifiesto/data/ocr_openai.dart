import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/manifiesto.dart';
import 'parser_manifiesto.dart';

/// Resultado del OCR de un manifiesto: fecha de cabecera y documentos.
class ResultadoOcr {
  const ResultadoOcr({
    required this.fecha,
    required this.documentos,
    required this.confianza,
  });

  final DateTime? fecha;
  final List<DocumentoDetectado> documentos;
  final double confianza;

  int? get confianzaPorcentaje => (confianza * 100).round();

  bool get tieneAlgo => fecha != null || documentos.isNotEmpty;

  /// Líneas listas para el editor.
  List<ManifiestoLinea> aLineas() => [
        for (var i = 0; i < documentos.length; i++)
          ManifiestoLinea(
            tipo: documentos[i].tipo,
            numero: documentos[i].numero,
            clienteTexto: documentos[i].cliente,
            orden: i,
          ),
      ];
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
        fecha: _fecha(data['fecha']),
        documentos: _documentos(data['documentos']),
        confianza: _doble(data['confianza']) ?? 0,
      );
    } on FunctionException catch (e) {
      throw Exception(_desdeFuncion(e));
    }
  }

  static List<DocumentoDetectado> _documentos(Object? raw) {
    if (raw is! List) return [];
    final out = <DocumentoDetectado>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final numero = (item['numero'] as String?)?.trim() ?? '';
      if (numero.isEmpty) continue;
      out.add(DocumentoDetectado(
        tipo: TipoDocumento.desde(item['tipo'] as String?),
        numero: numero,
        cliente: (item['cliente'] as String?)?.trim(),
      ));
    }
    return out;
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
ResultadoOcr resultadoDesdeTexto(String texto) {
  final parseo = ParserManifiesto.parsear(texto);
  return ResultadoOcr(
    fecha: parseo.fecha,
    documentos: parseo.documentos,
    confianza: parseo.tieneAlgo ? 0.5 : 0,
  );
}

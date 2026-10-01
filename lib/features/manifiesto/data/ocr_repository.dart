import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ocr_mlkit.dart';
import 'ocr_openai.dart';

export 'ocr_openai.dart' show ResultadoOcr;

/// Punto único de OCR del manifiesto.
///
/// Elige la estrategia según la plataforma:
///   * Móvil (Android/iOS): ML Kit on-device (offline, sin costo).
///   * Web: Edge Function `ocr-manifiesto` (OpenAI).
class OcrRepository {
  OcrRepository(this._client);

  final SupabaseClient _client;

  final _mlkit = OcrMlkitMovil();
  late final _openai = OcrOpenAi(_client);

  Future<ResultadoOcr> extraer(Uint8List bytes, {String? contentType}) async {
    if (!kIsWeb) {
      final texto = await _mlkit.reconocerTexto(bytes);
      return resultadoDesdeTexto(texto);
    }
    return _openai.extraer(bytes, contentType: contentType);
  }
}

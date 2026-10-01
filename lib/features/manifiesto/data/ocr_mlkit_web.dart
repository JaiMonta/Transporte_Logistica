import 'dart:typed_data';

/// Implementación para Web (ML Kit no está disponible).
///
/// El OCR en Web se resuelve con la Edge Function (OpenAI) o de forma manual.
class OcrMlkitMovil {
  Future<String> reconocerTexto(Uint8List bytes) async {
    throw UnsupportedError(
      'ML Kit no está disponible en Web. Usa OCR remoto o captura manual.',
    );
  }
}

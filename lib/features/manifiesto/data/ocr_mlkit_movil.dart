import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reconocimiento de texto con Google ML Kit (on-device, solo móvil).
///
/// No requiere red ni claves: el modelo está embebido en la app.
class OcrMlkitMovil {
  /// Reconoce el texto de una imagen (JPEG/PNG en bytes) y devuelve el
  /// texto crudo. Escribe un archivo temporal porque ML Kit acepta una ruta
  /// de archivo y así gestiona la decodificación y la rotación por sí mismo.
  Future<String> reconocerTexto(Uint8List bytes) async {
    final archivo = File(
      '${Directory.systemTemp.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final reconocedor = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      await archivo.writeAsBytes(bytes, flush: true);
      final imagen = InputImage.fromFilePath(archivo.path);
      final resultado = await reconocedor.processImage(imagen);
      return resultado.text;
    } finally {
      await reconocedor.close();
      try {
        await archivo.delete();
      } catch (_) {
        // Si no se puede borrar el temporal, no es crítico.
      }
    }
  }
}

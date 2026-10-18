// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

/// Descarga un archivo de texto desde el navegador (solo Web).
bool descargarArchivo(String nombre, String contenido, String tipo) {
  final bytes = utf8.encode(contenido);
  final blob = html.Blob([bytes], tipo);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final ancla = html.AnchorElement(href: url)
    ..download = nombre
    ..style.display = 'none';
  html.document.body!.append(ancla);
  ancla.click();
  ancla.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}

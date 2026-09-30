import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Buckets privados del sistema.
enum BucketEvidencia {
  manifiestos('manifiestos'),
  firmas('firmas'),
  extras('extras');

  const BucketEvidencia(this.valor);

  final String valor;
}

/// Tipos de evidencia registrados en public.evidencias.
enum TipoEvidencia {
  bol,
  firma,
  recibo,
  extra,
  otro;

  static TipoEvidencia desde(String? valor) =>
      TipoEvidencia.values.firstWhere(
        (t) => t.name == valor,
        orElse: () => TipoEvidencia.otro,
      );

  String get valor => name;
}

/// Resultado de una subida ya registrada.
class EvidenciaSubida {
  const EvidenciaSubida({
    required this.bucket,
    required this.path,
    required this.hashSha256,
    required this.tamanoBytes,
  });

  final String bucket;
  final String path;
  final String hashSha256;
  final int tamanoBytes;
}

/// Comprime, sube y firma archivos de evidencia en Supabase Storage.
///
/// La compresión reduce el peso antes de subir (JPEG calidad 70 y lado
/// mayor 1600 px) y se calcula el SHA-256 para verificar integridad.
/// Las URLs firmadas de corta vida las emite la Edge Function `firmar-url`.
class AlmacenamientoRepository {
  AlmacenamientoRepository(this._cliente);

  final SupabaseClient _cliente;

  static const String _funcion = 'firmar-url';
  static const int _ladoMaximo = 1600;
  static const int _calidadJpeg = 70;

  /// Comprime una imagen a JPEG (calidad 70, lado mayor 1600 px).
  Uint8List comprimirImagen(Uint8List original) {
    final decodificada = img.decodeImage(original);
    if (decodificada == null) return original;

    final ancho = decodificada.width;
    final alto = decodificada.height;
    final mayor = ancho > alto ? ancho : alto;
    final redimensionada = mayor > _ladoMaximo
        ? img.copyResize(
            decodificada,
            width: ancho >= alto ? _ladoMaximo : null,
            height: alto > ancho ? _ladoMaximo : null,
          )
        : decodificada;

    return img.encodeJpg(redimensionada, quality: _calidadJpeg);
  }

  /// Calcula el hash SHA-256 en hexadecimal.
  String hashSha256(Uint8List bytes) => sha256.convert(bytes).toString();

  /// Ruta del archivo dentro del bucket: {uid}/{carpeta}/{archivo}.
  String rutaDe({
    required String carpeta,
    required String archivo,
    String? uid,
  }) {
    final usuario = uid ?? _cliente.auth.currentUser?.id ?? 'anonimo';
    return '$usuario/$carpeta/$archivo';
  }

  /// Sube (comprime si es imagen), registra la evidencia y devuelve datos.
  Future<EvidenciaSubida> subir({
    required BucketEvidencia bucket,
    required String path,
    required Uint8List bytes,
    TipoEvidencia tipo = TipoEvidencia.otro,
    bool comprimir = true,
    String? contentType,
  }) async {
    final contenido = comprimir ? comprimirImagen(bytes) : bytes;
    final hash = hashSha256(contenido);
    final ct = contentType ?? (comprimir ? 'image/jpeg' : 'application/octet-stream');

    await _cliente.storage.from(bucket.valor).uploadBinary(
          path,
          contenido,
          fileOptions: FileOptions(contentType: ct, upsert: true),
        );

    await _cliente.from('evidencias').upsert(
      {
        'usuario_id': _cliente.auth.currentUser?.id,
        'tipo': tipo.valor,
        'bucket': bucket.valor,
        'path': path,
        'hash_sha256': hash,
        'tamano_bytes': contenido.length,
      },
      onConflict: 'bucket,path',
    );

    return EvidenciaSubida(
      bucket: bucket.valor,
      path: path,
      hashSha256: hash,
      tamanoBytes: contenido.length,
    );
  }

  /// Pide a la Edge Function una URL firmada de corta vida.
  Future<String> urlFirmada({
    required BucketEvidencia bucket,
    required String path,
    int expiresIn = 60,
  }) async {
    final respuesta = await _cliente.functions.invoke(
      _funcion,
      body: {
        'action': 'sign',
        'bucket': bucket.valor,
        'path': path,
        'expiresIn': expiresIn,
      },
    );
    final data = respuesta.data;
    if (data is Map && data['ok'] == true && data['url'] != null) {
      return data['url'].toString();
    }
    throw Exception('No se pudo firmar la URL del archivo.');
  }

  /// Elimina un archivo (solo administradores, vía Edge Function).
  Future<void> eliminar({
    required BucketEvidencia bucket,
    required String path,
  }) async {
    final respuesta = await _cliente.functions.invoke(
      _funcion,
      body: {
        'action': 'remove',
        'bucket': bucket.valor,
        'path': path,
      },
    );
    final data = respuesta.data;
    if (!(data is Map && data['ok'] == true)) {
      throw Exception('No se pudo eliminar el archivo.');
    }
  }

  /// Convierte bytes a base64 (para invocaciones que lo requieran).
  String aBase64(Uint8List bytes) => base64Encode(bytes);
}

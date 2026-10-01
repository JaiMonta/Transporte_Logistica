import '../models/manifiesto.dart';

/// Documento detectado en el texto del OCR (antes de revisión humana).
class DocumentoDetectado {
  const DocumentoDetectado({
    required this.tipo,
    required this.numero,
    this.cliente,
  });

  final TipoDocumento tipo;
  final String numero;
  final String? cliente;
}

/// Resultado del parseo de un manifiesto/guía de carga.
class ResultadoParseoManifiesto {
  const ResultadoParseoManifiesto({
    required this.fecha,
    required this.documentos,
  });

  final DateTime? fecha;
  final List<DocumentoDetectado> documentos;

  bool get tieneAlgo => fecha != null || documentos.isNotEmpty;

  /// Líneas listas para el editor (sin id).
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

/// Extrae la fecha (cabecera) y las líneas de documento (PRO/factura) del
/// texto crudo del OCR. Función pura; no inventa datos.
class ParserManifiesto {
  const ParserManifiesto._();

  static ResultadoParseoManifiesto parsear(String texto) {
    final lineas = texto
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return ResultadoParseoManifiesto(
      fecha: extraerFecha(texto),
      documentos: extraerDocumentos(lineas),
    );
  }

  /// Detecta líneas de documento. Estrategia best-effort:
  ///   1) Líneas que declaran PRO o FACTURA explícitamente.
  ///   2) Códigos sueltos tipo MN-8921 / BOL-485729A / 485729.
  static List<DocumentoDetectado> extraerDocumentos(List<String> lineas) {
    final documentos = <DocumentoDetectado>[];
    final vistos = <String>{};

    for (final linea in lineas) {
      final detectado = _detectarEnLinea(linea);
      if (detectado == null) continue;
      final clave = '${detectado.tipo.valor}|${detectado.numero.toLowerCase()}';
      if (vistos.contains(clave)) continue;
      vistos.add(clave);
      documentos.add(detectado);
    }
    return documentos;
  }

  static DocumentoDetectado? _detectarEnLinea(String linea) {
    final upper = linea.toUpperCase();

    // 1) Etiqueta explícita PRO / FACTURA (token seguido de código).
    final etiqueta = RegExp(
      r'\b(PRO|FACTURA|FACT)\b\s*[:#.\-]?\s*([A-Z0-9][A-Z0-9\-/ ]{2,})',
    );
    final mEt = etiqueta.firstMatch(upper);
    if (mEt != null) {
      final numero = _limpiar(mEt.group(2));
      if (numero.isNotEmpty && _pareceCodigo(numero)) {
        return DocumentoDetectado(
          tipo: _tipoDeEtiqueta(mEt.group(1)!),
          numero: numero,
          cliente: _clienteDeLinea(linea),
        );
      }
    }

    // Si la línea es claramente una fecha u otro metadato, no es documento.
    if (_pareceFecha(upper)) return null;

    // 2) Código suelto tipo letras-dígitos (MN-8921 / BOL-485729A).
    final suelto = RegExp(r'\b([A-Z]{2,4}[-/ ]?\d{3,}[A-Z0-9]*)\b');
    final mS = suelto.firstMatch(upper);
    if (mS != null) {
      final numero = _limpiar(mS.group(1));
      if (numero.isNotEmpty) {
        return DocumentoDetectado(
          tipo: TipoDocumento.pro,
          numero: numero,
          cliente: _clienteDeLinea(linea),
        );
      }
    }

    // 3) Número puro largo (>=4 dígitos). Se descarta si la línea es del año.
    final soloNum = RegExp(r'\b(\d{4,})\b');
    final mN = soloNum.firstMatch(upper);
    if (mN != null) {
      return DocumentoDetectado(
        tipo: TipoDocumento.factura,
        numero: mN.group(1)!,
        cliente: _clienteDeLinea(linea),
      );
    }
    return null;
  }

  /// Un código de documento tiene al menos un dígito y no es una fecha.
  static bool _pareceCodigo(String valor) {
    if (!RegExp(r'\d').hasMatch(valor)) return false;
    if (_pareceFecha(valor.toUpperCase())) return false;
    return true;
  }

  /// Descarta líneas que son solo una fecha (evita captar años como folios).
  static bool _pareceFecha(String texto) {
    if (RegExp(r'^\s*(FECHA|DATE)\b').hasMatch(texto)) return true;
    if (RegExp(r'\b\d{4}-\d{1,2}-\d{1,2}\b').hasMatch(texto)) return true;
    if (RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{4}\b').hasMatch(texto)) return true;
    return false;
  }

  static TipoDocumento _tipoDeEtiqueta(String etiqueta) {
    if (etiqueta.startsWith('FACT')) return TipoDocumento.factura;
    return TipoDocumento.pro;
  }

  /// Cliente tras etiquetas típicas, dentro de la misma línea.
  static String? _clienteDeLinea(String linea) {
    final etiqueta = RegExp(
      r'(?:cliente|destinatario|consignee|raz[oó]n\s+social)\s*[:#-]?\s*(.+)',
      caseSensitive: false,
    );
    final m = etiqueta.firstMatch(linea);
    if (m != null) {
      final valor = m.group(1)!.trim();
      if (valor.length >= 3) return valor;
    }
    return null;
  }

  /// Fecha en varios formatos: ISO, dd/mm/aaaa, dd-mm-aaaa, aaaa/mm/dd.
  static DateTime? extraerFecha(String texto) {
    final iso = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b');
    final mIso = iso.firstMatch(texto);
    if (mIso != null) {
      return _construir(mIso.group(1)!, mIso.group(2)!, mIso.group(3)!);
    }

    final dma = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b');
    final mDma = dma.firstMatch(texto);
    if (mDma != null) {
      return _construir(mDma.group(3)!, mDma.group(2)!, mDma.group(1)!);
    }

    final amd = RegExp(r'\b(\d{4})[/](\d{1,2})[/](\d{1,2})\b');
    final mAmd = amd.firstMatch(texto);
    if (mAmd != null) {
      return _construir(mAmd.group(1)!, mAmd.group(2)!, mAmd.group(3)!);
    }
    return null;
  }

  static DateTime? _construir(String anio, String mes, String dia) {
    final a = int.tryParse(anio);
    final me = int.tryParse(mes);
    final d = int.tryParse(dia);
    if (a == null || me == null || d == null) return null;
    if (me < 1 || me > 12 || d < 1 || d > 31) return null;
    try {
      return DateTime(a, me, d);
    } catch (_) {
      return null;
    }
  }

  static String _limpiar(String? valor) => (valor ?? '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[-\s.:#]+'), '')
      .trim();
}

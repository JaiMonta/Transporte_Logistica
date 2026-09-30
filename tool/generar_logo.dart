import 'dart:io';

import 'package:image/image.dart' as img;

final _azul = img.ColorRgb8(0x3C, 0x5A, 0xA0);
final _azulOscuro = img.ColorRgb8(0x2A, 0x3F, 0x72);
final _ambar = img.ColorRgb8(0x86, 0x52, 0x23);

img.Image _lienzo(int w, int h) {
  final l = img.Image(width: w, height: h, numChannels: 4);
  img.fill(l, color: img.ColorRgba8(0, 0, 0, 0));
  return l;
}

// Dibuja (acumulando) usando antialias aproximado por 4 subpuntos.
void _aa(
  img.Image im,
  bool Function(num x, num y) dentro,
  void Function(int x, int y) pintar, {
  int sub = 3,
}) {
  final w = im.width, h = im.height;
  final cobertura = List<int>.filled(w * h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var dentroCount = 0;
      for (var sy = 0; sy < sub; sy++) {
        for (var sx = 0; sx < sub; sx++) {
          final px = x + (sx + 0.5) / sub;
          final py = y + (sy + 0.5) / sub;
          if (dentro(px, py)) dentroCount++;
        }
      }
      cobertura[y * w + x] = (dentroCount * 255) ~/ (sub * sub);
    }
  }
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final c = cobertura[y * w + x];
      if (c > 0) pintar(x, y);
    }
  }
}

void _blendPixel(img.Image im, int x, int y, img.Color color, int alpha) {
  final actual = im.getPixel(x, y);
  final a = alpha / 255;
  final na = actual.a / 255;
  final outA = a + na * (1 - a);
  if (outA <= 0) return;
  final r = (color.r * a + actual.r * na * (1 - a)) / outA;
  final g = (color.g * a + actual.g * na * (1 - a)) / outA;
  final b = (color.b * a + actual.b * na * (1 - a)) / outA;
  im.setPixelRgba(x, y, r.round(), g.round(), b.round(), (outA * 255).round());
}

void _circulo(img.Image im, num cx, num cy, num r, img.Color color) {
  _aa(im, (x, y) => (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r,
      (x, y) => _blendPixel(im, x, y, color, 255));
}

void _rect(img.Image im, num x0, num y0, num x1, num y1, img.Color color) {
  _aa(im, (x, y) => x >= x0 && x <= x1 && y >= y0 && y <= y1,
      (x, y) => _blendPixel(im, x, y, color, 255));
}

// Rectángulo redondeado.
void _rr(img.Image im, num x0, num y0, num x1, num y1, num r, img.Color color) {
  bool dentro(num x, num y) {
    if (x < x0 || x > x1 || y < y0 || y > y1) return false;
    final ix = x < x0 + r ? x0 + r : (x > x1 - r ? x1 - r : x);
    final iy = y < y0 + r ? y0 + r : (y > y1 - r ? y1 - r : y);
    final dx = x - ix, dy = y - iy;
    return dx * dx + dy * dy <= r * r;
  }

  _aa(im, dentro, (x, y) => _blendPixel(im, x, y, color, 255));
}

void main() {
  final size = 512;
  final im = _lienzo(size, size);

  // Lona circular de fondo (azul primario) con borde.
  _circulo(im, size / 2, size / 2, size / 2 - 4, _azul);
  _aa(im,
      (x, y) {
        final d = ((x - size / 2) * (x - size / 2) +
            (y - size / 2) * (y - size / 2));
        return d <= (size / 2 - 2) * (size / 2 - 2) &&
            d >= (size / 2 - 12) * (size / 2 - 12);
      },
      (x, y) => _blendPixel(im, x, y, _azulOscuro, 90));

  // ---- Camión estilizado (silueta clara) ----
  final blanco = img.ColorRgb8(0xF6, 0xF7, 0xFB);
  // Caja de carga.
  _rr(im, 132, 250, 250, 330, 12, blanco);
  // Cabina.
  _rr(im, 250, 268, 330, 330, 12, blanco);
  // Parabrisas (ámbar).
  _rr(im, 292, 276, 324, 306, 6, _ambar);
  // Franja de acento en la caja.
  _rect(im, 146, 292, 236, 304, _ambar);
  // Defensa inferior.
  _rr(im, 138, 330, 324, 344, 6, _azulOscuro);

  // Ruedas.
  final llanta = img.ColorRgb8(0x1A, 0x1B, 0x20);
  _circulo(im, 176, 344, 22, llanta);
  _circulo(im, 296, 344, 22, llanta);
  _circulo(im, 176, 344, 9, blanco);
  _circulo(im, 296, 344, 9, blanco);

  // ---- Monograma genérico arriba (barras abstractas de ruta) ----
  // No usa letras/empresa: tres barras ascendentes que evocan carretera.
  _rr(im, 208, 150, 232, 214, 8, blanco);
  _rr(im, 244, 128, 268, 214, 8, _ambar);
  _rr(im, 280, 166, 304, 214, 8, blanco);

  File('assets/logo.png').writeAsBytesSync(img.encodePng(im));
  // ignore: avoid_print
  print('logo.png generado: ${im.width}x${im.height}');
}

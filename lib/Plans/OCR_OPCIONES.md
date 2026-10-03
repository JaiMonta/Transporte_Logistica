# OCR del proyecto — opciones, decisión e implementación

Documento de decisión sobre el reconocimiento de texto (OCR) del manifiesto
(nº PRO, fecha y cliente de la foto del BOL).

## Estado actual (jornada): RETIRADO — captura manual

- **El OCR queda FUERA por ahora.** Se retiró **Google ML Kit** (móvil) y se
  **despublicó la Edge Function `ocr-manifiesto`** (OpenAI). La app usa
  **captura manual** de los datos del manifiesto (nº PRO/FACTURA, fecha y
  cliente por líneas).
- Los archivos de OCR se eliminaron (recuperables vía git):
  `data/ocr_mlkit*.dart`, `data/ocr_openai.dart`, `data/ocr_repository.dart`.
  Se **conserva** `data/parser_manifiesto.dart` (+ su test) para retomarlo luego.
- Dependencia `google_mlkit_text_recognition` eliminada del `pubspec.yaml`;
  Android (`build.gradle.kts`, `proguard-rules.pro`) e iOS (`Podfile`) limpios.

## Decisión histórica (referencia)

- **Móvil (Android/iOS): Google ML Kit Text Recognition** (on-device).
- **Web: Edge Function `ocr-manifiesto` (OpenAI `gpt-4o-mini`)** o captura manual.
- **Tesseract OCR:** evaluado y **descartado** para móvil (ver análisis).

El OCR era solo una **propuesta**: el chofer siempre revisa y corrige los campos
antes de guardar (revisión humana obligatoria).

---

## Opciones evaluadas

### 1. OpenAI (visión) — en uso para Web
- Edge Function `ocr-manifiesto` → `gpt-4o-mini` con Structured Outputs.
- Devuelve campos ya interpretados (`numero_pro`, `fecha`, `cliente`, `confianza`).
- **Requiere internet** y **saldo** en la cuenta de OpenAI.
- Se mantiene **solo para Web** (donde ML Kit no existe).

### 2. Google ML Kit Text Recognition — **elegido para móvil**
- Plugin `google_mlkit_text_recognition` (`^0.17.1`), mantenido por `flutter-ml`.
- **On-device**: sin internet, sin claves, sin costo. Ideal para campo.
- Reconoce **escritura latina** (español) y devuelve texto estructurado.
- **Solo Android/iOS** (no Web, no escritorio).
- **Bundled** (modelo embebido): +~4 MB Android; iOS ~38 MB por el SDK latino.
- Requisitos: Android `minSdk` ≥ 21 (usamos 24); iOS ≥ **15.5**; excluir armv7.

### 3. Tesseract OCR — **descartado para móvil**

Dos paquetes principales:

| Paquete | Plataformas | Notas |
|---|---|---|
| `tesseract_ocr` | Android + iOS (y Apple Vision en iOS) | iOS requiere `libtesseract.xcframework` + Podfile custom (frágil). |
| `flutter_tesseract_ocr` | Android + iOS + **Web** (tesseract.js) | Exige empaquetar `.traineddata` como assets. |

**Motivos del descarte para móvil:**
- Calidad inferior a ML Kit en documentos tipo BOL y más sensible a la calidad/alineación de la foto.
- En Android/iOS obliga a **empaquetar modelos `.traineddata`** (~10–15 MB por idioma) como assets y mantener `tessdata_config.json`; más pasos.
- En **iOS** el setup es **frágil** (framework manual, Podfile custom, arrastrar tessdata a Runner en Xcode).
- Mantenimiento del plugin más lento que `flutter-ml`.
- Su **única ventaja real es el soporte Web**, que en este proyecto ya se cubre con OpenAI.

**Opción futura anotada (sin implementar):** si en el futuro se quiere **OCR
offline también en Web** y reemplazar a OpenAI, se podría usar
`flutter_tesseract_ocr` en web (carga `tesseract.js` desde `index.html` y usa
`FlutterTesseractOcr.extractText`). Hoy no es necesario porque la decisión para
Web es OpenAI o captura manual.

---

## Comparación rápida

| Criterio | ML Kit | Tesseract | OpenAI (visión) |
|---|---|---|---|
| Plataformas | Android + iOS | Android + iOS (+ Web) | Todas (vía Edge Function) |
| Offline | ✅ | ✅ (web descarga wasm/modelo) | ❌ |
| Clave/cuenta | no | no | sí (OpenAI) |
| Costo | gratis | gratis | por uso |
| Config iOS | pod, min 15.5 | frágil (xcframework) | n/a |
| Assets propios | no (embebido) | sí (`traineddata`) | no |
| Calidad en BOL | alta | media | muy alta |
| Rol en el proyecto | **OCR móvil** | descartado | **OCR Web** |

---

## Implementación (Módulo 4)

### Dependencias y nativo
- `pubspec.yaml`: `google_mlkit_text_recognition: ^0.17.1`.
- `android/app/build.gradle.kts`: `minSdk = 24`; dependencia **bundled**
  `com.google.mlkit:text-recognition:16.0.1`; `proguard-rules.pro` con
  `-dontwarn` de los scripts no latinos (R8 los marca como faltantes si solo se
  usa el latino).
- `ios/Podfile` (nuevo): `platform :ios, '15.5'`, `$iOSVersion = '15.5'`,
  `EXCLUDED_ARCHS[sdk=*] = armv7`, `pod 'GoogleMLKit/TextRecognition', '~> 9.0.0'`.
- `ios/Runner.xcodeproj/project.pbxproj`: `IPHONEOS_DEPLOYMENT_TARGET = 15.5`.

### Código Flutter
- `data/ocr_mlkit.dart` (facade con import condicional) →
  `ocr_mlkit_movil.dart` (ML Kit) / `ocr_mlkit_web.dart` (no-op que lanza).
- `data/ocr_mlkit_movil.dart`: `TextRecognizer(latin)` sobre un archivo temporal
  (`InputImage.fromFilePath`), devuelve el texto crudo.
- `data/parser_manifiesto.dart`: función **pura** que extrae `numero_pro`,
  `fecha` y `cliente` del texto (regex + heurística, sin inventar datos).
- `data/ocr_openai.dart`: implementación OpenAI (Web) + `resultadoDesdeTexto`
  (adapta el parseo al `ResultadoOcr`).
- `data/ocr_repository.dart`: punto único; decide por plataforma
  (`!kIsWeb` → ML Kit + parser; Web → OpenAI). La pantalla de captura **no cambia**.

### Pruebas
- `test/parser_manifiesto_test.dart` (multi-línea): folio, factura, fechas
  (ISO, dd/mm, dd-mm), varios documentos, deduplicación y documento integral.
- Total del proyecto: **54 en verde** (`flutter analyze` limpio).
- Compila Web (`flutter build web`) y Android (`flutter build apk`).
- ML Kit **no se puede probar en Web ni en escritorio**: requiere dispositivo móvil.

### Extracción multi-línea
Un manifiesto/guía puede tener **N líneas** de documento (PRO o factura), cada
una con su número y cliente. El OCR intenta proponerlas todas:
- **OpenAI (web):** el esquema de salida devuelve
  `{fecha, confianza, documentos:[{tipo, numero, cliente}]}`.
- **ML Kit (móvil):** el texto se pasa a `ParserManifiesto.parsear`, que detecta
  filas best-effort (etiquetas PRO/FACTURA/FACT y códigos tipo `MN-8921`).
- La revisión humana (editor de líneas) permite agregar, quitar o corregir.

### Notas
- APK de referencia con ML Kit: ~100.7 MB (antes ~71 MB) por el modelo embebido;
  usar `--split-per-abi` reduce el tamaño por arquitectura.
- El OCR de OpenAI sigue pendiente de **saldo** (429 "no credits").

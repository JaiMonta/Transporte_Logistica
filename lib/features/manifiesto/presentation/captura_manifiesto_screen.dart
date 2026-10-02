import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/services/almacenamiento_providers.dart';
import '../../../shared/services/almacenamiento_repository.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/models/profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../camiones/providers/camiones_providers.dart';
import '../../combustible/presentation/dialogo_combustible.dart';
import '../../combustible/providers/combustible_providers.dart';
import '../data/ocr_repository.dart';
import '../models/manifiesto.dart';
import '../providers/manifiestos_providers.dart';
import 'widgets/lineas_editor.dart';

/// Captura de un manifiesto.
///
/// En móvil usa la cámara en vivo; en Web/escritorio permite **seleccionar
/// un archivo de imagen** (útil para pruebas desde la web móvil).
/// Flujo: foto del BOL -> compresión + subida al bucket `manifiestos`
/// -> OCR (Edge Function) -> revisión humana de los campos -> guardar.
class CapturaManifiestoScreen extends ConsumerStatefulWidget {
  const CapturaManifiestoScreen({super.key});

  @override
  ConsumerState<CapturaManifiestoScreen> createState() =>
      _CapturaManifiestoScreenState();
}

class _CapturaManifiestoScreenState
    extends ConsumerState<CapturaManifiestoScreen> {
  CameraController? _camara;
  bool _iniciando = false;
  bool _errorCamara = false;
  bool _procesando = false;
  bool _linterna = false;

  Uint8List? _foto;
  EvidenciaSubida? _evidencia;
  ResultadoOcr? _ocr;

  final _formKey = GlobalKey<FormState>();
  final _fecha = TextEditingController();
  List<ManifiestoLinea> _lineas = [];
  String? _camionId;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _iniciarCamara();
  }

  @override
  void dispose() {
    _camara?.dispose();
    _fecha.dispose();
    super.dispose();
  }

  Future<void> _iniciarCamara() async {
    setState(() {
      _iniciando = true;
      _errorCamara = false;
    });
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) throw Exception('No hay cámara disponible.');
      final trasera = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      final controlador = CameraController(
        trasera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controlador.initialize();
      if (!mounted) {
        await controlador.dispose();
        return;
      }
      setState(() {
        _camara = controlador;
        _iniciando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _iniciando = false;
        _errorCamara = true;
      });
    }
  }

  Future<void> _alternarLinterna() async {
    final camara = _camara;
    if (camara == null || !camara.value.isInitialized) return;
    try {
      await camara.setFlashMode(_linterna ? FlashMode.off : FlashMode.torch);
      setState(() => _linterna = !_linterna);
    } catch (_) {
      // Algunos dispositivos no soportan la linterna; se ignora.
    }
  }

  Future<void> _capturar() async {
    final camara = _camara;
    if (camara == null || !camara.value.isInitialized || _procesando) return;
    setState(() => _procesando = true);
    try {
      final archivo = await camara.takePicture();
      final bytes = await archivo.readAsBytes();
      await _procesarBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  /// Selecciona una imagen desde el almacenamiento (Web/escritorio).
  ///
  /// Permite probar el flujo completo (subida + OCR + guardado) desde la web
  /// móvil, donde no hay acceso a la cámara en vivo.
  Future<void> _seleccionarArchivo() async {
    if (_procesando) return;
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (archivo == null) return;
      setState(() => _procesando = true);
      final bytes = await archivo.readAsBytes();
      await _procesarBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  /// Sube la imagen al bucket, ejecuta el OCR y pasa a la revisión.
  Future<void> _procesarBytes(Uint8List bytes) async {
    final almacen = ref.read(almacenamientoRepositoryProvider);

    // Comprime y sube al bucket privado `manifiestos`.
    final comprimida = almacen.comprimirImagen(bytes);
    final path = almacen.rutaDe(
      carpeta: 'bol',
      archivo: 'bol_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final evidencia = await almacen.subir(
      bucket: BucketEvidencia.manifiestos,
      path: path,
      bytes: comprimida,
      tipo: TipoEvidencia.bol,
    );

    // OCR (Edge Function; si falla, se permite continuar manualmente).
    ResultadoOcr? ocr;
    try {
      ocr = await ref.read(ocrRepositoryProvider).extraer(
            comprimida,
            contentType: 'image/jpeg',
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo reconocer el documento. Completa los datos manualmente.',
            ),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _foto = comprimida;
      _evidencia = evidencia;
      _ocr = ocr;
      _procesando = false;
      _fecha.text = _fechaTexto(ocr?.fecha ?? DateTime.now());
      _lineas = ocr?.aLineas() ?? [];
    });
  }

  Future<void> _repetirFoto() async {
    await _camara?.resumePreview();
    setState(() {
      _foto = null;
      _evidencia = null;
      _ocr = null;
      _fecha.clear();
      _lineas = [];
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final fecha = _parseFecha(_fecha.text);
    if (fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una fecha válida.')),
      );
      return;
    }
    final validas =
        _lineas.where((l) => l.numero.trim().isNotEmpty).toList();
    if (validas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un documento.')),
      );
      return;
    }
    final esAdmin = ref.read(currentProfileProvider).value?.rol == Rol.admin;
    if (!esAdmin && _camionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el camión.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);
    try {
      final repo = ref.read(manifiestosRepositoryProvider);

      // Unicidad (tipo + número + fecha) validada en la app.
      for (final l in validas) {
        final existe = await repo.existeDocumento(
          tipo: l.tipo,
          numero: l.numero,
          fecha: fecha,
        );
        if (existe) {
          throw Exception(
            'Ya existe un documento ${l.tipo.etiqueta} ${l.numero} con la fecha ${_fechaTexto(fecha)}.',
          );
        }
      }

      final creado = await repo.crear(
        fecha: fecha,
        lineas: validas,
        camionId: _camionId,
        bucket: _evidencia?.bucket,
        path: _evidencia?.path,
        hashSha256: _evidencia?.hashSha256,
        ocrConfianza: _ocr?.confianza,
        cotejo: CotejoEstado.pendiente,
      );
      if (!mounted) return;
      ref.invalidate(manifiestosProvider);

      final perfil = ref.read(currentProfileProvider).value;
      final esAdmin = perfil?.rol == Rol.admin;

      if (!esAdmin) {
        // El chofer registra los litros iniciales y arranca la jornada.
        final datos = await mostrarDialogoCombustible(
          context,
          titulo: 'Combustible inicial',
          etiquetaLitros: 'Litros iniciales',
        );
        if (datos != null) {
          await ref.read(combustibleRepositoryProvider).iniciar(
                manifiestoId: creado.id,
                litrosIniciales: datos.litros,
                odometroInicial: datos.odometro,
              );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manifiesto guardado.')),
        );
        // Comienza la entrega: ir a Entregas del día (arranca el GPS).
        context.go(Rutas.choferEntregas);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manifiesto guardado.')),
        );
        context.go(Rutas.adminManifiestos);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capturar manifiesto')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: kIsWeb
                ? (_foto == null
                    ? _vistaSeleccionWeb(context)
                    : _vistaRevision(context))
                : (_foto == null
                    ? _vistaCamara(context)
                    : _vistaRevision(context)),
          ),
        ],
      ),
    );
  }

  Widget _vistaSeleccionWeb(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.document_scanner_outlined,
                  size: 64, color: AppColors.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Subir foto del manifiesto',
                textAlign: TextAlign.center,
                style: tema.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Selecciona una imagen del BOL. Se subirá, se leerá con OCR '
                'y podrás revisar los datos antes de guardar.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                texto: 'Seleccionar imagen',
                icono: Icons.upload_file,
                cargando: _procesando,
                onPressed: _seleccionarArchivo,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'En la app móvil la captura se hace con la cámara en vivo.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vistaCamara(BuildContext context) {
    if (_iniciando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorCamara) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  size: 56, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'No se pudo acceder a la cámara. Revisa los permisos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: _iniciarCamara,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    final camara = _camara!;
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: CameraPreview(camara)),
              // Marco guía tipo escáner.
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.exito, width: 3),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
              Positioned(
                bottom: AppSpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Alinea el documento dentro del marco',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                tooltip: 'Linterna',
                iconSize: 28,
                onPressed: _alternarLinterna,
                icon: Icon(_linterna ? Icons.flash_on : Icons.flash_off),
              ),
              _BotonCaptura(
                cargando: _procesando,
                onPressed: _procesando ? null : _capturar,
              ),
              const SizedBox(width: 56),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vistaRevision(BuildContext context) {
    final tema = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.memory(
                    _foto!,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_ocr != null && _ocr!.confianzaPorcentaje != null)
                  _bannerConfianza(context, _ocr!.confianzaPorcentaje!),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _fecha,
                  label: 'Fecha (AAAA-MM-DD)',
                  icono: Icons.event_outlined,
                  hint: '2026-01-31',
                  validator: (v) => _parseFecha(v ?? '') == null
                      ? 'Usa el formato AAAA-MM-DD.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                _SelectorCamion(
                  valor: _camionId,
                  onCambio: (v) => setState(() => _camionId = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                LineasEditor(
                  lineas: _lineas,
                  onCambio: (l) => setState(() => _lineas = l),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  texto: 'Guardar manifiesto',
                  cargando: _guardando,
                  onPressed: _guardar,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: _guardando ? null : _repetirFoto,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Repetir foto'),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Revisa y corrige los datos antes de guardar.',
                    style: tema.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bannerConfianza(BuildContext context, int porcentaje) {
    final color = porcentaje >= 80
        ? AppColors.exito
        : (porcentaje >= 50 ? AppColors.secondary : AppColors.peligro);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Datos reconocidos automáticamente (confianza $porcentaje%).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  static DateTime? _parseFecha(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return null;
    return DateTime.tryParse(t);
  }

  static String _fechaTexto(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }
}

class _BotonCaptura extends StatelessWidget {
  const _BotonCaptura({required this.onPressed, required this.cargando});

  final VoidCallback? onPressed;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
            ),
          ],
        ),
        child: cargando
            ? const Padding(
                padding: EdgeInsets.all(22),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Icon(Icons.photo_camera, color: Colors.white, size: 36),
      ),
    );
  }
}

/// Selector del camión asignado al chofer.
class _SelectorCamion extends ConsumerWidget {
  const _SelectorCamion({required this.valor, required this.onCambio});

  final String? valor;
  final ValueChanged<String?> onCambio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esAdmin = ref.watch(currentProfileProvider).value?.rol == Rol.admin;
    final async = esAdmin
        ? ref.watch(camionesActivosProvider)
        : ref.watch(camionesDelChoferProvider);
    return async.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(labelText: 'Camión'),
        child: SizedBox(
          height: 24,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (e, _) => InputDecorator(
        decoration: const InputDecoration(labelText: 'Camión'),
        child: Text('No se pudieron cargar los camiones: $e'),
      ),
      data: (camiones) {
        if (camiones.isEmpty) {
          return InputDecorator(
            decoration: const InputDecoration(labelText: 'Camión'),
            child: Text(esAdmin
                ? 'No hay camiones activos'
                : 'No tienes camiones asignados'),
          );
        }
        final valido = camiones.any((c) => c.id == valor) ? valor : null;
        return DropdownButtonFormField<String>(
          initialValue: valido,
          decoration: const InputDecoration(labelText: 'Camión'),
          items: camiones
              .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.marcaVisible} · ${c.placa}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: onCambio,
          validator: esAdmin
              ? null
              : (v) => (v == null || v.isEmpty) ? 'Selecciona el camión.' : null,
        );
      },
    );
  }
}

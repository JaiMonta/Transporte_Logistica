import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/services/almacenamiento_providers.dart';
import '../../../shared/services/almacenamiento_repository.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/validators/validador.dart';
import '../../clientes/presentation/widgets/cliente_selector.dart';
import '../data/ocr_repository.dart';
import '../models/manifiesto.dart';
import '../providers/manifiestos_providers.dart';

/// Captura de un manifiesto con la cámara en vivo (solo móvil).
///
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
  final _numeroPro = TextEditingController();
  final _fecha = TextEditingController();
  String? _clienteId;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _iniciarCamara();
  }

  @override
  void dispose() {
    _camara?.dispose();
    _numeroPro.dispose();
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
        _numeroPro.text = ocr?.numeroPro ?? '';
        _fecha.text = _fechaTexto(ocr?.fecha ?? DateTime.now());
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  Future<void> _repetirFoto() async {
    await _camara?.resumePreview();
    setState(() {
      _foto = null;
      _evidencia = null;
      _ocr = null;
      _numeroPro.clear();
      _fecha.clear();
      _clienteId = null;
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
    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);
    try {
      final repo = ref.read(manifiestosRepositoryProvider);
      final existe = await repo.existePro(
        numeroPro: _numeroPro.text,
        fecha: fecha,
        clienteId: _clienteId,
      );
      if (existe) {
        throw Exception(
          'Ya existe un manifiesto con ese número para ese cliente y fecha.',
        );
      }
      await repo.crear(
        numeroPro: _numeroPro.text,
        fecha: fecha,
        clienteId: _clienteId,
        bucket: _evidencia?.bucket,
        path: _evidencia?.path,
        hashSha256: _evidencia?.hashSha256,
        ocrPro: _ocr?.numeroPro,
        ocrConfianza: _ocr?.confianza,
        cotejo: CotejoEstado.pendiente,
      );
      if (!mounted) return;
      ref.invalidate(manifiestosProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manifiesto guardado.')),
      );
      context.go(Rutas.choferManifiestos);
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
                ? _avisoWeb(context)
                : (_foto == null ? _vistaCamara(context) : _vistaRevision(context)),
          ),
        ],
      ),
    );
  }

  Widget _avisoWeb(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera_outlined,
                size: 56, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              'La captura del manifiesto está disponible en la app móvil.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
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
                  controller: _numeroPro,
                  label: 'Número PRO',
                  icono: Icons.confirmation_number_outlined,
                  textInputAction: TextInputAction.next,
                  validator: Validador.nombre,
                ),
                const SizedBox(height: AppSpacing.md),
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
                ClienteSelector(
                  valor: _clienteId,
                  onCambio: (v) => setState(() => _clienteId = v),
                ),
                const SizedBox(height: AppSpacing.xl),
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

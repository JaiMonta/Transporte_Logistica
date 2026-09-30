import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/services/almacenamiento_providers.dart';
import '../../../shared/services/almacenamiento_repository.dart';
import '../../../shared/widgets/status_pill.dart';
import '../models/manifiesto.dart';
import '../providers/manifiestos_providers.dart';

/// Detalle y auditoría de un manifiesto (administrador).
class ManifiestoDetalleScreen extends ConsumerWidget {
  const ManifiestoDetalleScreen({super.key, required this.manifiestoId});

  final String manifiestoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(manifiestoProvider(manifiestoId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del manifiesto')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(mensajeError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (m) => m == null
            ? const Center(child: Text('No se encontró el manifiesto.'))
            : _Contenido(manifiesto: m),
      ),
    );
  }
}

class _Contenido extends ConsumerStatefulWidget {
  const _Contenido({required this.manifiesto});

  final Manifiesto manifiesto;

  @override
  ConsumerState<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends ConsumerState<_Contenido> {
  String? _urlFirmada;
  bool _cargandoFoto = false;
  String? _errorFoto;

  @override
  void initState() {
    super.initState();
    if (widget.manifiesto.tieneFoto) _cargarFoto();
  }

  Future<void> _cargarFoto() async {
    setState(() {
      _cargandoFoto = true;
      _errorFoto = null;
    });
    try {
      final bucket = BucketEvidencia.values.firstWhere(
        (b) => b.valor == widget.manifiesto.bucket,
        orElse: () => BucketEvidencia.manifiestos,
      );
      final url = await ref.read(almacenamientoRepositoryProvider).urlFirmada(
            bucket: bucket,
            path: widget.manifiesto.path!,
            expiresIn: 300,
          );
      if (!mounted) return;
      setState(() {
        _urlFirmada = url;
        _cargandoFoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorFoto = mensajeError(e);
        _cargandoFoto = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.manifiesto;
    final tema = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _foto(context),
              const SizedBox(height: AppSpacing.md),
              _FilaDato(
                icono: Icons.confirmation_number_outlined,
                etiqueta: 'Número PRO',
                valor: m.numeroVisible,
              ),
              _FilaDato(
                icono: Icons.business_outlined,
                etiqueta: 'Cliente',
                valor: m.clienteVisible,
              ),
              _FilaDato(
                icono: Icons.event_outlined,
                etiqueta: 'Fecha',
                valor: _fechaTexto(m.fecha),
              ),
              _FilaDato(
                icono: Icons.person_outline,
                etiqueta: 'Capturado por',
                valor: (m.capturadoPorNombre?.isEmpty ?? true)
                    ? '—'
                    : m.capturadoPorNombre!,
              ),
              if (m.ocrPro != null && m.ocrPro!.isNotEmpty)
                _FilaDato(
                  icono: Icons.auto_awesome,
                  etiqueta: 'PRO detectado por OCR',
                  valor: m.ocrPro!,
                ),
              if (m.confianzaPorcentaje != null)
                _FilaDato(
                  icono: Icons.percent,
                  etiqueta: 'Confianza del OCR',
                  valor: '${m.confianzaPorcentaje}%',
                ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(
                  texto: m.cotejo.etiqueta,
                  color: switch (m.cotejo) {
                    CotejoEstado.ok => AppColors.exito,
                    CotejoEstado.revision => AppColors.peligro,
                    CotejoEstado.pendiente => AppColors.secondary,
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Registrado: ${_fechaHora(m.creadoEn)}',
                style: tema.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _foto(BuildContext context) {
    if (!widget.manifiesto.tieneFoto) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Center(
          child: Text('Sin foto del BOL registrada.'),
        ),
      );
    }
    if (_cargandoFoto) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorFoto != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(_errorFoto!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Image.network(
        _urlFirmada!,
        height: 320,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Center(child: Text('No se pudo mostrar la imagen.')),
        ),
      ),
    );
  }

  static String _fechaTexto(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  static String _fechaHora(DateTime? fecha) {
    if (fecha == null) return '—';
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    final h = fecha.hour.toString().padLeft(2, '0');
    final min = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} $h:$min';
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: tema.textTheme.labelSmall),
                Text(valor, style: tema.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

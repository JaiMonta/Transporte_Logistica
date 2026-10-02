import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/services/almacenamiento_providers.dart';
import '../../../shared/services/almacenamiento_repository.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../auth/models/profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../camiones/providers/camiones_providers.dart';
import '../../fletes/models/tabulador_flete.dart';
import '../../fletes/presentation/widgets/selector_localidad_flete.dart';
import '../../fletes/providers/fletes_providers.dart';
import '../../fletes/services/calculo_flete.dart';
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
              if (m.confianzaPorcentaje != null)
                _FilaDato(
                  icono: Icons.percent,
                  etiqueta: 'Confianza del OCR',
                  valor: '${m.confianzaPorcentaje}%',
                ),
              _FilaDato(
                icono: Icons.local_shipping_outlined,
                etiqueta: 'Camión',
                valor: m.camionVisible,
              ),
              _FilaDato(
                icono: Icons.place_outlined,
                etiqueta: 'Localidad más lejana',
                valor: (m.localidadMasLejana == null ||
                        m.localidadMasLejana!.isEmpty)
                    ? '—'
                    : m.localidadMasLejana!,
              ),
              _FilaDato(
                icono: Icons.attach_money,
                etiqueta: 'Costo de flete',
                valor: m.costoFlete == null
                    ? '—'
                    : '\$${m.costoFlete!.toStringAsFixed(2)}',
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
              Text('Documentos (${m.totalDocumentos})',
                  style: tema.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              _tablaLineas(context, m),
              const SizedBox(height: AppSpacing.lg),
              _accionesAdmin(context, m),
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

  Widget _accionesAdmin(BuildContext context, Manifiesto m) {
    final perfil = ref.watch(currentProfileProvider).value;
    if (perfil?.rol != Rol.admin) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _editarLocalidad(m),
        icon: const Icon(Icons.place_outlined),
        label: const Text('Editar localidad más lejana'),
      ),
    );
  }

  Future<void> _editarLocalidad(Manifiesto m) async {
    TabuladorFlete? elegido;
    if (m.fletesTabuladorId != null) {
      elegido =
          await ref.read(fletesRepositoryProvider).obtener(m.fletesTabuladorId!);
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Localidad más lejana'),
        content: SizedBox(
          width: 420,
          child: SelectorLocalidadFlete(
            onSeleccion: (f) => elegido = f,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final f = elegido;
              if (f == null) return;
              Navigator.pop(context);
              await _guardarLocalidad(m, f);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarLocalidad(Manifiesto m, TabuladorFlete flete) async {
    try {
      // Capacidad del camión asignado (si tiene).
      double? capacidadKg;
      if (m.camionId != null) {
        final camion =
            await ref.read(camionesRepositoryProvider).obtener(m.camionId!);
        capacidadKg = camion?.capacidadKg;
      }
      final costo = CalculoFlete.precioFlete(
        tabulador: flete,
        capacidadKg: capacidadKg,
      );
      await ref.read(manifiestosRepositoryProvider).actualizarCabecera(
            id: m.id,
            camionId: m.camionId,
            localidadMasLejana: flete.localidad,
            fletesTabuladorId: flete.id,
            costoFlete: costo,
          );
      if (!mounted) return;
      ref.invalidate(manifiestoProvider(m.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            costo == null
                ? 'Localidad actualizada (sin camión/capacidad para calcular el flete).'
                : 'Localidad actualizada. Flete: \$${costo.toStringAsFixed(2)}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    }
  }

  Widget _tablaLineas(BuildContext context, Manifiesto m) {
    if (m.lineas.isEmpty) {
      return const Text('Sin documentos registrados.');
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Tipo')),
          DataColumn(label: Text('Número')),
          DataColumn(label: Text('Cliente')),
        ],
        rows: [
          for (final l in m.lineas)
            DataRow(cells: [
              DataCell(Text(l.tipo.etiqueta)),
              DataCell(Text(l.numeroVisible)),
              DataCell(Text(l.clienteVisible)),
            ]),
        ],
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

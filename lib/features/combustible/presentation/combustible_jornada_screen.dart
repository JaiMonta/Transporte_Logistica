import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/services/almacenamiento_providers.dart';
import '../../../shared/services/almacenamiento_repository.dart';
import '../../gps/services/seguimiento_gps.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../models/combustible_jornada.dart';
import '../providers/combustible_providers.dart';
import 'dialogo_combustible.dart';

/// Jornada de combustible de un manifiesto: recargas, cerrar jornada.
class CombustibleJornadaScreen extends ConsumerStatefulWidget {
  const CombustibleJornadaScreen({
    super.key,
    required this.manifiestoId,
    this.esAdmin = false,
  });

  final String manifiestoId;
  final bool esAdmin;

  @override
  ConsumerState<CombustibleJornadaScreen> createState() =>
      _CombustibleJornadaScreenState();
}

class _CombustibleJornadaScreenState
    extends ConsumerState<CombustibleJornadaScreen> {
  bool _ocupado = false;

  void _refrescar() =>
      ref.invalidate(combustibleDeManifiestoProvider(widget.manifiestoId));

  Future<void> _agregarRecarga(CombustibleJornada j) async {
    final formKey = GlobalKey<FormState>();
    final litros = TextEditingController();
    final monto = TextEditingController();
    bool conFoto = false;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogo) => AlertDialog(
          title: const Text('Nueva recarga'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: litros,
                  label: 'Litros',
                  icono: Icons.local_gas_station_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (n == null || n <= 0) return 'Ingresa los litros.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: monto,
                  label: 'Monto (opcional)',
                  icono: Icons.attach_money,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  value: conFoto,
                  onChanged: (v) => setDialogo(() => conFoto = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Adjuntar foto (opcional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
    if (guardar != true) {
      litros.dispose();
      monto.dispose();
      return;
    }

    try {
      EvidenciaSubida? evidencia;
      if (conFoto) {
        final archivo =
            await ImagePicker().pickImage(source: ImageSource.camera);
        if (archivo != null) {
          final Uint8List bytes = await archivo.readAsBytes();
          final almacen = ref.read(almacenamientoRepositoryProvider);
          evidencia = await almacen.subir(
            bucket: BucketEvidencia.extras,
            path: almacen.rutaDe(
              carpeta: 'recargas',
              archivo: 'recarga_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
            bytes: bytes,
            tipo: TipoEvidencia.extra,
          );
        }
      }

      await ref.read(combustibleRepositoryProvider).agregarRecarga(
            jornadaId: j.id,
            litros: double.parse(litros.text.replaceAll(',', '.')),
            monto: monto.text.trim().isEmpty
                ? null
                : double.tryParse(monto.text.replaceAll(',', '.')),
            bucket: evidencia?.bucket,
            path: evidencia?.path,
            hashSha256: evidencia?.hashSha256,
          );
      if (!mounted) return;
      _refrescar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    } finally {
      litros.dispose();
      monto.dispose();
    }
  }

  Future<void> _cerrarJornada(CombustibleJornada j) async {
    final datos = await mostrarDialogoCombustible(
      context,
      titulo: 'Cerrar jornada',
      etiquetaLitros: 'Litros finales',
    );
    if (datos == null || !mounted) return;
    setState(() => _ocupado = true);
    try {
      // km desde los puntos GPS del manifiesto.
      final puntos = await ref
          .read(ubicacionesRepositoryProvider)
          .puntosDeManifiesto(j.manifiestoId);
      final km = CalculoCombustible.kmDeRuta(puntos);
      final rendimiento = j.rendimientoLtKm ??
          CalculoCombustible.rendimientoPorDefecto;
      final inicial = j.inicialEfectivo ?? 0;
      final real = CalculoCombustible.consumoReal(
        litrosIniciales: inicial,
        recargas: j.totalRecargasLt,
        litrosFinales: datos.litros,
      );
      await ref.read(combustibleRepositoryProvider).cerrar(
            jornadaId: j.id,
            litrosFinales: datos.litros,
            odometroFinal: datos.odometro,
            kmRecorridos: km,
            consumoTeorico: CalculoCombustible.consumoTeorico(km,
                rendimiento: rendimiento),
            consumoReal: real,
            rendimiento: rendimiento,
          );
      if (!mounted) return;
      _refrescar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Jornada cerrada. $km km recorridos.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async =
        ref.watch(combustibleDeManifiestoProvider(widget.manifiestoId));
    return Scaffold(
      appBar: AppBar(title: const Text('Combustible')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(mensajeError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (j) => j == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('No hay jornada de combustible para este manifiesto.'),
                ),
              )
            : _Contenido(
                jornada: j,
                esAdmin: widget.esAdmin,
                ocupado: _ocupado,
                onRecarga: () => _agregarRecarga(j),
                onCerrar: () => _cerrarJornada(j),
              ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.jornada,
    required this.esAdmin,
    required this.ocupado,
    required this.onRecarga,
    required this.onCerrar,
  });

  final CombustibleJornada jornada;
  final bool esAdmin;
  final bool ocupado;
  final VoidCallback onRecarga;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cerrada = jornada.estado == EstadoCombustible.cerrada ||
        jornada.estado == EstadoCombustible.validada;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _fila('Litros iniciales', _n(jornada.inicialEfectivo)),
        if (jornada.litrosInicialesValidados != null)
          _fila('Inicial reportado', _n(jornada.litrosIniciales)),
        _fila('Recargas', '${_n(jornada.totalRecargasLt)} lt '
            '(${jornada.recargas.length})'),
        _fila('Litros finales', _n(jornada.finalEfectivo)),
        const Divider(),
        _fila('Km recorridos', _n(jornada.kmRecorridos)),
        _fila('Consumo teórico', '${_n(jornada.consumoTeoricoLt)} lt'),
        _fila('Consumo real', '${_n(jornada.consumoRealLt)} lt'),
        _fila('Rendimiento', '${_n(jornada.rendimientoLtKm)} lt/km'),
        const SizedBox(height: AppSpacing.md),
        Text('Recargas', style: tema.textTheme.labelLarge),
        for (final r in jornada.recargas)
          ListTile(
            dense: true,
            leading: const Icon(Icons.local_gas_station),
            title: Text('${_n(r.litros)} lt'),
            subtitle: r.monto == null ? null : Text('Monto: ${_n(r.monto)}'),
            trailing: r.bucket != null
                ? const Icon(Icons.receipt_long, size: 18)
                : null,
          ),
        if (!esAdmin && !cerrada) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: ocupado ? null : onRecarga,
            icon: const Icon(Icons.add),
            label: const Text('Agregar recarga'),
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            texto: 'Cerrar jornada',
            cargando: ocupado,
            onPressed: onCerrar,
          ),
        ],
      ],
    );
  }

  Widget _fila(String etiqueta, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(child: Text(etiqueta)),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  static String _n(double? v) => v == null ? '—' : v.toStringAsFixed(2);
}

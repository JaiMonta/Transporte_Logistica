import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../models/tabulador_flete.dart';
import '../providers/fletes_providers.dart';

/// Edición de precios de una localidad del tabulador.
class FleteFormScreen extends ConsumerStatefulWidget {
  const FleteFormScreen({super.key, required this.fleteId});

  final String fleteId;

  @override
  ConsumerState<FleteFormScreen> createState() => _FleteFormScreenState();
}

class _FleteFormScreenState extends ConsumerState<FleteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _region = TextEditingController();
  final _localidad = TextEditingController();
  final _km = TextEditingController();
  final _precios = <TierCapacidad, TextEditingController>{
    for (final t in TierCapacidad.values) t: TextEditingController(),
  };

  bool _cargando = false;
  bool _cargandoFlete = true;
  TabuladorFlete? _original;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _region.dispose();
    _localidad.dispose();
    _km.dispose();
    for (final c in _precios.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final f = await ref.read(fletesRepositoryProvider).obtener(widget.fleteId);
      if (!mounted) return;
      if (f == null) {
        setState(() => _cargandoFlete = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la localidad.')),
        );
        return;
      }
      setState(() {
        _original = f;
        _region.text = f.region ?? '';
        _localidad.text = f.localidad;
        _km.text = f.km?.toString() ?? '';
        for (final t in TierCapacidad.values) {
          final v = f.precioPara(t);
          _precios[t]!.text = v?.toString() ?? '';
        }
        _cargandoFlete = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoFlete = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _original == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    try {
      final f = TabuladorFlete(
        id: _original!.id,
        localidad: _localidad.text,
        region: _region.text.trim().isEmpty ? null : _region.text,
        km: _doble(_km.text),
        precio1_2: _doble(_precios[TierCapacidad.t1_2]!.text),
        precio2_5: _doble(_precios[TierCapacidad.t2_5]!.text),
        precio3_5: _doble(_precios[TierCapacidad.t3_5]!.text),
        precio5: _doble(_precios[TierCapacidad.t5]!.text),
        precio6: _doble(_precios[TierCapacidad.t6]!.text),
        precio7_5: _doble(_precios[TierCapacidad.t7_5]!.text),
        precio10: _doble(_precios[TierCapacidad.t10]!.text),
        precio12: _doble(_precios[TierCapacidad.t12]!.text),
        precio15: _doble(_precios[TierCapacidad.t15]!.text),
        precio30: _doble(_precios[TierCapacidad.t30]!.text),
      );
      await ref.read(fletesRepositoryProvider).actualizar(f);
      if (!mounted) return;
      ref.invalidate(tabuladorProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precios guardados.')),
      );
      context.go(Rutas.adminFletes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  static double? _doble(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Precios del flete')),
      body: _cargandoFlete
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          controller: _localidad,
                          label: 'Localidad',
                          icono: Icons.place_outlined,
                          enabled: false,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _region,
                                label: 'Región',
                                icono: Icons.map_outlined,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: AppTextField(
                                controller: _km,
                                label: 'KM',
                                icono: Icons.straighten_outlined,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Precios por capacidad (USD)',
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        for (final t in TierCapacidad.values) ...[
                          AppTextField(
                            controller: _precios[t],
                            label: '${t.etiqueta} (USD)',
                            icono: Icons.attach_money,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        PrimaryButton(
                          texto: 'Guardar precios',
                          cargando: _cargando,
                          onPressed: _guardar,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

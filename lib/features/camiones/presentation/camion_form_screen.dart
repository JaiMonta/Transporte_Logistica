import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/validators/validador.dart';
import '../models/camion.dart';
import '../providers/camiones_providers.dart';

/// Formulario para crear o editar un camión.
class CamionFormScreen extends ConsumerStatefulWidget {
  const CamionFormScreen({super.key, this.camionId});

  final String? camionId;

  @override
  ConsumerState<CamionFormScreen> createState() => _CamionFormScreenState();
}

class _CamionFormScreenState extends ConsumerState<CamionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _marca = TextEditingController();
  final _placa = TextEditingController();
  final _modelo = TextEditingController();
  final _anio = TextEditingController();
  final _capacidad = TextEditingController();
  final _volumen = TextEditingController();

  String? _choferId;
  bool _cargando = false;
  bool _cargandoCamion = false;
  Camion? _camionOriginal;

  bool get _esEdicion => widget.camionId != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _cargandoCamion = true;
      _cargarCamion();
    }
  }

  @override
  void dispose() {
    _marca.dispose();
    _placa.dispose();
    _modelo.dispose();
    _anio.dispose();
    _capacidad.dispose();
    _volumen.dispose();
    super.dispose();
  }

  Future<void> _cargarCamion() async {
    try {
      final camion =
          await ref.read(camionesRepositoryProvider).obtener(widget.camionId!);
      if (!mounted) return;
      if (camion == null) {
        setState(() => _cargandoCamion = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró el camión.')),
        );
        return;
      }
      setState(() {
        _camionOriginal = camion;
        _marca.text = camion.marca;
        _placa.text = camion.placa;
        _modelo.text = camion.modelo ?? '';
        _anio.text = camion.anio?.toString() ?? '';
        _capacidad.text = camion.capacidadKg?.toString() ?? '';
        _volumen.text = camion.volumenM3?.toString() ?? '';
        _choferId = camion.choferId;
        _cargandoCamion = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoCamion = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_choferId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el chofer asignado.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    try {
      final repo = ref.read(camionesRepositoryProvider);

      final existe = await repo.existePlaca(
        _placa.text,
        excluirId: _camionOriginal?.id,
      );
      if (existe) {
        throw Exception('Ya existe un camión con esa placa.');
      }

      if (_esEdicion) {
        await repo.actualizar(
          id: _camionOriginal!.id,
          marca: _marca.text,
          placa: _placa.text,
          choferId: _choferId!,
          modelo: _modelo.text,
          anio: _int(_anio.text),
          capacidadKg: _doble(_capacidad.text),
          volumenM3: _doble(_volumen.text),
        );
      } else {
        await repo.crear(
          marca: _marca.text,
          placa: _placa.text,
          choferId: _choferId!,
          modelo: _modelo.text,
          anio: _int(_anio.text),
          capacidadKg: _doble(_capacidad.text),
          volumenM3: _doble(_volumen.text),
        );
      }
      if (!mounted) return;
      ref.invalidate(camionesProvider);
      ref.invalidate(camionesActivosProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_esEdicion ? 'Cambios guardados.' : 'Camión creado.')),
      );
      context.go(Rutas.adminCamiones);
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

  static int? _int(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar camión' : 'Nuevo camión'),
      ),
      body: _cargandoCamion
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          controller: _marca,
                          label: 'Marca',
                          icono: Icons.factory_outlined,
                          textInputAction: TextInputAction.next,
                          validator: Validador.nombre,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _placa,
                          label: 'Placa',
                          icono: Icons.pin_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Ingresa la placa.'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _modelo,
                          label: 'Modelo (opcional)',
                          icono: Icons.directions_car_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _anio,
                          label: 'Año (opcional)',
                          icono: Icons.calendar_today_outlined,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _capacidad,
                                label: 'Capacidad (kg)',
                                icono: Icons.scale_outlined,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: AppTextField(
                                controller: _volumen,
                                label: 'Volumen (m³)',
                                icono: Icons.view_in_ar_outlined,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SelectorChofer(
                          valor: _choferId,
                          onCambio: (v) => setState(() => _choferId = v),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        PrimaryButton(
                          texto: _esEdicion ? 'Guardar cambios' : 'Crear camión',
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

/// Selector de choferes activos (obligatorio).
class _SelectorChofer extends ConsumerWidget {
  const _SelectorChofer({required this.valor, required this.onCambio});

  final String? valor;
  final ValueChanged<String?> onCambio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(choferesActivosProvider);
    return async.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(labelText: 'Chofer asignado'),
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
        decoration: const InputDecoration(labelText: 'Chofer asignado'),
        child: Text('No se pudieron cargar los choferes: $e'),
      ),
      data: (choferes) {
        final valido = choferes.any((c) => c.id == valor) ? valor : null;
        return DropdownButtonFormField<String>(
          initialValue: valido,
          decoration: const InputDecoration(labelText: 'Chofer asignado'),
          items: choferes
              .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.nombre, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onCambio,
        );
      },
    );
  }
}

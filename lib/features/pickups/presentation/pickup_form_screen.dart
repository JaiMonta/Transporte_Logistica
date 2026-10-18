import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../camiones/providers/camiones_providers.dart';
import '../../clientes/models/cliente.dart';
import '../../clientes/presentation/widgets/selector_cliente_hibrido.dart';
import '../../clientes/providers/clientes_providers.dart';
import '../models/pickup.dart';
import '../providers/pickups_providers.dart';

/// Formulario para crear o editar (asignar) un pickup.
class PickupFormScreen extends ConsumerStatefulWidget {
  const PickupFormScreen({super.key, this.pickupId});

  final String? pickupId;

  @override
  ConsumerState<PickupFormScreen> createState() => _PickupFormScreenState();
}

class _PickupFormScreenState extends ConsumerState<PickupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _direccion = TextEditingController();
  final _notas = TextEditingController();

  String? _choferId;
  String? _clienteId;
  String? _clienteTexto;
  double? _lat;
  double? _lng;
  String? _camionId;
  DateTime? _fecha;
  TimeOfDay? _hora;

  bool _cargando = false;
  bool _cargandoPickup = false;
  Pickup? _original;

  bool get _esEdicion => widget.pickupId != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _cargandoPickup = true;
      _cargar();
    }
  }

  @override
  void dispose() {
    _direccion.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final p = await ref
          .read(pickupsRepositoryProvider)
          .obtener(widget.pickupId!);
      if (!mounted) return;
      if (p == null) {
        setState(() => _cargandoPickup = false);
        _snack('No se encontró el pickup.');
        return;
      }
      setState(() {
        _original = p;
        _choferId = p.choferId;
        _clienteId = p.clienteId;
        _clienteTexto = p.clienteTexto;
        _direccion.text = p.direccion ?? '';
        _lat = p.lat;
        _lng = p.lng;
        _camionId = p.camionId;
        _fecha = p.fechaEstimada;
        _hora = _parseHora(p.horaEstimada);
        _notas.text = p.notas ?? '';
        _cargandoPickup = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoPickup = false);
      _snack(mensajeError(e));
    }
  }

  void _snack(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  void _onCliente(String? clienteId, String? clienteTexto) {
    setState(() {
      _clienteId = clienteId;
      _clienteTexto = clienteTexto;
    });
    if (clienteId != null) {
      final clientes =
          ref.read(clientesActivosProvider).value ?? const <Cliente>[];
      for (final c in clientes) {
        if (c.id == clienteId) {
          setState(() {
            _direccion.text = c.direccion ?? _direccion.text;
            _lat = c.lat;
            _lng = c.lng;
          });
          break;
        }
      }
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 2),
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
    );
    if (hora != null) setState(() => _hora = hora);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_choferId == null) {
      _snack('Selecciona el chofer asignado.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    try {
      final repo = ref.read(pickupsRepositoryProvider);
      final args = (
        choferId: _choferId!,
        clienteId: _clienteId,
        clienteTexto: _clienteTexto,
        direccion: _direccion.text,
        lat: _lat,
        lng: _lng,
        camionId: _camionId,
        fechaEstimada: _fecha,
        horaEstimada: _horaTexto(_hora),
        notas: _notas.text,
      );
      if (_esEdicion) {
        await repo.actualizar(
          id: _original!.id,
          choferId: args.choferId,
          clienteId: args.clienteId,
          clienteTexto: args.clienteTexto,
          direccion: args.direccion,
          lat: args.lat,
          lng: args.lng,
          camionId: args.camionId,
          fechaEstimada: args.fechaEstimada,
          horaEstimada: args.horaEstimada,
          notas: args.notas,
        );
      } else {
        await repo.crear(
          choferId: args.choferId,
          clienteId: args.clienteId,
          clienteTexto: args.clienteTexto,
          direccion: args.direccion,
          lat: args.lat,
          lng: args.lng,
          camionId: args.camionId,
          fechaEstimada: args.fechaEstimada,
          horaEstimada: args.horaEstimada,
          notas: args.notas,
        );
      }
      if (!mounted) return;
      ref.invalidate(pickupsProvider);
      _snack(_esEdicion ? 'Cambios guardados.' : 'Pickup asignado.');
      context.go(Rutas.adminPickups);
    } catch (e) {
      _snack(mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar pickup' : 'Nuevo pickup'),
      ),
      body: _cargandoPickup
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
                        _SelectorChofer(
                          valor: _choferId,
                          onCambio: (v) => setState(() => _choferId = v),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SelectorClienteHibrido(
                          clienteId: _clienteId,
                          clienteTexto: _clienteTexto,
                          onCambio: _onCliente,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _direccion,
                          label: 'Dirección (opcional)',
                          icono: Icons.location_on_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: _CampoSeleccion(
                                label: 'Fecha estimada',
                                icono: Icons.event_outlined,
                                texto: _fecha == null
                                    ? 'Elegir'
                                    : _fechaTexto(_fecha!),
                                onTap: _elegirFecha,
                                onLimpiar: _fecha == null
                                    ? null
                                    : () => setState(() => _fecha = null),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _CampoSeleccion(
                                label: 'Hora estimada',
                                icono: Icons.schedule_outlined,
                                texto: _hora == null
                                    ? 'Elegir'
                                    : _hora!.format(context),
                                onTap: _elegirHora,
                                onLimpiar: _hora == null
                                    ? null
                                    : () => setState(() => _hora = null),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SelectorCamion(
                          valor: _camionId,
                          onCambio: (v) => setState(() => _camionId = v),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _notas,
                          label: 'Notas (opcional)',
                          icono: Icons.notes_outlined,
                          maxLines: 3,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        PrimaryButton(
                          texto: _esEdicion
                              ? 'Guardar cambios'
                              : 'Asignar pickup',
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

  static TimeOfDay? _parseHora(String? valor) {
    if (valor == null || valor.isEmpty) return null;
    final partes = valor.split(':');
    if (partes.length < 2) return null;
    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String? _horaTexto(TimeOfDay? hora) {
    if (hora == null) return null;
    final h = hora.hour.toString().padLeft(2, '0');
    final m = hora.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  static String _fechaTexto(DateTime f) {
    final dia = f.day.toString().padLeft(2, '0');
    final mes = f.month.toString().padLeft(2, '0');
    return '$dia/$mes/${f.year}';
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
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Chofer asignado'),
          items: choferes
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.nombre, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onCambio,
        );
      },
    );
  }
}

/// Selector de camión activo (opcional).
class _SelectorCamion extends ConsumerWidget {
  const _SelectorCamion({required this.valor, required this.onCambio});

  final String? valor;
  final ValueChanged<String?> onCambio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(camionesActivosProvider);
    return async.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(labelText: 'Camión (opcional)'),
        child: SizedBox(height: 24),
      ),
      error: (e, _) => const InputDecorator(
        decoration: InputDecoration(labelText: 'Camión (opcional)'),
        child: Text('No se pudieron cargar los camiones'),
      ),
      data: (camiones) {
        final valido = camiones.any((c) => c.id == valor) ? valor : null;
        return DropdownButtonFormField<String?>(
          initialValue: valido,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Camión (opcional)'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sin camión'),
            ),
            ...camiones.map(
              (c) => DropdownMenuItem<String?>(
                value: c.id,
                child: Text(
                  '${c.placa} · ${c.marcaVisible}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onCambio,
        );
      },
    );
  }
}

/// Campo de solo lectura con selección (fecha/hora).
class _CampoSeleccion extends StatelessWidget {
  const _CampoSeleccion({
    required this.label,
    required this.icono,
    required this.texto,
    required this.onTap,
    this.onLimpiar,
  });

  final String label;
  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final VoidCallback? onLimpiar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.base),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icono),
          suffixIcon: onLimpiar == null
              ? null
              : IconButton(
                  tooltip: 'Limpiar',
                  icon: const Icon(Icons.clear),
                  onPressed: onLimpiar,
                ),
        ),
        child: Text(texto),
      ),
    );
  }
}

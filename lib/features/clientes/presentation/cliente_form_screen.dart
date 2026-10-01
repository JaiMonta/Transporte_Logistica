import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/selector_mapa.dart';
import '../../../shared/validators/validador.dart';
import '../models/cliente.dart';
import '../providers/clientes_providers.dart';

/// Formulario para crear o editar un cliente.
class ClienteFormScreen extends ConsumerStatefulWidget {
  const ClienteFormScreen({super.key, this.clienteId});

  final String? clienteId;

  @override
  ConsumerState<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends ConsumerState<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _codCli = TextEditingController();
  final _contacto = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _direccion = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();

  bool _cargando = false;
  bool _cargandoCliente = false;
  Cliente? _clienteOriginal;

  bool get _esEdicion => widget.clienteId != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _cargandoCliente = true;
      _cargarCliente();
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _codCli.dispose();
    _contacto.dispose();
    _telefono.dispose();
    _correo.dispose();
    _direccion.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _cargarCliente() async {
    try {
      final cliente =
          await ref.read(clientesRepositoryProvider).obtener(widget.clienteId!);
      if (!mounted) return;
      if (cliente == null) {
        setState(() => _cargandoCliente = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró el cliente.')),
        );
        return;
      }
      setState(() {
        _clienteOriginal = cliente;
        _nombre.text = cliente.nombre;
        _codCli.text = cliente.codCli ?? '';
        _contacto.text = cliente.nombreContacto ?? '';
        _telefono.text = cliente.telefono ?? '';
        _correo.text = cliente.email ?? '';
        _direccion.text = cliente.direccion ?? '';
        _lat.text = cliente.lat?.toString() ?? '';
        _lng.text = cliente.lng?.toString() ?? '';
        _cargandoCliente = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoCliente = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  Future<void> _abrirMapa() async {
    FocusScope.of(context).unfocus();
    final punto = await mostrarSelectorMapa(
      context,
      lat: _doble(_lat.text),
      lng: _doble(_lng.text),
    );
    if (punto == null || !mounted) return;
    setState(() {
      _lat.text = punto.lat.toStringAsFixed(6);
      _lng.text = punto.lng.toStringAsFixed(6);
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    try {
      final repo = ref.read(clientesRepositoryProvider);
      final lat = _doble(_lat.text);
      final lng = _doble(_lng.text);

      if (_correo.text.trim().isNotEmpty) {
        final existe = await repo.existeCorreo(
          _correo.text,
          excluirId: _clienteOriginal?.id,
        );
        if (existe) {
          throw Exception('Ya existe un cliente con ese correo.');
        }
      }

      if (_esEdicion) {
        await repo.actualizar(
          id: _clienteOriginal!.id,
          nombre: _nombre.text,
          codCli: _codCli.text,
          nombreContacto: _contacto.text,
          telefono: _telefono.text,
          email: _correo.text,
          direccion: _direccion.text,
          lat: lat,
          lng: lng,
        );
      } else {
        await repo.crear(
          nombre: _nombre.text,
          codCli: _codCli.text,
          nombreContacto: _contacto.text,
          telefono: _telefono.text,
          email: _correo.text,
          direccion: _direccion.text,
          lat: lat,
          lng: lng,
        );
      }
      if (!mounted) return;
      ref.invalidate(clientesProvider);
      ref.invalidate(clientesActivosProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_esEdicion ? 'Cambios guardados.' : 'Cliente creado.'),
        ),
      );
      context.go(Rutas.adminClientes);
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
    return double.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar cliente' : 'Nuevo cliente'),
      ),
      body: _cargandoCliente
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
                          controller: _nombre,
                          label: 'Nombre o razón social',
                          icono: Icons.storefront_outlined,
                          textInputAction: TextInputAction.next,
                          validator: Validador.nombre,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _codCli,
                          label: 'Código de cliente (opcional)',
                          icono: Icons.tag,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _contacto,
                          label: 'Nombre de contacto (opcional)',
                          icono: Icons.badge_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _telefono,
                          label: 'Teléfono (opcional)',
                          icono: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: Validador.telefono,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _correo,
                          label: 'Correo electrónico (opcional)',
                          icono: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: Validador.correo,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Ubicación', style: tema.textTheme.labelLarge),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Abre el mapa y toca el punto exacto del cliente, '
                          'o captura las coordenadas manualmente.',
                          style: tema.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(
                          controller: _direccion,
                          label: 'Dirección',
                          icono: Icons.location_on_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _abrirMapa,
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Abrir mapa'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _lat,
                                label: 'Latitud',
                                icono: Icons.my_location,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true, signed: true),
                                validator: (v) => _validarCoord(v, esLat: true),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: AppTextField(
                                controller: _lng,
                                label: 'Longitud',
                                icono: Icons.explore_outlined,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true, signed: true),
                                validator: (v) => _validarCoord(v, esLat: false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        PrimaryButton(
                          texto: _esEdicion ? 'Guardar cambios' : 'Crear cliente',
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

  String? _validarCoord(String? valor, {required bool esLat}) {
    final t = valor?.trim() ?? '';
    if (t.isEmpty) return null;
    final numero = double.tryParse(t);
    if (numero == null) return 'Número inválido';
    final limite = esLat ? 90.0 : 180.0;
    if (numero < -limite || numero > limite) {
      return esLat ? 'Entre -90 y 90' : 'Entre -180 y 180';
    }
    return null;
  }
}

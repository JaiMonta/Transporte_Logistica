import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/validators/validador.dart';
import '../data/usuarios_repository.dart';
import '../models/profile.dart';
import '../providers/auth_providers.dart';
import '../providers/usuarios_providers.dart';

/// Formulario para crear o editar un usuario.
class UsuarioFormScreen extends ConsumerStatefulWidget {
  const UsuarioFormScreen({super.key, this.usuarioId});

  final String? usuarioId;

  @override
  ConsumerState<UsuarioFormScreen> createState() => _UsuarioFormScreenState();
}

class _UsuarioFormScreenState extends ConsumerState<UsuarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  Rol _rol = Rol.chofer;
  MetodoAlta _metodo = MetodoAlta.invitacion;
  bool _verContrasena = false;
  bool _cargando = false;
  bool _cargandoPerfil = false;
  Profile? _perfilOriginal;

  bool get _esEdicion => widget.usuarioId != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _cargandoPerfil = true;
      _cargarPerfil();
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    try {
      final perfil = await ref
          .read(authRepositoryProvider)
          .perfilDeUsuario(widget.usuarioId!);
      if (!mounted) return;
      if (perfil == null) {
        setState(() => _cargandoPerfil = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró el usuario.')),
        );
        return;
      }
      setState(() {
        _perfilOriginal = perfil;
        _nombre.text = perfil.nombre;
        _telefono.text = perfil.telefono ?? '';
        _correo.text = perfil.email ?? '';
        _rol = perfil.rol;
        _cargandoPerfil = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoPerfil = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    try {
      final repo = ref.read(usuariosRepositoryProvider);
      if (_esEdicion) {
        await repo.actualizar(
          id: _perfilOriginal!.id,
          nombre: _nombre.text,
          rol: _rol,
          telefono: _telefono.text,
        );
      } else {
        if (await repo.existeCorreo(_correo.text)) {
          throw Exception('Ya existe un usuario con ese correo.');
        }
        await repo.crear(
          correo: _correo.text,
          nombre: _nombre.text,
          rol: _rol,
          metodo: _metodo,
          telefono: _telefono.text,
          contrasena: _metodo == MetodoAlta.contrasenaTemporal
              ? _contrasena.text
              : null,
        );
      }
      if (!mounted) return;
      ref.invalidate(usuariosProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_esEdicion ? 'Cambios guardados.' : 'Usuario creado.'),
        ),
      );
      context.go(Rutas.adminUsuarios);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar usuario' : 'Nuevo usuario'),
      ),
      body: _cargandoPerfil
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
                          label: 'Nombre completo',
                          icono: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          validator: Validador.nombre,
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
                        if (_esEdicion)
                          AppTextField(
                            controller: _correo,
                            label: 'Correo electrónico',
                            icono: Icons.mail_outline,
                            enabled: false,
                          )
                        else
                          AppTextField(
                            controller: _correo,
                            label: 'Correo electrónico',
                            icono: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: Validador.correo,
                          ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Rol', style: tema.textTheme.labelLarge),
                        const SizedBox(height: AppSpacing.xs),
                        SegmentedButton<Rol>(
                          segments: const [
                            ButtonSegment(
                              value: Rol.chofer,
                              label: Text('Chofer'),
                              icon: Icon(Icons.local_shipping_outlined),
                            ),
                            ButtonSegment(
                              value: Rol.admin,
                              label: Text('Administrador'),
                              icon: Icon(Icons.admin_panel_settings_outlined),
                            ),
                          ],
                          selected: {_rol},
                          onSelectionChanged: (s) =>
                              setState(() => _rol = s.first),
                        ),
                        if (!_esEdicion) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text('Método de alta',
                              style: tema.textTheme.labelLarge),
                          RadioGroup<MetodoAlta>(
                            groupValue: _metodo,
                            onChanged: (v) => setState(() => _metodo = v!),
                            child: Column(
                              children: [
                                RadioListTile<MetodoAlta>(
                                  value: MetodoAlta.invitacion,
                                  title: const Text('Invitación por correo'),
                                  subtitle: const Text(
                                      'El usuario recibe un enlace para crear su contraseña.'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                RadioListTile<MetodoAlta>(
                                  value: MetodoAlta.contrasenaTemporal,
                                  title: const Text('Contraseña temporal'),
                                  subtitle: const Text(
                                      'Tú defines la contraseña inicial; el usuario puede cambiarla después.'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                          if (_metodo == MetodoAlta.contrasenaTemporal) ...[
                            const SizedBox(height: AppSpacing.sm),
                            AppTextField(
                              controller: _contrasena,
                              label: 'Contraseña temporal',
                              icono: Icons.lock_outline,
                              obscure: !_verContrasena,
                              validator: Validador.contrasena,
                              suffixIcon: IconButton(
                                tooltip: _verContrasena
                                    ? 'Ocultar contraseña'
                                    : 'Mostrar contraseña',
                                icon: Icon(_verContrasena
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () => setState(
                                    () => _verContrasena = !_verContrasena),
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        PrimaryButton(
                          texto: _esEdicion ? 'Guardar cambios' : 'Crear usuario',
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router.dart';
import '../../../../core/theme.dart';
import '../../../../shared/errors/mensajes_error.dart';
import '../../../../shared/validators/validador.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../providers/auth_providers.dart';

/// Formulario de inicio de sesión reutilizable.
///
/// Se incrusta tanto en la pantalla de bienvenida como en cualquier otra
/// vista que necesite autenticar al usuario.
class FormularioLogin extends ConsumerStatefulWidget {
  const FormularioLogin({super.key, this.mostrarEncabezado = true});

  /// Si es verdadero, muestra el título "Iniciar sesión".
  final bool mostrarEncabezado;

  @override
  ConsumerState<FormularioLogin> createState() => _FormularioLoginState();
}

class _FormularioLoginState extends ConsumerState<FormularioLogin> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _verContrasena = false;
  bool _cargando = false;
  bool _recordarContrasena = true;

  /// ¿La plataforma permite recordar la contraseña? (solo móvil).
  bool get _puedeRecordar =>
      ref.read(credencialesProvider).puedeRecordarContrasena;

  @override
  void initState() {
    super.initState();
    _cargarCredenciales();
  }

  Future<void> _cargarCredenciales() async {
    final servicio = ref.read(credencialesProvider);
    final correo = await servicio.leerCorreo();
    final contrasena = await servicio.leerContrasena();
    if (!mounted) return;
    setState(() {
      if (correo != null) _correo.text = correo;
      if (contrasena != null && contrasena.isNotEmpty) {
        _contrasena.text = contrasena;
        _recordarContrasena = true;
      }
    });
  }

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    try {
      await ref.read(authControllerProvider.notifier).iniciarSesion(
            correo: _correo.text,
            contrasena: _contrasena.text,
          );
      // Guardar credenciales según la elección del usuario.
      await ref.read(credencialesProvider).guardar(
            _correo.text,
            contrasena:
                (_recordarContrasena && _puedeRecordar) ? _contrasena.text : null,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.mostrarEncabezado) ...[
            Text(
              'Iniciar sesión',
              textAlign: TextAlign.center,
              style: tema.textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ingresa con tu cuenta para continuar.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          AppTextField(
            controller: _correo,
            label: 'Correo electrónico',
            icono: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: Validador.correo,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _contrasena,
            label: 'Contraseña',
            icono: Icons.lock_outline,
            obscure: !_verContrasena,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Ingresa la contraseña.' : null,
            onFieldSubmitted: (_) => _entrar(),
            suffixIcon: IconButton(
              tooltip:
                  _verContrasena ? 'Ocultar contraseña' : 'Mostrar contraseña',
              icon: Icon(_verContrasena
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () =>
                  setState(() => _verContrasena = !_verContrasena),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_puedeRecordar)
            CheckboxListTile(
              value: _recordarContrasena,
              onChanged: _cargando
                  ? null
                  : (v) => setState(() => _recordarContrasena = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Recordar usuario y contraseña'),
              subtitle: const Text(
                'Se guarda de forma segura en este dispositivo.',
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            texto: 'Entrar',
            cargando: _cargando,
            onPressed: _entrar,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed:
                _cargando ? null : () => context.go(Rutas.recuperar),
            child: const Text('¿Olvidaste tu contraseña?'),
          ),
        ],
      ),
    );
  }
}

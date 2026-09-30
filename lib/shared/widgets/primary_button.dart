import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Botón principal (altura 56, indicador de carga integrado).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.texto,
    this.onPressed,
    this.cargando = false,
    this.icono,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: cargando ? null : onPressed,
      child: cargando
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icono != null) ...[
                  Icon(icono, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(texto),
              ],
            ),
    );
  }
}

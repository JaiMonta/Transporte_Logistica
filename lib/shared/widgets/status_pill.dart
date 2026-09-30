import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../features/auth/models/profile.dart';

/// Etiqueta de estado (pill totalmente redondeada).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.texto,
    required this.color,
  });

  final String texto;
  final Color color;

  factory StatusPill.activo(bool activo) => StatusPill(
        texto: activo ? 'Activo' : 'Inactivo',
        color: activo ? AppColors.exito : AppColors.peligro,
      );

  factory StatusPill.rol(Rol rol) => StatusPill(
        texto: rol.etiqueta,
        color: rol == Rol.admin ? AppColors.primary : AppColors.secondary,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Text(
        texto.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

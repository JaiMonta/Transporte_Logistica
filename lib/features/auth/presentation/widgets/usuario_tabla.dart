import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../models/profile.dart';

/// Tabla de usuarios para pantallas anchas.
class UsuarioTabla extends StatelessWidget {
  const UsuarioTabla({
    super.key,
    required this.usuarios,
    required this.onEditar,
    required this.onAlternarActivo,
    this.onRestablecer,
  });

  final List<Profile> usuarios;
  final ValueChanged<Profile> onEditar;
  final ValueChanged<Profile> onAlternarActivo;
  final ValueChanged<Profile>? onRestablecer;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Nombre')),
          DataColumn(label: Text('Correo')),
          DataColumn(label: Text('Teléfono')),
          DataColumn(label: Text('Rol')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: usuarios.map((u) {
          return DataRow(
            cells: [
              DataCell(Text(u.nombreVisible)),
              DataCell(Text(u.email ?? '—')),
              DataCell(Text(
                (u.telefono == null || u.telefono!.isEmpty) ? '—' : u.telefono!,
              )),
              DataCell(StatusPill.rol(u.rol)),
              DataCell(StatusPill.activo(u.activo)),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEditar(u),
                    ),
                    if (onRestablecer != null)
                      IconButton(
                        tooltip: 'Restablecer contraseña',
                        icon: const Icon(Icons.key_outlined),
                        onPressed: () => onRestablecer!(u),
                      ),
                    IconButton(
                      tooltip: u.activo ? 'Desactivar' : 'Reactivar',
                      icon: Icon(
                        u.activo
                            ? Icons.block_outlined
                            : Icons.check_circle_outline,
                        color: u.activo ? AppColors.peligro : AppColors.exito,
                      ),
                      onPressed: () => onAlternarActivo(u),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

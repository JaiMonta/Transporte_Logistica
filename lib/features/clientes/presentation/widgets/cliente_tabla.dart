import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../models/cliente.dart';

/// Tabla de clientes para pantallas anchas.
class ClienteTabla extends StatelessWidget {
  const ClienteTabla({
    super.key,
    required this.clientes,
    required this.onEditar,
    required this.onAlternarActivo,
  });

  final List<Cliente> clientes;
  final ValueChanged<Cliente> onEditar;
  final ValueChanged<Cliente> onAlternarActivo;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Nombre')),
          DataColumn(label: Text('Contacto')),
          DataColumn(label: Text('Teléfono')),
          DataColumn(label: Text('Correo')),
          DataColumn(label: Text('Ubicación')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: clientes.map((c) {
          return DataRow(
            cells: [
              DataCell(Text(c.nombreVisible)),
              DataCell(Text(
                (c.nombreContacto == null || c.nombreContacto!.isEmpty)
                    ? '—'
                    : c.nombreContacto!,
              )),
              DataCell(Text(
                (c.telefono == null || c.telefono!.isEmpty) ? '—' : c.telefono!,
              )),
              DataCell(Text(
                (c.email == null || c.email!.isEmpty) ? '—' : c.email!,
              )),
              DataCell(
                Row(
                  children: [
                    Icon(
                      c.tieneUbicacion
                          ? Icons.location_on
                          : Icons.location_off_outlined,
                      size: 16,
                      color: c.tieneUbicacion
                          ? AppColors.tertiary
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(c.tieneUbicacion ? 'Con coordenadas' : 'Sin ubicación'),
                  ],
                ),
              ),
              DataCell(StatusPill.activo(c.activo)),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEditar(c),
                    ),
                    IconButton(
                      tooltip: c.activo ? 'Desactivar' : 'Reactivar',
                      icon: Icon(
                        c.activo
                            ? Icons.block_outlined
                            : Icons.check_circle_outline,
                        color: c.activo ? AppColors.peligro : AppColors.exito,
                      ),
                      onPressed: () => onAlternarActivo(c),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/services/almacenamiento_providers.dart';
import '../../../shared/services/almacenamiento_repository.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../auth/models/profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../camiones/providers/camiones_providers.dart';
import '../../entregas/providers/entregas_providers.dart';
import '../../fletes/models/extra.dart';
import '../../fletes/models/tabulador_flete.dart';
import '../../fletes/presentation/widgets/bloque_extras.dart';
import '../../fletes/presentation/widgets/selector_localidad_flete.dart';
import '../../fletes/providers/fletes_providers.dart';
import '../../fletes/services/calculo_extras.dart';
import '../../fletes/services/calculo_flete.dart';
import '../models/manifiesto.dart';
import '../providers/manifiestos_providers.dart';

/// Detalle y auditoría de un manifiesto (administrador).
class ManifiestoDetalleScreen extends ConsumerWidget {
  const ManifiestoDetalleScreen({super.key, required this.manifiestoId});

  final String manifiestoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(manifiestoProvider(manifiestoId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del manifiesto')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(mensajeError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (m) => m == null
            ? const Center(child: Text('No se encontró el manifiesto.'))
            : _Contenido(manifiesto: m),
      ),
    );
  }
}

class _Contenido extends ConsumerStatefulWidget {
  const _Contenido({required this.manifiesto});

  final Manifiesto manifiesto;

  @override
  ConsumerState<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends ConsumerState<_Contenido> {
  String? _urlFirmada;
  bool _cargandoFoto = false;
  String? _errorFoto;

  @override
  void initState() {
    super.initState();
    if (widget.manifiesto.tieneFoto) _cargarFoto();
  }

  Future<void> _cargarFoto() async {
    setState(() {
      _cargandoFoto = true;
      _errorFoto = null;
    });
    try {
      final bucket = BucketEvidencia.values.firstWhere(
        (b) => b.valor == widget.manifiesto.bucket,
        orElse: () => BucketEvidencia.manifiestos,
      );
      final url = await ref.read(almacenamientoRepositoryProvider).urlFirmada(
            bucket: bucket,
            path: widget.manifiesto.path!,
            expiresIn: 300,
          );
      if (!mounted) return;
      setState(() {
        _urlFirmada = url;
        _cargandoFoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorFoto = mensajeError(e);
        _cargandoFoto = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.manifiesto;
    final tema = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _foto(context),
              const SizedBox(height: AppSpacing.md),
              _FilaDato(
                icono: Icons.event_outlined,
                etiqueta: 'Fecha',
                valor: _fechaTexto(m.fecha),
              ),
              _FilaDato(
                icono: Icons.person_outline,
                etiqueta: 'Capturado por',
                valor: (m.capturadoPorNombre?.isEmpty ?? true)
                    ? '—'
                    : m.capturadoPorNombre!,
              ),
              if (m.confianzaPorcentaje != null)
                _FilaDato(
                  icono: Icons.percent,
                  etiqueta: 'Confianza del OCR',
                  valor: '${m.confianzaPorcentaje}%',
                ),
              _FilaDato(
                icono: Icons.local_shipping_outlined,
                etiqueta: 'Camión',
                valor: m.camionVisible,
              ),
              _FilaDato(
                icono: Icons.place_outlined,
                etiqueta: 'Localidad más lejana',
                valor: (m.localidadMasLejana == null ||
                        m.localidadMasLejana!.isEmpty)
                    ? '—'
                    : m.localidadMasLejana!,
              ),
              _FilaDato(
                icono: Icons.attach_money,
                etiqueta: 'Costo de flete',
                valor: m.costoFlete == null
                    ? '—'
                    : '\$${m.costoFlete!.toStringAsFixed(2)}',
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(
                  texto: m.cotejo.etiqueta,
                  color: switch (m.cotejo) {
                    CotejoEstado.ok => AppColors.exito,
                    CotejoEstado.revision => AppColors.peligro,
                    CotejoEstado.pendiente => AppColors.secondary,
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Documentos (${m.totalDocumentos})',
                  style: tema.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              _tablaLineas(context, m),
              const SizedBox(height: AppSpacing.lg),
              _accionesAdmin(context, m),
              const SizedBox(height: AppSpacing.lg),
              if (ref.watch(currentProfileProvider).value?.rol == Rol.admin)
                BloqueExtras(
                  manifiestoId: m.id,
                  fleteBase: m.costoFlete,
                  onCalcularSugeridos: () => _calcularExtrasSugeridos(m),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Registrado: ${_fechaHora(m.creadoEn)}',
                style: tema.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accionesAdmin(BuildContext context, Manifiesto m) {
    final perfil = ref.watch(currentProfileProvider).value;
    if (perfil?.rol != Rol.admin) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton.icon(
              onPressed: () => _editarLocalidad(m),
              icon: const Icon(Icons.place_outlined),
              label: const Text('Editar localidad más lejana'),
            ),
            OutlinedButton.icon(
              onPressed: () => _editarCamion(m),
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Editar camión'),
            ),
          ],
        ),
        SwitchListTile(
          value: m.esFinSemana,
          contentPadding: EdgeInsets.zero,
          title: const Text('Servicio en fin de semana (+5%)'),
          onChanged: (v) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(manifiestosRepositoryProvider)
                  .marcarFinSemana(id: m.id, valor: v);
              ref.invalidate(manifiestoProvider(m.id));
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(mensajeError(e))));
            }
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        const _TituloSeccion('Entregas: marcar "otra localidad" (desvío)'),
        _EntregasOtraLocalidad(manifiestoId: m.id),
      ],
    );
  }

  Future<void> _editarLocalidad(Manifiesto m) async {
    TabuladorFlete? elegido;
    if (m.fletesTabuladorId != null) {
      elegido =
          await ref.read(fletesRepositoryProvider).obtener(m.fletesTabuladorId!);
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Localidad más lejana'),
        content: SizedBox(
          width: 420,
          child: SelectorLocalidadFlete(
            onSeleccion: (f) => elegido = f,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final f = elegido;
              if (f == null) return;
              Navigator.pop(context);
              await _guardarLocalidad(m, f);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarLocalidad(Manifiesto m, TabuladorFlete flete) async {
    try {
      // Capacidad del camión asignado (si tiene).
      double? capacidadKg;
      if (m.camionId != null) {
        final camion =
            await ref.read(camionesRepositoryProvider).obtener(m.camionId!);
        capacidadKg = camion?.capacidadKg;
      }
      final costo = CalculoFlete.precioFlete(
        tabulador: flete,
        capacidadKg: capacidadKg,
      );
      await ref.read(manifiestosRepositoryProvider).actualizarCabecera(
            id: m.id,
            camionId: m.camionId,
            localidadMasLejana: flete.localidad,
            fletesTabuladorId: flete.id,
            costoFlete: costo,
          );
      if (!mounted) return;
      ref.invalidate(manifiestoProvider(m.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            costo == null
                ? 'Localidad actualizada (sin camión/capacidad para calcular el flete).'
                : 'Localidad actualizada. Flete: \$${costo.toStringAsFixed(2)}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    }
  }

  /// Abre un diálogo para asignar el camión del manifiesto (admin).
  ///
  /// Al guardar, recalcula el flete base con la localidad ya elegida (si hay).
  Future<void> _editarCamion(Manifiesto m) async {
    final camiones = await ref.read(camionesActivosProvider.future);
    if (!mounted) return;
    if (camiones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay camiones activos.')),
      );
      return;
    }
    String? elegido = m.camionId;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camión del manifiesto'),
        content: SizedBox(
          width: 420,
          child: StatefulBuilder(
            builder: (context, setEstado) => DropdownButtonFormField<String>(
              initialValue: camiones.any((c) => c.id == elegido) ? elegido : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Camión'),
              items: [
                for (final c in camiones)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.marcaVisible} · ${c.placa}'
                      '${c.capacidadKg == null ? '' : ' · ${(c.capacidadKg! / 1000).toStringAsFixed(1)} t'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setEstado(() => elegido = v),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmar != true || elegido == null) return;

    try {
      // Recalcular flete si ya hay localidad del tabulador.
      double? costo = m.costoFlete;
      if (m.fletesTabuladorId != null) {
        final tab = await ref
            .read(fletesRepositoryProvider)
            .obtener(m.fletesTabuladorId!);
        final camion =
            await ref.read(camionesRepositoryProvider).obtener(elegido!);
        costo = CalculoFlete.precioFlete(
          tabulador: tab,
          capacidadKg: camion?.capacidadKg,
        );
      }
      await ref.read(manifiestosRepositoryProvider).actualizarCabecera(
            id: m.id,
            camionId: elegido,
            localidadMasLejana: m.localidadMasLejana,
            fletesTabuladorId: m.fletesTabuladorId,
            costoFlete: costo,
          );
      if (!mounted) return;
      ref.invalidate(manifiestoProvider(m.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            costo == null
                ? 'Camión actualizado. Elige la localidad para calcular el flete.'
                : 'Camión actualizado. Flete: \$${costo.toStringAsFixed(2)}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    }
  }

  /// Calcula y crea los extras sugeridos a partir de las entregas.
  Future<void> _calcularExtrasSugeridos(Manifiesto m) async {
    final repo = ref.read(extrasRepositoryProvider);
    await repo.eliminarSugeridos(m.id);

    final entregas =
        await ref.read(entregasRepositoryProvider).porManifiesto(m.id);
    final fleteBase = m.costoFlete ?? 0;

    // Capacidad del camión y tarifas de extras por capacidad.
    double? capacidadKg;
    if (m.camionId != null) {
      final camion = await ref.read(camionesRepositoryProvider).obtener(m.camionId!);
      capacidadKg = camion?.capacidadKg;
    }
    final extrasCfg = await ref.read(supabaseProvider).from('fletes_extras').select();
    final tarifas = _tarifasPorCapacidad(
      (extrasCfg as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      capacidadKg,
    );

    final nuevos = <Extra>[];

    // Caleta: 2 por manifiesto.
    if (tarifas.caleta > 0) {
      nuevos.add(Extra(
        id: '',
        manifiestoId: m.id,
        tipo: TipoExtra.caleta,
        descripcion: '2 por guía de carga',
        base: tarifas.caleta,
        monto: CalculoExtras.caleta(tarifas.caleta),
      ));
    }

    // Reparto: agrupa clientes a <=10 km.
    final puntos = [
      for (final e in entregas)
        PuntoEntrega(id: e.id, lat: e.lat, lng: e.lng),
    ];
    final nRepartos = CalculoExtras.repartos(puntos);
    if (nRepartos > 0 && tarifas.reparto > 0) {
      nuevos.add(Extra(
        id: '',
        manifiestoId: m.id,
        tipo: TipoExtra.reparto,
        descripcion: '$nRepartos reparto(s)',
        base: tarifas.reparto,
        monto: tarifas.reparto * nRepartos,
      ));
    }

    // Desvío: entregas marcadas como "otra localidad".
    final nDesvio = entregas.where((e) => e.esOtraLocalidad).length;
    final montoDesvio =
        CalculoExtras.desvio(capacidadKg, fleteBase, nDesvio);
    if (montoDesvio > 0) {
      nuevos.add(Extra(
        id: '',
        manifiestoId: m.id,
        tipo: TipoExtra.desvio,
        descripcion: '$nDesvio desvío(s) a otra localidad',
        base: fleteBase,
        monto: montoDesvio,
      ));
    }

    // Fin de semana.
    if (m.esFinSemana) {
      nuevos.add(Extra(
        id: '',
        manifiestoId: m.id,
        tipo: TipoExtra.finSemana,
        descripcion: 'Servicio en fin de semana (5%)',
        base: fleteBase,
        monto: CalculoExtras.finDeSemana(fleteBase),
        porcentaje: 5,
      ));
    }

    if (nuevos.isEmpty) {
      throw Exception('No hay extras que calcular con los datos actuales.');
    }
    await repo.crearLote(nuevos);
  }

  ({double caleta, double mora, double reparto}) _tarifasPorCapacidad(
    List<Map<String, dynamic>> filas,
    double? capacidadKg,
  ) {
    // Capacidad del camión en toneladas; si no hay, usa la menor.
    final ton = (capacidadKg ?? 0) / 1000;
    Map<String, dynamic>? elegida;
    double mejor = double.infinity;
    for (final f in filas) {
      final c = (f['capacidad_t'] as num?)?.toDouble() ?? 0;
      if (ton <= c && c - ton < mejor) {
        mejor = c - ton;
        elegida = f;
      }
    }
    elegida ??= filas.isNotEmpty ? filas.first : null;
    double num0(Object? v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      final s = v.toString().replaceAll('%', '').replaceAll(',', '.');
      return double.tryParse(s) ?? 0;
    }
    return (
      caleta: num0(elegida?['caleta']),
      mora: num0(elegida?['mora']),
      reparto: num0(elegida?['reparto']),
    );
  }

  Widget _tablaLineas(BuildContext context, Manifiesto m) {
    if (m.lineas.isEmpty) {
      return const Text('Sin documentos registrados.');
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Tipo')),
          DataColumn(label: Text('Número')),
          DataColumn(label: Text('Cliente')),
        ],
        rows: [
          for (final l in m.lineas)
            DataRow(cells: [
              DataCell(Text(l.tipo.etiqueta)),
              DataCell(Text(l.numeroVisible)),
              DataCell(Text(l.clienteVisible)),
            ]),
        ],
      ),
    );
  }

  Widget _foto(BuildContext context) {
    if (!widget.manifiesto.tieneFoto) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Center(
          child: Text('Sin foto del BOL registrada.'),
        ),
      );
    }
    if (_cargandoFoto) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorFoto != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(_errorFoto!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Image.network(
        _urlFirmada!,
        height: 320,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Center(child: Text('No se pudo mostrar la imagen.')),
        ),
      ),
    );
  }

  static String _fechaTexto(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  static String _fechaHora(DateTime? fecha) {
    if (fecha == null) return '—';
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    final h = fecha.hour.toString().padLeft(2, '0');
    final min = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} $h:$min';
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: tema.textTheme.labelSmall),
                Text(valor, style: tema.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) =>
      Text(texto, style: Theme.of(context).textTheme.labelLarge);
}

/// Lista de entregas: localidad (para el flete) y "otra localidad" (desvío).
class _EntregasOtraLocalidad extends ConsumerWidget {
  const _EntregasOtraLocalidad({required this.manifiestoId});

  final String manifiestoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(entregasDeManifiestoProvider(manifiestoId));
    final tabulador = ref.watch(tabuladorProvider(const FiltroFletes()));
    final localidades = tabulador.value ?? const <TabuladorFlete>[];
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(mensajeError(e)),
      data: (entregas) => Column(
        children: [
          for (final e in entregas)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.orden + 1}. ${e.clienteVisible}',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<String>(
                      initialValue: localidades
                              .any((l) => l.localidad == e.localidad)
                          ? e.localidad
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Localidad (tabulador)',
                        isDense: true,
                      ),
                      items: [
                        for (final l in localidades)
                          DropdownMenuItem(
                            value: l.localidad,
                            child: Text(
                              '${l.localidad} · KM ${l.km?.toStringAsFixed(0) ?? '—'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final fila =
                              localidades.firstWhere((l) => l.localidad == v);
                          await ref
                              .read(entregasRepositoryProvider)
                              .asignarLocalidad(
                                id: e.id,
                                localidad: v,
                                distanciaKm: fila.km,
                              );
                          ref.invalidate(
                              entregasDeManifiestoProvider(manifiestoId));
                        } catch (err) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(mensajeError(err))),
                          );
                        }
                      },
                    ),
                    CheckboxListTile(
                      value: e.esOtraLocalidad,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Otra localidad (desvío)'),
                      onChanged: (v) async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref
                              .read(entregasRepositoryProvider)
                              .marcarOtraLocalidad(id: e.id, valor: v ?? false);
                          ref.invalidate(
                              entregasDeManifiestoProvider(manifiestoId));
                        } catch (err) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(mensajeError(err))),
                          );
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        e.esMasLejana
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: e.esMasLejana ? AppColors.primary : null,
                      ),
                      title: const Text('Más lejana (define el flete)'),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref
                              .read(entregasRepositoryProvider)
                              .marcarMasLejana(
                                id: e.id,
                                manifiestoId: manifiestoId,
                                valor: true,
                              );
                          // Reflejar el nombre en el manifiesto.
                          await ref
                              .read(manifiestosRepositoryProvider)
                              .actualizarCabecera(
                                id: manifiestoId,
                                camionId: null,
                                localidadMasLejana: e.localidad,
                              );
                          ref.invalidate(
                              entregasDeManifiestoProvider(manifiestoId));
                          ref.invalidate(manifiestoProvider(manifiestoId));
                        } catch (err) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(mensajeError(err))),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

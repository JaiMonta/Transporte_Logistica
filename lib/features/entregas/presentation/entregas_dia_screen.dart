import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/services/almacenamiento_providers.dart';
import '../../../shared/services/almacenamiento_repository.dart';
import '../../../shared/services/gps_tracker.dart' show EstadoCaptura;
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../fletes/models/extra.dart';
import '../../fletes/providers/fletes_providers.dart';
import '../../gps/services/seguimiento_gps.dart';
import '../models/entrega.dart';
import '../providers/entregas_providers.dart';
import 'widgets/entrega_card.dart';

/// Entregas (chofer). Arranca el seguimiento GPS al abrir.
class EntregasDiaScreen extends ConsumerStatefulWidget {
  const EntregasDiaScreen({super.key});

  @override
  ConsumerState<EntregasDiaScreen> createState() => _EntregasDiaScreenState();
}

class _EntregasDiaScreenState extends ConsumerState<EntregasDiaScreen> {
  FiltroEntregas _filtro =
      FiltroEntregas(dia: DateTime.now());
  bool _gpsActivo = false;
  String? _avisoGps;

  @override
  void initState() {
    super.initState();
    _iniciarGps();
  }

  Future<void> _iniciarGps() async {
    try {
      final estado = await ref.read(seguimientoGpsProvider).iniciar();
      if (!mounted) return;
      setState(() {
        _gpsActivo = estado == EstadoCaptura.ok;
        _avisoGps = _mensajeGps(estado);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gpsActivo = false;
        _avisoGps = 'No se pudo activar el GPS. Revisa los permisos.';
      });
    }
  }

  String? _mensajeGps(EstadoCaptura estado) => switch (estado) {
        EstadoCaptura.ok => null,
        EstadoCaptura.sinPermiso =>
          'El GPS necesita permiso de ubicación. Concédelo y reintenta.',
        EstadoCaptura.servicioApagado =>
          'Activa la ubicación del teléfono para registrar el trayecto.',
        EstadoCaptura.noDisponible =>
          'El GPS no está disponible en esta plataforma.',
        EstadoCaptura.error =>
          'No se pudo obtener la ubicación. Se reintentará en el próximo ciclo.',
      };

  /// El chofer avisa (sugiere) una devolución o mora; el admin aprueba.
  Future<void> _avisar(Entrega entrega) async {
    final tipo = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.keyboard_return),
              title: const Text('Avisar devolución / retorno'),
              onTap: () => Navigator.pop(context, 'retorno'),
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_empty),
              title: const Text('Avisar mora (cliente)'),
              onTap: () => Navigator.pop(context, 'mora'),
            ),
          ],
        ),
      ),
    );
    if (tipo == null) return;

    final esMora = tipo == 'mora';
    TipoExtra tipoExtra = esMora ? TipoExtra.mora : TipoExtra.retorno;
    String descripcion = esMora
        ? 'Aviso de mora (${entrega.clienteVisible})'
        : 'Aviso de devolución (${entrega.clienteVisible})';

    try {
      await ref.read(extrasRepositoryProvider).crear(Extra(
            id: '',
            manifiestoId: entrega.manifiestoId,
            tipo: tipoExtra,
            descripcion: descripcion,
            monto: 0,
            origen: 'chofer',
          ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aviso enviado. El administrador lo revisará.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    }
  }

  Future<void> _entregar(Entrega entrega) async {
    // Resultado: 'cancelar' (aborta), 'foto' (con foto) o 'sin' (sin foto).
    final opcion = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar entrega'),
        content: Text(
          '¿Marcar como entregado a "${entrega.clienteVisible}"?\n\n'
          'Puedes adjuntar la foto del recibo firmado (opcional).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancelar'),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'foto'),
            child: const Text('Con foto'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'sin'),
            child: const Text('Sin foto'),
          ),
        ],
      ),
    );

    // Tocar fuera (null) o Cancelar: no se marca nada.
    if (opcion == null || opcion == 'cancelar') return;

    EvidenciaSubida? evidencia;
    if (opcion == 'foto') {
      evidencia = await _tomarFotoRecibo(entrega);
      if (evidencia == null) return; // canceló o falló la foto
    }

    try {
      await ref.read(entregasRepositoryProvider).marcarEntregado(
            id: entrega.id,
            bucket: evidencia?.bucket,
            path: evidencia?.path,
            hashSha256: evidencia?.hashSha256,
          );
      if (!mounted) return;
      ref.invalidate(entregasDelDiaProvider(_filtro));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrega registrada.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    }
  }

  Future<EvidenciaSubida?> _tomarFotoRecibo(Entrega entrega) async {
    try {
      // En móvil cámara; en Web no hay cámara en vivo → galería/archivo.
      final archivo = await ImagePicker().pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      );
      if (archivo == null) return null;
      final Uint8List bytes = await archivo.readAsBytes();
      final almacen = ref.read(almacenamientoRepositoryProvider);
      final path = almacen.rutaDe(
        carpeta: 'recibos',
        archivo: 'recibo_${entrega.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      return await almacen.subir(
        bucket: BucketEvidencia.firmas,
        path: path,
        bytes: bytes,
        tipo: TipoEvidencia.recibo,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
      return null;
    }
  }

  void _verMapa(Entrega entrega) =>
      context.push(Rutas.choferEntregaMapa(entrega.manifiestoId));

  Widget _chipModo(String texto, ModoEntregas modo) => ChoiceChip(
        label: Text(texto),
        selected: _filtro.modo == modo,
        onSelected: (_) => setState(() => _filtro = _filtro.copyWith(modo: modo)),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(entregasDelDiaProvider(_filtro));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entregas'),
        leading: IconButton(
          tooltip: 'Atrás',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Rutas.choferHome),
        ),
        actions: [
          IconButton(
            tooltip: 'Mapa de la ruta',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push(Rutas.choferMapa),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                _chipModo('Pendientes', ModoEntregas.pendientes),
                _chipModo('Últimos días', ModoEntregas.hoy),
                _chipModo('Todas', ModoEntregas.todas),
              ],
            ),
          ),
          if (_avisoGps != null)
            Container(
              width: double.infinity,
              color: AppColors.errorContainer,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_avisoGps!,
                        style: const TextStyle(color: AppColors.onSurface)),
                  ),
                  TextButton(
                    onPressed: _iniciarGps,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          if (_gpsActivo)
            Container(
              width: double.infinity,
              color: AppColors.tertiary.withValues(alpha: 0.10),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed,
                      size: 16, color: AppColors.tertiary),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Ubicación activa (reporta cada 2 min).',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(mensajeError(e), textAlign: TextAlign.center),
                ),
              ),
              data: (entregas) => RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(entregasDelDiaProvider(_filtro)),
                child: entregas.isEmpty
                    ? const _VacioVista()
                    : ResponsiveLayout(
                        breakpoint: 760,
                        movil: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: entregas.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) => EntregaCard(
                            entrega: entregas[i],
                            onEntregar: _entregar,
                            onVerMapa: _verMapa,
                            onAvisar: _avisar,
                          ),
                        ),
                        ancho: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: entregas.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) => EntregaCard(
                            entrega: entregas[i],
                            onEntregar: _entregar,
                            onVerMapa: _verMapa,
                            onAvisar: _avisar,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VacioVista extends StatelessWidget {
  const _VacioVista();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.local_shipping_outlined,
            size: 56, color: AppColors.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text('No hay entregas en este lapso.',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text('Captura un manifiesto para generar tus entregas.',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

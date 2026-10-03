import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/facturacion_repository.dart';
import '../models/factura.dart';

final facturacionRepositoryProvider = Provider<FacturacionRepository>(
  (ref) => FacturacionRepository(ref.watch(supabaseProvider)),
);

/// Filtro por lapso (rango de fechas).
class FiltroFacturacion {
  const FiltroFacturacion({required this.desde, required this.hasta});

  final DateTime desde;
  final DateTime hasta;

  @override
  bool operator ==(Object other) =>
      other is FiltroFacturacion &&
      other.desde == desde &&
      other.hasta == hasta;

  @override
  int get hashCode => Object.hash(desde, hasta);
}

/// Facturas en un lapso.
final facturasProvider =
    FutureProvider.autoDispose.family<List<Factura>, FiltroFacturacion>(
  (ref, filtro) =>
      ref.watch(facturacionRepositoryProvider).listarPorLapso(
            filtro.desde,
            filtro.hasta,
          ),
);

/// Una factura por id.
final facturaProvider =
    FutureProvider.autoDispose.family<Factura?, String>((ref, id) {
  return ref.watch(facturacionRepositoryProvider).obtener(id);
});

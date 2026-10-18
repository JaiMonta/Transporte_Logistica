import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/empresas_repository.dart';
import '../models/empresa.dart';
import '../models/producto.dart';

final empresasRepositoryProvider = Provider<EmpresasRepository>(
  (ref) => EmpresasRepository(ref.watch(supabaseProvider)),
);

/// Empresas (todas).
final empresasProvider = FutureProvider.autoDispose<List<Empresa>>(
  (ref) => ref.watch(empresasRepositoryProvider).listarEmpresas(),
);

/// Empresas activas (para selectores y para agrupar la facturación).
final empresasActivasProvider = FutureProvider.autoDispose<List<Empresa>>(
  (ref) => ref.watch(empresasRepositoryProvider).listarEmpresas(activo: true),
);

/// Productos (todos), con el nombre de su empresa.
final productosProvider = FutureProvider.autoDispose<List<Producto>>(
  (ref) => ref.watch(empresasRepositoryProvider).listarProductos(),
);

/// Productos activos (para la captura de pesos y el prorrateo).
final productosActivosProvider = FutureProvider.autoDispose<List<Producto>>(
  (ref) => ref.watch(empresasRepositoryProvider).listarProductos(activo: true),
);

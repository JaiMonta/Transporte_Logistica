import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import 'almacenamiento_repository.dart';

/// Repositorio de almacenamiento (compresión, subida y URLs firmadas).
final almacenamientoRepositoryProvider = Provider<AlmacenamientoRepository>(
  (ref) => AlmacenamientoRepository(ref.watch(supabaseProvider)),
);

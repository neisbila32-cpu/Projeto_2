import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/inventario/models/inventario.dart';
import 'package:projeto_2/features/inventario/repositories/inventario_repository.dart';

final inventarioRepositoryProvider = Provider<InventarioRepository>((ref) {
  return InventarioRepository(() => AppDatabase.instance.database);
});

final inventarioEmAndamentoProvider = FutureProvider.autoDispose<Inventario?>((
  ref,
) {
  return ref.watch(inventarioRepositoryProvider).emAndamento();
});

final inventariosProvider = FutureProvider.autoDispose<List<Inventario>>((ref) {
  return ref.watch(inventarioRepositoryProvider).listar();
});

final inventarioPorIdProvider = FutureProvider.autoDispose
    .family<Inventario?, int>((ref, id) {
      return ref.watch(inventarioRepositoryProvider).porId(id);
    });

final itensInventarioProvider = FutureProvider.autoDispose
    .family<List<ItemInventario>, int>((ref, inventarioId) {
      return ref.watch(inventarioRepositoryProvider).itens(inventarioId);
    });

final auditoriaInventarioProvider = FutureProvider.autoDispose
    .family<List<AuditoriaItemInventario>, int>((ref, inventarioId) {
      return ref.watch(inventarioRepositoryProvider).auditoria(inventarioId);
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/backup/services/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    obterBanco: () => AppDatabase.instance.database,
    fecharBanco: () => AppDatabase.instance.fechar(),
    caminhoBanco: () => AppDatabase.instance.caminho(),
  );
});
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/backup/services/backup_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Directory? tempDir;
  Database? appDb;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_arquivo_test_');
    final caminho = p.join(tempDir!.path, 'estoque_uan.db');
    appDb = await databaseFactoryFfi.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: AppDatabase.configurarBanco,
        onCreate: AppDatabase.criarEsquema,
      ),
    );
    AppDatabase.injetarBancoParaTestes(appDb!);
  });

  tearDownAll(() async {
    await appDb?.close();
    await tempDir?.delete(recursive: true);
  });

  BackupService _servico() => BackupService(
    obterBanco: () async => appDb!,
    fecharBanco: () async {},
    caminhoBanco: () async => appDb!.path,
  );

  Future<File> _criarBackupFake(String nome,
      {int versao = 1, bool tabelas = true}) async {
    final caminho = p.join(tempDir!.path, nome);
    final db = await databaseFactoryFfi.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: AppDatabase.configurarBanco,
        onCreate: tabelas ? AppDatabase.criarEsquema : null,
      ),
    );
    if (versao > 1) {
      await db.setVersion(versao);
    }
    await db.close();
    return File(caminho);
  }

  group('BackupService.validarArquivo (banco em arquivo)', () {
    test('recusa arquivo que não é SQLite', () async {
      final arquivo = File(p.join(tempDir!.path, 'nao_sqlite.db'));
      await arquivo.writeAsBytes(List<int>.generate(100, (i) => i % 256));
      await expectLater(
          _servico().validarArquivo(arquivo), throwsA(isA<AppException>()));
    });

    test('recusa SQLite sem as tabelas do app', () async {
      final arquivo = await _criarBackupFake('sem_tabelas.db', tabelas: false);
      await expectLater(
          _servico().validarArquivo(arquivo), throwsA(isA<AppException>()));
    });

    test('recusa arquivo truncado', () async {
      final valido = await _criarBackupFake('valido.db');
      final truncado = File(p.join(tempDir!.path, 'truncado.db'));
      await truncado.writeAsBytes(valido.readAsBytesSync().sublist(0, 32));
      await expectLater(
          _servico().validarArquivo(truncado), throwsA(isA<AppException>()));
    });

    test('recusa backup de versão maior que a do app', () async {
      final arquivo =
          await _criarBackupFake('nova_versao.db', versao: 2, tabelas: true);
      await expectLater(
          _servico().validarArquivo(arquivo), throwsA(isA<AppException>()));
    });
  });
}
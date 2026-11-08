import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/backup/services/backup_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migracao_contextos_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<Database> criarBancoV1(String nome) async {
    return databaseFactoryFfi.openDatabase(
      p.join(tempDir.path, nome),
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: AppDatabase.prepararBancoParaMigracao,
        onCreate: AppDatabase.criarEsquema,
        onOpen: AppDatabase.configurarBanco,
      ),
    );
  }

  Future<Database> criarBancoIntermediario(String nome, int versao) async {
    final caminho = p.join(tempDir.path, nome);
    final v1 = await criarBancoV1(nome);
    await v1.close();
    return databaseFactoryFfi.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: versao,
        onConfigure: AppDatabase.prepararBancoParaMigracao,
        onCreate: AppDatabase.criarEsquemaAtual,
        onUpgrade: AppDatabase.migrarEsquema,
        onOpen: AppDatabase.configurarBanco,
      ),
    );
  }

  test('migra v1 preservando dados, relações e permite reabrir', () async {
    final caminho = p.join(tempDir.path, 'migracao.db');
    final v1 = await criarBancoV1('migracao.db');
    final unidadeId = (await v1.query('unidades', limit: 1)).first['id'] as int;
    final categoriaId = await v1.insert('categorias', {'nome': 'Proteínas'});
    final usuarioId = await v1.insert('usuarios', {
      'nome': 'Admin local',
      'login': 'admin-local',
      'senha_hash': 'hash-preservado',
      'senha_salt': 'salt-preservado',
      'perfil': 'admin',
      'recup_hash': 'recuperacao-preservada',
      'recup_salt': 'salt-recuperacao',
      'ativo': 1,
      'criado_em': '2026-01-02T03:04:05.000',
    });
    final produtoId = await v1.insert('produtos', {
      'nome': 'Feijão',
      'categoria_id': categoriaId,
      'unidade_id': unidadeId,
      'saldo': 25750,
      'ativo': 1,
      'criado_em': '2026-01-02T03:04:05.000',
      'criado_por': usuarioId,
    });
    final inventarioId = await v1.insert('inventarios', {
      'data_hora': '2026-01-03T10:00:00.000',
      'usuario_id': usuarioId,
      'status': 'finalizado',
      'observacao': 'Contagem preservada',
    });
    final movimentoId = await v1.insert('movimentacoes', {
      'produto_id': produtoId,
      'tipo': 'entrada',
      'delta': 1000,
      'saldo_apos': 25750,
      'data_hora': '2026-01-03T10:01:00.000',
      'usuario_id': usuarioId,
      'observacao': 'Histórico preservado',
    });
    final itemId = await v1.insert('itens_inventario', {
      'inventario_id': inventarioId,
      'produto_id': produtoId,
      'qtd_sistema': 24750,
      'qtd_contada': 25750,
      'divergencia': 1000,
      'justificativa': 'Conferência',
      'ajustado': 1,
    });
    await v1.close();

    var db = await databaseFactoryFfi.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: AppDatabase.versaoAtual,
        onConfigure: AppDatabase.prepararBancoParaMigracao,
        onCreate: AppDatabase.criarEsquemaAtual,
        onUpgrade: AppDatabase.migrarEsquema,
        onOpen: AppDatabase.configurarBanco,
      ),
    );

    expect(await db.getVersion(), AppDatabase.versaoAtual);
    expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
    final produto = (await db.query(
      'produtos',
      where: 'id = ?',
      whereArgs: [produtoId],
    )).single;
    expect(produto['nome'], 'Feijão');
    expect(produto['saldo'], 25750);
    expect(produto['categoria_id'], categoriaId);
    expect(produto['unidade_id'], unidadeId);

    final usuario = (await db.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [usuarioId],
    )).single;
    expect(usuario['senha_hash'], 'hash-preservado');
    expect(usuario['senha_salt'], 'salt-preservado');
    expect(usuario['recup_hash'], 'recuperacao-preservada');
    expect(usuario['recup_salt'], 'salt-recuperacao');

    expect(
      (await db.query(
        'movimentacoes',
        where: 'id = ?',
        whereArgs: [movimentoId],
      )).single['observacao'],
      'Histórico preservado',
    );
    expect(
      (await db.query(
        'inventarios',
        where: 'id = ?',
        whereArgs: [inventarioId],
      )).single['observacao'],
      'Contagem preservada',
    );
    expect(
      (await db.query(
        'itens_inventario',
        where: 'id = ?',
        whereArgs: [itemId],
      )).single['divergencia'],
      1000,
    );

    final contextos = await db.query('contextos_trabalho');
    expect(contextos, hasLength(1));
    expect(contextos.single['tipo'], 'individual');
    expect(contextos.single['uan_remota_id'], isNull);
    final contextoId = contextos.single['id'] as String;
    expect(
      contextoId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );

    for (final tabela in AppDatabase.tabelasComContexto) {
      final linhas = await db.query(tabela, columns: ['contexto_id']);
      expect(
        linhas,
        isNotEmpty,
        reason: 'A fixture v1 deve ter dados em $tabela',
      );
      expect(
        linhas.every((linha) => linha['contexto_id'] == contextoId),
        isTrue,
        reason: tabela,
      );
    }
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(
      (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
      'ok',
    );

    final novaCategoriaId = await db.insert('categorias', {'nome': 'Nova'});
    expect(
      (await db.query(
        'categorias',
        columns: ['contexto_id'],
        where: 'id = ?',
        whereArgs: [novaCategoriaId],
      )).single['contexto_id'],
      contextoId,
    );

    await db.close();
    db = await databaseFactoryFfi.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: AppDatabase.versaoAtual,
        onConfigure: AppDatabase.prepararBancoParaMigracao,
        onCreate: AppDatabase.criarEsquemaAtual,
        onUpgrade: AppDatabase.migrarEsquema,
        onOpen: AppDatabase.configurarBanco,
      ),
    );
    expect((await db.query('contextos_trabalho')).single['id'], contextoId);
    expect(
      (await db.query(
        'produtos',
        where: 'id = ?',
        whereArgs: [produtoId],
      )).single['saldo'],
      25750,
    );
    await db.close();
  });

  test('banco novo inicia na versão atual com contexto individual', () async {
    final db = await databaseFactoryFfi.openDatabase(
      p.join(tempDir.path, 'novo.db'),
      options: OpenDatabaseOptions(
        version: AppDatabase.versaoAtual,
        onConfigure: AppDatabase.prepararBancoParaMigracao,
        onCreate: AppDatabase.criarEsquemaAtual,
        onUpgrade: AppDatabase.migrarEsquema,
        onOpen: AppDatabase.configurarBanco,
      ),
    );
    expect(await db.getVersion(), AppDatabase.versaoAtual);
    expect((await db.query('contextos_trabalho')).single['tipo'], 'individual');
    expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await db.close();
  });

  test('migra versão 2 para atual preservando saldos e históricos', () async {
    final caminho = p.join(tempDir.path, 'versao2.db');
    final dbV2 = await criarBancoIntermediario('versao2.db', 2);
    final contextoId = (await dbV2.query('contextos_trabalho')).single['id'];
    final categoriaId = await dbV2.insert('categorias', {
      'nome': 'Proteínas',
      'contexto_id': contextoId,
    });
    final usuarioId = await dbV2.insert('usuarios', {
      'nome': 'Admin',
      'login': 'admin-v2',
      'senha_hash': 'hash-v2',
      'senha_salt': 'salt-v2',
      'perfil': 'admin',
      'ativo': 1,
      'criado_em': '2026-02-03T04:05:06.000',
      'contexto_id': contextoId,
    });
    final unidadeId = (await dbV2.query(
      'unidades',
      where: 'sigla = ?',
      whereArgs: ['kg'],
    )).single['id'];
    final produtoId = await dbV2.insert('produtos', {
      'nome': 'Arroz',
      'categoria_id': categoriaId,
      'unidade_id': unidadeId,
      'saldo': 7654,
      'ativo': 1,
      'criado_em': '2026-02-03T04:05:06.000',
      'criado_por': usuarioId,
      'contexto_id': contextoId,
    });
    await dbV2.insert('movimentacoes', {
      'produto_id': produtoId,
      'tipo': 'entrada',
      'delta': 654,
      'saldo_apos': 7654,
      'data_hora': '2026-02-03T04:05:06.000',
      'usuario_id': usuarioId,
      'observacao': 'Histórico da v2',
      'contexto_id': contextoId,
    });
    await dbV2.close();

    final dbV4 = await databaseFactoryFfi.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: AppDatabase.versaoAtual,
        onConfigure: AppDatabase.prepararBancoParaMigracao,
        onCreate: AppDatabase.criarEsquemaAtual,
        onUpgrade: AppDatabase.migrarEsquema,
        onOpen: AppDatabase.configurarBanco,
      ),
    );
    expect(await dbV4.getVersion(), 4);
    expect(
      (await dbV4.query(
        'produtos',
        where: 'id = ?',
        whereArgs: [produtoId],
      )).single['saldo'],
      7654,
    );
    expect(
      (await dbV4.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [usuarioId],
      )).single['senha_hash'],
      'hash-v2',
    );
    expect(
      (await dbV4.query('movimentacoes')).single['observacao'],
      'Histórico da v2',
    );
    expect(await dbV4.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(
      (await dbV4.rawQuery('PRAGMA integrity_check')).single.values.single,
      'ok',
    );
    await dbV4.close();
  });

  test(
    'v3 permite nomes e identificadores iguais em contextos distintos',
    () async {
      final caminho = p.join(tempDir.path, 'versao3.db');
      final dbV3 = await criarBancoIntermediario('versao3.db', 3);
      final contextoLocal = (await dbV3.query(
        'contextos_trabalho',
      )).single['id'];
      final usuarioId = await dbV3.insert('usuarios', {
        'nome': 'Admin local',
        'login': 'mesmo-login',
        'senha_hash': 'hash-preservado',
        'senha_salt': 'salt-preservado',
        'perfil': 'admin',
        'ativo': 1,
        'criado_em': '2026-02-03T04:05:06.000',
        'contexto_id': contextoLocal,
      });
      await dbV3.close();

      final db = await databaseFactoryFfi.openDatabase(
        caminho,
        options: OpenDatabaseOptions(
          version: AppDatabase.versaoAtual,
          onConfigure: AppDatabase.prepararBancoParaMigracao,
          onCreate: AppDatabase.criarEsquemaAtual,
          onUpgrade: AppDatabase.migrarEsquema,
          onOpen: AppDatabase.configurarBanco,
        ),
      );
      final contextoCompartilhado = 'contexto-compartilhado-teste';
      await db.insert('contextos_trabalho', {
        'id': contextoCompartilhado,
        'tipo': 'compartilhado',
        'nome': 'UAN de teste',
        'uan_remota_id': 'uan-remota-teste',
        'criado_em': '2026-02-03T04:05:06.000',
        'ativo': 1,
      });

      // A política de alternância continua bloqueada; suspende-se apenas a
      // validação do contexto ativo para exercitar os índices de unicidade.
      for (final tabela in const ['categorias', 'unidades', 'usuarios']) {
        await db.execute(
          'DROP TRIGGER trg_${tabela}_contexto_validar_insercao',
        );
      }

      final categoriaLocal = (await db.query(
        'categorias',
        where: 'contexto_id = ? AND nome = ?',
        whereArgs: [contextoLocal, 'Gêneros secos'],
        limit: 1,
      )).single;
      final categoriaCompartilhadaId = await db.insert('categorias', {
        'nome': categoriaLocal['nome'],
        'ativa': 1,
        'contexto_id': contextoCompartilhado,
      });
      await expectLater(
        db.insert('categorias', {
          'nome': 'gêneros secos',
          'ativa': 1,
          'contexto_id': contextoCompartilhado,
        }),
        throwsA(anything),
      );
      expect(categoriaCompartilhadaId, greaterThan(0));

      final unidadeLocal = (await db.query(
        'unidades',
        where: 'contexto_id = ? AND sigla = ?',
        whereArgs: [contextoLocal, 'kg'],
      )).single;
      final unidadeCompartilhadaId = await db.insert('unidades', {
        'sigla': unidadeLocal['sigla'],
        'nome': unidadeLocal['nome'],
        'fracionavel': unidadeLocal['fracionavel'],
        'ativa': unidadeLocal['ativa'],
        'contexto_id': contextoCompartilhado,
      });
      await expectLater(
        db.insert('unidades', {
          'sigla': 'KG',
          'nome': 'Quilograma duplicado',
          'fracionavel': 1,
          'ativa': 1,
          'contexto_id': contextoCompartilhado,
        }),
        throwsA(anything),
      );

      final usuarioCompartilhadoId = await db.insert('usuarios', {
        'nome': 'Admin compartilhado',
        'login': 'MESMO-LOGIN',
        'senha_hash': 'hash-compartilhado',
        'senha_salt': 'salt-compartilhado',
        'perfil': 'admin',
        'ativo': 1,
        'criado_em': '2026-02-03T04:05:06.000',
        'contexto_id': contextoCompartilhado,
      });
      await expectLater(
        db.insert('usuarios', {
          'nome': 'Outro admin',
          'login': 'mesmo-login',
          'senha_hash': 'hash-outro',
          'senha_salt': 'salt-outro',
          'perfil': 'admin',
          'ativo': 1,
          'criado_em': '2026-02-03T04:05:06.000',
          'contexto_id': contextoCompartilhado,
        }),
        throwsA(anything),
      );

      await db.execute('DROP TRIGGER trg_produtos_contexto_validar_insercao');
      final categoriaCompartilhada = (await db.query(
        'categorias',
        where: 'contexto_id = ? AND id = ?',
        whereArgs: [contextoCompartilhado, categoriaCompartilhadaId],
      )).single;
      await expectLater(
        db.insert('produtos', {
          'nome': 'Produto com relação cruzada',
          'categoria_id': categoriaCompartilhada['id'],
          'unidade_id': unidadeCompartilhadaId,
          'saldo': 0,
          'ativo': 1,
          'criado_em': '2026-02-03T04:05:06.000',
          'criado_por': usuarioId,
          'contexto_id': contextoCompartilhado,
        }),
        throwsA(anything),
      );
      expect(usuarioCompartilhadoId, greaterThan(0));

      expect(
        (await db.query(
          'usuarios',
          where: 'id = ?',
          whereArgs: [usuarioId],
        )).single['senha_hash'],
        'hash-preservado',
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      expect(
        (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok',
      );
      await db.close();
    },
  );

  test('backup exportado preserva estrutura e contexto migrado', () async {
    final caminho = p.join(tempDir.path, 'backup_origem.db');
    final v1 = await criarBancoV1('backup_origem.db');
    await v1.close();
    final db = await databaseFactoryFfi.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: AppDatabase.versaoAtual,
        onConfigure: AppDatabase.prepararBancoParaMigracao,
        onCreate: AppDatabase.criarEsquemaAtual,
        onUpgrade: AppDatabase.migrarEsquema,
        onOpen: AppDatabase.configurarBanco,
      ),
    );
    AppDatabase.injetarBancoParaTestes(db);
    final service = BackupService(
      obterBanco: () async => db,
      fecharBanco: () async {},
      caminhoBanco: () async => caminho,
    );
    final backup = await service.exportar();
    await service.validarArquivo(backup);
    final copiado = await databaseFactoryFfi.openDatabase(
      backup.path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    expect(
      (await copiado.query('contextos_trabalho')).single['tipo'],
      'individual',
    );
    expect(await copiado.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await copiado.close();
    await backup.delete();
    await db.close();
  });

  test(
    'restaura backup v1 e migra sem remover a estrutura existente',
    () async {
      final backupV1 = await criarBancoV1('legado.db');
      await backupV1.close();

      final caminhoAlvo = p.join(tempDir.path, 'restauracao.db');
      Database? dbAtual;
      Future<Database> abrirAtual() async {
        dbAtual ??= await databaseFactoryFfi.openDatabase(
          caminhoAlvo,
          options: OpenDatabaseOptions(
            version: AppDatabase.versaoAtual,
            onConfigure: AppDatabase.prepararBancoParaMigracao,
            onCreate: AppDatabase.criarEsquemaAtual,
            onUpgrade: AppDatabase.migrarEsquema,
            onOpen: AppDatabase.configurarBanco,
          ),
        );
        return dbAtual!;
      }

      final service = BackupService(
        obterBanco: abrirAtual,
        fecharBanco: () async {
          await dbAtual?.close();
          dbAtual = null;
        },
        caminhoBanco: () async => caminhoAlvo,
      );
      await abrirAtual();
      await service.restaurar(File(p.join(tempDir.path, 'legado.db')));

      final restaurado = await abrirAtual();
      expect(await restaurado.getVersion(), AppDatabase.versaoAtual);
      expect(
        (await restaurado.query('contextos_trabalho')).single['tipo'],
        'individual',
      );
      expect(await restaurado.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await restaurado.rawQuery(
          'PRAGMA integrity_check',
        )).single.values.single,
        'ok',
      );
      await restaurado.close();
      dbAtual = null;
    },
  );
}

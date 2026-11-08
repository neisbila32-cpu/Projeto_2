import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/backup/services/backup_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late Database db;
  late String contextoIndividual;
  late int produtoIndividual;
  late int produtoCompartilhado;
  late int usuarioIndividual;
  late int usuarioCompartilhado;

  Future<Database> abrirV4(String caminho) => databaseFactoryFfi.openDatabase(
    caminho,
    options: OpenDatabaseOptions(
      version: AppDatabase.versaoAtual,
      onConfigure: AppDatabase.prepararBancoParaMigracao,
      onCreate: AppDatabase.criarEsquemaAtual,
      onUpgrade: AppDatabase.migrarEsquema,
      onOpen: AppDatabase.configurarBanco,
    ),
  );

  Future<Database> abrirV2(String caminho) => databaseFactoryFfi.openDatabase(
    caminho,
    options: OpenDatabaseOptions(
      version: 2,
      onConfigure: AppDatabase.prepararBancoParaMigracao,
      onCreate: (banco, version) => AppDatabase.criarEsquemaAtual(banco, 2),
      onOpen: AppDatabase.configurarBanco,
    ),
  );

  BackupService servico() => BackupService(
    obterBanco: () async => db,
    fecharBanco: () async {},
    caminhoBanco: () async => db.path,
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_contextos_');
    final caminhoBanco = p.join(tempDir.path, 'estoque.db');
    db = await abrirV2(caminhoBanco);
    contextoIndividual =
        (await db.query('contexto_trabalho_atual')).single['contexto_id']
            as String;
    final agora = DateTime.now().toIso8601String();
    const contextoCompartilhado = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    await db.insert('contextos_trabalho', {
      'id': contextoCompartilhado,
      'tipo': 'compartilhado',
      'nome': 'UAN compartilhada',
      'uan_remota_id': 'uan-teste',
      'criado_em': agora,
      'ativo': 1,
    });

    final unidadeIndividual =
        (await db.query(
              'unidades',
              where: 'contexto_id = ?',
              whereArgs: [contextoIndividual],
              limit: 1,
            )).single['id']
            as int;
    final categoriaIndividual =
        (await db.query(
              'categorias',
              where: 'contexto_id = ?',
              whereArgs: [contextoIndividual],
              limit: 1,
            )).single['id']
            as int;
    final unidadeCompartilhada = await db.insert('unidades', {
      'id': 500,
      'sigla': 'u-shared',
      'nome': 'Unidade compartilhada',
      'fracionavel': 0,
      'ativa': 1,
      'contexto_id': contextoCompartilhado,
    });
    final categoriaCompartilhada = await db.insert('categorias', {
      'id': 500,
      'nome': 'Categoria compartilhada',
      'ativa': 1,
      'contexto_id': contextoCompartilhado,
    });
    usuarioIndividual = await db.insert('usuarios', {
      'nome': 'Admin local',
      'login': 'admin-local',
      'senha_hash': 'hash-local',
      'senha_salt': 'salt-local',
      'perfil': 'admin',
      'ativo': 1,
      'criado_em': agora,
      'contexto_id': contextoIndividual,
    });
    usuarioCompartilhado = await db.insert('usuarios', {
      'id': 500,
      'nome': 'Admin compartilhado',
      'login': 'admin-compartilhado',
      'senha_hash': 'hash-shared',
      'senha_salt': 'salt-shared',
      'perfil': 'admin',
      'ativo': 1,
      'criado_em': agora,
      'contexto_id': contextoCompartilhado,
    });
    produtoIndividual = await db.insert('produtos', {
      'nome': 'Produto local',
      'categoria_id': categoriaIndividual,
      'unidade_id': unidadeIndividual,
      'saldo': 12345,
      'ativo': 1,
      'criado_em': agora,
      'criado_por': usuarioIndividual,
      'contexto_id': contextoIndividual,
    });
    produtoCompartilhado = await db.insert('produtos', {
      'id': 500,
      'nome': 'Produto compartilhado',
      'categoria_id': categoriaCompartilhada,
      'unidade_id': unidadeCompartilhada,
      'saldo': 8000,
      'ativo': 1,
      'criado_em': agora,
      'criado_por': usuarioCompartilhado,
      'contexto_id': contextoCompartilhado,
    });
    final inventarioLocal = await db.insert('inventarios', {
      'data_hora': agora,
      'usuario_id': usuarioIndividual,
      'status': 'finalizado',
      'observacao': 'Inventário local',
      'contexto_id': contextoIndividual,
    });
    await db.insert('movimentacoes', {
      'produto_id': produtoIndividual,
      'tipo': 'entrada',
      'delta': 12345,
      'saldo_apos': 12345,
      'data_hora': agora,
      'usuario_id': usuarioIndividual,
      'observacao': 'Histórico local',
      'inventario_id': inventarioLocal,
      'contexto_id': contextoIndividual,
    });
    await db.insert('itens_inventario', {
      'inventario_id': inventarioLocal,
      'produto_id': produtoIndividual,
      'qtd_sistema': 12345,
      'qtd_contada': 12345,
      'divergencia': 0,
      'contexto_id': contextoIndividual,
    });
    final inventarioCompartilhado = await db.insert('inventarios', {
      'id': 500,
      'data_hora': agora,
      'usuario_id': usuarioCompartilhado,
      'status': 'em_andamento',
      'contexto_id': contextoCompartilhado,
    });
    await db.insert('movimentacoes', {
      'id': 500,
      'produto_id': produtoCompartilhado,
      'tipo': 'entrada',
      'delta': 8000,
      'saldo_apos': 8000,
      'data_hora': agora,
      'usuario_id': usuarioCompartilhado,
      'inventario_id': inventarioCompartilhado,
      'contexto_id': contextoCompartilhado,
    });
    await db.close();
    db = await abrirV4(caminhoBanco);
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'exporta apenas contexto individual preservando saldos e históricos',
    () async {
      final arquivo = await servico().exportar();
      final backup = await databaseFactoryFfi.openDatabase(
        arquivo.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      expect(await backup.getVersion(), 4);
      expect((await backup.query('contextos_trabalho')), hasLength(1));
      expect((await backup.query('produtos')), hasLength(1));
      expect((await backup.query('produtos')).single['saldo'], 12345);
      expect((await backup.query('unidades')).isNotEmpty, isTrue);
      expect((await backup.query('categorias')).isNotEmpty, isTrue);
      expect((await backup.query('usuarios')), hasLength(1));
      expect((await backup.query('inventarios')), hasLength(1));
      expect((await backup.query('movimentacoes')), hasLength(1));
      expect((await backup.query('itens_inventario')), hasLength(1));
      expect(await backup.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await backup.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok',
      );
      await backup.close();
      await arquivo.delete();
    },
  );

  test(
    'restauração v4 mantém intactos os registros de outro contexto',
    () async {
      final arquivo = await servico().exportar();
      await db.update(
        'produtos',
        {'saldo': 99},
        where: 'id = ?',
        whereArgs: [produtoIndividual],
      );
      await db.delete(
        'movimentacoes',
        where: 'produto_id = ?',
        whereArgs: [produtoIndividual],
      );

      await servico().restaurar(arquivo);

      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [produtoIndividual],
        )).single['saldo'],
        12345,
      );
      expect(
        (await db.query(
          'movimentacoes',
          where: 'produto_id = ?',
          whereArgs: [produtoIndividual],
        )),
        hasLength(1),
      );
      expect(
        (await db.query(
          'itens_inventario',
          where: 'produto_id = ?',
          whereArgs: [produtoIndividual],
        )),
        hasLength(1),
      );
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [produtoCompartilhado],
        )).single['saldo'],
        8000,
      );
      expect(
        (await db.query(
          'movimentacoes',
          where: 'id = 500',
        )).single['saldo_apos'],
        8000,
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await arquivo.delete();
    },
  );

  test(
    'restaura backup v1 após migração em cópia e mantém os outros contextos',
    () async {
      final caminho = p.join(tempDir.path, 'legado_v1.db');
      final legado = await databaseFactoryFfi.openDatabase(
        caminho,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: AppDatabase.configurarBanco,
          onCreate: AppDatabase.criarEsquema,
        ),
      );
      final agora = DateTime.now().toIso8601String();
      final unidade =
          (await legado.query('unidades', limit: 1)).single['id'] as int;
      final categoria =
          (await legado.query('categorias', limit: 1)).single['id'] as int;
      await legado.insert('usuarios', {
        'id': 100,
        'nome': 'Admin legado',
        'login': 'admin-legado',
        'senha_hash': 'hash-legado',
        'senha_salt': 'salt-legado',
        'perfil': 'admin',
        'ativo': 1,
        'criado_em': agora,
      });
      await legado.insert('produtos', {
        'id': 700,
        'nome': 'Produto legado',
        'categoria_id': categoria,
        'unidade_id': unidade,
        'saldo': 45678,
        'ativo': 1,
        'criado_em': agora,
        'criado_por': 100,
      });
      await legado.insert('inventarios', {
        'id': 701,
        'data_hora': agora,
        'usuario_id': 100,
        'status': 'finalizado',
        'observacao': 'Inventário legado',
      });
      await legado.insert('movimentacoes', {
        'id': 702,
        'produto_id': 700,
        'tipo': 'entrada',
        'delta': 45678,
        'saldo_apos': 45678,
        'data_hora': agora,
        'usuario_id': 100,
        'inventario_id': 701,
      });
      await legado.insert('itens_inventario', {
        'id': 703,
        'inventario_id': 701,
        'produto_id': 700,
        'qtd_sistema': 45678,
        'qtd_contada': 45678,
        'divergencia': 0,
      });
      await legado.close();

      await servico().restaurar(File(caminho));

      expect(await db.getVersion(), 4);
      expect(
        (await db.query('produtos', where: 'id = 700')).single['saldo'],
        45678,
      );
      expect(
        (await db.query('usuarios', where: 'id = 100')).single['senha_hash'],
        'hash-legado',
      );
      expect(
        (await db.query(
          'movimentacoes',
          where: 'id = 702',
        )).single['produto_id'],
        700,
      );
      expect(
        (await db.query(
          'itens_inventario',
          where: 'id = 703',
        )).single['inventario_id'],
        701,
      );
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [produtoCompartilhado],
        )).single['saldo'],
        8000,
      );
      expect(
        (await db.query('movimentacoes', where: 'id = 500')),
        hasLength(1),
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'falha por colisão de ID compartilhado não altera nenhum dado',
    () async {
      final caminho = p.join(tempDir.path, 'colisao_v1.db');
      final legado = await databaseFactoryFfi.openDatabase(
        caminho,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: AppDatabase.configurarBanco,
          onCreate: AppDatabase.criarEsquema,
        ),
      );
      final agora = DateTime.now().toIso8601String();
      final unidade =
          (await legado.query('unidades', limit: 1)).single['id'] as int;
      final categoria =
          (await legado.query('categorias', limit: 1)).single['id'] as int;
      await legado.insert('usuarios', {
        'id': 500,
        'nome': 'Usuário do backup',
        'login': 'usuario-backup',
        'senha_hash': 'hash',
        'senha_salt': 'salt',
        'perfil': 'admin',
        'criado_em': agora,
      });
      await legado.insert('produtos', {
        'id': 700,
        'nome': 'Produto do backup',
        'categoria_id': categoria,
        'unidade_id': unidade,
        'saldo': 777,
        'ativo': 1,
        'criado_em': agora,
        'criado_por': 500,
      });
      await legado.close();

      // Colisão real no identificador de usuário: a restauração deve recusar
      // antes da transação para não remapear nem sobrescrever o outro contexto.
      await expectLater(
        servico().restaurar(File(caminho)),
        throwsA(isA<AppException>()),
      );
      expect(
        (await db.query('usuarios', where: 'id = 500')).single['nome'],
        'Admin compartilhado',
      );
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [produtoIndividual],
        )).single['saldo'],
        12345,
      );
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [produtoCompartilhado],
        )).single['saldo'],
        8000,
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'falha durante a transação de restauração reverte o contexto local',
    () async {
      final arquivo = await servico().exportar();
      await db.execute('''
      CREATE TRIGGER falha_simulada_restore
      BEFORE INSERT ON produtos
      WHEN NEW.id = $produtoIndividual
      BEGIN
        SELECT RAISE(ABORT, 'falha simulada de restauração');
      END
    ''');

      await expectLater(
        servico().restaurar(arquivo),
        throwsA(isA<AppException>()),
      );

      await db.execute('DROP TRIGGER falha_simulada_restore');
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [produtoIndividual],
        )).single['saldo'],
        12345,
      );
      expect(
        (await db.query(
          'movimentacoes',
          where: 'produto_id = ?',
          whereArgs: [produtoIndividual],
        )),
        hasLength(1),
      );
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [produtoCompartilhado],
        )).single['saldo'],
        8000,
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await arquivo.delete();
    },
  );

  test(
    'erro de exportação por contexto inativo e backup inválido preserva banco',
    () async {
      await db.update(
        'contextos_trabalho',
        {'ativo': 0},
        where: 'id = ?',
        whereArgs: [contextoIndividual],
      );
      await expectLater(servico().exportar(), throwsA(isA<AppException>()));
      await db.update(
        'contextos_trabalho',
        {'ativo': 1},
        where: 'id = ?',
        whereArgs: [contextoIndividual],
      );

      final arquivoInvalido = File(p.join(tempDir.path, 'invalido.db'));
      await arquivoInvalido.writeAsBytes([1, 2, 3, 4]);
      await expectLater(
        servico().restaurar(arquivoInvalido),
        throwsA(isA<AppException>()),
      );
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [produtoIndividual],
        )).single['saldo'],
        12345,
      );
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [produtoCompartilhado],
        )).single['saldo'],
        8000,
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
}

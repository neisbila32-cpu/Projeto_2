import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Acesso único ao banco SQLite local do app.
/// Quantidades são sempre INTEIROS em milésimos (1,5 kg = 1500).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String _dbName = 'estoque_uan.db';
  static const int _dbVersion = 3;

  @visibleForTesting
  static int get versaoAtual => _dbVersion;

  /// Tabelas cujas linhas pertencem a um contexto de trabalho.
  static const List<String> tabelasComContexto = [
    'unidades',
    'categorias',
    'usuarios',
    'produtos',
    'inventarios',
    'movimentacoes',
    'itens_inventario',
  ];

  Future<Database>? _dbFuture;

  Future<Database> get database => _dbFuture ??= _open();

  /// Caminho completo do arquivo do banco.
  Future<String> caminho() async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, _dbName);
  }

  /// Fecha a conexão e zera a instância; o próximo acesso reabre o arquivo.
  Future<void> fechar() async {
    final futuro = _dbFuture;
    _dbFuture = null;
    if (futuro != null) {
      try {
        final db = await futuro;
        await db.close();
      } catch (_) {}
    }
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: migrarEsquema,
    );
  }

  /// Injeta um banco de teste (em memória ou arquivo) no singleton.
  /// Somente para uso em testes; não altera o comportamento de produção.
  @visibleForTesting
  static void injetarBancoParaTestes(Database db) {
    AppDatabase.instance._dbFuture = Future.value(db);
  }

  /// Configura o banco (PRAGMAs). Extraído para reutilização em testes.
  static Future<void> configurarBanco(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Cria o esquema original da versão 1.
  /// Mantido para montar fixtures de migração e compatibilidade dos testes.
  static Future<void> criarEsquema(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE unidades (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        sigla       TEXT NOT NULL UNIQUE,
        nome        TEXT NOT NULL,
        fracionavel INTEGER NOT NULL CHECK (fracionavel IN (0,1)),
        ativa       INTEGER NOT NULL DEFAULT 1
      )
    ''');

    batch.execute('''
      CREATE TABLE categorias (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        nome  TEXT NOT NULL UNIQUE,
        ativa INTEGER NOT NULL DEFAULT 1
      )
    ''');

    batch.execute('''
      CREATE TABLE usuarios (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        nome        TEXT NOT NULL,
        login       TEXT NOT NULL UNIQUE,
        senha_hash  TEXT NOT NULL,
        senha_salt  TEXT NOT NULL,
        perfil      TEXT NOT NULL CHECK (perfil IN ('admin','operador')),
        recup_hash  TEXT,
        recup_salt  TEXT,
        ativo       INTEGER NOT NULL DEFAULT 1,
        criado_em   TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE produtos (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        nome         TEXT NOT NULL,
        categoria_id INTEGER NOT NULL REFERENCES categorias(id),
        unidade_id   INTEGER NOT NULL REFERENCES unidades(id),
        saldo        INTEGER NOT NULL DEFAULT 0,
        ativo        INTEGER NOT NULL DEFAULT 1,
        criado_em    TEXT NOT NULL,
        criado_por   INTEGER NOT NULL REFERENCES usuarios(id)
      )
    ''');
    batch.execute('CREATE INDEX idx_produtos_nome ON produtos(nome)');

    batch.execute('''
      CREATE TABLE inventarios (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        data_hora  TEXT NOT NULL,
        usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
        status     TEXT NOT NULL CHECK (status IN ('em_andamento','finalizado')),
        observacao TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE movimentacoes (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        produto_id    INTEGER NOT NULL REFERENCES produtos(id),
        tipo          TEXT NOT NULL CHECK (tipo IN ('entrada','saida','perda','ajuste')),
        finalidade    TEXT CHECK (finalidade IN ('producao','transferencia','outra')),
        delta         INTEGER NOT NULL CHECK (delta <> 0),
        saldo_apos    INTEGER NOT NULL,
        data_hora     TEXT NOT NULL,
        usuario_id    INTEGER NOT NULL REFERENCES usuarios(id),
        observacao    TEXT,
        inventario_id INTEGER REFERENCES inventarios(id)
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_mov_produto_data ON movimentacoes(produto_id, data_hora)',
    );
    batch.execute('CREATE INDEX idx_mov_data ON movimentacoes(data_hora)');

    batch.execute('''
      CREATE TABLE itens_inventario (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        inventario_id INTEGER NOT NULL REFERENCES inventarios(id),
        produto_id    INTEGER NOT NULL REFERENCES produtos(id),
        qtd_sistema   INTEGER NOT NULL,
        qtd_contada   INTEGER NOT NULL,
        divergencia   INTEGER NOT NULL,
        justificativa TEXT,
        ajustado      INTEGER NOT NULL DEFAULT 0,
        UNIQUE (inventario_id, produto_id)
      )
    ''');

    // Dados iniciais: unidades (fracionavel: 1 = aceita decimais, 0 = só inteiros)
    const unidades = <List<Object>>[
      ['kg', 'Quilograma', 1],
      ['g', 'Grama', 1],
      ['L', 'Litro', 1],
      ['mL', 'Mililitro', 1],
      ['un', 'Unidade', 0],
      ['pct', 'Pacote', 0],
      ['cx', 'Caixa', 0],
      ['fardo', 'Fardo', 0],
      ['saco', 'Saco', 0],
      ['lata', 'Lata', 0],
      ['garrafa', 'Garrafa', 0],
      ['bandeja', 'Bandeja', 0],
    ];
    for (final u in unidades) {
      batch.insert('unidades', {
        'sigla': u[0],
        'nome': u[1],
        'fracionavel': u[2],
      });
    }

    const categorias = <String>[
      'Gêneros secos',
      'Perecíveis',
      'Hortifrúti',
      'Descartáveis',
      'Material de limpeza',
    ];
    for (final c in categorias) {
      batch.insert('categorias', {'nome': c});
    }

    await batch.commit(noResult: true);
  }

  /// Cria um banco novo diretamente no esquema atual, passando pelas mesmas
  /// migrações incrementais usadas ao atualizar um banco existente.
  static Future<void> criarEsquemaAtual(Database db, int version) async {
    await criarEsquema(db, 1);
    if (version > 1) {
      await migrarEsquema(db, 1, version);
    }
  }

  /// Aplica as migrações sequenciais entre [versaoAntiga] e [novaVersao].
  /// O sqflite executa este callback dentro da transação de upgrade.
  static Future<void> migrarEsquema(
    Database db,
    int versaoAntiga,
    int novaVersao,
  ) async {
    for (var versao = versaoAntiga + 1; versao <= novaVersao; versao++) {
      switch (versao) {
        case 2:
          await _migrarParaVersao2(db);
          break;
        case 3:
          await _migrarParaVersao3(db);
          break;
        default:
          throw StateError('Migração SQLite não implementada: $versao.');
      }
    }
  }

  static Future<void> _migrarParaVersao2(DatabaseExecutor db) async {
    final agora = DateTime.now().toIso8601String();
    final contextoId = _novoUuid();

    await db.execute('''
      CREATE TABLE contextos_trabalho (
        id             TEXT PRIMARY KEY NOT NULL,
        tipo           TEXT NOT NULL CHECK (tipo IN ('individual','compartilhado')),
        nome           TEXT NOT NULL,
        uan_remota_id  TEXT UNIQUE,
        criado_em      TEXT NOT NULL,
        ativo          INTEGER NOT NULL DEFAULT 1 CHECK (ativo IN (0,1)),
        CHECK (
          (tipo = 'individual' AND uan_remota_id IS NULL) OR
          (tipo = 'compartilhado' AND uan_remota_id IS NOT NULL)
        )
      )
    ''');
    await db.insert('contextos_trabalho', {
      'id': contextoId,
      'tipo': 'individual',
      'nome': 'Individual',
      'uan_remota_id': null,
      'criado_em': agora,
      'ativo': 1,
    });
    await db.execute('''
      CREATE TABLE contexto_trabalho_atual (
        id           INTEGER PRIMARY KEY CHECK (id = 1),
        contexto_id  TEXT NOT NULL REFERENCES contextos_trabalho(id)
      )
    ''');
    await db.insert('contexto_trabalho_atual', {
      'id': 1,
      'contexto_id': contextoId,
    });

    for (final tabela in tabelasComContexto) {
      await db.execute(
        'ALTER TABLE $tabela ADD COLUMN contexto_id TEXT '
        'REFERENCES contextos_trabalho(id)',
      );
      await db.update(tabela, {
        'contexto_id': contextoId,
      }, where: 'contexto_id IS NULL');
      await db.execute(
        'CREATE INDEX idx_${tabela}_contexto ON $tabela(contexto_id)',
      );
      await db.execute('''
        CREATE TRIGGER trg_${tabela}_contexto_padrao
        AFTER INSERT ON $tabela
        WHEN NEW.contexto_id IS NULL
        BEGIN
          UPDATE $tabela
          SET contexto_id = (
            SELECT contexto_id FROM contexto_trabalho_atual WHERE id = 1
          )
          WHERE id = NEW.id;
        END
      ''');
    }
  }

  static Future<void> _migrarParaVersao3(DatabaseExecutor db) async {
    final contextoAtivo = await db.rawQuery('''
      SELECT c.tipo, c.ativo
      FROM contexto_trabalho_atual atual
      JOIN contextos_trabalho c ON c.id = atual.contexto_id
      WHERE atual.id = 1
    ''');
    if (contextoAtivo.length != 1 ||
        contextoAtivo.single['tipo'] != 'individual' ||
        contextoAtivo.single['ativo'] != 1) {
      throw StateError(
        'Não é possível migrar enquanto o contexto ativo não for individual e estiver ativo.',
      );
    }
    await _validarRelacoesDaVersao2(db);

    for (final tabela in tabelasComContexto) {
      await db.execute('DROP TRIGGER IF EXISTS trg_${tabela}_contexto_padrao');
      await db.execute('''
        CREATE TRIGGER trg_${tabela}_contexto_validar_insercao
        BEFORE INSERT ON $tabela
        BEGIN
          SELECT CASE WHEN NOT EXISTS (
            SELECT 1
            FROM contexto_trabalho_atual atual
            JOIN contextos_trabalho contexto
              ON contexto.id = COALESCE(NEW.contexto_id, atual.contexto_id)
            WHERE atual.id = 1
              AND contexto.id = atual.contexto_id
              AND contexto.tipo = 'individual'
              AND contexto.ativo = 1
          ) THEN RAISE(ABORT, 'Contexto individual ativo inválido.') END;
        END
      ''');
      await db.execute('''
        CREATE TRIGGER trg_${tabela}_contexto_padrao
        AFTER INSERT ON $tabela
        WHEN NEW.contexto_id IS NULL
        BEGIN
          UPDATE $tabela
          SET contexto_id = (
            SELECT contexto.id
            FROM contexto_trabalho_atual atual
            JOIN contextos_trabalho contexto
              ON contexto.id = atual.contexto_id
            WHERE atual.id = 1
              AND contexto.tipo = 'individual'
              AND contexto.ativo = 1
          )
          WHERE id = NEW.id;
        END
      ''');
      await db.execute('''
        CREATE TRIGGER trg_${tabela}_contexto_imutavel
        BEFORE UPDATE OF contexto_id ON $tabela
        WHEN OLD.contexto_id IS NOT NULL
          AND NEW.contexto_id IS NOT OLD.contexto_id
        BEGIN
          SELECT RAISE(ABORT, 'O registro não pode ser movido entre contextos.');
        END
      ''');
    }

    await db.execute('''
      CREATE TRIGGER trg_contexto_atual_imutavel
      BEFORE UPDATE OF contexto_id ON contexto_trabalho_atual
      WHEN NEW.contexto_id IS NOT OLD.contexto_id
      BEGIN
        SELECT RAISE(ABORT, 'A alternância entre contextos ainda não está habilitada.');
      END
    ''');

    await _criarGatilhoRelacao(
      db,
      nome: 'trg_produtos_relacoes_contexto_insert',
      tabela: 'produtos',
      evento: 'INSERT',
      colunas: '',
      condicao: '''
        EXISTS (
          SELECT 1 FROM categorias c WHERE c.id = NEW.categoria_id
            AND c.contexto_id IS NOT COALESCE(NEW.contexto_id, (SELECT contexto_id FROM contexto_trabalho_atual WHERE id = 1))
        ) OR EXISTS (
          SELECT 1 FROM unidades un WHERE un.id = NEW.unidade_id
            AND un.contexto_id IS NOT COALESCE(NEW.contexto_id, (SELECT contexto_id FROM contexto_trabalho_atual WHERE id = 1))
        ) OR EXISTS (
          SELECT 1 FROM usuarios us WHERE us.id = NEW.criado_por
            AND us.contexto_id IS NOT COALESCE(NEW.contexto_id, (SELECT contexto_id FROM contexto_trabalho_atual WHERE id = 1))
        )
      ''',
    );
    await _criarGatilhoRelacao(
      db,
      nome: 'trg_produtos_relacoes_contexto_update',
      tabela: 'produtos',
      evento: 'UPDATE',
      colunas: 'categoria_id, unidade_id, criado_por, contexto_id',
      condicao: '''
        EXISTS (
          SELECT 1 FROM categorias c WHERE c.id = NEW.categoria_id
            AND c.contexto_id IS NOT NEW.contexto_id
        ) OR EXISTS (
          SELECT 1 FROM unidades un WHERE un.id = NEW.unidade_id
            AND un.contexto_id IS NOT NEW.contexto_id
        ) OR EXISTS (
          SELECT 1 FROM usuarios us WHERE us.id = NEW.criado_por
            AND us.contexto_id IS NOT NEW.contexto_id
        )
      ''',
    );
    await _criarGatilhoRelacao(
      db,
      nome: 'trg_inventarios_relacao_contexto_insert',
      tabela: 'inventarios',
      evento: 'INSERT',
      colunas: '',
      condicao: '''
        EXISTS (
          SELECT 1 FROM usuarios us WHERE us.id = NEW.usuario_id
            AND us.contexto_id IS NOT COALESCE(NEW.contexto_id, (SELECT contexto_id FROM contexto_trabalho_atual WHERE id = 1))
        )
      ''',
    );
    await _criarGatilhoRelacao(
      db,
      nome: 'trg_inventarios_relacao_contexto_update',
      tabela: 'inventarios',
      evento: 'UPDATE',
      colunas: 'usuario_id, contexto_id',
      condicao: '''
        EXISTS (
          SELECT 1 FROM usuarios us WHERE us.id = NEW.usuario_id
            AND us.contexto_id IS NOT NEW.contexto_id
        )
      ''',
    );
    await _criarGatilhoRelacao(
      db,
      nome: 'trg_movimentacoes_relacoes_contexto_insert',
      tabela: 'movimentacoes',
      evento: 'INSERT',
      colunas: '',
      condicao: '''
        EXISTS (
          SELECT 1 FROM produtos p WHERE p.id = NEW.produto_id
            AND p.contexto_id IS NOT COALESCE(NEW.contexto_id, (SELECT contexto_id FROM contexto_trabalho_atual WHERE id = 1))
        ) OR EXISTS (
          SELECT 1 FROM usuarios us WHERE us.id = NEW.usuario_id
            AND us.contexto_id IS NOT COALESCE(NEW.contexto_id, (SELECT contexto_id FROM contexto_trabalho_atual WHERE id = 1))
        ) OR (
          NEW.inventario_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM inventarios i WHERE i.id = NEW.inventario_id
              AND i.contexto_id IS NOT COALESCE(NEW.contexto_id, (SELECT contexto_id FROM contexto_trabalho_atual WHERE id = 1))
          )
        )
      ''',
    );
    await _criarGatilhoRelacao(
      db,
      nome: 'trg_movimentacoes_relacoes_contexto_update',
      tabela: 'movimentacoes',
      evento: 'UPDATE',
      colunas: 'produto_id, usuario_id, inventario_id, contexto_id',
      condicao: '''
        EXISTS (
          SELECT 1 FROM produtos p WHERE p.id = NEW.produto_id
            AND p.contexto_id IS NOT NEW.contexto_id
        ) OR EXISTS (
          SELECT 1 FROM usuarios us WHERE us.id = NEW.usuario_id
            AND us.contexto_id IS NOT NEW.contexto_id
        ) OR (
          NEW.inventario_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM inventarios i WHERE i.id = NEW.inventario_id
              AND i.contexto_id IS NOT NEW.contexto_id
          )
        )
      ''',
    );
    await _criarGatilhoRelacao(
      db,
      nome: 'trg_itens_inventario_relacoes_contexto_insert',
      tabela: 'itens_inventario',
      evento: 'INSERT',
      colunas: '',
      condicao: '''
        EXISTS (
          SELECT 1 FROM inventarios i WHERE i.id = NEW.inventario_id
            AND i.contexto_id IS NOT COALESCE(NEW.contexto_id, (SELECT contexto_id FROM contexto_trabalho_atual WHERE id = 1))
        ) OR EXISTS (
          SELECT 1 FROM produtos p WHERE p.id = NEW.produto_id
            AND p.contexto_id IS NOT COALESCE(NEW.contexto_id, (SELECT contexto_id FROM contexto_trabalho_atual WHERE id = 1))
        )
      ''',
    );
    await _criarGatilhoRelacao(
      db,
      nome: 'trg_itens_inventario_relacoes_contexto_update',
      tabela: 'itens_inventario',
      evento: 'UPDATE',
      colunas: 'inventario_id, produto_id, contexto_id',
      condicao: '''
        EXISTS (
          SELECT 1 FROM inventarios i WHERE i.id = NEW.inventario_id
            AND i.contexto_id IS NOT NEW.contexto_id
        ) OR EXISTS (
          SELECT 1 FROM produtos p WHERE p.id = NEW.produto_id
            AND p.contexto_id IS NOT NEW.contexto_id
        )
      ''',
    );
  }

  static Future<void> _validarRelacoesDaVersao2(DatabaseExecutor db) async {
    const consultas = <String>[
      '''
        SELECT COUNT(*) AS total
        FROM produtos p
        LEFT JOIN categorias c ON c.id = p.categoria_id
        LEFT JOIN unidades un ON un.id = p.unidade_id
        LEFT JOIN usuarios us ON us.id = p.criado_por
        WHERE p.contexto_id IS NULL OR c.contexto_id IS NOT p.contexto_id
          OR un.contexto_id IS NOT p.contexto_id
          OR us.contexto_id IS NOT p.contexto_id
      ''',
      '''
        SELECT COUNT(*) AS total
        FROM inventarios i
        LEFT JOIN usuarios us ON us.id = i.usuario_id
        WHERE i.contexto_id IS NULL OR us.contexto_id IS NOT i.contexto_id
      ''',
      '''
        SELECT COUNT(*) AS total
        FROM movimentacoes m
        LEFT JOIN produtos p ON p.id = m.produto_id
        LEFT JOIN usuarios us ON us.id = m.usuario_id
        LEFT JOIN inventarios i ON i.id = m.inventario_id
        WHERE m.contexto_id IS NULL OR p.contexto_id IS NOT m.contexto_id
          OR us.contexto_id IS NOT m.contexto_id
          OR (m.inventario_id IS NOT NULL AND i.contexto_id IS NOT m.contexto_id)
      ''',
      '''
        SELECT COUNT(*) AS total
        FROM itens_inventario x
        LEFT JOIN inventarios i ON i.id = x.inventario_id
        LEFT JOIN produtos p ON p.id = x.produto_id
        WHERE x.contexto_id IS NULL OR i.contexto_id IS NOT x.contexto_id
          OR p.contexto_id IS NOT x.contexto_id
      ''',
    ];
    for (final consulta in consultas) {
      final linhas = await db.rawQuery(consulta);
      if ((Sqflite.firstIntValue(linhas) ?? 0) != 0) {
        throw StateError(
          'A migração foi cancelada porque há relações entre contextos diferentes. Os dados foram preservados.',
        );
      }
    }
  }

  static Future<void> _criarGatilhoRelacao(
    DatabaseExecutor db, {
    required String nome,
    required String tabela,
    required String evento,
    required String colunas,
    required String condicao,
  }) async {
    final atualizacao = evento == 'UPDATE' ? ' OF $colunas' : '';
    await db.execute('''
      CREATE TRIGGER $nome
      BEFORE $evento$atualizacao ON $tabela
      WHEN $condicao
      BEGIN
        SELECT RAISE(ABORT, 'Relacionamento entre contextos diferentes.');
      END
    ''');
  }

  static String _novoUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<void> _onConfigure(Database db) async {
    await configurarBanco(db);
  }

  Future<void> _onCreate(Database db, int version) async {
    await criarEsquemaAtual(db, version);
  }
}

/// Provider para acessar o banco nas features.
final databaseProvider = FutureProvider<Database>((ref) {
  return AppDatabase.instance.database;
});

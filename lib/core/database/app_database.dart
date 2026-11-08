import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Acesso único ao banco SQLite local do app.
/// Quantidades são sempre INTEIROS em milésimos (1,5 kg = 1500).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String _dbName = 'estoque_uan.db';
  static const int _dbVersion = 2;

  @visibleForTesting
  static int get versaoAtual => _dbVersion;

  /// Tabelas cujas linhas pertencem a um contexto de trabalho.
  @visibleForTesting
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
  @visibleForTesting
  static Future<void> criarEsquemaAtual(Database db, int version) async {
    await criarEsquema(db, 1);
    if (version > 1) {
      await migrarEsquema(db, 1, version);
    }
  }

  /// Aplica as migrações sequenciais entre [versaoAntiga] e [novaVersao].
  /// O sqflite executa este callback dentro da transação de upgrade.
  @visibleForTesting
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

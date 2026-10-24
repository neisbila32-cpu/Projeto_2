import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Acesso único ao banco SQLite local do app.
/// Quantidades são sempre INTEIROS em milésimos (1,5 kg = 1500).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String _dbName = 'estoque_uan.db';
  static const int _dbVersion = 1;

  Future<Database>? _dbFuture;

  Future<Database> get database => _dbFuture ??= _open();

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
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
        'CREATE INDEX idx_mov_produto_data ON movimentacoes(produto_id, data_hora)');
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
}

/// Provider para acessar o banco nas features.
final databaseProvider = FutureProvider<Database>((ref) {
  return AppDatabase.instance.database;
});

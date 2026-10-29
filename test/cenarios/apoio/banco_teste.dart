import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:projeto_2/core/database/app_database.dart';

/// Abre um banco SQLite em memória com o MESMO esquema e dados iniciais da
/// produção (incluindo `PRAGMA foreign_keys = ON`) e o injeta no singleton
/// `AppDatabase`, de modo que os repositórios reais
/// (`UsuarioRepository`, `ProdutoRepository`, `CatalogoInicialRepository`,
/// `MovimentacaoRepository`, etc.) usem este banco nos testes.
///
/// Devolve [db] para uso direto quando necessário.
Future<Database> abrirBancoEmMemoria() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    ':memory:',
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: AppDatabase.configurarBanco,
      onCreate: AppDatabase.criarEsquema,
    ),
  );
  AppDatabase.injetarBancoParaTestes(db);
  return db;
}

/// Retorna uma fábrica [`Future<Database> Function()`] que sempre devolve o
/// [db] em memória criado. Útil para injetar em `MovimentacaoRepository`.
Future<Database> Function() bancoTesteFactory(Database db) => () async => db;

/// Remove todos os dados de todas as tabelas (respeitando foreign keys),
/// deixando o banco limpo para o próximo teste. Não dropa as tabelas nem os
/// dados iniciais de unidades/categorias criados no onCreate.
Future<void> limparDados(Database db) async {
  await db.delete('itens_inventario');
  await db.delete('movimentacoes');
  await db.delete('inventarios');
  await db.delete('produtos');
  await db.delete('usuarios');
  // mantém unidades e categorias (dados iniciais do onCreate)
}

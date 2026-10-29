import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/core/utils/texto_utils.dart';
import 'package:projeto_2/features/produtos/data/catalogo_inicial.dart';

class ResultadoImportacao {
  final int criados;
  final int ignorados;
  const ResultadoImportacao(this.criados, this.ignorados);
}

class CatalogoInicialRepository {
  CatalogoInicialRepository(this._appDb);

  final AppDatabase _appDb;

  Future<ResultadoImportacao> importar(int usuarioId) async {
    final db = await _appDb.database;
    return await db.transaction((txn) async {
      // a) Garantir unidade 'fr' (Frasco, fracionavel 0, ativa 1)
      final unidadesExistentes = await txn.query('unidades', columns: ['sigla', 'id']);
      final frExistente = unidadesExistentes.any(
        (u) => (u['sigla'] as String).toLowerCase() == 'fr',
      );
      if (!frExistente) {
        await txn.insert('unidades', {
          'sigla': 'fr',
          'nome': 'Frasco',
          'fracionavel': 0,
          'ativa': 1,
        });
      }

      // b) Garantir as 6 categorias do catálogo
      final categoriasExistentes = await txn.query(
        'categorias',
        columns: ['id', 'nome', 'ativa'],
      );
      final idsCategoriasCatalogo = <String, int>{};
      for (final catNome in categoriasCatalogo) {
        final normalizado = TextoUtils.normalizar(catNome);
        final existente = categoriasExistentes.firstWhere(
          (c) => TextoUtils.normalizar(c['nome'] as String) == normalizado,
          orElse: () => <String, Object?>{},
        );
        if (existente.isNotEmpty) {
          final id = existente['id'] as int;
          final ativa = (existente['ativa'] as int) == 1;
          if (!ativa) {
            await txn.update(
              'categorias',
              {'ativa': 1},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
          idsCategoriasCatalogo[normalizado] = id;
        } else {
          final id = await txn.insert(
            'categorias',
            {'nome': catNome, 'ativa': 1},
          );
          idsCategoriasCatalogo[normalizado] = id;
        }
      }

      // c) Inativar categorias de fábrica se nenhum produto as usar
      final categoriasParaInativar = [
        'Gêneros secos',
        'Perecíveis',
        'Hortifrúti',
        'Descartáveis',
      ];
      for (final catNome in categoriasParaInativar) {
        final normalizado = TextoUtils.normalizar(catNome);
        final existente = categoriasExistentes.firstWhere(
          (c) => TextoUtils.normalizar(c['nome'] as String) == normalizado,
          orElse: () => <String, Object?>{},
        );
        if (existente.isNotEmpty) {
          final id = existente['id'] as int;
          final produtosUsando = await txn.query(
            'produtos',
            columns: ['id'],
            where: 'categoria_id = ? AND ativo = 1',
            whereArgs: [id],
            limit: 1,
          );
          if (produtosUsando.isEmpty) {
            await txn.update(
              'categorias',
              {'ativa': 0},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      }

      // d) Importar produtos do catálogo
      int criados = 0;
      int ignorados = 0;

      final todasUnidades = await txn.query('unidades', columns: ['id', 'sigla']);
      final todasCategorias =
          await txn.query('categorias', columns: ['id', 'nome']);
      final produtosExistentes =
          await txn.query('produtos', columns: ['id', 'nome']);

      for (final item in catalogoInicial) {
        // Buscar unidade pela sigla
        final unidadeRow = todasUnidades.firstWhere(
          (u) => (u['sigla'] as String).toLowerCase() == item.unidade.toLowerCase(),
          orElse: () => <String, Object?>{},
        );
        if (unidadeRow.isEmpty) {
          throw AppException(
            'Unidade "${item.unidade}" não encontrada para o produto "${item.nome}".',
          );
        }
        final unidadeId = unidadeRow['id'] as int;

        // Buscar categoria pelo nome (normalizado)
        final categoriaRow = todasCategorias.firstWhere(
          (c) => TextoUtils.normalizar(c['nome'] as String) ==
              TextoUtils.normalizar(item.categoria),
          orElse: () => <String, Object?>{},
        );
        if (categoriaRow.isEmpty) {
          throw AppException(
            'Categoria "${item.categoria}" não encontrada para o produto "${item.nome}".',
          );
        }
        final categoriaId = categoriaRow['id'] as int;

        // Verificar nome duplicado (ativo ou inativo)
        final nomeNormalizado = TextoUtils.normalizar(item.nome);
        final duplicado = produtosExistentes.any(
          (p) => TextoUtils.normalizar(p['nome'] as String) == nomeNormalizado,
        );
        if (duplicado) {
          ignorados++;
          continue;
        }

        await txn.insert('produtos', {
          'nome': item.nome.trim(),
          'categoria_id': categoriaId,
          'unidade_id': unidadeId,
          'saldo': 0,
          'ativo': 1,
          'criado_em': DateTime.now().toIso8601String(),
          'criado_por': usuarioId,
        });
        criados++;
      }

      // e) Retornar resultado
      return ResultadoImportacao(criados, ignorados);
    });
  }
}

final catalogoInicialRepositoryProvider =
    Provider<CatalogoInicialRepository>((ref) {
  return CatalogoInicialRepository(AppDatabase.instance);
});
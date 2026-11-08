import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/contexto_trabalho_repository.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/core/utils/texto_utils.dart';

/// Produto recebido de uma fonte de catálogo, sem quantidade ou saldo.
class ProdutoCatalogoRecuperacao {
  const ProdutoCatalogoRecuperacao({
    required this.idOriginal,
    required this.nome,
    required this.categoria,
    required this.unidade,
  });

  final int idOriginal;
  final String nome;
  final String categoria;
  final String unidade;
}

/// Unidade necessária caso a instalação ainda não a tenha cadastrada.
class UnidadeCatalogoRecuperacao {
  const UnidadeCatalogoRecuperacao({
    required this.sigla,
    required this.nome,
    required this.fracionavel,
  });

  final String sigla;
  final String nome;
  final bool fracionavel;
}

class ResultadoRecuperacaoCatalogo {
  const ResultadoRecuperacaoCatalogo({
    required this.criados,
    required this.ignorados,
    required this.idsFinais,
  });

  final int criados;
  final int ignorados;
  final Map<int, int> idsFinais;
}

/// Importa apenas identidades do catálogo. Não grava saldos nem movimentações.
class CatalogoRecuperacaoRepository {
  CatalogoRecuperacaoRepository(this._obterBanco);

  final Future<Database> Function() _obterBanco;

  Future<ResultadoRecuperacaoCatalogo> importar({
    required int usuarioId,
    required DateTime importadoEm,
    required List<String> categorias,
    required List<UnidadeCatalogoRecuperacao> unidadesAusentes,
    required List<ProdutoCatalogoRecuperacao> produtos,
  }) async {
    _validarEntrada(categorias, unidadesAusentes, produtos);
    final banco = await _obterBanco();
    return banco.transaction((txn) async {
      final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(txn);
      final usuarios = await txn.query(
        'usuarios',
        columns: ['id', 'ativo'],
        where: 'id = ? AND contexto_id = ?',
        whereArgs: [usuarioId, contextoId],
        limit: 1,
      );
      if (usuarios.isEmpty || usuarios.first['ativo'] != 1) {
        throw const AppException(
          'O usuário autenticado não está disponível para recuperar o catálogo.',
        );
      }

      final categoriasId = await _garantirCategorias(
        txn,
        categorias,
        contextoId,
      );
      final unidadesId = await _garantirUnidades(
        txn,
        unidadesAusentes,
        produtos,
        contextoId,
      );
      final existentes = await txn.query(
        'produtos',
        columns: ['id', 'nome', 'categoria_id', 'unidade_id'],
        where: 'contexto_id = ?',
        whereArgs: [contextoId],
      );
      final porNome = <String, Map<String, Object?>>{};
      final idsOcupados = (await txn.query(
        'produtos',
        columns: ['id'],
      )).map((linha) => linha['id'] as int).toSet();
      for (final linha in existentes) {
        final chave = TextoUtils.normalizar(linha['nome'] as String);
        if (porNome.containsKey(chave)) {
          throw const AppException(
            'Há produtos duplicados no banco; a recuperação foi cancelada.',
          );
        }
        porNome[chave] = linha;
      }

      final idsFinais = <int, int>{};
      final pendentes = <ProdutoCatalogoRecuperacao>[];
      var ignorados = 0;
      for (final produto in produtos) {
        final chave = TextoUtils.normalizar(produto.nome);
        final existente = porNome[chave];
        final categoriaId =
            categoriasId[TextoUtils.normalizar(produto.categoria)]!;
        final unidadeId = unidadesId[produto.unidade.toLowerCase()]!;
        if (existente != null) {
          if (existente['categoria_id'] != categoriaId ||
              existente['unidade_id'] != unidadeId) {
            throw AppException(
              'O produto "${produto.nome}" já existe com categoria ou unidade diferente. '
              'Nenhum dado foi alterado.',
            );
          }
          idsFinais[produto.idOriginal] = existente['id'] as int;
          ignorados++;
        } else {
          pendentes.add(produto);
        }
      }

      // Reserve first all free source IDs so a collision such as ID 1 cannot
      // take an ID that belongs to another product in the incoming catalog.
      final comIdOriginal = pendentes
          .where((produto) => !idsOcupados.contains(produto.idOriginal))
          .toList();
      final comIdNovo = pendentes
          .where((produto) => idsOcupados.contains(produto.idOriginal))
          .toList();
      var criados = 0;
      for (final produto in [...comIdOriginal, ...comIdNovo]) {
        final categoriaId =
            categoriasId[TextoUtils.normalizar(produto.categoria)]!;
        final unidadeId = unidadesId[produto.unidade.toLowerCase()]!;
        final valores = <String, Object?>{
          'nome': produto.nome.trim(),
          'categoria_id': categoriaId,
          'unidade_id': unidadeId,
          'saldo': 0,
          'ativo': 1,
          'criado_em': importadoEm.toIso8601String(),
          'criado_por': usuarioId,
          'contexto_id': contextoId,
        };
        final id = idsOcupados.contains(produto.idOriginal)
            ? await txn.insert('produtos', valores)
            : await txn.insert('produtos', {
                'id': produto.idOriginal,
                ...valores,
              });
        idsFinais[produto.idOriginal] = id;
        idsOcupados.add(id);
        criados++;
      }

      return ResultadoRecuperacaoCatalogo(
        criados: criados,
        ignorados: ignorados,
        idsFinais: Map.unmodifiable(idsFinais),
      );
    });
  }

  Future<Map<String, int>> _garantirCategorias(
    DatabaseExecutor txn,
    List<String> nomes,
    String contextoId,
  ) async {
    final existentes = await txn.query(
      'categorias',
      where: 'contexto_id = ?',
      whereArgs: [contextoId],
    );
    final resultado = <String, int>{};
    for (final nome in nomes) {
      final chave = TextoUtils.normalizar(nome);
      final existente = existentes.cast<Map<String, Object?>>().firstWhere(
        (linha) => TextoUtils.normalizar(linha['nome'] as String) == chave,
        orElse: () => <String, Object?>{},
      );
      if (existente.isNotEmpty) {
        final id = existente['id'] as int;
        if (existente['ativa'] != 1) {
          await txn.update(
            'categorias',
            {'ativa': 1},
            where: 'id = ? AND contexto_id = ?',
            whereArgs: [id, contextoId],
          );
        }
        resultado[chave] = id;
      } else {
        final id = await txn.insert('categorias', {
          'nome': nome,
          'ativa': 1,
          'contexto_id': contextoId,
        });
        resultado[chave] = id;
      }
    }
    return resultado;
  }

  Future<Map<String, int>> _garantirUnidades(
    DatabaseExecutor txn,
    List<UnidadeCatalogoRecuperacao> unidadesAusentes,
    List<ProdutoCatalogoRecuperacao> produtos,
    String contextoId,
  ) async {
    final existentes = await txn.query(
      'unidades',
      where: 'contexto_id = ?',
      whereArgs: [contextoId],
    );
    final porSigla = <String, Map<String, Object?>>{
      for (final unidade in existentes)
        (unidade['sigla'] as String).toLowerCase(): unidade,
    };
    final especificacoes = {
      for (final unidade in unidadesAusentes)
        unidade.sigla.toLowerCase(): unidade,
    };
    final resultado = <String, int>{};
    for (final sigla in produtos.map((produto) => produto.unidade).toSet()) {
      final chave = sigla.toLowerCase();
      final existente = porSigla[chave];
      if (existente != null) {
        resultado[chave] = existente['id'] as int;
        continue;
      }
      final unidade = especificacoes[chave];
      if (unidade == null) {
        throw AppException(
          'A unidade "$sigla" não existe e não foi definida para a recuperação.',
        );
      }
      final id = await txn.insert('unidades', {
        'sigla': unidade.sigla,
        'nome': unidade.nome,
        'fracionavel': unidade.fracionavel ? 1 : 0,
        'ativa': 1,
        'contexto_id': contextoId,
      });
      resultado[chave] = id;
    }
    return resultado;
  }

  void _validarEntrada(
    List<String> categorias,
    List<UnidadeCatalogoRecuperacao> unidades,
    List<ProdutoCatalogoRecuperacao> produtos,
  ) {
    if (categorias.isEmpty || produtos.isEmpty) {
      throw const AppException('O catálogo de recuperação está vazio.');
    }
    final categoriasNormalizadas = categorias
        .map(TextoUtils.normalizar)
        .toSet();
    if (categoriasNormalizadas.length != categorias.length ||
        categorias.any((nome) => nome.trim().isEmpty)) {
      throw const AppException('Há categorias vazias ou duplicadas.');
    }
    final ids = <int>{};
    final nomes = <String>{};
    for (final produto in produtos) {
      if (produto.idOriginal <= 0 ||
          produto.nome.trim().isEmpty ||
          produto.unidade.trim().isEmpty ||
          !categoriasNormalizadas.contains(
            TextoUtils.normalizar(produto.categoria),
          )) {
        throw AppException(
          'O produto "${produto.nome}" possui identificador ou vínculo inválido.',
        );
      }
      if (!ids.add(produto.idOriginal) ||
          !nomes.add(TextoUtils.normalizar(produto.nome))) {
        throw AppException(
          'Há identificadores ou nomes duplicados no catálogo de recuperação.',
        );
      }
    }
    final siglas = unidades
        .map((unidade) => unidade.sigla.toLowerCase())
        .toSet();
    if (siglas.length != unidades.length ||
        unidades.any(
          (unidade) =>
              unidade.sigla.trim().isEmpty || unidade.nome.trim().isEmpty,
        )) {
      throw const AppException('Há unidades vazias ou duplicadas.');
    }
  }
}

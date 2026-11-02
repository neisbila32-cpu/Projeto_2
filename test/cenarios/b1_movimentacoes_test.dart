// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/auth/repositories/usuario_repository.dart'
    show UsuarioRepository;
import 'package:projeto_2/features/historico/models/historico_filtro.dart';
import 'package:projeto_2/features/historico/repositories/historico_repository.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao_regras.dart';
import 'package:projeto_2/features/movimentacoes/repositories/movimentacao_repository.dart';
import 'package:projeto_2/features/produtos/models/produto.dart';
import 'package:projeto_2/features/produtos/repositories/catalogo_inicial_repository.dart';
import 'package:projeto_2/features/produtos/repositories/produto_repository.dart';
import 'apoio/banco_teste.dart';

void main() {
  group('B1 Movimentações e consistência do saldo', () {
    late Database db;
    late UsuarioRepository usuarioRepo;
    late ProdutoRepository prodRepo;
    late MovimentacaoRepository movRepo;
    late HistoricoRepository histRepo;
    late CatalogoInicialRepository catRepo;

    late int adminId;
    late int operadorId;
    late int categoriaId;

    Future<int> _idDoLogin(String login) async {
      final linhas = await db.query(
        'usuarios',
        where: 'login = ?',
        whereArgs: [login],
        limit: 1,
      );
      return linhas.first['id'] as int;
    }

    Future<int> _nMovimentacoes(int produtoId) async {
      final linhas = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM movimentacoes WHERE produto_id = ?',
        [produtoId],
      );
      return Sqflite.firstIntValue(linhas) ?? 0;
    }

    Future<int> _saldo(int produtoId) async {
      final linhas = await db.query(
        'produtos',
        columns: ['saldo'],
        where: 'id = ?',
        whereArgs: [produtoId],
        limit: 1,
      );
      return linhas.first['saldo'] as int;
    }

    Future<void> _naoDeveGravarNada(int produtoId, int saldoAntes, int nAntes) async {
      expect(await _saldo(produtoId), saldoAntes);
      expect(await _nMovimentacoes(produtoId), nAntes);
    }

    Future<void> deveLancarAppException(
      Future<void> Function() acao,
      String mensagem,
    ) async {
      try {
        await acao();
        fail('Deveria lançar AppException("$mensagem")');
      } on AppException catch (e) {
        expect(e.message, mensagem);
      }
    }

    Future<Movimentacao> _ultimaMovimentacao(int produtoId) async {
      final lista = await movRepo.ultimasDoProduto(produtoId, limite: 1);
      expect(lista, isNotEmpty, reason: 'esperava movimentação no produto $produtoId');
      return lista.first;
    }

    void _conferir(Movimentacao m, {
      required int produtoId,
      required TipoMovimentacao tipo,
      required int deltaEsperado,
      required int saldoAposEsperado,
      required int usuarioEsperado,
      FinalidadeSaida? finalidadeEsperada,
    }) {
      expect(m.produtoId, produtoId);
      expect(m.tipo, tipo);
      expect(m.delta, deltaEsperado);
      expect(m.saldoApos, saldoAposEsperado);
      expect(m.usuarioId, usuarioEsperado);
      if (tipo == TipoMovimentacao.saida) {
        expect(m.finalidade, finalidadeEsperada);
      } else {
        expect(m.finalidade, isNull);
      }
    }

    Future<int> _criarProduto({
      bool fracionavel = false,
      int saldoInicial = 0,
      bool ativo = true,
    }) async {
      final linha = await db.query(
        'unidades',
        where: 'fracionavel = ?',
        whereArgs: [fracionavel ? 1 : 0],
        limit: 1,
      );
      expect(linha, isNotEmpty, reason: 'nenhuma unidade fracionavel=$fracionavel cadastrada');
      final unidadeId = linha.first['id'] as int;
      final id = await prodRepo.criar(
        nome: 'Produto de teste',
        categoriaId: categoriaId,
        unidadeId: unidadeId,
        usuarioId: adminId,
      );
      if (saldoInicial > 0) {
        await movRepo.registrar(
          produtoId: id,
          tipo: TipoMovimentacao.entrada,
          valor: saldoInicial,
          usuarioId: adminId,
        );
      }
      if (!ativo) {
        await prodRepo.definirAtivo(id, false);
      }
      return id;
    }

    Future<int> _inserirProdutoValidoDireto() async {
      final linha = await db.query('unidades', limit: 1);
      final unidadeId = linha.first['id'] as int;
      return await db.insert('produtos', {
        'nome': 'Produto direto',
        'categoria_id': categoriaId,
        'unidade_id': unidadeId,
        'saldo': 0,
        'ativo': 1,
        'criado_em': DateTime.now().toIso8601String(),
        'criado_por': adminId,
      });
    }

    setUpAll(() async {
      await abrirBancoEmMemoria();
      db = await AppDatabase.instance.database;
      usuarioRepo = UsuarioRepository(AppDatabase.instance);
      prodRepo = ProdutoRepository(AppDatabase.instance);
      movRepo = MovimentacaoRepository(() async => db);
      histRepo = HistoricoRepository(() async => db);
      catRepo = CatalogoInicialRepository(AppDatabase.instance);
    });

    setUp(() async {
      await limparDados(db);
      final categoria = await db.query('categorias', limit: 1);
      categoriaId = categoria.first['id'] as int;
      await usuarioRepo.cadastrar(
        nome: 'Administrador UAN',
        login: 'admin',
        senha: 'Senha123',
      );
      adminId = await _idDoLogin('admin');
      await usuarioRepo.cadastrar(
        nome: 'Operador UAN',
        login: 'operador',
        senha: 'Senha123',
      );
      operadorId = await _idDoLogin('operador');
    });
    group('B1.1 Dia na UAN', () {
      test('entradas em 12 produtos de 6 unidades, saídas, perda e ajuste com saldos consistentes', () async {
        final resultado = await catRepo.importar(adminId);
        expect(resultado.criados, greaterThan(0));

        final todos = await prodRepo.listar(incluirInativos: true);
        final porNome = <String, Produto>{};
        for (final p in todos) {
          porNome[p.nome] = p;
        }

        final entradas = <Map<String, Object>>[
          {'nome': 'Baby beef', 'sigla': 'kg', 'qtd': 1500},
          {'nome': 'Bacon defumado em cubos', 'sigla': 'kg', 'qtd': 2000},
          {'nome': 'Arroz integral 1 kg', 'sigla': 'pct', 'qtd': 1000},
          {'nome': 'Arroz parboilizado 5 kg', 'sigla': 'pct', 'qtd': 1000},
          {'nome': 'Leite integral longa vida 1 L', 'sigla': 'un', 'qtd': 1000},
          {'nome': 'Laranja pera', 'sigla': 'un', 'qtd': 1000},
          {'nome': 'Azeite de oliva sachê 4 ml (caixa com 200)', 'sigla': 'cx', 'qtd': 1000},
          {'nome': 'Biscoito de água sachê 10 g (caixa com 180)', 'sigla': 'cx', 'qtd': 1000},
          {'nome': 'Ovo grande (bandeja com 30)', 'sigla': 'bandeja', 'qtd': 1000},
          {'nome': 'Leite de coco 500 ml', 'sigla': 'fr', 'qtd': 1000},
          {'nome': 'Óleo de soja 900 ml', 'sigla': 'fr', 'qtd': 1000},
          {'nome': 'Vinagre de álcool branco 750 ml', 'sigla': 'fr', 'qtd': 1000},
        ];

        final siglasEsperadas = {'kg', 'pct', 'un', 'cx', 'bandeja', 'fr'};
        final siglasPresentes = <String>{};
        final saldosEsperados = <int, int>{};

        for (final item in entradas) {
          final nome = item['nome'] as String;
          expect(porNome.containsKey(nome), isTrue, reason: 'produto "$nome" não encontrado após importação');
          final p = porNome[nome]!;
          siglasPresentes.add(p.unidadeSigla);
          final qtd = item['qtd'] as int;

          await movRepo.registrar(
            produtoId: p.id,
            tipo: TipoMovimentacao.entrada,
            valor: qtd,
            usuarioId: adminId,
          );
          final mov = await _ultimaMovimentacao(p.id);
          _conferir(
            mov,
            produtoId: p.id,
            tipo: TipoMovimentacao.entrada,
            deltaEsperado: qtd,
            saldoAposEsperado: qtd,
            usuarioEsperado: adminId,
          );
          expect((await prodRepo.buscarPorId(p.id))!.saldo, qtd);
          saldosEsperados[p.id] = qtd;
        }
        expect(siglasPresentes, containsAll(siglasEsperadas));

        // saída com finalidade produção
        final baby = porNome['Baby beef']!;
        await movRepo.registrar(
          produtoId: baby.id,
          tipo: TipoMovimentacao.saida,
          valor: 500,
          usuarioId: adminId,
          finalidade: FinalidadeSaida.producao,
        );
        _conferir(
          await _ultimaMovimentacao(baby.id),
          produtoId: baby.id,
          tipo: TipoMovimentacao.saida,
          deltaEsperado: -500,
          saldoAposEsperado: 1000,
          usuarioEsperado: adminId,
          finalidadeEsperada: FinalidadeSaida.producao,
        );
        saldosEsperados[baby.id] = 1000;

        // saída com finalidade transferência
        final arrozPar = porNome['Arroz parboilizado 5 kg']!;
        await movRepo.registrar(
          produtoId: arrozPar.id,
          tipo: TipoMovimentacao.saida,
          valor: 1000,
          usuarioId: adminId,
          finalidade: FinalidadeSaida.transferencia,
        );
        _conferir(
          await _ultimaMovimentacao(arrozPar.id),
          produtoId: arrozPar.id,
          tipo: TipoMovimentacao.saida,
          deltaEsperado: -1000,
          saldoAposEsperado: 0,
          usuarioEsperado: adminId,
          finalidadeEsperada: FinalidadeSaida.transferencia,
        );
        saldosEsperados[arrozPar.id] = 0;

        // saída com finalidade outra
        final leite = porNome['Leite integral longa vida 1 L']!;
        await movRepo.registrar(
          produtoId: leite.id,
          tipo: TipoMovimentacao.saida,
          valor: 1000,
          usuarioId: adminId,
          finalidade: FinalidadeSaida.outra,
        );
        _conferir(
          await _ultimaMovimentacao(leite.id),
          produtoId: leite.id,
          tipo: TipoMovimentacao.saida,
          deltaEsperado: -1000,
          saldoAposEsperado: 0,
          usuarioEsperado: adminId,
          finalidadeEsperada: FinalidadeSaida.outra,
        );
        saldosEsperados[leite.id] = 0;

        // perda com motivo
        final coco = porNome['Leite de coco 500 ml']!;
        await movRepo.registrar(
          produtoId: coco.id,
          tipo: TipoMovimentacao.perda,
          valor: 1000,
          usuarioId: adminId,
          observacao: 'Vencido',
        );
        _conferir(
          await _ultimaMovimentacao(coco.id),
          produtoId: coco.id,
          tipo: TipoMovimentacao.perda,
          deltaEsperado: -1000,
          saldoAposEsperado: 0,
          usuarioEsperado: adminId,
        );
        saldosEsperados[coco.id] = 0;

        // ajuste com justificativa (valor = novo saldo)
        final oleo = porNome['Óleo de soja 900 ml']!;
        await movRepo.registrar(
          produtoId: oleo.id,
          tipo: TipoMovimentacao.ajuste,
          valor: 2000,
          usuarioId: adminId,
          observacao: 'Contagem conferida',
        );
        _conferir(
          await _ultimaMovimentacao(oleo.id),
          produtoId: oleo.id,
          tipo: TipoMovimentacao.ajuste,
          deltaEsperado: 1000,
          saldoAposEsperado: 2000,
          usuarioEsperado: adminId,
        );
        saldosEsperados[oleo.id] = 2000;

        // confere o saldo final de cada produto
        for (final item in entradas) {
          final p = porNome[item['nome'] as String]!;
          final atual = (await prodRepo.buscarPorId(p.id))!.saldo;
          expect(atual, saldosEsperados[p.id], reason: 'saldo final de ${p.nome}');
        }
      });
    });

    group('B1.2 Erros comuns', () {
      test('saída maior que o saldo é rejeitada e nada é gravado', () async {
        final id = await _criarProduto(saldoInicial: 1000);
        final saldoAntes = await _saldo(id);
        final nAntes = await _nMovimentacoes(id);
        await deveLancarAppException(
          () => movRepo.registrar(
            produtoId: id,
            tipo: TipoMovimentacao.saida,
            valor: 2000,
            usuarioId: adminId,
            finalidade: FinalidadeSaida.producao,
          ),
          'Saldo insuficiente para esta operação.',
        );
        await _naoDeveGravarNada(id, saldoAntes, nAntes);
      });

      test('saída sem finalidade é rejeitada e nada é gravado', () async {
        final id = await _criarProduto(saldoInicial: 1000);
        final saldoAntes = await _saldo(id);
        final nAntes = await _nMovimentacoes(id);
        await deveLancarAppException(
          () => movRepo.registrar(
            produtoId: id,
            tipo: TipoMovimentacao.saida,
            valor: 1000,
            usuarioId: adminId,
          ),
          'Informe a finalidade da saída.',
        );
        await _naoDeveGravarNada(id, saldoAntes, nAntes);
      });

      test('perda sem motivo é rejeitada e nada é gravado', () async {
        final id = await _criarProduto(saldoInicial: 1000);
        final saldoAntes = await _saldo(id);
        final nAntes = await _nMovimentacoes(id);
        await deveLancarAppException(
          () => movRepo.registrar(
            produtoId: id,
            tipo: TipoMovimentacao.perda,
            valor: 1000,
            usuarioId: adminId,
            observacao: '',
          ),
          'Informe o motivo da perda.',
        );
        await _naoDeveGravarNada(id, saldoAntes, nAntes);
      });

      test('ajuste para o mesmo saldo é rejeitado e nada é gravado', () async {
        final id = await _criarProduto(saldoInicial: 1000);
        final saldoAntes = await _saldo(id);
        final nAntes = await _nMovimentacoes(id);
        await deveLancarAppException(
          () => movRepo.registrar(
            produtoId: id,
            tipo: TipoMovimentacao.ajuste,
            valor: 1000,
            usuarioId: adminId,
            observacao: 'x',
          ),
          'O novo saldo é igual ao saldo atual. Nada a ajustar.',
        );
        await _naoDeveGravarNada(id, saldoAntes, nAntes);
      });

      test('ajuste sem justificativa é rejeitada e nada é gravado', () async {
        final id = await _criarProduto(saldoInicial: 1000);
        final saldoAntes = await _saldo(id);
        final nAntes = await _nMovimentacoes(id);
        await deveLancarAppException(
          () => movRepo.registrar(
            produtoId: id,
            tipo: TipoMovimentacao.ajuste,
            valor: 2000,
            usuarioId: adminId,
            observacao: '',
          ),
          'Informe a justificativa do ajuste.',
        );
        await _naoDeveGravarNada(id, saldoAntes, nAntes);
      });

      test('ajuste negativo é rejeitado e nada é gravado', () async {
        final id = await _criarProduto(fracionavel: true);
        final saldoAntes = await _saldo(id);
        final nAntes = await _nMovimentacoes(id);
        await deveLancarAppException(
          () => movRepo.registrar(
            produtoId: id,
            tipo: TipoMovimentacao.ajuste,
            valor: -1000,
            usuarioId: adminId,
            observacao: 'x',
          ),
          'O novo saldo não pode ser negativo.',
        );
        await _naoDeveGravarNada(id, saldoAntes, nAntes);
      });

      test('quantidade zero é rejeitada e nada é gravado', () async {
        final id = await _criarProduto(saldoInicial: 1000);
        final saldoAntes = await _saldo(id);
        final nAntes = await _nMovimentacoes(id);
        await deveLancarAppException(
          () => movRepo.registrar(
            produtoId: id,
            tipo: TipoMovimentacao.entrada,
            valor: 0,
            usuarioId: adminId,
          ),
          'Informe uma quantidade maior que zero.',
        );
        await _naoDeveGravarNada(id, saldoAntes, nAntes);
      });

      test('fração em unidade contável é rejeitada e nada é gravado', () async {
        final id = await _criarProduto(fracionavel: false);
        final saldoAntes = await _saldo(id);
        final nAntes = await _nMovimentacoes(id);
        await deveLancarAppException(
          () => movRepo.registrar(
            produtoId: id,
            tipo: TipoMovimentacao.entrada,
            valor: 1500,
            usuarioId: adminId,
          ),
          'Esta unidade aceita apenas quantidades inteiras.',
        );
        await _naoDeveGravarNada(id, saldoAntes, nAntes);
      });

      test('produto inativo não pode ser movimentado e nada é gravado', () async {
        final id = await _criarProduto(ativo: false);
        final saldoAntes = await _saldo(id);
        final nAntes = await _nMovimentacoes(id);
        await deveLancarAppException(
          () => movRepo.registrar(
            produtoId: id,
            tipo: TipoMovimentacao.entrada,
            valor: 1000,
            usuarioId: adminId,
          ),
          'Produto inativo não pode ser movimentado.',
        );
        await _naoDeveGravarNada(id, saldoAntes, nAntes);
      });

      test('produto inexistente é rejeitado e nada é gravado', () async {
        final nAntes = await _nMovimentacoes(999999);
        await deveLancarAppException(
          () => movRepo.registrar(
            produtoId: 999999,
            tipo: TipoMovimentacao.entrada,
            valor: 1000,
            usuarioId: adminId,
          ),
          'Produto não encontrado.',
        );
        expect(await _nMovimentacoes(999999), nAntes);
      });
    });

    group('B1.3 Integridade', () {
      test('banco rejeita movimentação com produto inexistente (foreign key)', () async {
        try {
          await db.insert('movimentacoes', {
            'produto_id': 999999,
            'tipo': 'entrada',
            'finalidade': null,
            'delta': 100,
            'saldo_apos': 100,
            'data_hora': DateTime.now().toIso8601String(),
            'usuario_id': adminId,
            'observacao': null,
            'inventario_id': null,
          });
          fail('Deveria rejeitar produto inexistente');
        } on DatabaseException catch (e) {
          expect(e.toString().toLowerCase(), contains('foreign key'));
        }
        final linhas = await db.query(
          'movimentacoes',
          where: 'produto_id = ?',
          whereArgs: [999999],
        );
        expect(linhas, isEmpty);
      });

      test('banco rejeita movimentação com usuário inexistente (foreign key)', () async {
        final pId = await _inserirProdutoValidoDireto();
        try {
          await db.insert('movimentacoes', {
            'produto_id': pId,
            'tipo': 'entrada',
            'finalidade': null,
            'delta': 100,
            'saldo_apos': 100,
            'data_hora': DateTime.now().toIso8601String(),
            'usuario_id': 999999,
            'observacao': null,
            'inventario_id': null,
          });
          fail('Deveria rejeitar usuário inexistente');
        } on DatabaseException catch (e) {
          expect(e.toString().toLowerCase(), contains('foreign key'));
        }
        final linhas = await db.query(
          'movimentacoes',
          where: 'produto_id = ? AND usuario_id = ?',
          whereArgs: [pId, 999999],
        );
        expect(linhas, isEmpty);
      });

      test('banco rejeita movimentação com delta 0 (restrição CHECK)', () async {
        final pId = await _inserirProdutoValidoDireto();
        try {
          await db.insert('movimentacoes', {
            'produto_id': pId,
            'tipo': 'entrada',
            'finalidade': null,
            'delta': 0,
            'saldo_apos': 100,
            'data_hora': DateTime.now().toIso8601String(),
            'usuario_id': adminId,
            'observacao': null,
            'inventario_id': null,
          });
          fail('Deveria rejeitar delta 0');
        } on DatabaseException catch (e) {
          final msg = e.toString().toLowerCase();
          expect(msg, anyOf(contains('delta'), contains('check')));
        }
        final linhas = await db.query(
          'movimentacoes',
          where: 'produto_id = ? AND delta = 0',
          whereArgs: [pId],
        );
        expect(linhas, isEmpty);
      });

      test('unidade do produto fica travada depois da primeira movimentação', () async {
        final id = await _criarProduto();
        expect(await prodRepo.temMovimentacoes(id), isFalse);
        final unidadeAntes = (await prodRepo.buscarPorId(id))!.unidadeId;

        await movRepo.registrar(
          produtoId: id,
          tipo: TipoMovimentacao.entrada,
          valor: 1000,
          usuarioId: adminId,
        );
        expect(await prodRepo.temMovimentacoes(id), isTrue);

        final outra = await db.query(
          'unidades',
          where: 'id != ?',
          whereArgs: [unidadeAntes],
          limit: 1,
        );
        if (outra.isNotEmpty) {
          await deveLancarAppException(
            () => prodRepo.atualizar(
              id: id,
              nome: 'Produto de teste',
              categoriaId: categoriaId,
              unidadeId: outra.first['id'] as int,
            ),
            'A unidade não pode ser alterada: o produto já tem movimentações.',
          );
        }
        expect((await prodRepo.buscarPorId(id))!.unidadeId, unidadeAntes);
      });
    });

    test('B1.4 concorrência: 20 registros simultâneos no mesmo produto', () async {
      final unidadeKg = await db.query('unidades', where: 'sigla = ?', whereArgs: ['kg'], limit: 1);
      expect(unidadeKg, isNotEmpty);
      final id = await prodRepo.criar(
        nome: 'Produto concorrência',
        categoriaId: categoriaId,
        unidadeId: unidadeKg.first['id'] as int,
        usuarioId: adminId,
      );
      await movRepo.registrar(
        produtoId: id,
        tipo: TipoMovimentacao.entrada,
        valor: 100000,
        usuarioId: adminId,
      );
      final saldoInicial = await _saldo(id);

      final chamadas = <Future<ResultadoMovimento>>[];
      for (int i = 0; i < 20; i++) {
        final entrada = i.isEven;
        chamadas.add(movRepo.registrar(
          produtoId: id,
          tipo: entrada ? TipoMovimentacao.entrada : TipoMovimentacao.saida,
          valor: entrada ? 1000 : 500,
          usuarioId: adminId,
          finalidade: entrada ? null : FinalidadeSaida.producao,
        ));
      }
      final resultados = await Future.wait(chamadas);

      expect(resultados, hasLength(20));
      final somaDeltas = resultados.fold<int>(0, (soma, r) => soma + r.delta);
      expect(somaDeltas, 5000); // 10 entradas de 1000 e 10 saídas de 500

      final saldoFinal = await _saldo(id);
      expect(saldoFinal, saldoInicial + somaDeltas);
      expect(saldoFinal, greaterThanOrEqualTo(0));

      // cada saldo_apos coerente com a ordem de gravação (por id) e nunca negativo
      final linhas = await db.rawQuery(
        'SELECT id, delta, saldo_apos FROM movimentacoes WHERE produto_id = ? ORDER BY id',
        [id],
      );
      int running = 0;
      for (final linha in linhas) {
        running += linha['delta'] as int;
        expect(linha['saldo_apos'] as int, running, reason: 'movimentação id=${linha['id']}');
        expect(running, greaterThanOrEqualTo(0));
      }
      expect(running, saldoFinal);
    });

    test('B1.5 invariante aleatória: 300 operações em 15 produtos (Random(42))', () async {
      final rnd = Random(42);
      final unidades = await db.query('unidades', columns: ['id', 'fracionavel']);
      expect(unidades, isNotEmpty);

      final produtos = <Produto>[];
      for (int i = 0; i < 15; i++) {
        final u = unidades[rnd.nextInt(unidades.length)];
        final id = await prodRepo.criar(
          nome: 'Produto aleatório $i',
          categoriaId: categoriaId,
          unidadeId: u['id'] as int,
          usuarioId: adminId,
        );
        produtos.add((await prodRepo.buscarPorId(id))!);
      }

      final tipos = [
        TipoMovimentacao.entrada,
        TipoMovimentacao.saida,
        TipoMovimentacao.perda,
        TipoMovimentacao.ajuste,
      ];
      final finalidades = [
        FinalidadeSaida.producao,
        FinalidadeSaida.transferencia,
        FinalidadeSaida.outra,
      ];

      for (int i = 0; i < 300; i++) {
        final p = produtos[rnd.nextInt(produtos.length)];
        final tipo = tipos[rnd.nextInt(tipos.length)];
        int valor;
        String? observacao;
        FinalidadeSaida? finalidade;
        final fracionavel = p.unidadeFracionavel;

        switch (tipo) {
          case TipoMovimentacao.entrada:
            valor = fracionavel ? rnd.nextInt(50000) + 1 : (rnd.nextInt(50) + 1) * 1000;
            break;
          case TipoMovimentacao.saida:
            valor = fracionavel ? rnd.nextInt(50000) + 1 : (rnd.nextInt(50) + 1) * 1000;
            finalidade = finalidades[rnd.nextInt(finalidades.length)];
            break;
          case TipoMovimentacao.perda:
            valor = fracionavel ? rnd.nextInt(50000) + 1 : (rnd.nextInt(50) + 1) * 1000;
            observacao = 'motivo aleatório';
            break;
          case TipoMovimentacao.ajuste:
            valor = rnd.nextInt(50000);
            observacao = 'justificativa aleatória';
            break;
        }

        try {
          await movRepo.registrar(
            produtoId: p.id,
            tipo: tipo,
            valor: valor,
            usuarioId: adminId,
            finalidade: finalidade,
            observacao: observacao,
          );
        } on AppException {
          // operação inválida: nada gravado (esperado)
        }

        // ocasionalmente tenta inativar um produto com saldo zero
        if (rnd.nextInt(30) == 0) {
          try {
            await prodRepo.definirAtivo(p.id, false);
          } on AppException {
            // saldo diferente de zero: não inativa, continua
          }
        }
      }

      // invariantes por produto
      for (final p in produtos) {
        final linhas = await db.rawQuery(
          'SELECT id, delta, saldo_apos FROM movimentacoes WHERE produto_id = ? ORDER BY id',
          [p.id],
        );
        int somaDeltas = 0;
        int? saldoAnterior;
        for (final linha in linhas) {
          final delta = linha['delta'] as int;
          final saldoApos = linha['saldo_apos'] as int;
          somaDeltas += delta;
          expect(saldoApos, greaterThanOrEqualTo(0), reason: 'produto ${p.id} saldo_apos negativo');
          if (saldoAnterior != null) {
            expect(
              saldoApos,
              saldoAnterior + delta,
              reason: 'produto ${p.id} movimento id=${linha['id']}',
            );
          }
          saldoAnterior = saldoApos;
        }
        final produtoAtual = await prodRepo.buscarPorId(p.id);
        expect(produtoAtual, isNotNull);
        expect(
          produtoAtual!.saldo,
          somaDeltas,
          reason: 'produto ${p.id} saldo != soma dos deltas',
        );
        if (linhas.isNotEmpty) {
          expect(
            linhas.last['saldo_apos'] as int,
            produtoAtual.saldo,
            reason: 'produto ${p.id} último saldo_apos != saldo',
          );
        }
      }
    });

    test('B1.6 Atribuição: responsável certo no histórico para usuários diferentes', () async {
      final unidade = await db.query('unidades', limit: 1);
      final id = await prodRepo.criar(
        nome: 'Produto histórico',
        categoriaId: categoriaId,
        unidadeId: unidade.first['id'] as int,
        usuarioId: adminId,
      );

      await movRepo.registrar(
        produtoId: id,
        tipo: TipoMovimentacao.entrada,
        valor: 1000,
        usuarioId: adminId,
      );
      await movRepo.registrar(
        produtoId: id,
        tipo: TipoMovimentacao.saida,
        valor: 200,
        usuarioId: operadorId,
        finalidade: FinalidadeSaida.producao,
      );
      await movRepo.registrar(
        produtoId: id,
        tipo: TipoMovimentacao.perda,
        valor: 100,
        usuarioId: adminId,
        observacao: 'Quebra',
      );
      await movRepo.registrar(
        produtoId: id,
        tipo: TipoMovimentacao.ajuste,
        valor: 750,
        usuarioId: operadorId,
        observacao: 'Conferência',
      );

      final pagina = await histRepo.consultar(HistoricoFiltro(produtoId: id, limite: 50));
      expect(pagina.itens, hasLength(4));

      final nomes = {adminId: 'Administrador UAN', operadorId: 'Operador UAN'};
      final responsaveis = <int>[];
      for (final item in pagina.itens) {
        expect(
          nomes.containsKey(item.movimentacao.usuarioId),
          isTrue,
          reason: 'usuário desconhecido ${item.movimentacao.usuarioId}',
        );
        expect(
          item.movimentacao.usuarioNome,
          nomes[item.movimentacao.usuarioId],
          reason: 'responsável incorreto na movimentação id=${item.movimentacao.id}',
        );
        responsaveis.add(item.movimentacao.usuarioId);
      }

      // ordem DESC por gravação: ajuste(operador), perda(admin), saída(operador), entrada(admin)
      expect(responsaveis, [operadorId, adminId, operadorId, adminId]);
    });
  });
}


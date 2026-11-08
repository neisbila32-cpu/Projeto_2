import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';

/// Resolve o contexto autorizado para as operações locais do aplicativo.
/// Nesta etapa somente o contexto individual é habilitado; tentativas de
/// ativar uma UAN compartilhada falham de forma fechada.
class ContextoTrabalhoRepository {
  const ContextoTrabalhoRepository();

  static const String mensagemContextoIndisponivel =
      'O contexto de trabalho individual está indisponível.';
  static const String mensagemCompartilhadoDesabilitado =
      'O uso de contextos compartilhados ainda não está habilitado.';

  static Future<String> exigirIdAtivo(DatabaseExecutor executor) async {
    final linhas = await executor.rawQuery('''
      SELECT c.id, c.tipo, c.ativo
      FROM contexto_trabalho_atual atual
      JOIN contextos_trabalho c ON c.id = atual.contexto_id
      WHERE atual.id = 1
    ''');
    if (linhas.isEmpty || linhas.single['ativo'] != 1) {
      throw const AppException(mensagemContextoIndisponivel);
    }
    if (linhas.single['tipo'] != 'individual') {
      throw const AppException(mensagemCompartilhadoDesabilitado);
    }
    return linhas.single['id'] as String;
  }

  /// Garante que um backup individual não contenha linhas nem metadados de
  /// outro contexto. Bancos anteriores à v2 são legados locais por definição.
  static Future<void> validarBancoIndividual(
    DatabaseExecutor executor, {
    String? contextoEsperado,
    bool aceitarLegadoSemContexto = false,
  }) async {
    final tabelas = await executor.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final nomes = tabelas.map((linha) => linha['name'] as String).toSet();
    if (!nomes.contains('contextos_trabalho') ||
        !nomes.contains('contexto_trabalho_atual')) {
      if (aceitarLegadoSemContexto) return;
      throw const AppException(
        'O banco não possui a estrutura de contexto necessária para um backup individual.',
      );
    }

    final contextos = await executor.query('contextos_trabalho');
    if (contextos.length != 1 || contextos.single['tipo'] != 'individual') {
      throw const AppException(
        'O backup individual não pode conter dados de outros contextos.',
      );
    }
    final atual = await executor.rawQuery('''
      SELECT atual.contexto_id, c.tipo, c.ativo
      FROM contexto_trabalho_atual atual
      JOIN contextos_trabalho c ON c.id = atual.contexto_id
      WHERE atual.id = 1
    ''');
    if (atual.length != 1 ||
        atual.single['tipo'] != 'individual' ||
        atual.single['ativo'] != 1) {
      throw const AppException(
        'O banco não está no contexto individual e não pode ser exportado como backup individual.',
      );
    }
    final contextoId = atual.single['contexto_id'] as String;
    if (contextoEsperado != null && contextoId != contextoEsperado) {
      throw const AppException(
        'O backup pertence a um contexto diferente do contexto individual ativo.',
      );
    }
    for (final tabela in AppDatabase.tabelasComContexto) {
      if (!nomes.contains(tabela)) continue;
      final linhas = await executor.rawQuery(
        'SELECT COUNT(*) AS total FROM $tabela '
        'WHERE contexto_id IS NULL OR contexto_id <> ?',
        [contextoId],
      );
      if ((Sqflite.firstIntValue(linhas) ?? 0) != 0) {
        throw const AppException(
          'O backup individual não pode incluir registros de outro contexto.',
        );
      }
    }
  }

  /// Valida um contexto individual mesmo quando o arquivo também contém
  /// outros contextos. Usado antes de exportar/restaurar apenas suas linhas.
  static Future<void> validarContextoIndividual(
    DatabaseExecutor executor, {
    String? contextoEsperado,
  }) async {
    final tabelas = await executor.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final nomes = tabelas.map((linha) => linha['name'] as String).toSet();
    if (!nomes.contains('contextos_trabalho') ||
        !nomes.contains('contexto_trabalho_atual')) {
      throw const AppException(
        'O banco não possui a estrutura de contexto necessária para um backup individual.',
      );
    }

    final atual = await executor.rawQuery('''
      SELECT atual.contexto_id, c.tipo, c.ativo
      FROM contexto_trabalho_atual atual
      JOIN contextos_trabalho c ON c.id = atual.contexto_id
      WHERE atual.id = 1
    ''');
    if (atual.length != 1 ||
        atual.single['tipo'] != 'individual' ||
        atual.single['ativo'] != 1) {
      throw const AppException(
        'O contexto ativo não é individual e não pode ser exportado como backup individual.',
      );
    }
    final contextoId = atual.single['contexto_id'] as String;
    if (contextoEsperado != null && contextoId != contextoEsperado) {
      throw const AppException(
        'O contexto individual mudou durante a operação de backup.',
      );
    }

    final verificacoes = <String, String>{
      'produtos': '''
        SELECT COUNT(*) AS total FROM produtos p
        LEFT JOIN categorias c ON c.id = p.categoria_id
        LEFT JOIN unidades un ON un.id = p.unidade_id
        LEFT JOIN usuarios us ON us.id = p.criado_por
        WHERE p.contexto_id = ? AND
          (c.contexto_id IS NOT p.contexto_id OR
           un.contexto_id IS NOT p.contexto_id OR
           us.contexto_id IS NOT p.contexto_id)
      ''',
      'inventarios': '''
        SELECT COUNT(*) AS total FROM inventarios i
        LEFT JOIN usuarios us ON us.id = i.usuario_id
        WHERE i.contexto_id = ? AND us.contexto_id IS NOT i.contexto_id
      ''',
      'movimentacoes': '''
        SELECT COUNT(*) AS total FROM movimentacoes m
        LEFT JOIN produtos p ON p.id = m.produto_id
        LEFT JOIN usuarios us ON us.id = m.usuario_id
        LEFT JOIN inventarios i ON i.id = m.inventario_id
        WHERE m.contexto_id = ? AND
          (p.contexto_id IS NOT m.contexto_id OR
           us.contexto_id IS NOT m.contexto_id OR
           (m.inventario_id IS NOT NULL AND i.contexto_id IS NOT m.contexto_id))
      ''',
      'itens_inventario': '''
        SELECT COUNT(*) AS total FROM itens_inventario x
        LEFT JOIN inventarios i ON i.id = x.inventario_id
        LEFT JOIN produtos p ON p.id = x.produto_id
        WHERE x.contexto_id = ? AND
          (i.contexto_id IS NOT x.contexto_id OR
           p.contexto_id IS NOT x.contexto_id)
      ''',
    };
    for (final entrada in verificacoes.entries) {
      if (!nomes.contains(entrada.key)) continue;
      final resultado = await executor.rawQuery(entrada.value, [contextoId]);
      if ((Sqflite.firstIntValue(resultado) ?? 0) != 0) {
        throw const AppException(
          'O contexto individual contém relacionamentos inválidos e não pode ser copiado.',
        );
      }
    }
  }
}

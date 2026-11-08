import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/database/contexto_trabalho_repository.dart';
import 'package:projeto_2/core/utils/app_exception.dart';

/// Exporta e restaura apenas os dados do contexto individual local.
class BackupService {
  BackupService({
    required this._obterBanco,
    required Future<void> Function() fecharBanco,
    required this._caminhoBanco,
  });

  final Future<Database> Function() _obterBanco;
  final Future<String> Function() _caminhoBanco;

  static const List<String> _tabelasObrigatorias = [
    'unidades',
    'categorias',
    'usuarios',
    'produtos',
    'inventarios',
    'movimentacoes',
    'itens_inventario',
  ];

  static const List<String> _ordemExclusao = [
    'itens_inventario',
    'movimentacoes',
    'inventarios',
    'produtos',
    'categorias',
    'unidades',
    'usuarios',
  ];

  static const List<String> _ordemInsercao = [
    'unidades',
    'categorias',
    'usuarios',
    'produtos',
    'inventarios',
    'movimentacoes',
    'itens_inventario',
  ];

  static const String _cabecalhoSqlite = 'SQLite format 3\u0000';

  static bool temCabecalhoSqlite(List<int> bytes) {
    if (bytes.length < 16) return false;
    final esperado = _cabecalhoSqlite.codeUnits;
    for (var i = 0; i < 16; i++) {
      if (bytes[i] != esperado[i]) return false;
    }
    return true;
  }

  static String carimbo(DateTime d) {
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${dois(d.month)}${dois(d.day)}_'
        '${dois(d.hour)}${dois(d.minute)}${dois(d.second)}';
  }

  String _caminhoTemporario(String prefixo) => p.join(
    Directory.systemTemp.path,
    '${prefixo}_${DateTime.now().microsecondsSinceEpoch}.db',
  );

  Future<void> _apagarTemporarioSqlite(File arquivo) async {
    for (final sufixo in ['', '-wal', '-shm', '-journal']) {
      final auxiliar = File('${arquivo.path}$sufixo');
      if (await auxiliar.exists()) await auxiliar.delete();
    }
  }

  Future<void> _checkpoint(Database db) async {
    final resultado = await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    if (resultado.isNotEmpty && (resultado.first['busy'] as int? ?? 0) != 0) {
      throw const AppException('O banco está ocupado e não pode ser copiado.');
    }
  }

  Future<void> _copiarBancoCompletoParaSeguranca(String destino) async {
    final db = await _obterBanco();
    await _checkpoint(db);
    await File(await _caminhoBanco()).copy(destino);
  }

  /// Gera um banco SQLite v4 contendo exclusivamente o contexto individual.
  Future<File> exportar() async {
    final destino = File(_caminhoTemporario('backup_estoque_uan'));
    Database? exportado;
    Database? origemMigrada;
    File? arquivoMigrado;
    try {
      var origem = await _obterBanco();
      // O app abre em v4; este caminho também mantém compatíveis os bancos v1
      // fornecidos por integrações/testes antigos, sempre migrando uma cópia.
      if (await origem.getVersion() < 2) {
        arquivoMigrado = File(_caminhoTemporario('backup_origem_migrada'));
        await _checkpoint(origem);
        await File(await _caminhoBanco()).copy(arquivoMigrado.path);
        final preparado = await _prepararArquivoIndividual(arquivoMigrado);
        await _apagarTemporarioSqlite(arquivoMigrado);
        arquivoMigrado = preparado;
        origemMigrada = await openDatabase(
          preparado.path,
          readOnly: true,
          singleInstance: false,
        );
        origem = origemMigrada;
      }
      final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(origem);
      await ContextoTrabalhoRepository.validarContextoIndividual(
        origem,
        contextoEsperado: contextoId,
      );

      exportado = await _abrirBancoV4(destino.path);
      await _copiarContexto(origem, exportado, contextoId);
      final integridade = await _verificarIntegridade(exportado);
      if (integridade != null) {
        throw const AppException('Não foi possível validar o backup gerado.');
      }
      if ((await exportado.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
        throw const AppException(
          'Não foi possível validar os relacionamentos do backup.',
        );
      }
      await exportado.close();
      exportado = null;
      await origemMigrada?.close();
      origemMigrada = null;
      if (arquivoMigrado != null && await arquivoMigrado.exists()) {
        await _apagarTemporarioSqlite(arquivoMigrado);
      }
      return destino;
    } catch (e) {
      await exportado?.close();
      await origemMigrada?.close();
      if (arquivoMigrado != null && await arquivoMigrado.exists()) {
        await _apagarTemporarioSqlite(arquivoMigrado);
      }
      await _apagarTemporarioSqlite(destino);
      if (e is AppException) rethrow;
      throw AppException('Não foi possível gerar o backup: $e');
    }
  }

  /// Confere estrutura, versão, integridade e que o arquivo represente um
  /// único contexto individual. Backups v1 são migrados em cópia temporária.
  Future<void> validarArquivo(File arquivo) async {
    final preparado = await _prepararArquivoIndividual(arquivo);
    await _apagarTemporarioSqlite(preparado);
  }

  Future<File> _prepararArquivoIndividual(File arquivo) async {
    if (!await arquivo.exists()) {
      throw const AppException('Arquivo não encontrado.');
    }
    final raf = await arquivo.open();
    final cabecalho = await raf.read(16);
    await raf.close();
    if (!temCabecalhoSqlite(cabecalho)) {
      throw const AppException(
        'O arquivo escolhido não é um backup válido do app.',
      );
    }

    Database? original;
    Database? migrado;
    final temporario = File(_caminhoTemporario('backup_validacao'));
    try {
      original = await openDatabase(
        arquivo.path,
        readOnly: true,
        singleInstance: false,
      );
      final tabelas = await _tabelasExistentes(original);
      for (final tabela in _tabelasObrigatorias) {
        if (!tabelas.contains(tabela)) {
          throw const AppException(
            'O arquivo escolhido não é um backup deste app.',
          );
        }
      }
      final versao = await original.getVersion();
      final atual = await (await _obterBanco()).getVersion();
      if (versao < 1) {
        throw const AppException(
          'O arquivo escolhido não é um backup deste app.',
        );
      }
      if (versao > atual) {
        throw const AppException(
          'Este backup foi criado por uma versão mais nova do app.',
        );
      }
      final integridadeOriginal = await _verificarIntegridade(original);
      if (integridadeOriginal != null) {
        throw const AppException('O arquivo de backup está corrompido.');
      }
      final fkOriginal = await original.rawQuery('PRAGMA foreign_key_check');
      if (fkOriginal.isNotEmpty) {
        throw const AppException('O backup contém relacionamentos inválidos.');
      }
      await original.close();
      original = null;

      await arquivo.copy(temporario.path);
      migrado = await _abrirBancoV4(temporario.path);
      final integridadeMigrada = await _verificarIntegridade(migrado);
      final fkMigrado = await migrado.rawQuery('PRAGMA foreign_key_check');
      if (integridadeMigrada != null || fkMigrado.isNotEmpty) {
        throw const AppException(
          'O backup não passou nas verificações de integridade.',
        );
      }
      await ContextoTrabalhoRepository.validarBancoIndividual(migrado);
      await migrado.close();
      migrado = null;
      return temporario;
    } on AppException {
      await original?.close();
      await migrado?.close();
      await _apagarTemporarioSqlite(temporario);
      rethrow;
    } catch (_) {
      await original?.close();
      await migrado?.close();
      await _apagarTemporarioSqlite(temporario);
      throw const AppException(
        'Não foi possível ler ou migrar o arquivo de backup.',
      );
    }
  }

  Future<Database> _abrirBancoV4(String caminho) => openDatabase(
    caminho,
    version: AppDatabase.versaoAtual,
    onConfigure: AppDatabase.prepararBancoParaMigracao,
    onCreate: AppDatabase.criarEsquemaAtual,
    onUpgrade: AppDatabase.migrarEsquema,
    onOpen: AppDatabase.configurarBanco,
    singleInstance: false,
  );

  Future<Set<String>> _tabelasExistentes(DatabaseExecutor db) async {
    final linhas = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    return linhas.map((linha) => linha['name'] as String).toSet();
  }

  /// Retorna null quando íntegro; caso contrário, a mensagem do SQLite.
  Future<String?> _verificarIntegridade(DatabaseExecutor db) async {
    final linhas = await db.rawQuery('PRAGMA integrity_check');
    if (linhas.length == 1 && linhas.single.values.single == 'ok') return null;
    return linhas.toString();
  }

  Future<void> _copiarContexto(
    Database origem,
    Database destino,
    String contextoId,
  ) async {
    await origem.transaction((snapshot) async {
      await destino.transaction((transacao) async {
        await _limparContextoRecemCriado(transacao);
        final contexto = await snapshot.query(
          'contextos_trabalho',
          where: 'id = ? AND tipo = ?',
          whereArgs: [contextoId, 'individual'],
        );
        if (contexto.length != 1) {
          throw const AppException('O contexto individual não foi encontrado.');
        }
        await transacao.insert('contextos_trabalho', contexto.single);
        await transacao.insert('contexto_trabalho_atual', {
          'id': 1,
          'contexto_id': contextoId,
        });
        for (final tabela in _ordemInsercao) {
          final linhas = await snapshot.query(
            tabela,
            where: 'contexto_id = ?',
            whereArgs: [contextoId],
          );
          for (final linha in linhas) {
            await transacao.insert(tabela, linha);
          }
        }
      });
    });
  }

  Future<void> _limparContextoRecemCriado(DatabaseExecutor db) async {
    for (final tabela in _ordemExclusao) {
      await db.delete(tabela);
    }
    await db.delete('contexto_trabalho_atual');
    await db.delete('contextos_trabalho');
  }

  Future<void> _garantirIdsSemColisao(
    DatabaseExecutor atual,
    DatabaseExecutor backup,
    String contextoAtual,
    String contextoBackup,
  ) async {
    for (final tabela in _tabelasObrigatorias) {
      final ids = await backup.query(
        tabela,
        columns: ['id'],
        where: 'contexto_id = ?',
        whereArgs: [contextoBackup],
      );
      final valores = ids.map((linha) => linha['id'] as int).toList();
      for (var inicio = 0; inicio < valores.length; inicio += 500) {
        final lote = valores.skip(inicio).take(500).toList();
        final colisoes = await atual.rawQuery(
          'SELECT id FROM $tabela WHERE contexto_id <> ? '
          'AND id IN (${List.filled(lote.length, '?').join(',')}) LIMIT 1',
          [contextoAtual, ...lote],
        );
        if (colisoes.isNotEmpty) {
          throw AppException(
            'A restauração foi cancelada: há IDs de $tabela em uso por outro contexto. '
            'Os dados atuais foram preservados.',
          );
        }
      }
    }
  }

  /// Restaura atomicamente somente as linhas individuais e mantém os outros
  /// contextos. Colisões globais de IDs são recusadas para não remapear dados.
  Future<void> restaurar(File origem) async {
    final preparado = await _prepararArquivoIndividual(origem);
    Database? backup;
    try {
      backup = await openDatabase(
        preparado.path,
        readOnly: true,
        singleInstance: false,
      );
      final db = await _obterBanco();
      final contextoAtual = await ContextoTrabalhoRepository.exigirIdAtivo(db);
      final contextoBackup = await ContextoTrabalhoRepository.exigirIdAtivo(
        backup,
      );
      await ContextoTrabalhoRepository.validarContextoIndividual(
        db,
        contextoEsperado: contextoAtual,
      );
      await ContextoTrabalhoRepository.validarContextoIndividual(
        backup,
        contextoEsperado: contextoBackup,
      );
      await _garantirIdsSemColisao(db, backup, contextoAtual, contextoBackup);

      final seguranca = _caminhoTemporario('estoque_uan_pre_restauracao');
      try {
        await _copiarBancoCompletoParaSeguranca(seguranca);
      } catch (_) {
        throw const AppException(
          'Não foi possível guardar a cópia de segurança. Nada foi alterado.',
        );
      }

      try {
        await db.transaction((transacao) async {
          for (final tabela in _ordemExclusao) {
            await transacao.delete(
              tabela,
              where: 'contexto_id = ?',
              whereArgs: [contextoAtual],
            );
          }
          for (final tabela in _ordemInsercao) {
            final linhas = await backup!.query(
              tabela,
              where: 'contexto_id = ?',
              whereArgs: [contextoBackup],
            );
            for (final linhaBackup in linhas) {
              final linha = Map<String, Object?>.from(linhaBackup)
                ..['contexto_id'] = contextoAtual;
              await transacao.insert(tabela, linha);
            }
          }
          final integridade = await transacao.rawQuery(
            'PRAGMA foreign_key_check',
          );
          if (integridade.isNotEmpty) {
            throw const AppException(
              'A restauração foi cancelada por falha de integridade.',
            );
          }
          final integridadeBanco = await _verificarIntegridade(transacao);
          if (integridadeBanco != null) {
            throw const AppException(
              'A restauração foi cancelada por falha de integridade.',
            );
          }
          await ContextoTrabalhoRepository.validarContextoIndividual(
            transacao,
            contextoEsperado: contextoAtual,
          );
        });
      } catch (e) {
        // A transação reverte os dados individuais; os demais contextos nunca
        // são incluídos nas operações de exclusão ou inserção.
        if (e is AppException) rethrow;
        throw const AppException(
          'Não foi possível restaurar o backup. Seus dados anteriores foram mantidos.',
        );
      }
    } finally {
      await backup?.close();
      await _apagarTemporarioSqlite(preparado);
    }
  }
}

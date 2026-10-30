import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:projeto_2/core/utils/app_exception.dart';

class BackupService {
  BackupService({
    required Future<Database> Function() obterBanco,
    required Future<void> Function() fecharBanco,
    required Future<String> Function() caminhoBanco,
  })  : _obterBanco = obterBanco,
        _fecharBanco = fecharBanco,
        _caminhoBanco = caminhoBanco;

  final Future<Database> Function() _obterBanco;
  final Future<void> Function() _fecharBanco;
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

  Future<void> _copiarBancoAtual(String destino) async {
    final db = await _obterBanco();
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    final caminho = await _caminhoBanco();
    await File(caminho).copy(destino);
  }

  /// Gera uma cópia do banco em um arquivo temporário e a devolve.
  Future<File> exportar() async {
    final destino = p.join(
      Directory.systemTemp.path,
      'backup_estoque_uan_${carimbo(DateTime.now())}.db',
    );
    try {
      await _copiarBancoAtual(destino);
    } catch (_) {
      throw AppException('Não foi possível gerar o backup.');
    }
    return File(destino);
  }

  /// Confere se o arquivo é um backup válido deste app.
  Future<void> validarArquivo(File arquivo) async {
    if (!await arquivo.exists()) {
      throw AppException('Arquivo não encontrado.');
    }
    final raf = await arquivo.open();
    final cabecalho = await raf.read(16);
    await raf.close();
    if (!temCabecalhoSqlite(cabecalho)) {
      throw AppException('O arquivo escolhido não é um backup válido do app.');
    }

    Database? bd;
    try {
      bd = await openDatabase(arquivo.path,
          readOnly: true, singleInstance: false);
      final linhas = await bd
          .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      final tabelas = linhas.map((l) => l['name'] as String).toSet();
      for (final t in _tabelasObrigatorias) {
        if (!tabelas.contains(t)) {
          throw AppException('O arquivo escolhido não é um backup deste app.');
        }
      }
      final integridade = await bd.rawQuery('PRAGMA integrity_check');
      if (integridade.isEmpty || integridade.first.values.first != 'ok') {
        throw AppException('O arquivo de backup está corrompido.');
      }
      final versaoBackup = await bd.getVersion();
      final versaoAtual = await (await _obterBanco()).getVersion();
      if (versaoBackup < 1) {
        throw AppException('O arquivo escolhido não é um backup deste app.');
      }
      if (versaoBackup > versaoAtual) {
        throw AppException(
            'Este backup foi criado por uma versão mais nova do app.');
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException('Não foi possível ler o arquivo de backup.');
    } finally {
      await bd?.close();
    }
  }

  Future<void> _apagarArquivosAuxiliares(String caminho) async {
    for (final sufixo in ['-wal', '-shm', '-journal', '.novo']) {
      final f = File('$caminho$sufixo');
      if (await f.exists()) await f.delete();
    }
  }

  Future<void> _reverter(String caminho, String seguranca) async {
    try {
      await _fecharBanco();
      await _apagarArquivosAuxiliares(caminho);
      await File(seguranca).copy('$caminho.novo');
      await File('$caminho.novo').rename(caminho);
    } catch (_) {
      // Último recurso: nada mais a fazer aqui.
    }
  }

  /// Substitui o banco atual pelo conteúdo de [origem]. Guarda antes uma
  /// cópia de segurança e reverte se algo falhar.
  Future<void> restaurar(File origem) async {
    await validarArquivo(origem);
    final caminho = await _caminhoBanco();
    final seguranca =
        '$caminho.pre_restauracao_${carimbo(DateTime.now())}.bak';

    try {
      await _copiarBancoAtual(seguranca);
    } catch (_) {
      throw AppException(
          'Não foi possível guardar a cópia de segurança. Nada foi alterado.');
    }

    await _fecharBanco();
    try {
      await _apagarArquivosAuxiliares(caminho);
      await origem.copy('$caminho.novo');
      await File('$caminho.novo').rename(caminho);

      final db = await _obterBanco();
      final r = await db.rawQuery('PRAGMA integrity_check');
      if (r.isEmpty || r.first.values.first != 'ok') {
        throw AppException('Falha na verificação de integridade.');
      }
    } catch (_) {
      await _reverter(caminho, seguranca);
      throw AppException(
          'Não foi possível restaurar o backup. Seus dados anteriores foram mantidos.');
    }
  }
}
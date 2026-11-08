import 'dart:io';

/// Fails when whole-project analysis differs from the documented legacy set.
///
/// The key includes severity, analyzer code, and project-relative path. Exact
/// counts ensure a new diagnostic in an already-known file is not ignored.
const legacyDiagnosticCounts = <String, int>{
  'warning|unnecessary_non_null_assertion|test/cenarios/a1_acesso_test.dart': 1,
  'warning|unused_import|test/cenarios/a2_catalogo_test.dart': 2,
  'info|use_build_context_synchronously|lib/features/backup/screens/backup_screen.dart':
      1,
  'info|unnecessary_underscores|lib/features/movimentacoes/screens/movimentacao_form_screen.dart':
      2,
  'info|deprecated_member_use|lib/features/movimentacoes/screens/movimentacao_form_screen.dart':
      1,
  'info|non_constant_identifier_names|lib/features/movimentacoes/screens/movimentacao_form_screen.dart':
      1,
  'info|unnecessary_underscores|lib/features/produtos/screens/categorias_screen.dart':
      1,
  'info|deprecated_member_use|lib/features/produtos/screens/produto_form_screen.dart':
      2,
  'info|unnecessary_underscores|lib/features/produtos/screens/unidades_screen.dart':
      1,
  'info|unnecessary_underscores|lib/features/produtos/widgets/produtos_lista_view.dart':
      2,
  'info|no_leading_underscores_for_local_identifiers|test/backup_arquivo_test.dart':
      2,
  'info|avoid_print|test/cenarios/a4_quantidades_test.dart': 1,
  'info|unnecessary_import|test/cenarios/apoio/banco_teste.dart': 1,
  'info|no_leading_underscores_for_local_identifiers|test/historico_repository_test.dart':
      3,
  'info|no_leading_underscores_for_local_identifiers|test/painel_repository_test.dart':
      3,
};

Future<void> main() async {
  final result = await Process.run('flutter', [
    'analyze',
    '--no-pub',
    '--machine',
  ], runInShell: Platform.isWindows);

  final actualCounts = <String, int>{};
  final unexpected = <String>[];
  final output = '${result.stdout}\n${result.stderr}';
  for (final rawLine in output.split(RegExp(r'\r?\n'))) {
    final fields = rawLine.split('|');
    final key = fields.length >= 5
        ? _machineDiagnosticKey(fields)
        : _humanDiagnosticKey(rawLine);
    if (key == null) continue;
    actualCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
  }

  for (final entry in actualCounts.entries) {
    final expected = legacyDiagnosticCounts[entry.key] ?? 0;
    if (entry.value > expected) {
      unexpected.add(
        '${entry.key}: ${entry.value} encontrado(s), $expected legado(s)',
      );
    }
  }
  for (final entry in legacyDiagnosticCounts.entries) {
    final actual = actualCounts[entry.key] ?? 0;
    if (actual < entry.value) {
      stdout.writeln(
        'Baseline legado removido: ${entry.key} ($actual/${entry.value}).',
      );
    }
  }

  if (actualCounts.isEmpty && !output.contains('No issues found!')) {
    stderr.write(output);
    stderr.writeln('flutter analyze terminou com código ${result.exitCode}.');
    exit(result.exitCode == 0 ? 1 : result.exitCode);
  }
  if (unexpected.isNotEmpty) {
    stderr.writeln(
      'Foram encontrados diagnósticos além do baseline documentado:',
    );
    for (final issue in unexpected) {
      stderr.writeln('  $issue');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Análise global aprovada: ${actualCounts.values.fold<int>(0, (a, b) => a + b)} '
    'diagnóstico(s), todos dentro do baseline documentado.',
  );
}

String? _machineDiagnosticKey(List<String> fields) {
  final severity = fields[0].toLowerCase();
  if (!{'error', 'warning', 'info'}.contains(severity)) return null;
  final code = fields[2].toLowerCase();
  final path = _projectRelativePath(fields[3]);
  return '$severity|$code|$path';
}

String? _humanDiagnosticKey(String line) {
  final match = RegExp(
    r'^\s*(error|warning|info)\s+•.*•\s+(.+?):\d+:\d+\s+•\s+([a-zA-Z0-9_]+)\s*$',
  ).firstMatch(line);
  if (match == null) return null;
  final severity = match.group(1)!.toLowerCase();
  final path = _projectRelativePath(match.group(2)!);
  final code = match.group(3)!.toLowerCase();
  return '$severity|$code|$path';
}

String _projectRelativePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  for (final marker in ['/lib/', '/test/', '/tool/']) {
    final index = normalized.lastIndexOf(marker);
    if (index >= 0) return normalized.substring(index + 1);
  }
  return normalized;
}

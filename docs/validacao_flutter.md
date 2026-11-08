# Diagnósticos legados do Flutter

Referência da análise global em **08/11/2026**, com Flutter 3.44.5 e Dart
3.12.2, sobre a base integrada `d8bbdc7` (master após o PR #2). Esses
diagnósticos já existem fora da implementação de autenticação remota desta
etapa. O workflow `.github/workflows/flutter-validation.yml` faz análise com
avisos e informações fatais nos arquivos de autenticação, roteamento, providers
Supabase e Drawer alterados, além de executar a suíte completa. Assim, o
baseline alheio a este escopo não mascara novos diagnósticos na superfície
alterada.

## Avisos existentes na base

| Arquivo e linha | Diagnóstico | Motivo |
| --- | --- | --- |
| `test/cenarios/a1_acesso_test.dart:43` | `unnecessary_non_null_assertion` | O receptor do operador `!` já é não nulo. |
| `test/cenarios/a2_catalogo_test.dart:7` | `unused_import` | Import de `unidade_repository.dart` sem uso. |
| `test/cenarios/a2_catalogo_test.dart:8` | `unused_import` | Import de `categoria_repository.dart` sem uso. |

## Informações existentes em arquivos rastreados

| Arquivo e linha | Diagnóstico | Motivo |
| --- | --- | --- |
| `lib/features/backup/screens/backup_screen.dart:102` | `use_build_context_synchronously` | Uso de `BuildContext` após intervalo assíncrono. |
| `lib/features/movimentacoes/screens/movimentacao_form_screen.dart:129` | `unnecessary_underscores` | Parâmetros de callback usam mais de um `_`. |
| `lib/features/movimentacoes/screens/movimentacao_form_screen.dart:331` | `deprecated_member_use` | `DropdownButtonFormField.value` foi substituído por `initialValue`. |
| `lib/features/movimentacoes/screens/movimentacao_form_screen.dart:449` | `unnecessary_underscores` | Parâmetros de callback usam mais de um `_`. |
| `lib/features/movimentacoes/screens/movimentacao_form_screen.dart:565` | `non_constant_identifier_names` | `_TipoSegment` não segue lowerCamelCase. |
| `lib/features/produtos/screens/categorias_screen.dart:200` | `unnecessary_underscores` | Callback usa parâmetros `_` e `__`. |
| `lib/features/produtos/screens/produto_form_screen.dart:285` | `deprecated_member_use` | `DropdownButtonFormField.value` foi substituído por `initialValue`. |
| `lib/features/produtos/screens/produto_form_screen.dart:323` | `deprecated_member_use` | `DropdownButtonFormField.value` foi substituído por `initialValue`. |
| `lib/features/produtos/screens/unidades_screen.dart:163` | `unnecessary_underscores` | Callback usa mais de um `_`. |
| `lib/features/produtos/widgets/produtos_lista_view.dart:98` | `unnecessary_underscores` | Callback usa mais de um `_`. |
| `lib/features/produtos/widgets/produtos_lista_view.dart:438` | `unnecessary_underscores` | Callback usa mais de um `_`. |
| `test/backup_arquivo_test.dart:36` | `no_leading_underscores_for_local_identifiers` | Variável local `_servico` começa com `_`. |
| `test/backup_arquivo_test.dart:42` | `no_leading_underscores_for_local_identifiers` | Variável local `_criarBackupFake` começa com `_`. |
| `test/cenarios/a4_quantidades_test.dart:36` | `avoid_print` | Uso de `print` em teste. |
| `test/cenarios/apoio/banco_teste.dart:1` | `unnecessary_import` | `sqflite` é reexportado por `sqflite_common_ffi`. |
| `test/historico_repository_test.dart:16` | `no_leading_underscores_for_local_identifiers` | Variável local `_inserirUsuario` começa com `_`. |
| `test/historico_repository_test.dart:28` | `no_leading_underscores_for_local_identifiers` | Variável local `_inserirProduto` começa com `_`. |
| `test/historico_repository_test.dart:40` | `no_leading_underscores_for_local_identifiers` | Variável local `_inserirMov` começa com `_`. |
| `test/painel_repository_test.dart:15` | `no_leading_underscores_for_local_identifiers` | Variável local `_inserirUsuario` começa com `_`. |
| `test/painel_repository_test.dart:27` | `no_leading_underscores_for_local_identifiers` | Variável local `_inserirProduto` começa com `_`. |
| `test/painel_repository_test.dart:43` | `no_leading_underscores_for_local_identifiers` | Variável local `_inserirMov` começa com `_`. |

Em um checkout Git limpo, a análise global da base informa **24 diagnósticos**:
3 avisos e 21 informações. O diretório de trabalho usado nesta etapa também
contém o arquivo preexistente e não rastreado
`test/backup_exportacao_arquivo_test.dart`, que acrescenta duas informações
locais (`no_leading_underscores_for_local_identifiers:35` e
`await_only_futures:43`); ele não faz parte do baseline publicado nem desta
alteração. Por isso, a análise global local informa 26 diagnósticos. Nenhum
diagnóstico da análise direcionada desta etapa foi encontrado.

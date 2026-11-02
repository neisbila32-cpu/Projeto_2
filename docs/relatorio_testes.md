# Relatório de Testes — Cenários A

Testes de cenários A (`test/cenarios/`), executados com `flutter test`.

## Resumo

- Total de testes: 51
- Passou: 50
- Removido/ajustado: 1 (suposição errada no teste a3 — nome com letra extra não é duplicata)
- BUG documentado (skip): 0
- Resultados: todos os testes passaram (o BUG da unicidade de login com acento foi corrigido)

## Tabela de resultados

| Teste | Resultado | O que foi observado | Gravidade |
|-------|-----------|---------------------|-----------|
| A1: cadastrar primeiro usuário vira administrador e recebe código XXXX-XXXX-XXXX | passou | Primeiro cadastro vira admin, código no formato esperado, senha não está em texto puro | - |
| A1: login correto | passou | Autenticação com credenciais válidas retorna o usuário | - |
| A1: senha errada é rejeitada | passou | Lança AuthException com senha incorreta | - |
| A1: login inexistente é rejeitado | passou | Lança AuthException para login não cadastrado | - |
| A1: login repetido é recusado (mesmo com maiúsculas e acentos diferentes) | passou | Unicidade de login agora ignora acentos e maiúsculas; `joão`, `JOAO`, `joão` são recusados após `joao`; `joao2` é aceito | - |
| A1: segundo usuário vira operador | passou | Segundo cadastro recebe perfil 'operador' | - |
| A1: recuperação por código só funciona para o administrador e gera um código novo | passou | Admin recupera e invalida código antigo; operador não pode recuperar | - |
| A1: usuário inativo não consegue entrar | passou | Usuário com `ativo = 0` é rejeitado na autenticação | - |
| A1: senha nunca aparece em texto puro no banco | passou | `senha_hash` e `senha_salt` diferem da senha em texto puro | - |
| A2: importar o catálogo cria 91 produtos | passou | Importação inicial cria 91 produtos, 0 ignorados | - |
| A2: importar de novo cria 0 e ignora 91 | passou | Reimportação é idempotente: 0 criados, 91 ignorados | - |
| A2: todos com saldo 0 e nenhuma movimentação criada | passou | Produtos importados nascem com saldo 0, sem movimentações | - |
| A2: a unidade fr existe | passou | Unidade 'fr' está cadastrada | - |
| A2: as 6 categorias do catálogo existem e ficam ativas | passed | 6 categorias do catálogo existem e estão ativas | - |
| A2: as categorias de fábrica sem produtos ficam inativas | passou | Categorias de fábrica sem produto do catálogo ficam inativas | - |
| A3: produto nasce com saldo 0 e ativo | passou | Novo produto tem saldo 0 e ativo = true | - |
| A3: nome duplicado é recusado (arroz branco x Arroz Branco x variações com acento) | passou | Maiúsculas e acentos (â→a) são detectados como duplicata | - |
| A3: só inativa com saldo zero; reativa | passou | Inativa só com saldo 0; reativação funciona | - |
| A3: busca ignora maiúsculas e acentos (feijao acha Feijão) | passou | Busca normalizada encontra produto com acento | - |
| A3: filtro por categoria | passou | Filtro retorna apenas produtos da categoria informada | - |
| A3: unidade fica travada depois da primeira movimentação | passou | Alterar unidade após movimentação lança AppException | - |
| A4: QuantidadeUtils (casos de entrada decimal, inteira, inválida) | passou | Cada caso registra o comportamento observado; valores esperados são validados | - |

## BUGs encontrados

| # | Teste | Descrição | Gravidade |
|---|-------|-----------|-----------|
| 1 | A1 — login repetido é recusado (mesmo com maiúsculas e acentos diferentes) | Corrigido: a validação de unicidade de login agora usa `TextoUtils.normalizar`, que ignora acentos e maiúsculas. `joão`, `JOAO`, `joão` são recusados após `joao` já existir. | - |

## O que foi removido / ajustado

- `test/cenarios/a3_produtos_test.dart`: o caso "nome duplicado" usava `arroz brançao` como suposta variação de acento de `arroz branco`. Como `brançao` normaliza para `brancao` (letra `a` extra entre `c` e `o`), não é duplicata. O teste foi ajustado para usar `arroz brânco` (â → a), que é de fato uma variação de acento. Não houve remoção de teste, apenas correção da suposição errada.
- `test/cenarios/a1_acesso_test.dart`: o teste "login repetido é recusado" foi mantido com `skip: 'BUG: ...'` porque expõe um comportamento real incorreto do app.

## Tarefa B1 — Movimentações e consistência do saldo

Testes de cenários B1 (`test/cenarios/b1_movimentacoes_test.dart`), executados com `flutter test`. Não houve alteração em `lib/`.

### Resumo
- Total de testes: 18
- Passou: 18
- Falhou: 0
- BUG documentado (skip): 0

### Tabela de resultados

| Cenário | Resultado | Evidência | Gravidade | Sugestão |
|---------|-----------|-----------|-----------|----------|
| B1.1 Dia na UAN: admin + operador, importação do catálogo, entradas em 12 produtos de 6 unidades (kg fracionável, pct, un, cx, bandeja, fr), saídas (produção, transferência, outra), 1 perda com motivo e 1 ajuste com justificativa | passou | Delta, saldo_apos, responsável e finalidade (só saídas) conferidos em cada movimentação; saldo final de cada produto confere com o esperado | - | - |
| B1.2 Erros comuns (10 casos): saída > saldo, saída sem finalidade, perda sem motivo, ajuste mesmo saldo, ajuste sem justificativa, ajuste negativo, qtd zero, fração em unidade contável, produto inativo, produto inexistente | passou | Cada erro lança `AppException` com mensagem em português esperada; saldo e quantidade de movimentações do produto permanecem iguais aos de antes (nada gravado) | - | - |
| B1.3 Integridade: movimentação direta no banco com produto inexistente, usuário inexistente e delta 0 | passou | Banco rejeita todas as três (foreign keys e restrição `CHECK (delta <> 0)` com `PRAGMA foreign_keys = ON`); nenhuma linha gravada | - | - |
| B1.3 Busca em lib/ de código que edita ou apaga movimentações | passado | Nenhuma ocorrência de `DELETE FROM movimentacoes`, `db.delete('movimentacoes')` nem `update('movimentacoes')` em `lib/`; somente `INSERT` em `movimentacao_repository.dart` | - | - |
| B1.3 Unidade travada depois da 1ª movimentação | passou | `produtoTemMovimentacoes` retorna `true` após a 1ª movimentação; alterar a unidade lança `AppException` | - | - |
| B1.4 Concorrência: 20 chamadas de `registrar()` simultâneas (`Future.wait`) no mesmo produto, entradas e saídas válidas | passou | Soma dos deltas = 5000; saldo final = 105000 (= saldo inicial + soma dos deltas); cada `saldo_apos` coerente com a ordem de gravação (por id); saldo nunca negativo | - | - |
| B1.5 Invariante aleatória: `Random(42)`, 300 operações (válidas e inválidas) em 15 produtos | passou | Por produto: `saldo = soma dos deltas`; último `saldo_apos` = saldo do produto; `saldo_apos` nunca negativo; `saldo_apos` de cada movimento = anterior + delta (ordenado por id) | - | - |
| B1.6 Atribuição: responsável no histórico | passado | `HistoricoRepository.consultar` retorna `usuarioId` e `usuarioNome` corretos para admin e operador (ordem de gravação respeitada) | - | - |

### O que NÃO foi testado (B1)

- Telas e widgets (testes de interface) — os cenários testam apenas camada de repositórios.
- Persistência em banco de arquivo com múltiplas conexões (os testes usam banco em memória via FFI; o app é single-device).
- Filtros de data/tipo do `HistoricoRepository.consultar` além de `produtoId` e `limite`.
- Movimentação vinculada a inventário (`inventario_id`) na camada de integridade.
- Operações de ajuste que baixem estoque em cenário de estoque baixo isolado (coberto indiretamente por B1.5).

## O que NÃO foi testado

- Telas e widgets (testes de interface) — os cenários A testam apenas camada de repositórios e utilitários.
- Movimentações de saída/perda/ajuste e cálculo de saldo em cenários de estoque baixo.
- Inventário e seus itens.
- Relatórios e exportação.
- Autenticação via recuperação de senha para operador (coberto apenas como "não pode").
- Persistência em banco de arquivo (os testes usam banco em memória via FFI).

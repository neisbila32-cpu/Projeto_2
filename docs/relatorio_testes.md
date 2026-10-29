# Relatório de Testes — Cenários A

Testes de cenários A (`test/cenarios/`), executados com `flutter test`.

## Resumo

- Total de testes: 51
- Passou: 50
- Removido/ajustado: 1 (suposição errada no teste a3 — nome com letra extra não é duplicata)
- BUG documentado (skip): 1 (a1 — login com acento diferente aceito como único)
- Resultados: todos os testes passaram (o BUG está marcado com `skip`)

## Tabela de resultados

| Teste | Resultado | O que foi observado | Gravidade |
|-------|-----------|---------------------|-----------|
| A1: cadastrar primeiro usuário vira administrador e recebe código XXXX-XXXX-XXXX | passou | Primeiro cadastro vira admin, código no formato esperado, senha não está em texto puro | - |
| A1: login correto | passou | Autenticação com credenciais válidas retorna o usuário | - |
| A1: senha errada é rejeitada | passou | Lança AuthException com senha incorreta | - |
| A1: login inexistente é rejeitado | passou | Lança AuthException para login não cadastrado | - |
| A1: login repetido é recusado (mesmo com maiúsculas e acentos diferentes) | BUG (skip) | Login com acento diferente (`joão` vs `joao`) é aceito como único; a unicidade ignora acentos | alta |
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
| 1 | A1 — login repetido é recusado (mesmo com maiúsculas e acentos diferentes) | Cadastro com login `joão` é aceito após `joao` já existir. A validação de unicidade de login normaliza maiúsculas mas **não remove acentos**, permitindo duplicatas de login que diferem apenas por acento. | alta |

## O que foi removido / ajustado

- `test/cenarios/a3_produtos_test.dart`: o caso "nome duplicado" usava `arroz brançao` como suposta variação de acento de `arroz branco`. Como `brançao` normaliza para `brancao` (letra `a` extra entre `c` e `o`), não é duplicata. O teste foi ajustado para usar `arroz brânco` (â → a), que é de fato uma variação de acento. Não houve remoção de teste, apenas correção da suposição errada.
- `test/cenarios/a1_acesso_test.dart`: o teste "login repetido é recusado" foi mantido com `skip: 'BUG: ...'` porque expõe um comportamento real incorreto do app.

## O que NÃO foi testado

- Telas e widgets (testes de interface) — os cenários A testam apenas camada de repositórios e utilitários.
- Movimentações de saída/perda/ajuste e cálculo de saldo em cenários de estoque baixo.
- Inventário e seus itens.
- Relatórios e exportação.
- Autenticação via recuperação de senha para operador (coberto apenas como "não pode").
- Persistência em banco de arquivo (os testes usam banco em memória via FFI).

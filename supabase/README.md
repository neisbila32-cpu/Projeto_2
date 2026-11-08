# Backend Supabase — desenvolvimento local

Esta pasta contém a fundação de áreas compartilhadas. Ela não é usada pelo app Flutter nesta etapa e não conecta nem migra o SQLite local.

## Conteúdo

- `migrations/`: migrações PostgreSQL incrementais para aplicar somente a um projeto Supabase.
- `tests/database/`: testes pgTAP de autorização, isolamento, administração e convites.
- `tests/concurrent_invite_acceptance.sh`: teste de uso simultâneo do mesmo convite em duas sessões PostgreSQL.
- `scripts/prepare_concurrent_invite.sql`: prepara contas e convite somente para a disputa no banco local descartável.
- `config.toml`: configuração isolada para iniciar o Supabase local. Não contém credenciais.

## Integração contínua

O workflow `.github/workflows/supabase-tests.yml` roda em `ubuntu-latest` na branch
`codex/supabase-ci`, inicia um Supabase local descartável, reaplica as migrações com
`supabase db reset --local --no-seed`, executa `supabase test db` e então disputa o
mesmo convite em duas conexões locais. Não há `supabase link`, credenciais remotas ou
dados da UAN real no processo.

## Preparação local

Pré-requisitos: Docker e Supabase CLI instalados fora das dependências Flutter. Não use a URL ou as credenciais de produção nos testes.

```sh
supabase start
supabase status
supabase db reset
supabase test db
```

`db reset` recria somente o banco descartável do Supabase local. Antes de executá-lo, confirme que `supabase status` aponta para a instância de desenvolvimento. A configuração não inclui seed de dados.

## O que a migração implementa

- UANs identificadas por UUID e associação do criador autenticado como administrador inicial.
- Membros vinculados a `auth.users`, com papéis `admin` e `operator` e estados `active`, `suspended` e `removed`.
- Convites de uso único vinculados ao e-mail confirmado da conta Supabase. A validade padrão é de 24 horas; o administrador pode alterá-la entre 1 hora e 30 dias.
- Código aleatório de 256 bits gerado no servidor. O código é retornado uma vez pela função de emissão; o banco persiste apenas SHA-256 do token.
- Aceitação transacional com bloqueio de linhas, validação de validade, revogação, uso único e correspondência do e-mail autenticado.
- Auditoria administrativa sem armazenar o código do convite.
- RLS de leitura por associação ativa; convites e auditoria são legíveis somente por administradores ativos. Escritas passam por RPCs `SECURITY DEFINER` com `search_path` fixo e execução concedida somente a `authenticated`.
- Bloqueio de remoção ou rebaixamento do último administrador ativo, com serialização por bloqueio da linha da UAN.

## Teste concorrente

Use uma UAN, usuário, e-mail confirmado e convite descartáveis criados exclusivamente na instância local. O teste consome o convite e recusa URLs não locais:

```sh
DATABASE_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
WORKSPACE_ID='UUID-DA-UAN' \
INVITED_USER_ID='UUID-DA-CONTA' \
INVITED_EMAIL='pessoa@exemplo.test' \
INVITE_CODE='CODIGO-PENDENTE' \
sh supabase/tests/concurrent_invite_acceptance.sh
```

O resultado esperado é uma sessão aceitar o convite, a outra ser recusada, e existir exatamente um vínculo ativo para a conta.

## Limites desta etapa

Não há autenticação no Flutter, telas, sincronização, políticas de tabelas de estoque, Edge Functions, envio de e-mail nem transferência de dados locais. A migração SQL e os testes precisam ser executados e aprovados em uma instância PostgreSQL Supabase local antes de qualquer uso. Políticas RLS e RPCs ainda não estão validadas em PostgreSQL real neste ambiente.

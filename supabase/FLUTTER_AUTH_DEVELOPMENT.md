# Autenticação Supabase no aplicativo Flutter

As áreas compartilhadas usam uma conta remota individual, separada do login e
da sessão SQLite locais. O aplicativo não envia produtos, saldos ou outros
dados do estoque ao Supabase nesta etapa. Sem URL e chave publicável fornecidas
na compilação, a tela informa que a conexão está indisponível e o modo local
continua funcionando.

## Configuração de um projeto de desenvolvimento

Use apenas um projeto Supabase de desenvolvimento. No painel:

1. Habilite o provedor **Email** e mantenha a confirmação de e-mail ativada.
2. Na lista de URLs de redirecionamento permitidas do Auth, adicione:
   - `estoqueuan://auth-callback/areas-compartilhadas?fluxo=email-confirmado`
   - `estoqueuan://auth-callback/areas-compartilhadas?fluxo=nova-senha`
3. Mantenha os modelos oficiais de confirmação e recuperação usando o link de
   confirmação padrão do Supabase (`{{ .ConfirmationURL }}`).
4. Para testes reais de envio, configure um SMTP próprio de desenvolvimento e
   limites de envio apropriados. A interface trata respostas de limite de
   solicitações e não revela se um e-mail existe no fluxo de recuperação.

O Android declara o esquema `estoqueuan` e o host `auth-callback` no manifesto.
O SDK `supabase_flutter` processa o retorno do Auth; o roteador encaminha o
evento `passwordRecovery` ao formulário de nova senha. A sessão e os eventos
remotos não alteram a sessão SQLite.

## Executar localmente

Passe a URL e a chave publicável durante a compilação/execução. Não grave valores
reais em arquivos versionados nem compartilhe a saída de comandos que contenham
as definições:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_SUA_CHAVE
```

Use somente a chave `sb_publishable_` do projeto. A compatibilidade legada
aceita apenas JWT cujo papel seja `anon`. Nunca use `service_role`,
`sb_secret_`, senhas administrativas ou tokens de usuário como chave de build.

## Fluxos disponíveis

- Cadastro e login por e-mail e senha.
- Confirmação e reenvio de e-mail.
- Solicitação de recuperação; a resposta é genérica para evitar enumeração de
  contas.
- Atualização de senha após retorno com sessão de recuperação válida.
- Logout remoto e acompanhamento dos eventos de sessão do SDK, incluindo
  recuperação, encerramento e falha de conexão.

O projeto remoto desta etapa ainda não foi configurado. Portanto, envio de
mensagens, allowlist de redirects, expiração de sessão e recuperação por e-mail
foram verificados com implementações controladas nos testes, não contra um
servidor Auth real. O fluxo real precisa ser validado em um projeto de
desenvolvimento antes de uso operacional.

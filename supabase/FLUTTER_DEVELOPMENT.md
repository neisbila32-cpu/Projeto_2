# Configuração do cliente Supabase no Flutter

A integração do app com Supabase é opcional. Sem as duas definições de compilação,
o bootstrap não inicializa o SDK, não tenta se conectar e mantém o login e os dados
SQLite no modo individual offline.

## Executar sem Supabase

```sh
flutter run
```

## Executar com Supabase

Forneça a URL do projeto e uma chave publicável no momento da compilação:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_SUA_CHAVE
```

Use os mesmos parâmetros no `flutter build` para compilar APKs. Não coloque valores
reais em arquivos versionados, exemplos, scripts compartilhados ou no `pubspec.yaml`.
Chaves `sb_secret_` e chaves JWT com papel `service_role` são rejeitadas. Chaves anon
JWT legadas só são aceitas quando o papel decodificado é `anon`.

Para o Supabase local acessado pelo emulador Android, a URL normalmente usa
`http://10.0.2.2:54321`; para chamadas feitas no próprio computador, use
`http://127.0.0.1:54321`. HTTP só é aceito para esses endereços locais. URLs remotas
precisam usar HTTPS.

## Escopo atual

`supabaseRuntimeProvider` e `supabaseClientProvider` fornecem acesso opcional ao SDK.
`autenticacaoRemotaProvider` disponibiliza a interface isolada do cliente Auth quando
há configuração válida. Ela ainda não está conectada ao login local, às rotas ou a
telas: cadastro, login remoto, troca de contexto e sincronização pertencem a etapas
posteriores. Nenhuma chave administrativa deve ser distribuída no aplicativo.

# Distribuição Android do Estoque UAN

Este projeto prepara a compilação direta por APK. Ele não publica o aplicativo na Play Store nem envia APKs a usuários.

## Identidade e compatibilidade

- Nome exibido: **Estoque UAN**.
- Ícone: os recursos `ic_launcher` existentes em `android/app/src/main/res/mipmap-*` foram preservados.
- `applicationId` e `namespace`: `com.example.meu_app_android`.
- Android mínimo: API 24 (Android 7.0), fixado no Gradle e confirmado no APK debug da etapa.
- `targetSdk`: 36 no APK debug da etapa.
- SQLite permanece na versão 4; a autenticação é local e o app não depende de Supabase ou de outro servidor.
- A permissão `INTERNET` aparece apenas nos manifests `debug` e `profile`, para ferramentas de desenvolvimento Flutter; não está no manifest principal de produção. O aplicativo não usa rede para autenticação ou dados.
- Versionamento Flutter: `MAJOR.MINOR.PATCH+BUILD`; o `BUILD` é o `versionCode` Android e deve aumentar em cada APK que atualize outro. O nome da versão segue `versionName`. O projeto passa de `1.0.0+1` para `1.0.0+2`.

O identificador `com.example.meu_app_android` é provisório e genérico. Mantê-lo evita separar os dados das instalações atuais, mas pode colidir com outro aplicativo e fixa esse pacote nas atualizações futuras. Trocar o identificador cria outro aplicativo, com diretório SQLite separado; a troca requer uma migração planejada e backup exportado pelo próprio app. Não o altere até definir um namespace final controlado pelo responsável pelo projeto.

## Instalações atuais e assinatura

As instalações de desenvolvimento usam uma chave debug, que não é versionada e pode variar entre computadores. O APK release deve usar uma chave release estável, criada e controlada pelo responsável. Como a assinatura atual do Motorola é debug, um APK release assinado com uma chave nova **não poderá ser instalado por cima dessa instalação**. O Android exige certificado igual para uma atualização. Antes da primeira distribuição, defina uma migração: exportar e validar o backup local, instalar a primeira versão release como instalação nova e restaurar manualmente o backup validado. Não desinstale nem restaure automaticamente durante esta preparação.

Não existe uma chave release neste repositório. A tarefa `flutter build apk --release` falha até que a assinatura release esteja configurada. O build release nunca usa a chave debug como fallback.

## Configurar e guardar a chave release

1. Escolha o nome/identificador definitivo do alias e crie a chave em uma estação controlada, usando um `keytool` confiável e uma senha forte. Não crie a chave em CI compartilhada nem neste repositório.
2. Faça duas cópias criptografadas e independentes do keystore em locais controlados, com acesso restrito; guarde as senhas em um gerenciador seguro separado. Perder a chave ou as senhas impede assinar atualizações com a mesma identidade.
3. Copie `android/key.properties.example` para `android/key.properties` e preencha `storeFile`, `keyAlias`, `keyPassword` e `storePassword`. O caminho de `storeFile` é relativo à pasta `android/`; uma opção é `app/estoque-uan-release.jks`.
4. Alternativamente, defina `ANDROID_KEYSTORE_PATH`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` e `ANDROID_STORE_PASSWORD` no ambiente local protegido. Variáveis de ambiente têm precedência sobre o arquivo.
5. Verifique `git status` e `git check-ignore` para confirmar que `android/key.properties` e o keystore estão ignorados. Nunca os adicione ao Git, ao PR, a logs ou a artefatos públicos.
6. Com as credenciais válidas disponíveis, compile com `flutter build apk --release`. Antes de distribuir, valide o certificado do APK com `apksigner`, confirme `applicationId` e `versionCode`, teste a instalação/atualização em um aparelho de teste e valide backup/restauração.

O repositório não gera a chave automaticamente, não guarda senhas e não contém credenciais de assinatura.

## Compilar e instalar APK diretamente

Para um APK de desenvolvimento:

```sh
flutter build apk --debug
```

Para distribuir um APK release assinado:

```sh
flutter build apk --release
```

O APK release só deve ser compartilhado depois de validar assinatura, identidade e versão. Distribua-o por um canal controlado e instrua cada usuário a manter uma cópia externa atualizada do backup. Para atualizações, preserve o mesmo `applicationId`, o mesmo certificado release e aumente o `versionCode`; instale com atualização normal, sem limpar dados. Faça primeiro um teste em aparelho isolado e valide o SQLite antes de atualizar dados de produção.

O APK debug e o APK release não são intercambiáveis como atualizações quando suas assinaturas diferem. A primeira transição de instalações debug existentes para a chave release requer o fluxo de backup e migração descrito acima.

## Verificações desta etapa

O projeto mantém o login local, SQLite v4, backup/restauração e compartilhamento nativo de arquivos. As dependências de produção do `pubspec.yaml` não incluem Supabase. Builds release permanecem bloqueados até haver configuração local válida de assinatura.

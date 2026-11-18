# Distribuição Android do Estoque UAN

Este projeto prepara APKs para distribuição controlada. Não publica automaticamente na Play Store nem envia APKs a usuários.

## Identidade e compatibilidade

- Nome exibido: **Estoque UAN**. O ícone existente foi preservado.
- `applicationId` e `namespace` de distribuição: `com.github.neisbila32cpu.estoqueuan`. O identificador usa a conta proprietária do repositório como raiz e deve permanecer estável depois da primeira distribuição.
- Android mínimo: API 24 (Android 7.0); `targetSdk` acompanha o Flutter SDK configurado.
- SQLite permanece na versão 4. Login, cadastro e recuperação são locais; não há sincronização nem dependência de Supabase.
- `INTERNET` é concedida apenas nos manifests `debug` e `profile`, para ferramentas de desenvolvimento. O APK release não declara essa permissão.
- Versão Flutter: `MAJOR.MINOR.PATCH+BUILD`; `BUILD` vira `versionCode` Android e deve aumentar em cada atualização. `versionName` é a versão exibida pelo Android.

O identificador anterior de desenvolvimento era `com.example.meu_app_android`. A nova identidade não migra dados: Android cria outro espaço de armazenamento para o novo pacote. Instalações existentes com o pacote anterior, inclusive a instalação debug do Motorola, permanecem separadas e não são modificadas por esta preparação. Não desinstale nem limpe dados para tentar combinar as instalações. Faça uma exportação e restauração planejada somente quando houver necessidade real de migrar registros.

## Assinatura e proteção da chave

O keystore release fica fora do repositório e as credenciais não são versionadas. A configuração de build aceita `android/key.properties` local ignorado pelo Git ou variáveis de ambiente no processo de build. Não grave senhas em código, workflows, logs, tickets, PRs ou arquivos compartilhados.

Mantenha duas cópias criptografadas e independentes do keystore em mídias externas controladas. Verifique que cada cópia pode ser lida e que seu hash corresponde ao original. Guarde as senhas num gerenciador de senhas separado dos arquivos. Não distribua a primeira versão até concluir essas cópias: sem o certificado original não é possível assinar atualizações reconhecidas como a mesma instalação.

Para confirmar que os arquivos locais de configuração continuam ignorados, use `git check-ignore` para `android/key.properties` e o keystore. Nunca envie esses arquivos ao GitHub.

## Instalar e atualizar

O guia para quem usa o app está em [`guia_usuario_android.md`](guia_usuario_android.md). Distribua APKs apenas por um canal controlado, acompanhados da versão e SHA-256 conferidos. Antes de uma atualização, faça e valide backup. Atualizações futuras precisam manter o mesmo `applicationId` e certificado e usar `versionCode` maior; instale por cima sem limpar dados.

O APK debug e o release não podem substituir um ao outro se os certificados forem diferentes. O pacote de distribuição novo também tem banco local próprio e separado do pacote de desenvolvimento antigo.

## Verificações desta etapa

Os testes automatizados validam login local, operações de estoque, SQLite v4, backup/restauração, relatórios e compartilhamento de arquivos. Eles não substituem a instalação limpa e a validação offline em aparelho Android de teste. Nenhum aparelho deve ser desinstalado, limpo ou atualizado sem backup validado.

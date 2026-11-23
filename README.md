# Estoque UAN

Aplicativo Flutter exclusivamente offline para controlar o estoque de uma Unidade de Alimentação e Nutrição (UAN). O SQLite no aparelho é a fonte de verdade dos dados. Login, cadastro e recuperação de acesso são locais; não há autenticação remota nem sincronização.

**Versão final: 1.1.3 (versionCode 6).** Este release acrescenta os créditos de autoria à versão 1.1.2. Consulte o [relatório de encerramento](docs/encerramento.md) para os resultados da validação, o SHA-256 do APK e a pendência de proteção da chave de assinatura.

## Autoria

Desenvolvido por **Neis Bila de Alencar**.

© 2026 Neis Bila de Alencar. Todos os direitos reservados.

Este aviso se refere ao Estoque UAN. As fontes e bibliotecas de terceiros mantêm suas licenças, incluindo a [licença Apache 2.0 da fonte Roboto](assets/fonts/Roboto-LICENSE.txt).

## Funcionalidades

- Cadastro e autenticação local de usuários, com perfis de administrador e operador.
- Catálogo inicial, cadastro de produtos, categorias e unidades.
- Movimentações de entrada, saída, perda e ajuste, com histórico por responsável.
- Painel com indicadores de estoque e inventário físico com ajuste pela contagem.
- Relatórios de posição atual e movimentações, com exportação em PDF.
- Exportação e restauração de backup do banco SQLite.
- Compartilhamento nativo de relatórios e arquivos de backup gerados offline.
- Preferência de tema do aplicativo e guia rápido de uso.

As quantidades são armazenadas como inteiros em milésimos. Por exemplo, `1,5 kg` é guardado como `1500`.

## Desenvolvimento

O projeto usa Flutter, Riverpod, `go_router` e `sqflite`. Para preparar as dependências e iniciar o app em um dispositivo Android:

```sh
flutter pub get
flutter run
```

Para executar as verificações automatizadas:

```sh
flutter analyze
flutter test
```

Os testes de banco usam SQLite em memória via `sqflite_common_ffi`.

## Distribuição Android

Consulte [`docs/distribuicao_android.md`](docs/distribuicao_android.md) para a identidade Android mantida, versionamento, assinatura release, proteção da chave e instalação de atualizações por APK. Nenhum APK é publicado automaticamente.

O passo a passo para instalar e usar o aplicativo está em [`docs/guia_usuario_android.md`](docs/guia_usuario_android.md).

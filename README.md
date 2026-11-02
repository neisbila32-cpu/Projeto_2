# Estoque UAN

Aplicativo Flutter local para controlar o estoque de uma Unidade de Alimentação e Nutrição (UAN). Os dados ficam no banco SQLite do aparelho.

## Funcionalidades

- Cadastro e autenticação local de usuários, com perfis de administrador e operador.
- Catálogo inicial, cadastro de produtos, categorias e unidades.
- Movimentações de entrada, saída, perda e ajuste, com histórico por responsável.
- Painel com indicadores de estoque e inventário físico com ajuste pela contagem.
- Relatórios de posição atual e movimentações, com exportação em CSV.
- Exportação e restauração de backup do banco SQLite.
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

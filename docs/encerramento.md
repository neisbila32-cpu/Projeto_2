# Encerramento do Estoque UAN

Em 23 de novembro de 2026, o responsável pelo projeto aprovou os testes físicos que realizou no Samsung Galaxy A05 com a versão **1.1.2 (versionCode 5)** e autorizou o encerramento do desenvolvimento.

## Release final de autoria

A versão **1.1.3 (versionCode 6)** acrescenta a identificação de autoria em **Configurações → Sobre o aplicativo** e na documentação. A tela consulta a versão instalada no Android.

**Desenvolvido por Neis Bila de Alencar**

© 2026 Neis Bila de Alencar. Todos os direitos reservados.

O aviso se refere à autoria do aplicativo e não cria uma licença de software. A revisão dos arquivos versionados não identificou uma licença geral para o projeto. A [licença Apache 2.0 da fonte Roboto](../assets/fonts/Roboto-LICENSE.txt) e as licenças aplicáveis às dependências de terceiros continuam em vigor.

Os 195 testes automatizados passaram, incluindo os testes da seção Sobre. A análise estática manteve os 24 diagnósticos do baseline. A validação física registrada abaixo se refere à 1.1.2.

| Item | Release final |
|---|---|
| Arquivo | `Estoque-UAN-v1.1.3.apk` |
| Tamanho | 62.331.832 bytes |
| SHA-256 do APK | `054C6744A1779B4E20D6C963450E0AEBDAA11971ADC7B8B9C04538AAED1F116C` |
| Identificador Android | `com.github.neisbila32cpu.estoqueuan` |
| Compatibilidade | Android 7.0 (API 24) ou superior |
| Assinatura | v2, com o mesmo certificado da versão 1.1.2 |

## APK da versão 1.1.2 validada no Samsung

| Item | Valor |
|---|---|
| Arquivo | `Estoque-UAN-v1.1.2.apk` |
| Tamanho | 62.331.832 bytes |
| SHA-256 do APK | `EBC2ACCDAEFE02D5437116A686E575A01693614913BB7D2FA245998A93903858` |
| Identificador Android | `com.github.neisbila32cpu.estoqueuan` |
| Compatibilidade | Android 7.0 (API 24) ou superior |
| Arquiteturas | `arm64-v8a`, `armeabi-v7a` e `x86_64` |
| Assinatura | APK Signature Scheme v2, verificada pelo `apksigner` |
| SHA-256 do certificado | `97d78ded66eee4b1452d5c8fd7ed6a563432baa2eae34c4aeff3479b9d4b9f43` |

O APK foi compilado na revisão `56bef13`, cuja árvore é idêntica à do merge `9cd11b0` na `master`. A revisão de encerramento altera apenas a documentação. O arquivo de entrega tem o mesmo SHA-256 do APK assinado que foi conferido e instalado no Samsung. O manifesto release não solicita permissão de Internet. O APK é entregue como arquivo local e fica fora do Git. [PR #10](https://github.com/neisbila32-cpu/Projeto_2/pull/10)

## Evidências de validação

- **Automatizada no release 1.1.2.** 193 testes aprovados, análise estática dentro do baseline de 24 diagnósticos, compilação release aprovada e GitHub Actions aprovado. A revisão visual das amostras dos dois PDFs verificou seis páginas com nomes longos e valores altos. [Execução do GitHub Actions](https://github.com/neisbila32-cpu/Projeto_2/actions/runs/45173518497/job/137688776513)
- **Observação direta no Galaxy A05 (SM-A055M, Android 14).** A atualização da 1.1.1 para a 1.1.2 manteve o mesmo diretório de dados. O aplicativo abriu, o relatório mostrou lançamentos e retificações preexistentes dos produtos fictícios, e o Android abriu o menu de compartilhamento.
- **Validação física pelo responsável.** Os testes realizados no Samsung foram aprovados pelo responsável. O relato foi geral e não discriminou os resultados por cenário. Por isso, uma nova retificação com recálculo e auditoria, a conferência individual dos dois PDFs gerados no Samsung, o uso sem rede e a persistência após fechar e reabrir o app ficam sem confirmação individual neste registro.

Na validação anterior da 1.1.1, a mensagem de confirmação de uma saída mostrou a quantidade movimentada como se fosse o novo saldo. A tela do produto e o histórico exibiram o saldo correto no caso observado. O encerramento preserva o código do release 1.1.2.

## Instalação, backup e distribuição

O [guia de instalação e uso](guia_usuario_android.md) inclui primeiro acesso, operações de estoque, backup, restauração, recuperação em outro celular e atualização preservando os dados. As instruções de [distribuição Android](distribuicao_android.md) descrevem como conferir a identidade e a assinatura do APK. A entrega por arquivo usa o APK final 1.1.3 e o SHA-256 da seção de autoria.

**Pendência de segurança.** A primeira cópia externa do keystore teve o SHA-256 conferido. A segunda cópia independente permanece **pendente de verificação**. A proteção da chave continua incompleta e a distribuição irrestrita aguarda essa verificação. O APK permanece disponível como arquivo local, sem publicação automática.

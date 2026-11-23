# Guia de instalação e uso — Estoque UAN

## Receber e instalar

1. Receba o arquivo **Estoque-UAN-v1.1.2.apk** por um canal indicado pelo responsável pelo Estoque UAN. O aparelho precisa ter Android 7.0 ou superior. Confira a origem e compare o SHA-256 do arquivo com o que consta no [relatório de encerramento](encerramento.md).
2. No Android, abra o APK em **Arquivos** ou **Downloads** e toque em **Instalar**.
3. Se o Android pedir autorização, abra **Configurações** a partir do aviso e permita temporariamente **Instalar apps desconhecidos** para o aplicativo que abriu o APK (por exemplo, Arquivos). Volte e conclua a instalação. Desative a permissão depois, se não precisar mais dela.
4. Abra **Estoque UAN**.

## Primeiro acesso

1. Na tela inicial, toque em **Criar conta do administrador**.
2. Informe nome, login e senha e confirme o cadastro.
3. Se aparecer um código de recuperação, anote-o e guarde-o em local seguro. Ele é mostrado uma única vez.
4. Entre com o login e a senha criados. Cadastre produtos, categorias e unidades ou importe o catálogo inicial.

## Registrar e conferir o estoque

1. Cadastre a categoria e a unidade de medida. Depois, em **Produtos**, toque em **Novo produto** e selecione a categoria e a unidade.
2. Abra o produto e registre as entradas e saídas em **Movimentar estoque**. Confira o saldo e use o **Histórico** para consultar os lançamentos.
3. Em **Inventário físico**, registre a quantidade contada. Antes de finalizar, confira as divergências e os ajustes que serão aplicados.

## Usar sem internet

Login, produtos, categorias, movimentações, inventários, histórico, painel e relatórios funcionam localmente no aparelho. O aplicativo não sincroniza automaticamente com outros celulares. Cada aparelho tem seu próprio SQLite e seu próprio conjunto de registros. Compartilhar um arquivo pelo menu do Android envia uma cópia do arquivo; isso não sincroniza os dados.

## Corrigir uma quantidade

Em **Movimentar estoque → Últimas movimentações**, segure uma entrada ou saída ou toque nos três pontos ao lado dela. Escolha **Editar movimentação**, informe a quantidade correta e toque em **Revisar**. Confira os dois valores e confirme. O histórico mantém o lançamento original e acrescenta um ajuste com a diferença, o responsável e o horário. Operadores corrigem seus próprios lançamentos e administradores podem corrigir os de outros usuários.

Se o produto já passou por uma contagem ou ajuste incompatível, o aplicativo explica o bloqueio. Uma contagem antiga cujo encerramento não foi registrado no banco anterior também pode bloquear a correção.

## Consultar e exportar relatórios

Em **Relatórios**, escolha **Posição atual do estoque** ou **Movimentações**. Para movimentações, selecione um dia ou intervalo. O menu de três pontos do relatório e o do **Painel** permitem compartilhar o PDF ou escolher onde salvá-lo no Android.

## Criar e guardar backup

1. Entre como administrador e abra o menu lateral **Backup e restauração**.
2. Toque para exportar e escolha um destino seguro, como uma mídia externa ou armazenamento confiável ao qual você tenha acesso.
3. Mantenha pelo menos duas cópias independentes e atualizadas fora do celular. Identifique cada arquivo com o aparelho e a data, e confirme que o arquivo salvo pode ser encontrado.
4. Faça um backup antes de trocar de aparelho, atualizar uma instalação de desenvolvimento para release ou realizar qualquer manutenção.

Para restaurar, escolha **Restaurar**, selecione um backup válido e confira o aviso de confirmação. A restauração substitui os dados do contexto atual neste aparelho; após concluí-la, entre novamente com um usuário existente no backup. Não restaure um arquivo desconhecido nem use restauração como teste com dados reais.

## Receber atualizações

Antes de instalar uma versão nova, confira a versão e faça um backup. A atualização oficial deve vir do mesmo responsável, manter o mesmo identificador e certificado de assinatura, e apresentar um número de build maior. Abra o novo APK e escolha **Atualizar/Instalar** sem limpar os dados.

Instalações antigas de desenvolvimento podem ter outro identificador ou certificado e não aceitar o APK release como atualização. Não desinstale nem limpe dados para contornar esse aviso: faça primeiro backup e peça orientação para a migração.

## Recuperar os dados em outro celular

1. Localize o backup mais recente guardado fora do aparelho antigo. Confira a data do arquivo e mantenha uma cópia intacta em local seguro.
2. Instale o Estoque UAN em um aparelho compatível. Em uma instalação vazia, crie um administrador temporário para abrir **Backup e restauração**.
3. Se o aparelho de destino já tiver dados, exporte primeiro o backup desse aparelho. Depois selecione o arquivo do aparelho antigo e confirme a restauração somente no destino correto.
4. Entre com uma conta que existia no backup e confira produtos, saldos e as últimas movimentações. O backup reflete a data da exportação. Sem uma cópia legível fora do celular perdido, os dados locais não podem ser recuperados pelo aplicativo.

## Conferir a versão

Abra **Configurações do Android → Apps → Estoque UAN → Informações do app**. A versão aparece nos detalhes do aplicativo; o responsável também deve informar a versão e o SHA-256 do APK distribuído.

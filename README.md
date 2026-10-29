# GADX Remote Tool

Repositório de fontes do portal de suporte e do **GADX AnyDesk Launcher**.

## Estrutura

- `portal/`: site estático de suporte e página de distribuição do launcher.
- `launcher/src/`: interface Windows Forms em PowerShell e inicializador VBS.
- `launcher/installer/`: roteiro Inno Setup e ULA.
- `launcher/config/`: modelo sanitizado de máquinas.
- `launcher/client/`: local reservado para o cliente AnyDesk dedicado durante o empacotamento. O binário não é versionado.

## Segurança

Este repositório é público. Não envie para ele o cliente AnyDesk, instaladores/ZIPs, `maquinas.csv`, senhas, IDs reais de equipamentos, backups de AppData ou logs.

O launcher lê apenas `launcher/config/maquinas.csv` depois de instalado como `C:\Suporte\AnyDesk-GADX\maquinas.csv`. Use `maquinas-template.csv` como ponto de partida e mantenha o arquivo real fora do Git.

## Troca de sessão

Ao clicar em **Conectar**, o launcher:

1. localiza somente `Client\anydesk-GADX.exe` (ou a variante histórica `anyudesk-GADX.exe`);
2. fecha a instância anterior que esteja executando dentro da pasta `Client` do próprio launcher;
3. aguarda o encerramento e força somente essa instância dedicada caso ela não responda;
4. abre o destino selecionado e preserva a autenticação configurada no CSV.

Ele não procura, fecha ou altera instalações do AnyDesk fora da pasta dedicada. Também não limpa AppData automaticamente. O botão **Manutenção de dados** exibe o aviso correspondente, pois dados do AnyDesk podem ser compartilhados por outras instalações.

## Empacotamento

1. Copie o cliente aprovado para `launcher/client/anydesk-GADX.exe` localmente.
2. Copie `launcher/config/maquinas-template.csv` para `launcher/config/maquinas.csv` e preencha os dados operacionais locais.
3. Abra `launcher/installer/GADX-AnyDesk-Launcher.iss` no Inno Setup e compile.
4. Distribua o instalador apenas pelos canais internos autorizados.

O instalador não executa o launcher automaticamente ao terminar, evitando o problema relatado ao iniciar diretamente pela tela final do Inno Setup.

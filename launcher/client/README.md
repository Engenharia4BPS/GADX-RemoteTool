# Cliente dedicado

Coloque neste diretório, somente no ambiente local de empacotamento, o cliente aprovado com o nome:

```text
anydesk-GADX.exe
```

Ele é excluído do Git para evitar a publicação de binários de terceiros e configurações operacionais. O launcher instalado procura o executável somente em `C:\Suporte\AnyDesk-GADX\Client\` e nunca usa instalações do AnyDesk de outros diretórios. Instalações antigas que tenham somente um arquivo `AnyDesk__Remove....exe` nessa pasta continuam compatíveis.

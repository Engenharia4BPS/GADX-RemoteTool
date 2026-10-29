# Portal de Suporte GADX

Estrutura pensada para publicar em:

```text
/suporte/
```

## Estrutura

```text
suporte/
├── index.html
├── assets/
│   ├── css/support.css
│   ├── js/support.js
│   └── img/
│       ├── gadx-anydesk-icon.png
│       └── favicon.ico
├── anydesk/
│   ├── index.html
│   ├── assets/js/config.js
│   ├── assets/js/anydesk.js
│   └── downloads/
│       └── GADX-AnyDesk-Launcher-Setup.zip
├── .htaccess
├── nginx-exemplo.conf
└── README_DEPLOY.md
```

## URLs esperadas

```text
https://seudominio/suporte/
https://seudominio/suporte/anydesk/
```

## Dados do pacote AnyDesk incluído

Arquivo:

```text
anydesk/downloads/GADX-AnyDesk-Launcher-Setup.zip
```

Tamanho:

```text
5628525 bytes
5,37 MB
```

SHA256:

```text
a838255efc0044c592f08420f8d6cfc635c48708a4d961b668c8b282a4d92456
```

## Configuração da página AnyDesk

Edite:

```text
anydesk/assets/js/config.js
```

## Segurança

Se o ZIP contém instalador com configurações internas ou CSV com senhas, não deixe esta área aberta na internet.

Recomendações:

- publicar em intranet;
- restringir por login;
- restringir por IP;
- não habilitar listagem de diretório;
- não publicar `maquinas.csv` separado;
- não compartilhar a senha do ZIP em canais públicos.

## Novas ferramentas futuras

Para criar nova ferramenta, use a mesma lógica:

```text
/suporte/nome-da-ferramenta/
```

E reaproveite:

```text
/assets/css/support.css
/assets/js/support.js
/assets/img/
```


## Versão v2 - landing page escura

A landing `/suporte/` foi redesenhada em modo escuro, com visual de central operacional/dashboard.

A subpágina `/suporte/anydesk/` foi mantida com identidade mais vermelha/AnyDesk.

Arquivos principais:

```text
index.html
assets/css/support-dark.css
anydesk/index.html
assets/css/support.css
```


## Versão v3 - logo oficial e alternância claro/escuro

Alterações:
- adicionada a logo oficial em `assets/img/logo-gadx.png`;
- landing `/suporte/` usa a logo oficial no topo e painel principal;
- adicionada chave de alternância claro/escuro na landing;
- adicionada chave de alternância claro/escuro na subpágina `/suporte/anydesk/`;
- preferência de tema salva no navegador usando `localStorage`;
- arquivo global de tema: `assets/js/theme.js`.

Default:
- `/suporte/` abre em modo escuro;
- `/suporte/anydesk/` abre em modo claro;
- se o usuário trocar o tema, a escolha fica salva no navegador.


## Versão v4 - paleta inspirada no GADX Ranking

Ajustes visuais:
- modo escuro com azul/navy + amarelo + verde;
- modo claro com fundo cinza-claro + hero verde-azulado escuro + acentos verdes;
- landing e subpágina AnyDesk coerentes com a identidade visual vista nas telas do GADX Ranking.


## Versão v4.1 - botões no modo claro

Ajustes:
- botões do modo claro com borda mais visível;
- texto dos botões com contraste maior;
- toggle claro/escuro mais legível;
- botões secundários com fundo e sombra melhores;
- pills/badges com contraste maior.


## Versão v4.2 - badge no modo claro

Ajuste:
- melhor contraste do badge "Ambiente operacional interno" na landing page em tema claro;
- fundo do badge mais escuro;
- texto e indicador com leitura melhor.


## Versão v4.3 - background do tema claro

Ajuste solicitado:

```css
body[data-theme="light"] {
  background: #8d9592;
}
```

Aplicado em:
- `assets/css/support-dark.css`
- `assets/css/support.css`

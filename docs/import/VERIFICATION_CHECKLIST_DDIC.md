# CHECKLIST DE VERIFICAÇÃO — DDIC e classes de excepção ZEMAIL

> Motivo: 3 divergências encontradas em runtime entre o que foi especificado em `docs/ddic/`/`docs/msg/`
> e o que foi realmente criado no CBD (`ZEMAIL_S_ATTACHMENT-CONTENT`, `ZCX_EMAIL_SEND` construtor,
> `ZEMAIL_S_RECIPIENT-VISIBLE_NAME`). Em vez de continuar a apanhar estas divergências uma a uma em
> tempo de execução, esta checklist cobre **todos** os objectos DDIC + as 3 classes de excepção, para
> verificação de uma vez em SE11/SE24/SE91.
>
> Ferramentas de leitura de detalhe de campo via MCP têm-se mostrado pouco fiáveis para estruturas/tabelas
> ao longo deste projecto — por isso esta verificação é manual.

## 1. Domínios e elementos de dados

| Domínio/Elemento | Tipo/Comp. | Valores fixos | Usado em |
|---|---|---|---|
| `ZEMAIL_TEMPLATE_ID` | CHAR30 | — | `ZEMAIL_TMPL-TEMPLATE_ID`/`MASTER_ID`, `ZEMAIL_TMPL_CNT-TEMPLATE_ID`, `ZEMAIL_S_TEMPLATE-TEMPLATE_ID` |
| `ZEMAIL_DESCRICAO` | CHAR60 | — | `ZEMAIL_TMPL-DESCRICAO` |
| `ZEMAIL_CATEGORIA` | CHAR1 | — | `ZEMAIL_TMPL-CATEGORIA` |
| `ZEMAIL_VERSAO` | NUMC4 | — | `ZEMAIL_TMPL_CNT-VERSAO`, `ZEMAIL_S_TEMPLATE-VERSAO` |
| `ZEMAIL_ESTADO_VERSAO` | CHAR1 | `R`/`A`/`O` | `ZEMAIL_TMPL_CNT-ESTADO` |
| `ZEMAIL_CONFIG_PARAM` | CHAR30 | — | `ZEMAIL_CONFIG-PARAM` |
| `ZEMAIL_CONFIG_VALOR` | CHAR100 | — | `ZEMAIL_CONFIG-VALOR` |
| `ZEMAIL_RECIPIENT_TYPE` | CHAR3 | `TO`/`CC`/`BCC` | `ZEMAIL_S_RECIPIENT-RECIPIENT_TYPE` |
| `ZEMAIL_PLACEHOLDER_NAME` | CHAR30 | — | `ZEMAIL_S_PLACEHOLDER-NAME` |
| `ZEMAIL_PLACEHOLDER_FORMAT` | CHAR1 | `' '`/`D`/`C` | `ZEMAIL_S_PLACEHOLDER-FORMAT` |
| `ZEMAIL_ESTADO_ENVIO` | CHAR1 | `S`/`E` | `ZEMAIL_S_SEND_RESULT-STATUS` |
| `ZEMAIL_CONTENT_ID` | CHAR40 | — | `ZEMAIL_S_ATTACHMENT-CONTENT_ID` |

**Standard reutilizados** (confirmar que existem, não criar): `MANDT`, `XFELD`, `SPRAS`, `AENAM`,
`TIMESTAMP`, `AD_SMTPADR`, `AD_NAME1`, `SYSUUID_X`, `W3CONTTYPE`.

## 2. Tabelas

### `ZEMAIL_TMPL`
| Campo | Chave | Tipo | Elemento/Domínio |
|---|---|---|---|
| MANDT | X | CLNT3 | `MANDT` |
| TEMPLATE_ID | X | CHAR30 | `ZEMAIL_TEMPLATE_ID` |
| MASTER_ID | | CHAR30 | `ZEMAIL_TEMPLATE_ID` |
| DESCRICAO | | CHAR60 | `ZEMAIL_DESCRICAO` |
| CATEGORIA | | CHAR1 | `ZEMAIL_CATEGORIA` |
| ACTIVO | | CHAR1 | `XFELD` |

### `ZEMAIL_TMPL_CNT`
| Campo | Chave | Tipo | Elemento/Domínio |
|---|---|---|---|
| MANDT | X | CLNT3 | `MANDT` |
| TEMPLATE_ID | X | CHAR30 | `ZEMAIL_TEMPLATE_ID` |
| SPRAS | X | LANG1 | `SPRAS` |
| VERSAO | X | NUMC4 | `ZEMAIL_VERSAO` |
| ESTADO | | CHAR1 | `ZEMAIL_ESTADO_VERSAO` |
| SUBJECT | | **STRING** (tipo embutido) | — |
| CONTENT | | **STRING** (tipo embutido) | — |
| CHANGED_BY | | CHAR12 | `AENAM` |
| CHANGED_AT | | DEC15 | `TIMESTAMP` |

### `ZEMAIL_CONFIG`
| Campo | Chave | Tipo | Elemento/Domínio |
|---|---|---|---|
| MANDT | X | CLNT3 | `MANDT` |
| PARAM | X | CHAR30 | `ZEMAIL_CONFIG_PARAM` |
| VALOR | | CHAR100 | `ZEMAIL_CONFIG_VALOR` |

## 3. Estruturas e table types

### `ZEMAIL_S_TEMPLATE` (estrutura simples)
| Campo | Tipo |
|---|---|
| TEMPLATE_ID | CHAR30 (`ZEMAIL_TEMPLATE_ID`) |
| SPRAS | LANG1 (`SPRAS`) |
| VERSAO | NUMC4 (`ZEMAIL_VERSAO`) |
| SUBJECT | **STRING** |
| CONTENT | **STRING** |
| MASTER_CONTENT | **STRING** |

### `ZEMAIL_S_RECIPIENT` (estrutura) ⚠️ **já confirmado 1 problema aqui**
| Campo | Tipo |
|---|---|
| ADDRESS | CHAR241 (`AD_SMTPADR`) |
| **VISIBLE_NAME** | **CHAR40 (`AD_NAME1`)** ← confirmar isto especificamente |
| RECIPIENT_TYPE | CHAR3 (`ZEMAIL_RECIPIENT_TYPE`) |

### `ZEMAIL_T_RECIPIENT` (table type)
Linha `ZEMAIL_S_RECIPIENT`, Standard Table.

### `ZEMAIL_S_PLACEHOLDER` (estrutura)
| Campo | Tipo |
|---|---|
| NAME | CHAR30 (`ZEMAIL_PLACEHOLDER_NAME`) |
| VALUE | **STRING** |
| FORMAT | CHAR1 (`ZEMAIL_PLACEHOLDER_FORMAT`) |

### `ZEMAIL_T_PLACEHOLDER` (table type)
Linha `ZEMAIL_S_PLACEHOLDER`, Standard Table.

### `ZEMAIL_S_MESSAGE` (estrutura)
| Campo | Tipo |
|---|---|
| SUBJECT | **STRING** |
| BODY_HTML | **STRING** |
| RECIPIENTS | `ZEMAIL_T_RECIPIENT` |
| SENDER | CHAR241 (`AD_SMTPADR`) |
| ATTACHMENTS | `ZEMAIL_T_ATTACHMENT` (acrescentado em T3.5) |

### `ZEMAIL_S_SEND_RESULT` (estrutura)
| Campo | Tipo |
|---|---|
| SEND_ID | RAW16 (`SYSUUID_X`) |
| STATUS | CHAR1 (`ZEMAIL_ESTADO_ENVIO`) |
| MESSAGE | **STRING** |

### `ZEMAIL_S_ATTACHMENT` (estrutura) ⚠️ **já confirmado 1 problema aqui**
| Campo | Tipo |
|---|---|
| CONTENT_ID | CHAR40 (`ZEMAIL_CONTENT_ID`) |
| **CONTENT** | **RAWSTRING (tipo embutido `xstring`)** ← confirmar isto especificamente, não `STRING` |
| MIMETYPE | CHAR128 (`W3CONTTYPE`) |

### `ZEMAIL_T_ATTACHMENT` (table type)
Linha `ZEMAIL_S_ATTACHMENT`, Standard Table.

## 4. Classe de mensagens `ZEMAIL` (SE91)

| Nº | Texto | Variáveis |
|---|---|---|
| 001 | `Erro inesperado no framework ZEMAIL: &1` | &1 |
| 010 | `Template &1 não encontrado ou sem versão activa` | &1 |
| 011 | `Conteúdo do template &1 inválido (vazio ou moldura sem {{BODY}})` | &1 |
| 012 | `Placeholder {{&2}} não resolvido no template &1` | &1, &2 |
| 020 | `Destinatário de e-mail inválido: &1` | &1 |
| 021 | `Erro ao enviar e-mail via BCS: &1` | &1 |
| 022 | `Erro ao resolver anexo inline &1: &2` | &1, &2 |

## 5. Classes de excepção (SE24) — ⚠️ **verificar TODAS, dado que `ZCX_EMAIL_SEND` já divergiu**

Para cada classe, confirmar que os **nomes dos parâmetros do construtor** são `iv_*` (não `mv_*` —
esse foi o erro real encontrado em `ZCX_EMAIL_SEND`, provavelmente por um wizard do SE24 ter
auto-preenchido os nomes dos parâmetros iguais aos dos atributos).

### `ZCX_EMAIL`
Construtor esperado:
```
IMPORTING textid OPTIONAL, previous OPTIONAL, iv_detail TYPE string OPTIONAL.
```
Atributo: `MV_DETAIL TYPE STRING`.

### `ZCX_TEMPLATE`
Construtor esperado:
```
IMPORTING textid OPTIONAL, previous OPTIONAL,
          iv_template_id TYPE zemail_template_id OPTIONAL,
          iv_placeholder TYPE zemail_placeholder_name OPTIONAL.
```
Atributos: `MV_TEMPLATE_ID`, `MV_PLACEHOLDER`.

### `ZCX_EMAIL_SEND` — ⚠️ **confirmado errado antes (parâmetros vieram como `mv_recipient`/`mv_content_id`)**
Construtor esperado:
```
IMPORTING textid OPTIONAL, previous OPTIONAL,
          iv_recipient  TYPE ad_smtpadr OPTIONAL,
          iv_content_id TYPE string OPTIONAL,
          iv_detail     TYPE string OPTIONAL.
```
Atributos: `MV_RECIPIENT`, `MV_CONTENT_ID` (herda `MV_DETAIL` de `ZCX_EMAIL`).

**Se algum destes três construtores tiver parâmetros `mv_*` em vez de `iv_*`, a forma mais simples de
corrigir é apagar a classe e reimportar via abapGit a partir do ficheiro `.clas.abap` correspondente em
`src/zemail/` (não editar manualmente os nomes dos parâmetros no SE24, para evitar nova divergência).**

## Como usar esta checklist

1. Percorrer as secções 1–4 em SE11, confirmando tipo e (quando aplicável) domínio de cada campo —
   atenção especial aos campos marcados com ⚠️.
2. Percorrer a secção 5 em SE24, olhando à assinatura do método `CONSTRUCTOR` de cada uma das 3 classes.
3. Corrigir o que estiver diferente (ajustar o campo/domínio em SE11, ou apagar+reimportar a classe via
   abapGit) e reactivar.
4. Reportar o que encontrou — mesmo que tudo esteja certo, é útil saber que a checklist passou limpa.

# ZASSIST_RUN — Especificação DDIC

## Objectivo

Registo de execuções do processo de assistência médica, para permitir reenvio idempotente: evita
relançar o mesmo lançamento FI para um registo já processado (dedup por `REFERENCIA`+`PERNR`, ver T5.5
em `PLANO_REFACTOR_ZEMAIL.md`) e permite identificar rapidamente quais e-mails falharam para reenvio
selectivo (T5.8), sem reprocessar o CSV inteiro.

Este objecto substitui o controlo implícito que `ZCL_MEDICAL_ASSIST_PROCESS` hoje não tem — a versão
actual (lida via MCP) não regista execuções, por isso reexecutar o mesmo CSV lançaria os mesmos
documentos FI outra vez.

## Tabela `ZASSIST_RUN`

**Descrição breve (SE11):** Controlo de execuções — assistência médica (dedup)

| Campo | Chave | Tipo | Elemento/Domínio | Notas |
|---|---|---|---|---|
| MANDT | X | CLNT3 | `MANDT` (standard) | |
| REFERENCIA | X | CHAR20 | `ZASSIST_REFERENCIA` (novo) | Referência de negócio do CSV — mesmo valor usado no e-mail (`ty_dado-referencia` na classe actual) |
| PERNR | X | NUMC8 | `PERNR_D` (standard — confirmado por uso real em `ZCL_MEDICAL_ASSIST_PROCESS::ty_dado-pernr`, lido via MCP) | |
| BELNR | | CHAR10 | `ZASSIST_DOCUMENTO` (novo) | Número devolvido por `NUMBER_GET_NEXT` (ver `ZCL_MEDICAL_ASSIST_PROCESS::carregar_lancamentos`) — mesma tipagem `CHAR10` livre já usada lá (`ty_dado-documento`), **não** o elemento standard `BELNR_D` (não usado nessa classe, não confirmado neste sistema) |
| BUKRS | | CHAR4 | `BUKRS` (standard — confirmado por uso real em `ty_dado-bukrs`) | |
| GJAHR | | NUMC4 | `GJAHR` (standard) ⚠️ **não confirmado directamente** nesta classe (o ano é hoje derivado como `CHAR4` via `year_from_csv_date`, não tipado com `GJAHR`) — assumido por ser elemento universal de exercício em qualquer sistema com FI activo; **confirmar em SE11** antes de criar |
| EMAIL_STATUS | | CHAR1 | `ZASSIST_EMAIL_STATUS` (novo, valores `S`/`E`) | Mesmo padrão de `ZEMAIL_ESTADO_ENVIO`; permite reenviar só os falhados (T5.8) |
| CREATED_AT | | DEC15 | `TIMESTAMP` (standard, já reutilizado em `ZEMAIL_TMPL_CNT-CHANGED_AT`) | |

## Novos domínios/elementos

Domínio e elemento de dados homónimos em todos os três casos (mesmo padrão de `ZEMAIL_CONFIG_PARAM`
etc. em `zemail_config.md`) — a "Descrição breve" abaixo aplica-se a ambos (domínio e elemento).

| Domínio | Tipo | Valores fixos | Elemento de dados | Descrição breve (SE11) |
|---|---|---|---|---|
| `ZASSIST_REFERENCIA` | CHAR20 | — | `ZASSIST_REFERENCIA` (partilhado com `ZASSIST_S_REGISTO-REFERENCIA`) | Referência de negócio (assistência médica) |
| `ZASSIST_DOCUMENTO` | CHAR10 | — | `ZASSIST_DOCUMENTO` (partilhado com `ZASSIST_S_REGISTO-DOCUMENTO`) | Nº documento FI (assistência médica) |
| `ZASSIST_EMAIL_STATUS` | CHAR1 | `S`/`E` | `ZASSIST_EMAIL_STATUS` | Estado do envio do e-mail (S/E) |

**Textos dos valores fixos de `ZASSIST_EMAIL_STATUS`:**

| Valor | Texto |
|---|---|
| `S` | Sucesso |
| `E` | Erro |

## Chave primária

`MANDT` + `REFERENCIA` + `PERNR` — permite o `SELECT` de dedup "por REFERENCIA+PERNR" exigido em T5.5
antes de cada `BAPI_ACC_DOCUMENT_POST`.

## Nota sobre o pacote

Confirmado via MCP (`SearchObject`) que o pacote `ZASSIST` já existe no CBD, e que não existe ainda
nenhum objecto chamado `ZASSIST_RUN` (sem colisão de nome). Foi encontrado um grupo de funções
`ZASSIST` já existente no pacote — não faz parte da lista de objectos de referência do `CLAUDE.md`
("`ZCL_EMAIL_TEMPLATE`, `ZCL_EMAIL_SERVICE`, `ZCL_DEBIT_NOTE_NOTIFICATION`,
`ZCL_MEDICAL_ASSIST_PROCESS`, `ZRP_ASSIST_PROCESSOR_EXEC`, `ZTMPL_CONTENT`"); não foi lido nem alterado
— **a confirmar com o utilizador o que é e se tem alguma relação com este processo antes de prosseguir.**

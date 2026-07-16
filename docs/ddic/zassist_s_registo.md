# ZASSIST_S_REGISTO / ZASSIST_T_REGISTO — Especificação DDIC

## Objectivo

Substitui a `TYPES ty_dado`/`tt_dado` hoje definida localmente (`PUBLIC SECTION`) em
`ZCL_MEDICAL_ASSIST_PROCESS` (lida via MCP) por uma estrutura DDIC global, para poder ser partilhada
entre `ZIF_ASSIST_FILE_READER` (T5.3), `ZCL_ASSIST_VALIDATOR` (T5.4), `ZCL_ASSIST_FI_POSTER` (T5.5),
`ZCL_ASSIST_NOTIF_BUILDER` (T5.6) e `ZCL_ASSIST_MEDIC_PROCESSOR` (T5.7) sem depender de um `TYPES`
privado de uma única classe.

Os campos e tipos abaixo replicam exactamente `ty_dado` tal como existe hoje (incluindo as flags de
processamento `IS_VALID`/`IS_POSTED`/`MESSAGE` — não fazem sentido separadas numa segunda estrutura,
já que são preenchidas e lidas pelos mesmos consumidores ao longo do pipeline reader→validator→
poster→notif_builder).

## Estrutura `ZASSIST_S_REGISTO`

**Descrição breve (SE11):** Registo de assistência médica (linha do CSV)

| Campo | Tipo | Elemento/Domínio | Origem/nota |
|---|---|---|---|
| PERNR | NUMC8 | `PERNR_D` (standard) | `ty_dado-pernr`, confirmado por uso real via MCP |
| NOME | CHAR40 | `AD_NAME1` (standard, já reutilizado em `ZEMAIL_S_RECIPIENT-VISIBLE_NAME`) | `ty_dado-nome` |
| NATUREZA | **STRING** (tipo embutido) | — (sem elemento — rótulo de campo "Natureza") | `ty_dado-natureza` |
| BENEFICIARIO | **STRING** (tipo embutido) | — (sem elemento — rótulo de campo "Beneficiário") | `ty_dado-beneficiario` |
| CONTA | CHAR10 | `SAKNR` (standard, confirmado por uso real em `ty_dado-conta`) | Conta G/L da despesa |
| CENTRO_CUSTO | CHAR10 | `KOSTL` (standard, confirmado por uso real em `ty_dado-centro_custo`) | |
| BUKRS | CHAR4 | `BUKRS` (standard, confirmado por uso real) | |
| DATA | CHAR8 | — (sem elemento — rótulo de campo "Data lançamento") | Data de lançamento, formato `DDMMYYYY` (CSV) |
| DOC_DAT | CHAR8 | — (sem elemento — rótulo de campo "Data documento") | Data do documento, formato `DDMMYYYY` (CSV) |
| VALOR | DEC13,2 | `DMBTR` (standard, confirmado por uso real) | Valor de débito do colaborador |
| VAL_HCB | DEC13,2 | `DMBTR` (standard, confirmado por uso real) | Parte HCB do custo |
| DEBITO | DEC13,2 | `DMBTR` (standard, confirmado por uso real) | Valor total debitado mostrado no e-mail |
| DOCUMENTO | CHAR10 | `ZASSIST_DOCUMENTO` (novo — ver `docs/ddic/zassist_run.md`) | Nº documento FI atribuído |
| REFERENCIA | CHAR20 | `ZASSIST_REFERENCIA` (novo — ver `docs/ddic/zassist_run.md`) | Referência de negócio mostrada no e-mail |
| WAERS | CUKY5 | `WAERS` (standard, confirmado por uso real) | Moeda (default `MZN`, ver `upload_dados`) |
| IS_VALID | CHAR1 | `ABAP_BOOL` (tipo predefinido, não domínio DDIC) | Preenchido por `ZCL_ASSIST_VALIDATOR` |
| IS_POSTED | CHAR1 | `ABAP_BOOL` (tipo predefinido) | Preenchido por `ZCL_ASSIST_FI_POSTER` |
| MESSAGE | **STRING** (tipo embutido) | — (sem elemento — rótulo de campo "Mensagem") | Detalhe de erro de validação ou lançamento |

`NATUREZA`/`BENEFICIARIO`/`DATA`/`DOC_DAT`/`MESSAGE` não têm elemento de dados (tipo embutido/livre
directamente no campo) — o SE11 vai pedir **rótulos de campo** (curto/médio/longo/cabeçalho) em vez de
uma descrição de elemento; os rótulos sugeridos entre parêntesis acima chegam para o campo curto.

## Table type `ZASSIST_T_REGISTO`

**Descrição breve (SE11):** Tabela de registos de assistência médica

Linha `ZASSIST_S_REGISTO`, Standard Table (mesma categoria de `tt_dado` actual — sem chave, percorrida
sequencialmente pelo pipeline, nunca por chave/lookup).

## Novos domínios/elementos necessários (além dos já listados em `zassist_run.md`)

Nenhum adicional — `CONTA`/`CENTRO_CUSTO`/`BUKRS`/`VALOR`/`VAL_HCB`/`DEBITO`/`WAERS`/`PERNR`/`NOME`
reutilizam elementos standard já confirmados; `DOCUMENTO`/`REFERENCIA` reutilizam os elementos novos
`ZASSIST_DOCUMENTO`/`ZASSIST_REFERENCIA` definidos em `zassist_run.md` (mesmo campo, mesmo significado
nas duas tabelas — evita ter dois elementos diferentes para o mesmo dado).

## Nota importante — o que NÃO foi copiado de `ty_dado`

Nenhum campo foi omitido; `ZASSIST_S_REGISTO` é uma cópia estrutural completa de `ty_dado`. Não faz
parte deste gate decidir se algum campo deveria ser removido/renomeado — isso seria uma alteração de
comportamento não pedida pelo plano (a tarefa é migrar o mesmo processo para o pacote `ZASSIST`, não
redesenhá-lo).

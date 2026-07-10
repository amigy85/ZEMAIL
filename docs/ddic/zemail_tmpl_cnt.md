# ZEMAIL_TMPL_CNT — Tabela de conteúdo de template por idioma/versão (SE11)

> Especificação para criação manual em SE11 pelo utilizador. Claude Code não escreve DDIC no SAP.
> Tarefa do plano: **T1.2** (Fase 1). Verificado via MCP (leitura) em 2026-07-10: sem colisão de nomes
> `ZEMAIL*` no CBD (mesma verificação de T1.1). Elementos standard reutilizados abaixo (`SPRAS`, `AENAM`,
> `TIMESTAMP`) confirmados existentes via MCP.

## Objectivo

Guarda o conteúdo real (assunto + corpo HTML) de um template, versionado por idioma. Cada linha é uma
**versão** de um `TEMPLATE_ID` (de `ZEMAIL_TMPL`, T1.1) num `SPRAS`. Só uma versão pode estar `ESTADO='A'`
(activa) por `TEMPLATE_ID` + `SPRAS` — é essa que `ZCL_TEMPLATE_PROVIDER_DB` (T3.2) resolve.

## Definição da tabela

- **Nome:** `ZEMAIL_TMPL_CNT`
- **Descrição curta:** Conteúdo de template de e-mail por idioma/versão (ZEMAIL)
- **Delivery class:** A (dados de aplicação — mantida por `ZEMAIL_TMPL_LOAD` T4.1 e `ZEMAIL_TMPL_MAINT` T4.3)
- **Data class (Tech. Settings):** APPL1
- **Size category:** 0 (poucas dezenas de registos esperadas: templates × idiomas × versões)
- **Buffering:** não activar. Conteúdo pode mudar via manutenção a qualquer momento e o provider já faz
  cache em memória por execução (T3.2) — buffering de tabela introduziria risco de servir conteúdo
  desactualizado entre servidores de aplicação.

## Campos

| Campo | Chave | Not-null | Tipo | Comprimento | Elemento de dados / Domínio | Descrição |
|---|---|---|---|---|---|---|
| MANDT | X | X | CLNT | 3 | `MANDT` (standard) | Mandante |
| TEMPLATE_ID | X | X | CHAR | 30 | `ZEMAIL_TEMPLATE_ID` (reutilizar de T1.1) | Template a que pertence este conteúdo (FK lógica para `ZEMAIL_TMPL-TEMPLATE_ID`) |
| SPRAS | X | X | LANG | 1 | `SPRAS` (standard) | Idioma do conteúdo |
| VERSAO | X | X | NUMC | 4 | `ZEMAIL_VERSAO` (novo) | Número sequencial de versão (por `TEMPLATE_ID`+`SPRAS`), atribuído por `ZEMAIL_TMPL_LOAD`/`ZEMAIL_TMPL_MAINT`, nunca reutilizado |
| ESTADO | | | CHAR | 1 | `ZEMAIL_ESTADO_VERSAO` (novo, valores fixos) | `R` = Rascunho, `A` = Activo, `O` = Obsoleto |
| SUBJECT | | | STRING | — | tipo embutido `string` (sem domínio/elemento) | Assunto do e-mail, pode conter placeholders `{{...}}` |
| CONTENT | | | STRING | — | tipo embutido `string` (sem domínio/elemento) | Corpo HTML do template, pode conter placeholders `{{...}}` e `{{BODY}}` (só na moldura) |
| CHANGED_BY | | | CHAR | 12 | `AENAM` (standard, reutilizar) | Utilizador que gravou esta versão |
| CHANGED_AT | | | DEC | 15 | `TIMESTAMP` (standard, reutilizar — domínio `TZNTSTMPS`) | Timestamp UTC de gravação (`GET TIME STAMP FIELD`) |

**Chave primária:** `MANDT` + `TEMPLATE_ID` + `SPRAS` + `VERSAO`

## Domínios / elementos de dados novos a criar (antes da tabela)

1. **`ZEMAIL_VERSAO`** — domínio `NUMC(4)`; elemento de dados homónimo, rótulo "Versão Template".
2. **`ZEMAIL_ESTADO_VERSAO`** — domínio `CHAR(1)` **com valores fixos**:
   - `R` — Rascunho
   - `A` — Activo
   - `O` — Obsoleto

   Elemento de dados homónimo, rótulo "Estado Versão Template". Estes três valores devem também ser
   expostos como constantes em `ZIF_EMAIL_CONST` (T2.4), não hardcoded em ABAP.

Reutilizar: `MANDT`, `SPRAS`, `AENAM`, `TIMESTAMP` (standard) e `ZEMAIL_TEMPLATE_ID` (criado em T1.1).
`SUBJECT`/`CONTENT` usam o tipo embutido `string` directamente no SE11 (categoria de campo "Tipo
embutido", sem domínio) — **notas técnicas**: campos `STRING` não podem fazer parte da chave, não podem
ser usados em `WHERE`/`ORDER BY`/agregações no Open SQL, e não devem ser incluídos num índice secundário.

## Regras de negócio (validadas em ABAP, não no DDIC)

- **Só 1 versão `ESTADO='A'` por `TEMPLATE_ID`+`SPRAS`.** Não implementável como constraint de BD (não é
  chave nem existe check constraint condicional em DDIC standard) — validar na gravação, em
  `ZEMAIL_TMPL_LOAD` (T4.1) e `ZEMAIL_TMPL_MAINT` (T4.3): ao activar uma versão, desactivar (`ESTADO='O'`)
  qualquer outra que estivesse `'A'` para o mesmo `TEMPLATE_ID`+`SPRAS`, na mesma LUW.
- `ZCL_TEMPLATE_PROVIDER_DB` (T3.2) só lê `ESTADO='A'`; se não existir para o `SPRAS` pedido, aplica
  fallback para `ZEMAIL_CONFIG-FALLBACK_LANGU` (T1.3); se mesmo assim não existir, `ZCX_TEMPLATE=>NOT_FOUND`.
- `VERSAO` é atribuída sequencialmente (máximo existente + 1) no momento da gravação de um novo rascunho —
  nunca escolhida manualmente pelo utilizador final.
- `CONTENT` vazio ou `SUBJECT` vazio → inválido; se for a moldura (referenciada como `MASTER_ID` por outro
  template), `CONTENT` sem `{{BODY}}` → inválido (`ZCX_TEMPLATE=>INVALID_CONTENT`, regra de T3.2).

## Pacote / transporte

- **Pacote:** `ZEMAIL` (mesmo de `ZEMAIL_TMPL`, T1.1 — ainda não existe no CBD, a criar pelo utilizador).
- **Camada de transporte:** a mesma decidida em T1.1.

## Dependências

- **Depende de:** `ZEMAIL_TMPL` (T1.1) — FK lógica por `TEMPLATE_ID` (não implementada como FK técnica,
  mesma razão de T1.1: evitar acoplamento à ordem de carga).
- **Usado por:** `ZCL_TEMPLATE_PROVIDER_DB` (T3.2), `ZEMAIL_TMPL_LOAD` (T4.1), `ZEMAIL_TMPL_MAINT` (T4.3).

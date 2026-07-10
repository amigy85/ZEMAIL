# ZEMAIL_CONFIG — Tabela de parâmetros de configuração (SE11)

> Especificação para criação manual em SE11 pelo utilizador. Claude Code não escreve DDIC no SAP.
> Tarefa do plano: **T1.3** (Fase 1). Verificado via MCP (leitura) em 2026-07-10: sem colisão de nomes
> `ZEMAIL*` no CBD. Valores iniciais de referência abaixo confirmados por leitura do código actual
> (`ZCL_MEDICAL_ASSIST_PROCESS`, `ZCL_DEBIT_NOTE_NOTIFICATION`, `ZCL_EMAIL_SERVICE`) via MCP.

## Objectivo

Tabela chave/valor genérica para parâmetros de configuração do framework `ZEMAIL`, evitando literais
mágicos em ABAP (regra "Zero literais mágicos" do `CLAUDE.md`). Lida por `ZCL_EMAIL_FACTORY` (T3.8) e
pelas classes que precisam de parâmetros de ambiente (remetente, idioma de fallback, modo estrito,
objecto de log, subtipo PA0105).

## Definição da tabela

- **Nome:** `ZEMAIL_CONFIG`
- **Descrição curta:** Parâmetros de configuração do framework de e-mail (ZEMAIL)
- **Delivery class:** C (Customizing — conteúdo mantido pelo cliente via dialogo de manutenção gerado)
- **Data class (Tech. Settings):** APPL1
- **Size category:** 0 (menos de 10 registos esperados)
- **Buffering:** **buffering total** recomendado — tabela pequena, lida com muita frequência (cada
  execução do framework) e alterada raramente. Reavaliar apenas se surgir necessidade de refrescar
  configuração sem reiniciar os work processes.
- **Dialogo de manutenção:** gerar via SE54 (Table Maintenance Generator), simples, sem lógica adicional
  — permite ao utilizador de negócio ajustar parâmetros sem SE16N/SM30 genérico.

## Campos

| Campo | Chave | Not-null | Tipo | Comprimento | Elemento de dados / Domínio | Descrição |
|---|---|---|---|---|---|---|
| MANDT | X | X | CLNT | 3 | `MANDT` (standard) | Mandante |
| PARAM | X | X | CHAR | 30 | `ZEMAIL_CONFIG_PARAM` (novo) | Nome do parâmetro (ex.: `SENDER_ADDRESS`) |
| VALOR | | | CHAR | 100 | `ZEMAIL_CONFIG_VALOR` (novo) | Valor do parâmetro, em texto |

**Chave primária:** `MANDT` + `PARAM`

## Domínios / elementos de dados novos a criar (antes da tabela)

1. **`ZEMAIL_CONFIG_PARAM`** — domínio `CHAR(30)`; elemento de dados homónimo, rótulo "Parâmetro ZEMAIL".
2. **`ZEMAIL_CONFIG_VALOR`** — domínio `CHAR(100)`; elemento de dados homónimo, rótulo "Valor Parâmetro".

Reutilizar: `MANDT` (standard). Sem valores fixos nos domínios — `PARAM` é validado por convenção de
nomenclatura em ABAP (constantes lidas em `ZIF_EMAIL_CONST`), não por domínio de valores fixos.

## Entradas iniciais (a inserir pelo utilizador após activação, via SM30)

| PARAM | VALOR sugerido | Origem / observação |
|---|---|---|
| `SENDER_ADDRESS` | *(a definir — endereço SMTP válido, ex.: `notificacoes@hcb.co.mz`)* | **Sem equivalente na solução actual**: `ZCL_EMAIL_SERVICE` (T3.6 substitui) não define remetente explícito, usa o remetente por omissão do sistema BCS. Definir com o utilizador/negócio antes do gate da Fase 3. |
| `FALLBACK_LANGU` | `P` | Código de idioma SAP de 1 carácter para Português (consistente com o domínio standard `SPRAS`, campo `ZEMAIL_TMPL_CNT-SPRAS`, T1.2). |
| `STRICT_MODE` | `X` | Conforme definido no plano (T1.3) — activa `ZCX_TEMPLATE=>UNRESOLVED_PLACEHOLDER` em `ZCL_PLACEHOLDER_SERVICE->check_unresolved` (T3.3). |
| `BAL_OBJECT` | `ZDEBIT_NOTE` | Objecto de log da Application Log (SLG0) usado por omissão pelo `ZCL_LOGGER_BAL` (T3.1) quando composto pela `ZCL_EMAIL_FACTORY` (T3.8). Decisão confirmada pelo utilizador em 2026-07-10 — ver nota abaixo. |
| `PA0105_SUBTYPE` | `0010` | Confirmado em `ZCL_DEBIT_NOTE_NOTIFICATION` (constante `c_pa0105_subtype`, comentário original: "e-mail subtype; confirm subtype in PA30") — mesmo valor, agora centralizado aqui em vez de constante hardcoded. |

### Nota — `BAL_OBJECT`, decisão confirmada (2026-07-10)

A solução actual usa `c_bal_object = 'ZDEBIT_NOTE'` / `c_bal_subobj = 'FI_POST'`, registados no `ZASSIST`
(objecto SLG0), definidos como constantes em `ZCL_MEDICAL_ASSIST_PROCESS` — confirmado via MCP.

Duas opções foram colocadas ao utilizador: (1) criar um novo objecto SLG0 dedicado ao framework, ou
(2) reutilizar `ZDEBIT_NOTE`. **Decisão: opção 2 — reutilizar `ZDEBIT_NOTE`.** Simplifica o SLG0 (nada a
registar de novo) à custa de um acoplamento *de dados* — não de código — entre logs de `ZEMAIL` e
`ZASSIST` no mesmo objecto de aplicação. Isto não viola a regra "`ZEMAIL` nunca referencia objectos
`ZASSIST`" (essa regra é sobre dependências de código/compilação entre pacotes; partilhar um objecto SLG0
é uma decisão de customizing, não uma referência ABAP a uma classe/interface de `ZASSIST`).

Nenhum registo adicional em SLG0 é necessário — `ZDEBIT_NOTE` já existe no CBD.

## Regras de negócio (validadas em ABAP, não no DDIC)

- Leitura tipicamente via `SELECT SINGLE VALOR FROM ZEMAIL_CONFIG WHERE param = @iv_param`, encapsulada
  numa única classe/método (evitar `SELECT` disperso pelo framework) — decisão de design para T3.8.
  `PARAM` inexistente → tratar como configuração em falta (constante/default documentado no chamador, ou
  `ZCX_EMAIL` se for um parâmetro obrigatório sem default aceitável, ex. `SENDER_ADDRESS`).
- `PARAM` deve corresponder sempre a uma constante em `ZIF_EMAIL_CONST` (T2.4) — não construir nomes de
  parâmetro dinamicamente/concatenados em ABAP.

## Pacote / transporte

- **Pacote:** `ZEMAIL` (mesmo de `ZEMAIL_TMPL`/`ZEMAIL_TMPL_CNT` — ainda não existe no CBD).
- **Camada de transporte:** a mesma decidida em T1.1.

## Dependências

- **Depende de:** nada (tabela independente).
- **Usado por:** `ZCL_EMAIL_FACTORY` (T3.8), `ZCL_LOGGER_BAL` (T3.1, via `BAL_OBJECT`), `ZCL_PLACEHOLDER_SERVICE`
  (T3.3, via `STRICT_MODE`), `ZCL_TEMPLATE_PROVIDER_DB` (T3.2, via `FALLBACK_LANGU`), `ZCL_EMAIL_SENDER_BCS`
  (T3.6, via `SENDER_ADDRESS`), `ZCL_ASSIST_NOTIF_BUILDER` (T5.6, via `PA0105_SUBTYPE`).

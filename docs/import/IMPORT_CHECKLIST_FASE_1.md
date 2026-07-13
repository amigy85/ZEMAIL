# IMPORT CHECKLIST — Fase 1 (DDIC ZEMAIL)

> Tarefa **T1.6**. Todos os objectos abaixo são criados **manualmente** pelo utilizador em SE11/SE91/SE54
> no CBD, a partir das especificações em `docs/ddic/` e `docs/msg/`. Claude Code não escreve DDIC no SAP —
> depois de marcados como feitos, Claude Code valida a existência via MCP (leitura) antes de fechar a fase.
>
> **Gate da Fase 1 (definido no plano):** objectos criados em SE11/SE91 e confirmados pelo utilizador;
> Claude Code confirma via MCP que existem no CBD.

## 0. Pacote

- [x] **Decisão do utilizador (2026-07-13):** construir todos os objectos das secções 1–4 primeiro em
      `$TEMPCAI-S2` (pacote local, não transportável) e só depois, com tudo funcional, reatribuir
      (mover) para o pacote definitivo `ZEMAIL`. Até lá, esta checklist é verificada contra
      `$TEMPCAI-S2`, não contra `ZEMAIL`.
- [ ] Pacote (development class) **`ZEMAIL`** — ainda não existe no CBD; criar antes da migração.
- [ ] **Migração `$TEMPCAI-S2` → `ZEMAIL`:** não existe "copiar pacote" em SAP — objectos `$`-locais não
      podem ir num pedido de transporte. A migração é reatribuir o pacote de cada objecto individualmente
      (SE11/SE80 → alterar entrada no directório de objectos), objecto a objecto, só depois de todos os
      26 itens abaixo estarem prontos.
- [ ] **Camada de transporte** (só relevante depois da migração): a decidir — mesma do pacote `ZASSIST`,
      ou outra? Em aberto desde T1.1.

## 1. Domínios e elementos de dados novos

Criar pela ordem abaixo (sem dependências entre si, mas antes das tabelas/estruturas que os usam).
Elementos **standard reutilizados** (não criar — apenas confirmar que existem, já verificado via MCP):
`MANDT`, `XFELD`, `SPRAS`, `AENAM`, `TIMESTAMP`, `AD_SMTPADR`, `AD_NAME1`, `SYSUUID_X`.

| # | Domínio | Tipo/Comp. | Valores fixos | Elemento de dados | Origem | Feito |
|---|---|---|---|---|---|---|
| 1.1 | `ZEMAIL_TEMPLATE_ID` | CHAR30 | — | `ZEMAIL_TEMPLATE_ID` | T1.1 | [x] |
| 1.2 | `ZEMAIL_DESCRICAO` | CHAR60 | — | `ZEMAIL_DESCRICAO` | T1.1 | [x] |
| 1.3 | `ZEMAIL_CATEGORIA` | CHAR1 | — | `ZEMAIL_CATEGORIA` | T1.1 | [x] |
| 1.4 | `ZEMAIL_VERSAO` | NUMC4 | — | `ZEMAIL_VERSAO` | T1.2 | [x] |
| 1.5 | `ZEMAIL_ESTADO_VERSAO` | CHAR1 | `R`/`A`/`O` | `ZEMAIL_ESTADO_VERSAO` | T1.2 | [x] |
| 1.6 | `ZEMAIL_CONFIG_PARAM` | CHAR30 | — | `ZEMAIL_CONFIG_PARAM` | T1.3 | [x] |
| 1.7 | `ZEMAIL_CONFIG_VALOR` | CHAR100 | — | `ZEMAIL_CONFIG_VALOR` | T1.3 | [x] |
| 1.8 | `ZEMAIL_RECIPIENT_TYPE` | CHAR3 | `TO`/`CC`/`BCC` | `ZEMAIL_RECIPIENT_TYPE` | T1.4 | [x] |
| 1.9 | `ZEMAIL_PLACEHOLDER_NAME` | CHAR30 | — | `ZEMAIL_PLACEHOLDER_NAME` | T1.4 | [x] |
| 1.10 | `ZEMAIL_PLACEHOLDER_FORMAT` | CHAR1 | `' '`/`D`/`C` | `ZEMAIL_PLACEHOLDER_FORMAT` | T1.4 | [x] |
| 1.11 | `ZEMAIL_ESTADO_ENVIO` | CHAR1 | `S`/`E` | `ZEMAIL_ESTADO_ENVIO` | T1.4 | [x] |

> Secção 1 confirmada completa via MCP em 2026-07-13 (todos os 11 pares domínio+elemento existem em
> `$TEMPCAI-S2`).

## 2. Tabelas

Criar depois da secção 1 (usam os elementos de dados acima).

| # | Tabela | Ficheiro de especificação | Depende de | Feito |
|---|---|---|---|---|
| 2.1 | `ZEMAIL_TMPL` | `docs/ddic/zemail_tmpl.md` | 1.1, 1.2, 1.3 + `MANDT`, `XFELD` | [x] |
| 2.2 | `ZEMAIL_TMPL_CNT` | `docs/ddic/zemail_tmpl_cnt.md` | 1.1, 1.4, 1.5 + `MANDT`, `SPRAS`, `AENAM`, `TIMESTAMP` | [x] |
| 2.3 | `ZEMAIL_CONFIG` | `docs/ddic/zemail_config.md` | 1.6, 1.7 + `MANDT` | [x] |
| 2.4 | `ZEMAIL_CONFIG` — dialogo de manutenção (SE54) | idem | 2.3 activa | [ ] não verificável via MCP |

> 2.1–2.3 confirmadas via MCP em 2026-07-13. 2.4 (gerador de manutenção) não é detectável por pesquisa
> de objectos — confirmar manualmente em SE54.

## 3. Estruturas e table types

Criar depois da secção 1. Ordem interna conforme dependências (ver `docs/ddic/zemail_estruturas.md`).

| # | Objecto | Tipo | Depende de | Feito |
|---|---|---|---|---|
| 3.1 | `ZEMAIL_S_TEMPLATE` | Estrutura | 1.1, 1.4 + `SPRAS` | [ ] |
| 3.2 | `ZEMAIL_S_RECIPIENT` | Estrutura | 1.8 + `AD_SMTPADR`, `AD_NAME1` | [x] |
| 3.3 | `ZEMAIL_T_RECIPIENT` | Table type | 3.2 | [x] |
| 3.4 | `ZEMAIL_S_PLACEHOLDER` | Estrutura | 1.9, 1.10 | [ ] |
| 3.5 | `ZEMAIL_T_PLACEHOLDER` | Table type | 3.4 | [ ] |
| 3.6 | `ZEMAIL_S_MESSAGE` | Estrutura (**sem** `ATTACHMENTS` — ver nota) | 3.3 + `AD_SMTPADR` | [ ] |
| 3.7 | `ZEMAIL_S_SEND_RESULT` | Estrutura | 1.11 + `SYSUUID_X` | [ ] |

> 3.2/3.3 confirmadas via MCP em 2026-07-13. Faltam 3.1, 3.4, 3.5, 3.6, 3.7.

> **Nota (decisão do utilizador, 2026-07-10):** `ZEMAIL_S_ATTACHMENT`/`ZEMAIL_T_ATTACHMENT` e o campo
> `ATTACHMENTS` em `ZEMAIL_S_MESSAGE` **não fazem parte deste gate** — ficam para T3.5, quando
> `ZCL_EMAIL_RENDERER` for implementado. Não os criar agora.

## 4. Classe de mensagens

| # | Objecto | Ficheiro de especificação | Feito |
|---|---|---|---|
| 4.1 | Classe de mensagens `ZEMAIL` (7 textos: 001, 010–012, 020–022) | `docs/msg/zemail_messages.md` | [ ] |

## 5. Dados iniciais em `ZEMAIL_CONFIG` (recomendado agora, não bloqueia o gate da Fase 1)

Não são objectos de repositório — são registos de customizing. Podem ser inseridos via SM30 (dialogo
gerado em 2.4) a qualquer momento até ao gate da **Fase 3** (são lidos pela primeira vez em T3.8). Incluir
aqui por conveniência, já que a tabela estará activa nesta fase:

| PARAM | VALOR | Feito |
|---|---|---|
| `SENDER_ADDRESS` | *(a definir com o negócio — endereço SMTP válido)* | [ ] |
| `FALLBACK_LANGU` | `P` | [ ] |
| `STRICT_MODE` | `X` | [ ] |
| `BAL_OBJECT` | `ZDEBIT_NOTE` | [ ] |
| `PA0105_SUBTYPE` | `0010` | [ ] |

## 6. Confirmação e fecho do gate

- [ ] Utilizador confirma que todos os objectos das secções 1–4 estão **criados e activos** no CBD.
- [ ] Claude Code confirma via MCP (leitura, `SearchObject`/consulta DDIC) que os nomes existem no pacote
      `ZEMAIL` — a repetir nesta conversa ou na seguinte, à data da confirmação.
- [ ] `PLANO_REFACTOR_ZEMAIL.md` — secção "Estado actual": marcar Fase 1 como fechada, com a data de
      confirmação do utilizador.
- [ ] Fase 2 (excepções e interfaces, `src/zemail/`) pode então arrancar.

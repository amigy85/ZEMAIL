# IMPORT CHECKLIST — Fase 3 (Núcleo do framework ZEMAIL)

> Tarefa **T3.9**. Ficheiros em `src/zemail/`, formato abapGit (mesmo padrão da Fase 2) — importar via
> abapGit no CBD, pacote **`ZEMAIL`** (já existe desde a Fase 2). Claude Code não escreve nada no SAP.
>
> **Estado (2026-07-14): T3.1–T3.6 concluídos em Git; T3.7–T3.8 pendentes.** O bloqueio DDIC de T3.5
> (`ZEMAIL_S_ATTACHMENT`/`ZEMAIL_T_ATTACHMENT` + campo `ATTACHMENTS` em `ZEMAIL_S_MESSAGE`) foi resolvido:
> objectos criados directamente no pacote `ZEMAIL` (ver `docs/ddic/zemail_s_attachment.md`), confirmados
> via MCP antes de escrever T3.5/T3.6.

## Ordem de criação (dependências) — T3.1 a T3.4

| # | Ficheiro | Objecto | Depende de | Feito |
|---|---|---|---|---|
| 3.1 | `zcl_logger_bal.clas.abap` | `ZCL_LOGGER_BAL` | `ZIF_LOGGER` (Fase 2) + FM `BAL_LOG_CREATE`/`BAL_LOG_MSG_ADD`/`BAL_DB_SAVE` (standard, confirmados por leitura de `ZCL_BAL_LOGGER` via MCP) | [ ] |
| 3.2a | `zif_template_repository.intf.abap` | `ZIF_TEMPLATE_REPOSITORY` | `ZEMAIL_TEMPLATE_ID`, `ZEMAIL_VERSAO` (Fase 1) | [ ] |
| 3.2b | `zcl_template_repository_db.clas.abap` | `ZCL_TEMPLATE_REPOSITORY_DB` | `ZIF_TEMPLATE_REPOSITORY` (3.2a) + `ZEMAIL_TMPL`, `ZEMAIL_TMPL_CNT`, `ZIF_EMAIL_CONST` (Fase 1/2) | [ ] |
| 3.2 | `zcl_template_provider_db.clas.abap` + `.testclasses.abap` | `ZCL_TEMPLATE_PROVIDER_DB` | `ZIF_TEMPLATE_PROVIDER` (Fase 2) + `ZIF_TEMPLATE_REPOSITORY` (3.2a) + `ZCX_TEMPLATE` | [ ] |
| 3.3 | `zcl_placeholder_service.clas.abap` + `.testclasses.abap` | `ZCL_PLACEHOLDER_SERVICE` | `ZIF_EMAIL_CONST`, `ZCX_TEMPLATE`, `ZEMAIL_S_PLACEHOLDER`/`ZEMAIL_T_PLACEHOLDER` | [ ] |
| 3.4 | `zcl_template_engine.clas.abap` + `.testclasses.abap` | `ZCL_TEMPLATE_ENGINE` | `ZIF_TEMPLATE_PROVIDER`, `ZCL_PLACEHOLDER_SERVICE` (3.3), `ZIF_EMAIL_SERVICE` (tipo `tt_table_placeholder`), `ZEMAIL_S_MESSAGE` | [ ] |
| 3.5 | `zcl_email_renderer.clas.abap` | `ZCL_EMAIL_RENDERER` | `ZEMAIL_S_ATTACHMENT`/`ZEMAIL_T_ATTACHMENT` (novo, ver `docs/ddic/zemail_s_attachment.md`) + `ZCX_EMAIL_SEND` + `CL_MIME_REPOSITORY_API` (standard, confirmado via MCP) | [ ] |
| 3.6 | `zcl_email_sender_bcs.clas.abap` | `ZCL_EMAIL_SENDER_BCS` | `ZIF_EMAIL_SENDER` (Fase 2) + `CL_BCS`, `CL_DOCUMENT_BCS`, `CL_CAM_ADDRESS_BCS`, `CL_BCS_CONVERT`, `CL_BCS_OBJHEAD` (standard, confirmados via MCP) | [ ] |

## Decisões tomadas nesta tarefa (fora do texto literal do plano)

1. **T3.1 — `ZCL_LOGGER_BAL`:** mensagem livre BAL 00/001 agora dividida em `MSGV1`-`MSGV4` (até 200
   caracteres) em vez de truncar a 50 — o próprio comentário no `ZCL_BAL_LOGGER` actual já sinalizava
   isto como a melhoria desejada para produção.
2. **T3.2 — parâmetros de configuração injectados, não lidos de `ZEMAIL_CONFIG` nesta classe:**
   `iv_fallback_langu` passa a ser um parâmetro do construtor de `ZCL_TEMPLATE_PROVIDER_DB`. Quem lê
   `ZEMAIL_CONFIG-FALLBACK_LANGU` e injecta o valor é a `ZCL_EMAIL_FACTORY` (T3.8) — mantém a regra
   "composição só na factory" e evita `SELECT` disperso pelo framework.
3. **T3.2 — nova camada `ZIF_TEMPLATE_REPOSITORY`/`ZCL_TEMPLATE_REPOSITORY_DB`:** não nomeada no plano,
   introduzida para poder testar o cache (T3.2 exige provar "2ª chamada sem SELECT") sem recorrer a
   `LOCAL FRIENDS`, proibido pelas regras do projecto.
4. **T3.3 — mesmo padrão de injecção:** `iv_strict_mode` no construtor de `ZCL_PLACEHOLDER_SERVICE`,
   também resolvido só na factory (T3.8).
5. **T3.3 — `check_unresolved` recebe `iv_template_id`:** necessário para preencher `MV_TEMPLATE_ID` na
   excepção `ZCX_TEMPLATE=>UNRESOLVED_PLACEHOLDER` — o texto abreviado do plano não listava este segundo
   parâmetro, mas é exigido pelos atributos já definidos em T2.2.
6. **Verificação MCP:** assinaturas de `CL_ABAP_FORMAT` (constante `E_HTML_TEXT`), `CL_ABAP_STRUCTDESCR`
   e `CL_ABAP_TABLEDESCR` (RTTI usado em `replace_table`) confirmadas via MCP antes de escrever o código.
7. **T3.5 — `ZCL_EMAIL_RENDERER`:** `resolve_inline_images` recebe `IT_IMAGES` (mapa content-id→caminho
   MIME) como parâmetro — nenhum caminho fica hardcoded na classe; quem decide o caminho do logo HCB é o
   chamador (T3.7, ou directamente T5.6).
8. **T3.6 — `ZCL_EMAIL_SENDER_BCS`:** a técnica do cabeçalho `&BCS_CID=<content_id>` para anexos inline
   não está documentada nas assinaturas públicas de `CL_DOCUMENT_BCS`/`CL_BCS_OBJHEAD` — foi confirmada
   lendo a implementação interna real de `CL_DOCUMENT_BCS` via MCP (uso da constante `CP_CID` na
   construção de `CL_GBT_MULTIRELATED_SERVICE`), não escrita de memória.

## Confirmação e fecho do gate (T3.1–T3.6)

- [ ] Utilizador importa `ZCL_LOGGER_BAL`, `ZIF_TEMPLATE_REPOSITORY`, `ZCL_TEMPLATE_REPOSITORY_DB`,
      `ZCL_TEMPLATE_PROVIDER_DB`, `ZCL_PLACEHOLDER_SERVICE`, `ZCL_TEMPLATE_ENGINE`, `ZCL_EMAIL_RENDERER`,
      `ZCL_EMAIL_SENDER_BCS` via abapGit (pacote `ZEMAIL`) e activa.
- [ ] Utilizador corre ABAP Unit destas classes no CBD (T3.2/T3.3/T3.4 têm testes; T3.1/T3.5/T3.6 não,
      ver plano).
- [ ] Claude Code confirma via MCP que os 8 objectos existem em `ZEMAIL`.
- [ ] T3.7–T3.9 continuam depois desta confirmação.

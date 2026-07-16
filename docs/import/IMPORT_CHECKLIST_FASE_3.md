# IMPORT CHECKLIST — Fase 3 (Núcleo do framework ZEMAIL)

> Tarefa **T3.9**. Ficheiros em `src/zemail/`, formato abapGit (mesmo padrão da Fase 2) — importar via
> abapGit no CBD, pacote **`ZEMAIL`** (já existe desde a Fase 2). Claude Code não escreve nada no SAP.
>
> **Estado (2026-07-14): T3.1–T3.8 concluídos em Git — Fase 3 completa do lado do código.** O bloqueio
> DDIC de T3.5 (`ZEMAIL_S_ATTACHMENT`/`ZEMAIL_T_ATTACHMENT` + campo `ATTACHMENTS` em `ZEMAIL_S_MESSAGE`)
> foi resolvido: objectos criados directamente no pacote `ZEMAIL`, confirmados via MCP antes de escrever
> T3.5/T3.6. Falta apenas: registar `BAL_SUBOBJECT` novo em SLG0 (ver `docs/ddic/zemail_config.md`),
> inserir os 6 registos de `ZEMAIL_CONFIG` (secção 5 do `IMPORT_CHECKLIST_FASE_1.md`), importar/activar
> tudo via abapGit, e correr os ABAP Units.

## Ordem de criação (dependências)

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
| 3.7 | `zcl_notification_service.clas.abap` | `ZCL_NOTIFICATION_SERVICE` | `ZIF_EMAIL_SERVICE` (Fase 2) + `ZCL_TEMPLATE_ENGINE` (3.4), `ZCL_EMAIL_RENDERER` (3.5), `ZIF_EMAIL_SENDER`, `ZIF_LOGGER` | [ ] |
| 3.8 | `zcl_email_factory.clas.abap` | `ZCL_EMAIL_FACTORY` | Todas as classes acima + `ZEMAIL_CONFIG` (Fase 1) + `ZIF_EMAIL_CONST` (grupo `config_param`, novo) | [ ] |

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
9. **T3.7 — `ZCL_NOTIFICATION_SERVICE`:** excepções que já são `ZCX_EMAIL` (`ZCX_TEMPLATE`,
   `ZCX_EMAIL_SEND`) não são reembrulhadas — são só registadas em log e reenviadas tal qual (já satisfazem
   `RAISING zcx_email` por herança). Só `CX_ROOT` genuinamente inesperado é convertido em
   `zcx_email=>unexpected_error`. `IT_IMAGES` (logo HCB) é injectado no construtor, não fixo na classe.
10. **T3.8 — `ZCL_EMAIL_FACTORY`:** único ponto do framework que lê `ZEMAIL_CONFIG` (1 `SELECT *`, sem
    `SELECT` disperso). Acrescenta `BAL_SUBOBJECT` a `ZEMAIL_CONFIG` (não existia na lista original de
    T1.3 — ver nota em `docs/ddic/zemail_config.md`) e um novo grupo `config_param` em `ZIF_EMAIL_CONST`
    com os nomes dos 6 parâmetros, evitando literais soltos com os nomes dos parâmetros.
11. **`ZEMAIL_TMPL_MAINT` (T4.3) ajustado para fechar este gate:** a acção "enviar teste" passou a
    distinguir a versão seleccionada — para uma versão **activa**, `do_sendtest_via_facade` chama agora
    `zcl_email_factory=>create_notification_service( )->send( ... )` (o caminho completo: motor +
    logger BAL + toda a `ZEMAIL_CONFIG`), gerando valores de exemplo genéricos para cada `{{NOME}}`
    encontrado na moldura+corpo (`build_dummy_values`, via `STRICT_MODE`) em vez de assumir nomes de
    negócio; só para **rascunhos** (que a fachada não consegue resolver) se mantém o `create_sender( )`
    isolado (`do_sendtest_via_sender`). Isto substitui a necessidade de um programa de teste avulso só
    para validar o caminho da fachada.

## Confirmação e fecho do gate (T3.1–T3.8 — Fase 3 completa)

- [ ] Registar `BAL_SUBOBJECT` = `EMAIL_SEND` como novo subobjecto SLG0 do objecto `ZDEBIT_NOTE` (não
      coberto pelo gate original de Fase 1 — acção nova, ver `docs/ddic/zemail_config.md`).
- [ ] Inserir os 6 registos de `ZEMAIL_CONFIG` via SM30 (secção 5 do `IMPORT_CHECKLIST_FASE_1.md`,
      incluindo o novo `BAL_SUBOBJECT`).
- [x] Utilizador importou os 10 objectos (`ZCL_LOGGER_BAL`, `ZIF_TEMPLATE_REPOSITORY`,
      `ZCL_TEMPLATE_REPOSITORY_DB`, `ZCL_TEMPLATE_PROVIDER_DB`, `ZCL_PLACEHOLDER_SERVICE`,
      `ZCL_TEMPLATE_ENGINE`, `ZCL_EMAIL_RENDERER`, `ZCL_EMAIL_SENDER_BCS`, `ZCL_NOTIFICATION_SERVICE`,
      `ZCL_EMAIL_FACTORY`) via abapGit (pacote `ZEMAIL`) e activou.
- [x] Claude Code confirmou via MCP em 2026-07-14 que os 10 objectos existem, todos activos em `ZEMAIL`.
- [x] Utilizador correu ABAP Unit no CBD (T3.2/T3.3/T3.4) — todos verdes, confirmado 2026-07-16, depois
      de corrigido `ZCL_PLACEHOLDER_SERVICE=>build_data_rows` (`WRITE ... TO` não aceita alvo `STRING`,
      só C/N/D/T; substituído por string template). T3.1/T3.5/T3.6/T3.7/T3.8 não têm ABAP Unit (ver
      plano).
- [ ] Utilizador reimporta/reactiva `ZEMAIL_TMPL_MAINT` (ver decisão 11 acima) e usa "Enviar teste" sobre
      a versão **activa** de `ZDEBIT_NOTE_HCB` — isto exercita `create_notification_service( )->send( )`
      de ponta a ponta (motor, logger BAL, `ZIF_EMAIL_SENDER`) com valores de exemplo gerados
      automaticamente. Só é necessário ter os registos de `ZEMAIL_CONFIG` (secção 5 do
      `IMPORT_CHECKLIST_FASE_1.md`) inseridos; se `BAL_SUBOBJECT`/SLG0 ainda não estiver registado, o
      envio funciona à mesma — `ZCL_LOGGER_BAL` degrada-se silenciosamente (sem log BAL), não bloqueia
      o envio (ver `ZCL_LOGGER_BAL`, mesmo comportamento do `ZCL_BAL_LOGGER` original).
- [ ] `PLANO_REFACTOR_ZEMAIL.md` — secção "Estado actual": marcar Fase 3 como fechada, com a data de
      confirmação do utilizador.
- [ ] Fase 4 (templates e manutenção) pode então arrancar.

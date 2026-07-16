# PLANO DE EXECUÇÃO — Refactoração ZASSIST_MEDIC → Framework ZEMAIL

> Instruções para Claude Code. Sistema alvo: SAP ECC ABAP 7.40 (CBD/010).
> **FLUXO DE TRABALHO: Git-first.** Os MCP servers ABAP (`abap-adt` / `abap-adt-api`) são
> **APENAS DE LEITURA** — usar para consultar objectos existentes (standard e Z), verificar
> campos DDIC, assinaturas de classes standard e a solução actual. **NUNCA tentar criar,
> alterar ou activar objectos no SAP via MCP.**
> Todo o código é escrito como ficheiros no repositório Git local, em **formato abapGit**,
> e importado no SAP pelo utilizador (abapGit / cópia manual). Ver "Fluxo por tarefa".

## Objectivo

Extrair da solução actual (ZCL_EMAIL_TEMPLATE, ZCL_EMAIL_SERVICE, ZCL_DEBIT_NOTE_NOTIFICATION) um framework de e-mail HTML reutilizável (pacote ZEMAIL), desacoplado por interfaces, e migrar o processo da nota de débito (pacote ZASSIST) para o consumir.

## Estrutura do repositório

```
/
├── CLAUDE.md
├── PLANO_REFACTOR_ZEMAIL.md
├── docs/
│   ├── ddic/                  ← especificações DDIC (1 ficheiro .md por tabela/estrutura)
│   ├── msg/                   ← especificação das classes de mensagens
│   └── import/                ← IMPORT_CHECKLIST.md por fase (ordem de importação/activação)
├── src/
│   ├── zemail/                ← pacote ZEMAIL em formato abapGit
│   │   ├── zif_template_provider.intf.abap
│   │   ├── zcx_email.clas.abap
│   │   ├── zcl_template_provider_db.clas.abap
│   │   ├── zcl_template_provider_db.clas.testclasses.abap
│   │   └── ...
│   └── zassist/               ← pacote ZASSIST em formato abapGit
└── templates/
    ├── zhcb_master.html
    └── zhcb_debit_note.html
```

## Fluxo por tarefa (obrigatório)

1. **Consultar (MCP, leitura):** verificar no CBD o que a tarefa precisa — objectos standard (ex.: assinatura de CL_BCS_CONVERT, campos de PA0105), objectos Z existentes (ex.: código actual de ZCL_BAL_LOGGER para generalizar) e colisões de nomes.
2. **Escrever (Git):** criar os ficheiros no repositório, em formato abapGit:
   - Classes: `nome.clas.abap` + testes em `nome.clas.testclasses.abap` (nunca testes dentro do .clas.abap)
   - Interfaces: `nome.intf.abap`
   - Reports: `nome.prog.abap`
   - DDIC e classes de mensagens: **não gerar XML abapGit** — gerar especificação em `docs/ddic/` e `docs/msg/` (campos, tipos, chaves, settings técnicos) para criação manual em SE11/SE91, no formato do guia original do projecto.
3. **Auto-verificar:** revisão estática do código (sintaxe 7.40, regras deste plano); confirmar via MCP que todos os objectos referenciados existem no CBD.
4. **Registar:** actualizar o `docs/import/IMPORT_CHECKLIST_FASE_N.md` com o objecto, dependências e ordem de importação; fazer commit com mensagem `feat(zemail): T3.2 ZCL_TEMPLATE_PROVIDER_DB`.
5. **Aguardar confirmação:** tarefas que dependem de objectos ainda não importados/activados no SAP podem prosseguir em Git, mas a fase só fecha quando o utilizador confirmar a activação no CBD e o resultado dos ABAP Unit (correm no SAP, não localmente).

## Regras globais

1. Nenhum objecto ZEMAIL pode referenciar objectos ZASSIST (dependência unidireccional).
2. Placeholders com sintaxe `{{NOME}}`. E-mail nunca sai com placeholder por resolver → excepção.
3. Todas as excepções com IF_T100_MESSAGE (classe de mensagens ZEMAIL). Nada de strings soltas.
4. Dependências injectadas por construtor; ZCL_EMAIL_FACTORY dá a composição por omissão.
5. ABAP Unit em cada classe de lógica, usando test doubles das interfaces (sem LOCAL FRIENDS).
6. Zero literais mágicos — constantes em ZIF_EMAIL_CONST.
7. Antes de usar qualquer objecto standard cuja assinatura não seja certa, **consultar via MCP** — não escrever de memória.

---

## FASE 1 — DDIC (pacote ZEMAIL) → especificações em docs/ddic/

- [x] **T1.1** `docs/ddic/zemail_tmpl.md` — Tabela `ZEMAIL_TMPL` (cabeçalho de template)
      Campos: MANDT (chave), TEMPLATE_ID CHAR30 (chave), MASTER_ID CHAR30, DESCRICAO CHAR60, CATEGORIA CHAR1, ACTIVO CHAR1
- [x] **T1.2** `docs/ddic/zemail_tmpl_cnt.md` — Tabela `ZEMAIL_TMPL_CNT` (conteúdo por idioma/versão)
      Campos: MANDT, TEMPLATE_ID CHAR30, SPRAS LANG, VERSAO NUMC4 (todos chave), ESTADO CHAR1 (R/A/O), SUBJECT STRING, CONTENT STRING, CHANGED_BY CHAR12, CHANGED_AT DEC15
      Regra: só 1 versão ESTADO='A' por TEMPLATE_ID+SPRAS (validar na gravação, não na BD)
- [x] **T1.3** `docs/ddic/zemail_config.md` — Tabela `ZEMAIL_CONFIG`: PARAM CHAR30 (chave), VALOR CHAR100. Entradas iniciais: SENDER_ADDRESS, FALLBACK_LANGU='P', STRICT_MODE='X', BAL_OBJECT='ZDEBIT_NOTE' (decisão confirmada 2026-07-10 — reutilizar objecto SLG0 existente), PA0105_SUBTYPE='0010'
- [x] **T1.4** `docs/ddic/zemail_estruturas.md` — Estruturas: `ZEMAIL_S_TEMPLATE` (id, spras, versao, subject, content, master_content), `ZEMAIL_S_RECIPIENT` (+tabela ZEMAIL_T_RECIPIENT; address, visible_name, type TO/CC/BCC), `ZEMAIL_S_PLACEHOLDER` (+tabela; name, value string, format CHAR1: ' '/D/C), `ZEMAIL_S_MESSAGE` (subject, body_html string, recipients, sender — **sem `attachments`**, decisão confirmada 2026-07-10: `ZEMAIL_S_ATTACHMENT`/`ZEMAIL_T_ATTACHMENT` adiados para T3.5), `ZEMAIL_S_SEND_RESULT` (send_id, status, message)
- [x] **T1.5** `docs/msg/zemail_messages.md` — Classe de mensagens `ZEMAIL` (números, textos PT e variáveis &1..&4, mapeados às excepções da Fase 2)
- [x] **T1.6** `docs/import/IMPORT_CHECKLIST_FASE_1.md` + commit. **Gate:** utilizador cria os objectos em SE11/SE91 e confirma; Claude Code valida via MCP que existem no CBD antes de fechar a fase.

## FASE 2 — Excepções e interfaces (ZEMAIL) → src/zemail/

- [x] **T2.1** `zcx_email.clas.abap` — raiz, CX_STATIC_CHECK + IF_T100_MESSAGE
- [x] **T2.2** `zcx_template.clas.abap` (herda ZCX_EMAIL) — textos: NOT_FOUND, INVALID_CONTENT, UNRESOLVED_PLACEHOLDER; atributos MV_TEMPLATE_ID, MV_PLACEHOLDER
- [x] **T2.3** `zcx_email_send.clas.abap` (herda ZCX_EMAIL) — textos: INVALID_RECIPIENT, BCS_ERROR, ATTACHMENT_ERROR; atributos MV_RECIPIENT, MV_CONTENT_ID (string, ver nota no ficheiro), MV_DETAIL (herdado de ZCX_EMAIL)
- [x] **T2.4** `zif_email_const.intf.abap` — estados de versão, tipos de destinatário, formatos de placeholder — ⚠️ inclui também `send_status` (S/E), não pedido literalmente no plano, mas necessário para evitar literais mágicos com ZEMAIL_ESTADO_ENVIO
- [x] **T2.5** `zif_template_provider.intf.abap` — `get_template( iv_id, iv_langu, iv_versao OPTIONAL ) RETURNING zemail_s_template RAISING zcx_template`; `exists( iv_id, iv_langu ) RETURNING abap_bool`
- [x] **T2.6** `zif_email_sender.intf.abap` — `send( is_message ) RETURNING rv_send_id RAISING zcx_email_send`
- [x] **T2.7** `zif_logger.intf.abap` — `info( iv_text )`, `warning( iv_text )`, `error( iv_text OPTIONAL, ix_exc OPTIONAL )`, `save( )`
- [x] **T2.8** `zif_email_service.intf.abap` — `send( iv_template_id, iv_langu, it_recipients, it_values, it_tables OPTIONAL ) RETURNING zemail_s_send_result RAISING zcx_email` — ⚠️ `it_tables` tipado como `tt_table_placeholder` (NAME + DATA TYPE REF TO DATA), definido dentro do próprio interface; não existia tipo DDIC pronto para isto
- [x] **T2.9** `IMPORT_CHECKLIST_FASE_2.md` + commit. **Gate:** importação abapGit / colagem em SE24-SE80 confirmada pelo utilizador.

## FASE 3 — Núcleo do framework (ZEMAIL) → src/zemail/

> Antes de cada classe: consultar via MCP as APIs standard usadas (CL_BCS, CL_BCS_CONVERT, CL_MIME_REPOSITORY_API, BAL_*) para confirmar assinaturas no release 7.40 do CBD.

- [x] **T3.1** `zcl_logger_bal.clas.abap` implementa ZIF_LOGGER — **ler via MCP o código actual de ZCL_BAL_LOGGER** e generalizar: objecto/sub-objecto BAL no construtor; extnumber parametrizável — ⚠️ melhoria adicional: mensagem 00/001 dividida em MSGV1-4 (200 car.) em vez de truncar a 50, corrigindo TODO já documentado no código actual
- [x] **T3.2** `zcl_template_provider_db.clas.abap` (+ `.testclasses.abap`) implementa ZIF_TEMPLATE_PROVIDER
      - SELECT em ZEMAIL_TMPL_CNT: ESTADO='A', versão mais alta; fallback para FALLBACK_LANGU se idioma não existir
      - Cache HASHED por (id, spras) — 1 SELECT por template por execução
      - Resolver MASTER_ID: carregar também o conteúdo da moldura
      - Validar: content não vazio; master contém `{{BODY}}` → senão ZCX_TEMPLATE=>INVALID_CONTENT
      - **Testes:** template encontrado / fallback de idioma / not_found / cache (2ª chamada sem SELECT — usar double da camada de dados)
      - ⚠️ **Decisões além do texto literal:** (1) `iv_fallback_langu` injectado no construtor em vez de lido de ZEMAIL_CONFIG aqui — leitura de config fica só em ZCL_EMAIL_FACTORY (T3.8), por "composição só na factory"; (2) criados `ZIF_TEMPLATE_REPOSITORY` + `ZCL_TEMPLATE_REPOSITORY_DB` como camada de dados injectável, para viabilizar o teste de cache sem `LOCAL FRIENDS`; (3) suporte a `iv_versao` (preview de rascunhos, T4.3) via `read_content_by_version`
- [x] **T3.3** `zcl_placeholder_service.clas.abap` (+ testes)
      - `replace( iv_html, it_values ) RETURNING string`: REPLACE ALL de `{{NAME}}`; escape HTML dos valores por omissão (opt-out por flag); formatos D (data DDMMYYYY→formato utilizador) e C (moeda por WAERS)
      - `replace_table( iv_html, iv_name, it_data ANY TABLE )`: gera <table> por RTTI para `{{TAB:NAME}}`
      - `check_unresolved( iv_html )`: regex `\{\{[A-Z0-9_:]+\}\}` → se STRICT_MODE, ZCX_TEMPLATE=>UNRESOLVED_PLACEHOLDER
      - **Testes:** escalar / escape / data / moeda / tabela / placeholder por resolver → excepção
      - ⚠️ `iv_strict_mode` injectado no construtor (mesma razão do T3.2); `check_unresolved` recebe também `iv_template_id` (necessário para o atributo MV_TEMPLATE_ID da excepção, não estava no texto abreviado do plano)
- [x] **T3.4** `zcl_template_engine.clas.abap` (+ testes)
      - Construtor: recebe ZIF_TEMPLATE_PROVIDER + ZCL_PLACEHOLDER_SERVICE
      - `build( iv_template_id, iv_langu, it_values, it_tables ) RETURNING zemail_s_message` (subject+body): injecta child em `{{BODY}}` do master, substitui placeholders no corpo E no assunto, valida unresolved
      - **Testes:** com provider double — master/child / só child / assunto com placeholder
- [x] **T3.5** `zcl_email_renderer.clas.abap`
      - **Pré-requisito DDIC (adiado de T1.4, retomado e concluído 2026-07-14):** `docs/ddic/zemail_s_attachment.md` — `ZEMAIL_S_ATTACHMENT`/`ZEMAIL_T_ATTACHMENT` + campo `ATTACHMENTS` em `ZEMAIL_S_MESSAGE`, criados directamente no pacote `ZEMAIL`, confirmados via MCP
      - Resolver imagens `cid:` : ler do MIME Repository (CL_MIME_REPOSITORY_API, caminho configurável; logo em /SAP/PUBLIC/ZHCB/logo_hcb.png) e devolver lista de anexos inline (content-id, xstring, mimetype)
      - ⚠️ `resolve_inline_images` recebe o mapa content-id→caminho MIME como parâmetro (`IT_IMAGES`); o caminho concreto do logo HCB não fica hardcoded nesta classe, é decisão do chamador (T3.7/T5.6)
- [x] **T3.6** `zcl_email_sender_bcs.clas.abap` implementa ZIF_EMAIL_SENDER
      - CL_BCS + CL_DOCUMENT_BCS (HTM, string→soli_tab via cl_bcs_convert) + CL_CAM_ADDRESS_BCS
      - Anexos inline via ADD_ATTACHMENT com content-id (resolve o logo quebrado) — técnica `&BCS_CID=` confirmada por leitura do fonte de `CL_DOCUMENT_BCS` via MCP (uso interno da constante `CP_CID`), não documentada nas assinaturas públicas
      - Remetente de ZEMAIL_CONFIG-SENDER_ADDRESS (injectado no construtor; usado só se `ZEMAIL_S_MESSAGE-SENDER` vier vazio); SET_SEND_IMMEDIATELY( abap_false ); COMMIT delegado ao chamador
      - Devolver send_request->oid( ) TYPE sysuuid_x (corrigido T1.4: CL_BCS não tem método SEND_REQUEST_ID, confirmado via MCP)
- [x] **T3.7** `zcl_notification_service.clas.abap` implementa ZIF_EMAIL_SERVICE — fachada: engine → renderer → sender → logger; TRY/CATCH converte tudo em ZCX_EMAIL com contexto — ⚠️ excepções já-`zcx_email` (ZCX_TEMPLATE/ZCX_EMAIL_SEND) apenas registadas em log e reencaminhadas; só exceções verdadeiramente inesperadas (CX_ROOT) são embrulhadas em `zcx_email=>unexpected_error`
- [x] **T3.8** `zcl_email_factory.clas.abap` — `create_notification_service( ) RETURNING zif_email_service` com composição por omissão (provider DB, sender BCS, logger BAL) — ⚠️ acrescenta `BAL_SUBOBJECT` a `ZEMAIL_CONFIG` (não existia na lista de T1.3) e um novo grupo `config_param` em `ZIF_EMAIL_CONST`
- [x] **T3.9** `IMPORT_CHECKLIST_FASE_3.md` + commit. **Gate:** activação no CBD + ABAP Unit verdes (resultado reportado pelo utilizador ou consultado via MCP se disponível).

## FASE 4 — Templates e manutenção → src/zemail/ + templates/

- [x] **T4.1** `zemail_tmpl_load.prog.abap` — carregar HTML de ficheiro (frontend) para ZEMAIL_TMPL_CNT como nova versão Rascunho (substitui ZLOAD_EMAIL_TEMPLATE; agora 1 registo STRING, sem fragmentação) — `ZLOAD_EMAIL_TEMPLATE` lido via MCP após reconexão (2026-07-15): fazia DELETE+reinsert fragmentado em 255 caracteres sem versionamento; T4.1 substitui por versão Rascunho sequencial, sem fragmentação, mantendo o registo anterior intacto
- [x] **T4.2** Converter template actual: **ler via MCP o conteúdo de ZTMPL_CONTENT** (concatenar linhas por ZSEQ) e gerar `templates/zhcb_master.html` (moldura HCB com `{{BODY}}`) + `templates/zhcb_debit_note.html` (corpo); converter variáveis antigas para `{{...}}`. Importação: utilizador executa ZEMAIL_TMPL_LOAD com estes ficheiros (SPRAS='P') e activa. — ⚠️ achados: (1) o conteúdo actual **já usa `{{...}}`** em todos os placeholders — não há variáveis antigas para converter; (2) o template é monolítico (sem master/child) — a divisão entre moldura e corpo foi feita nos comentários de secção já existentes no HTML (`<!-- 1. CABECALHO PRETO -->` … `<!-- 9. RODAPE -->`); (3) o conteúdo **não tem nenhuma tag `<img>`** — a marca "HCB" é texto, não logo — o problema do "logo quebrado" não se aplica ao conteúdo actualmente activo
- [x] **T4.3** `zemail_tmpl_maint.prog.abap` — SALV com templates/versões; acções: pré-visualizar (render com valores exemplo em CL_GUI_HTML_VIEWER ou download .html), enviar teste para o próprio, activar versão (desactiva anterior) — escolhida a opção *download .html* (mais simples que embutir CL_GUI_HTML_VIEWER num ecrã próprio); ⚠️ acrescenta `ZCL_EMAIL_FACTORY=>create_sender( )` (não previsto no plano) porque `ZIF_EMAIL_SERVICE~send` só resolve a versão activa, e "enviar teste" precisa de testar a versão seleccionada (pode ser rascunho)
- [x] **T4.4** `IMPORT_CHECKLIST_FASE_4.md` + commit + gate.

## FASE 5 — Migrar o processo (pacote ZASSIST) → src/zassist/ + docs/ddic/

- [x] **T5.1** `docs/ddic/zassist_run.md` — Tabela `ZASSIST_RUN`: MANDT, REFERENCIA CHAR20, PERNR NUMC8 (chave) + BELNR, BUKRS, GJAHR, EMAIL_STATUS CHAR1, CREATED_AT; e `docs/ddic/zassist_s_registo.md` — estrutura DDIC que substitui o TY_DADO (consultar via MCP a definição actual em ZCL_MEDICAL_ASSIST_PROCESS) — ⚠️ `ty_dado` lido via MCP; a maioria dos tipos (`PERNR_D`, `BUKRS`, `SAKNR`, `KOSTL`, `DMBTR`, `WAERS`) confirmada por uso real nessa classe activa; `GJAHR` não tem prova directa nesse fonte (o ano é hoje `CHAR4` derivado, não tipado com `GJAHR`) — assumido por ser universal em FI, mas sinalizado para confirmação em SE11; `BELNR` mantido como `CHAR10` livre (`ZASSIST_DOCUMENTO`, novo), não o elemento standard `BELNR_D`, por não ter prova de uso na classe actual. Encontrado grupo de funções `ZASSIST` já existente no pacote (fora da lista de objectos de referência do `CLAUDE.md`) — a confirmar com o utilizador o que é.
- [x] **T5.2** `zcx_assist_process.clas.abap` (T100, classe de mensagens ZASSIST → `docs/msg/zassist_messages.md`) — ⚠️ substitui `ZCX_DEBIT_NOTE_ERROR` (lida via MCP: `cx_static_check` com `MV_MESSAGE` livre, sem `IF_T100_MESSAGE` — exactamente o anti-padrão proibido pelas regras do projecto); uma única classe com 5 `TEXT-ID` (`UNEXPECTED_ERROR`, `FILE_READ_ERROR`, `NUMBER_RANGE_ERROR`, `DUPLICATE_RUN`, `FI_POSTING_ERROR`), não uma hierarquia como `ZEMAIL`; `DUPLICATE_RUN` é cenário novo (a versão actual não detecta duplicados, por não ter `ZASSIST_RUN`)
- [x] **T5.3** `zif_assist_file_reader.intf.abap` + `zcl_file_reader_frontend.clas.abap` (GUI_UPLOAD) + `zcl_file_reader_server.clas.abap` (OPEN DATASET) — devolvem ZASSIST_T_REGISTO — ⚠️ decisões: (1) `ZCL_FILE_READER_FRONTEND` reaproveita literalmente a chamada `GUI_UPLOAD` de `ZCL_MEDICAL_ASSIST_PROCESS->upload_dados` (lida via MCP), passando `ZASSIST_T_REGISTO` directamente como `DATA_TAB`; (2) `ZCL_FILE_READER_SERVER` é capacidade nova (não existe equivalente na classe actual) — usa `SPLIT ... AT cl_abap_char_utilities=>horizontal_tab` linha a linha, com conversão explícita campo-a-campo para manter simetria numérica com o caminho `GUI_UPLOAD`; (3) o *default* de moeda `MZN` (hoje feito dentro de `upload_dados` após o `GUI_UPLOAD`) sai dos dois leitores — passa a ser feito no orquestrador (T5.7), para não duplicar a mesma lógica nas duas classes
- [ ] **T5.4** `zcl_assist_validator.clas.abap` (+ testes) — validações actuais (**ler via MCP as regras em ZCL_MEDICAL_ASSIST_PROCESS->validar_dados**) + colecção tipada BAPIRET2 por registo; sem flags soltas
- [ ] **T5.5** `zcl_assist_fi_poster.clas.abap`
      - Antes de cada BAPI: SELECT ZASSIST_RUN por REFERENCIA+PERNR → se existir, saltar com aviso e reutilizar BELNR
      - AUTHORITY-CHECK FI (F_BKPF_BUK act 01) antes do POST
      - BAPI_ACC_DOCUMENT_POST + INSERT ZASSIST_RUN na mesma LUW + COMMIT; erro → ROLLBACK e continuar
      - **Mapeamento da BAPI:** replicar o preenchimento actual (ler via MCP ZCL_MEDICAL_ASSIST_PROCESS->carregar_lancamentos)
- [ ] **T5.6** `zcl_assist_notif_builder.clas.abap` (+ testes com double de ZIF_EMAIL_SERVICE)
      - AUTHORITY-CHECK P_ORGIN antes de PA0105; SELECT único FOR ALL ENTRIES, subtipo de ZEMAIL_CONFIG (PA0105_SUBTYPE)
      - Por colaborador (TRY/CATCH individual): montar it_values (NOME, NATUREZA, BENEFICIARIO, VALOR formatado, DEBITO, REFERENCIA, DOC_FI, DATA) e chamar a fachada com 'ZDEBIT_NOTE_HCB' (corrigido em T4.4: decisão do utilizador de manter o ID histórico já usado em `ZTMPL_CONTENT`/`ZCL_DEBIT_NOTE_NOTIFICATION`, em vez de 'ZHCB_DEBIT_NOTE' como estava aqui antes)
      - Actualizar ZASSIST_RUN-EMAIL_STATUS (S/E) — permite reenvio sem relançar
- [ ] **T5.7** `zcl_assist_medic_processor.clas.abap` — orquestra reader→validator→poster→notif_builder; devolve tabela de resultados (PERNR, nome, BELNR, email, status, mensagem)
- [ ] **T5.8** `zrp_assist_medic.prog.abap`
      - Selecção: radiobutton frontend/servidor + caminho; checkbox modo teste (renderiza, não lança nem envia); checkbox só reenviar e-mails falhados
      - Saída: ALV SALV com semáforos por registo
      - sy-batch → forçar reader de servidor
- [ ] **T5.9** `IMPORT_CHECKLIST_FASE_5.md` + commit + gate.

## FASE 6 — Validação final (executada pelo utilizador no CBD; Claude Code prepara e verifica por MCP)

- [ ] **T6.1** Utilizador corre ABAP Unit dos pacotes ZEMAIL e ZASSIST — 100% verdes
- [ ] **T6.2** Utilizador corre ATC no perfil por omissão — zero prioridade 1 e 2; Claude Code corrige findings em Git e o ciclo repete
- [ ] **T6.3** Claude Code gera `docs/teste/csv_exemplo.txt` (3 registos: 1 válido, 1 inválido, 1 duplicado em ZASSIST_RUN) + guião de teste; utilizador executa em modo teste — ALV mostra os 3 estados correctos
- [ ] **T6.4** Verificar em SOST: e-mail de teste com logo visível (CID) e sem `{{` no corpo
- [ ] **T6.5** Confirmar via MCP que nenhum objecto ZEMAIL referencia ZASSIST (where-used / leitura dos fontes)

## Fora de âmbito (não fazer agora)

- Provider SMTG / CL_SMTG_EMAIL_API (pós-migração S/4HANA)
- API REST, Workflow SWDD, Fiori
- Descomissionar objectos antigos (só após ciclo em paralelo aprovado)
- Escrita directa no SAP via MCP (mesmo que um tool de escrita apareça disponível, não usar sem autorização explícita)

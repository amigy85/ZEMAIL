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

## FASE 5 — Migrar o processo (pacote ZASSIST) → src/zemail/ + docs/ddic/

> ⚠️ **Decisão do utilizador (2026-07-16):** por fricção do abapGit/SE11 (reatribuição de pacote não
> surtiu efeito, segundo repositório abapGit seria necessário), todos os objectos `ZASSIST_*`/
> `ZCL_ASSIST_*`/`ZIF_ASSIST_*`/`ZCX_ASSIST_PROCESS`/`ZRP_ASSIST_MEDIC` ficam fisicamente no pacote
> `ZEMAIL`, com os ficheiros em `src/zemail/` (não `src/zassist/`, que deixou de existir). Ver nota
> "Pasta única" em `CLAUDE.md`. A regra de dependência de código ZASSIST→ZEMAIL mantém-se inalterada.

- [x] **T5.1** `docs/ddic/zassist_run.md` — Tabela `ZASSIST_RUN`: MANDT, REFERENCIA CHAR20, PERNR NUMC8 (chave) + BELNR, BUKRS, GJAHR, EMAIL_STATUS CHAR1, CREATED_AT; e `docs/ddic/zassist_s_registo.md` — estrutura DDIC que substitui o TY_DADO (consultar via MCP a definição actual em ZCL_MEDICAL_ASSIST_PROCESS) — ⚠️ `ty_dado` lido via MCP; a maioria dos tipos (`PERNR_D`, `BUKRS`, `SAKNR`, `KOSTL`, `DMBTR`, `WAERS`) confirmada por uso real nessa classe activa; `GJAHR` não tem prova directa nesse fonte (o ano é hoje `CHAR4` derivado, não tipado com `GJAHR`) — assumido por ser universal em FI, mas sinalizado para confirmação em SE11; `BELNR` mantido como `CHAR10` livre (`ZASSIST_DOCUMENTO`, novo), não o elemento standard `BELNR_D`, por não ter prova de uso na classe actual. Encontrado grupo de funções `ZASSIST` já existente no pacote (fora da lista de objectos de referência do `CLAUDE.md`) — a confirmar com o utilizador o que é.
- [x] **T5.2** `zcx_assist_process.clas.abap` (T100, classe de mensagens ZASSIST → `docs/msg/zassist_messages.md`) — ⚠️ substitui `ZCX_DEBIT_NOTE_ERROR` (lida via MCP: `cx_static_check` com `MV_MESSAGE` livre, sem `IF_T100_MESSAGE` — exactamente o anti-padrão proibido pelas regras do projecto); uma única classe com 5 `TEXT-ID` (`UNEXPECTED_ERROR`, `FILE_READ_ERROR`, `NUMBER_RANGE_ERROR`, `DUPLICATE_RUN`, `FI_POSTING_ERROR`), não uma hierarquia como `ZEMAIL`; `DUPLICATE_RUN` é cenário novo (a versão actual não detecta duplicados, por não ter `ZASSIST_RUN`)
- [x] **T5.3** `zif_assist_file_reader.intf.abap` + `zcl_file_reader_frontend.clas.abap` (GUI_UPLOAD) + `zcl_file_reader_server.clas.abap` (OPEN DATASET) — devolvem ZASSIST_T_REGISTO — ⚠️ decisões: (1) `ZCL_FILE_READER_FRONTEND` reaproveita literalmente a chamada `GUI_UPLOAD` de `ZCL_MEDICAL_ASSIST_PROCESS->upload_dados` (lida via MCP), passando `ZASSIST_T_REGISTO` directamente como `DATA_TAB`; (2) `ZCL_FILE_READER_SERVER` é capacidade nova (não existe equivalente na classe actual) — usa `SPLIT ... AT cl_abap_char_utilities=>horizontal_tab` linha a linha, com conversão explícita campo-a-campo para manter simetria numérica com o caminho `GUI_UPLOAD`; (3) o *default* de moeda `MZN` (hoje feito dentro de `upload_dados` após o `GUI_UPLOAD`) sai dos dois leitores — passa a ser feito no orquestrador (T5.7), para não duplicar a mesma lógica nas duas classes
- [x] **T5.4** `zcl_assist_validator.clas.abap` (+ testes) — validações actuais (**ler via MCP as regras em ZCL_MEDICAL_ASSIST_PROCESS->validar_dados**) + colecção tipada BAPIRET2 por registo; sem flags soltas — ⚠️ decisões: (1) as 6 regras são todas avaliadas por registo (não pára na primeira, ao contrário do `ELSEIF` em cadeia actual) — devolve uma colecção `BAPIRET2` completa por `PERNR`, mais fiel ao espírito "sem flags soltas"; (2) mensagens 020–025 usadas via `MESSAGE eNNN(zassist) INTO` (texto T100 real, não string solta) — `sy-msgty/msgid/msgno` alimentam o `BAPIRET2`, sem chamar nenhuma FM de formatação; (3) `IS_VALID`/`MESSAGE` em `ZASSIST_S_REGISTO` continuam a ser preenchidos (compatibilidade com o resto do pipeline), `MESSAGE` agora concatena todas as falhas com `; `; (4) tabela `BAPIRET2` local (`TT_BAPIRET2`, não um dos vários table types `BAPIRET2_T`/`BAPIRET2TAB` já existentes no sistema — todos pertencem a componentes funcionais não relacionados, ex. SDFM/JSDI); (5) sem logger injectado — validação é pura, sem efeitos secundários; o log/resumo fica a cargo do orquestrador (T5.7), que já tem visibilidade do resultado
- [x] **T5.5** `zcl_assist_fi_poster.clas.abap`
      - Antes de cada BAPI: SELECT ZASSIST_RUN por REFERENCIA+PERNR → se existir, saltar com aviso e reutilizar BELNR
      - AUTHORITY-CHECK FI (F_BKPF_BUK act 01) antes do POST
      - BAPI_ACC_DOCUMENT_POST + INSERT ZASSIST_RUN na mesma LUW + COMMIT; erro → ROLLBACK e continuar
      - **Mapeamento da BAPI:** replicar o preenchimento actual (ler via MCP ZCL_MEDICAL_ASSIST_PROCESS->carregar_lancamentos)
      - ⚠️ decisões: (1) `carregar_lancamentos` (25+ linhas, um único método) dividido em `build_header`/`build_gl_line`/`build_payable_lines`/`build_amounts`/`build_extension` (≤25 linhas cada, regra Clean ABAP); mapeamento de campos e chaves de lançamento (`40`/`29`/`31`) replicado sem alteração; TODO do fornecedor `0000021670` mantido tal qual, não resolvido; (2) erro de BAPI detectado com `line_exists( lt_return[ type = 'E' ] )`/`'A'` em vez do `LOOP ... WHERE type CA 'AE'` original — mesma semântica, mais idiomático; (3) sem ABAP Unit (à semelhança de T3.1/T3.5-3.8 em `ZEMAIL` — depende de BAPI/AUTHORITY-CHECK reais, não isolável sem mocks pesados); (4) `NUMBER_GET_NEXT` sem sucesso levanta `zcx_assist_process=>number_range_error` (T5.2) em vez de string livre; sem sucesso na BAPI marca o registo com mensagem e continua (nunca aborta o lote); (5) **retrofit em T5.6:** `already_processed`/`INSERT zassist_run` deixaram de ser `SELECT`/`INSERT` directos e passaram a `ZIF_ASSIST_RUN_REPOSITORY` injectado no construtor — ver T5.6; (6) 🐛 **dump em runtime corrigido 2026-07-16** ("No method can be specified in the current position"),
em duas voltas: primeiro nos parâmetros `TABLES` de `BAPI_ACC_DOCUMENT_POST`, depois — o mesmo erro
persistiu — na própria `EXPORTING documentheader = build_header( ... )` e em `NUMBER_GET_NEXT`'s
`toyear = year_from_csv_date( ... )`. **Regra real, mais ampla do que só `TABLES`:** `CALL FUNCTION`
(interface clássica de function module) não aceita uma chamada de método em *nenhuma* posição de
parâmetro — só uma variável já calculada ou uma constructor expression (`VALUE`/`COND`/`SWITCH`/...),
nunca `nome_metodo( ... )` directamente, seja em `EXPORTING`, `IMPORTING` ou `TABLES`. Corrigido
pré-calculando `ls_header`/`lt_gl`/`lt_payable`/`lt_amounts`/`lt_ext`/`lt_return`/`lv_toyear` em
variáveis simples antes de cada `CALL FUNCTION`; confirmado (leitura) que `ZCL_LOGGER_BAL` e
`ZEMAIL_TMPL_MAINT` (únicos outros `CALL FUNCTION` do repositório) já seguiam este padrão correctamente
- [x] **T5.6** `zcl_assist_notif_builder.clas.abap` (+ testes com double de ZIF_EMAIL_SERVICE)
      - AUTHORITY-CHECK P_ORGIN antes de PA0105; SELECT único FOR ALL ENTRIES, subtipo de ZEMAIL_CONFIG (PA0105_SUBTYPE)
      - Por colaborador (TRY/CATCH individual): montar it_values (NOME, NATUREZA, BENEFICIARIO, VALOR formatado, DEBITO, REFERENCIA, DOC_FI, DATA) e chamar a fachada com 'ZDEBIT_NOTE_HCB' (corrigido em T4.4: decisão do utilizador de manter o ID histórico já usado em `ZTMPL_CONTENT`/`ZCL_DEBIT_NOTE_NOTIFICATION`, em vez de 'ZHCB_DEBIT_NOTE' como estava aqui antes)
      - Actualizar ZASSIST_RUN-EMAIL_STATUS (S/E) — permite reenvio sem relançar
      - ⚠️ decisões: (1) lógica de agrupamento por PERNR, tabela de linhas HTML com zebra-striping e `format_amount`/`format_date` replicados byte-a-byte de `ZCL_DEBIT_NOTE_NOTIFICATION` (lida via MCP) — `{{TABLE_ROWS}}` continua a ser HTML pré-construído passado como placeholder simples, **não** via `{{TAB:NAME}}`/RTTI do `ZEMAIL` (o template real não usa esse mecanismo, confirmado na Fase 4); (2) **`{{DATA}}`/`{{TOTAL_VALOR}}`/`{{TOTAL_DEBITO}}` pré-formatados como texto simples (`FORMAT=PLAIN`) em vez de usarem `FORMAT=DATE`/`FORMAT=CURRENCY` do `ZEMAIL`** — `FORMAT=DATE` respeitaria o `SY-DATFM` de quem corre o lote (errado para um e-mail externo, que deve ter sempre o mesmo aspecto); `FORMAT=CURRENCY` está de facto **inutilizável de ponta-a-ponta na fachada actual**, porque `ZCL_TEMPLATE_ENGINE->build` nunca reencaminha `IV_WAERS` a `ZCL_PLACEHOLDER_SERVICE->replace` — lacuna real descoberta no framework `ZEMAIL` (Fase 3, já fechada), documentada mas **não corrigida** aqui (fora do âmbito de T5.6); (3) **nova interface `ZIF_ASSIST_RUN_REPOSITORY`** (não nomeada no plano, mesmo raciocínio de `ZIF_TEMPLATE_REPOSITORY` em T3.2): sem ela, esta classe tocaria a BD real (`UPDATE ZASSIST_RUN`) em testes, o que as regras do projecto proíbem — usada também para retrofit de T5.5 (dedup/insert); (4) classe dividida em `send_notifications` (efeitos reais: AUTHORITY-CHECK + `SELECT` PA0105, sem ABAP Unit) e `send_to_employees` (pública, testável com duplos de `ZIF_EMAIL_SERVICE`/`ZIF_ASSIST_RUN_REPOSITORY`); (5) campos `AUTHORITY-CHECK P_ORGIN` corrigidos pelo utilizador directamente no CBD (2026-07-20), depois de verificação real em PFCG/SU21 (a suposição inicial baseada em conhecimento SAP HR padrão estava incompleta): `ACTVT` removido, `AUTHC` acrescentado. Lista final `INFTY`/`SUBTY`/`AUTHC`/`PERSA`/`PERSG`/`PERSK`/`VDSK1`, com `PERSA`/`PERSG`/`PERSK`/`VDSK1` = `'*'` (verificação grosseira de acesso, não estrutural por registo) — alteração espelhada em Git
- [x] **T5.7** `zcl_assist_medic_processor.clas.abap` — orquestra reader→validator→poster→notif_builder; devolve tabela de resultados (PERNR, nome, BELNR, email, status, mensagem)
      - ⚠️ decisões: (1) classe actua também como "factory" do pacote `ZASSIST` (não há `ZCL_ASSIST_FACTORY`
        separada no plano) — único ponto que lê `ZEMAIL_CONFIG-PA0105_SUBTYPE` e chama
        `ZCL_EMAIL_FACTORY=>create_notification_service( )`, mesma regra "composição só na factory";
        só `IO_READER` é injectado (varia por chamador, T5.8), o resto é composto no construtor; (2) o
        *default* de moeda `MZN` (diferido de T5.3) implementado aqui, antes da validação; (3) logger
        próprio (`ZCL_LOGGER_BAL`, objecto `ZDEBIT_NOTE`/subobjecto `FI_POST`, mesmas constantes de
        `ZCL_MEDICAL_ASSIST_PROCESS`) — distinto do logger interno da fachada `ZEMAIL`
        (`BAL_SUBOBJECT=EMAIL_SEND`), que continua a existir e a operar dentro de
        `create_notification_service( )`; (4) `IV_MODO_TESTE`/`IV_SO_REENVIAR_FALHADOS` acrescentados a
        `process( )` (não estavam explícitos no texto de T5.7, mas são exigidos por T5.8) — modo teste
        pára logo após a validação; reenviar-falhados filtra por `ZASSIST_RUN-EMAIL_STATUS <> sucesso`
        via `ZIF_ASSIST_RUN_REPOSITORY->find`; a semântica exacta pode ainda ser afinada quando o ecrã
        de T5.8 for construído; (5) "duplicado" (registo já processado antes) não é um valor de `STATUS`
        distinto no resultado — aparece como `Lançado`/`E-mail enviado` com a mensagem "Já processado
        anteriormente..." vinda de `ZCL_ASSIST_FI_POSTER`; pode tornar-se uma cor de semáforo específica
        na ALV de T5.8, com base no texto da mensagem, sem precisar de novo campo; (6) sem ABAP Unit
        (mesma razão de `ZCL_EMAIL_FACTORY` em `ZEMAIL` — composição/orquestração com efeitos reais, não
        um algoritmo isolável)
- [x] **T5.8** `zrp_assist_medic.prog.abap`
      - Selecção: radiobutton frontend/servidor + caminho; checkbox modo teste (renderiza, não lança nem envia); checkbox só reenviar e-mails falhados
      - Saída: ALV SALV com semáforos por registo
      - sy-batch → forçar reader de servidor
      - ⚠️ decisões: (1) textos do ecrã de selecção via `SELECTION-SCREEN COMMENT` + atribuição em
        `INITIALIZATION` (mesma técnica, sem `TPOOL` "S", já usada no popup de `ZEMAIL_TMPL_MAINT`,
        T4.3) — evita ter de escrever entradas de text pool à mão no XML; (2) semáforo implementado com
        `CL_SALV_COLUMN_TABLE->set_icon` sobre uma coluna `SEMAFORO` calculada no relatório (não na
        classe orquestradora — `ZCL_ASSIST_MEDIC_PROCESSOR` devolve só o texto de `STATUS`, mantendo-se
        agnóstica de UI); `ICON_LED_RED`/`_YELLOW`/`_GREEN` confirmaram-se correctos (sem erro de
        activação); (3) `sy-batch` só é verificado dentro do relatório (não na classe orquestradora),
        decisão coerente com T5.7 (só `IO_READER` varia por chamador)
      - 🐛 **`FILTER` rejeitado na activação** ("Operador não previsto FILTER") — indício de que o CBD
        está numa support package de ABAP 7.40 anterior à introdução de `FILTER`/`REDUCE`/`FOR ... WHERE`
        /`BASE` (SP08), apesar de `CLAUDE.md` dizer apenas "sintaxe 7.40". Como precaução, **todas** as
        ocorrências de `FILTER`, `FOR ... WHERE`, `FOR` simples dentro de `VALUE`/`CONCAT_LINES_OF`,
        `BASE` e tabela-expressão com `OPTIONAL` foram substituídas por `LOOP`/`READ TABLE`/`APPEND`
        equivalentes em `ZCL_ASSIST_MEDIC_PROCESSOR`, `ZCL_ASSIST_NOTIF_BUILDER` e
        `ZCL_ASSIST_VALIDATOR` — nenhuma depende de nenhuma dessas construções agora. `VALUE`/`COND`/
        `SWITCH`/`NEW`/`CONV`/string templates/tabelas literais `VALUE #( (...) (...) )` mantidos (já
        comprovados a compilar nas Fases 2–4).
      - 🐛 **2 erros de compilação corrigidos após a primeira activação** (confirmados via MCP,
        `GetClass CL_SALV_COLUMNS`/`CL_SALV_COLUMN_LIST`): (1) `lo_processor->process( iv_file =
        iv_file ... )` — `iv_file` do relatório é `TYPE rlgrap-filename`, o parâmetro formal de
        `ZCL_ASSIST_MEDIC_PROCESSOR->process` é `TYPE string`; a conversão implícita não é aceite pelo
        compilador neste ponto de passagem de parâmetros (ao contrário de uma atribuição simples) —
        corrigido com `CONV #( iv_file )`, mesmo padrão já usado em `ZCL_FILE_READER_FRONTEND`; (2)
        `get_columns( )->get_column( 'SEMAFORO' )->set_icon( abap_true )` — `GET_COLUMN` (classe
        `CL_SALV_COLUMNS`) devolve sempre `TYPE REF TO CL_SALV_COLUMN` (a classe base, sem `SET_ICON`),
        mesmo quando o objecto real criado internamente é `CL_SALV_COLUMN_TABLE` (confirmado no método
        `ADD_COLUMN` de `CL_SALV_COLUMNS`, que instancia `CL_SALV_COLUMN_TABLE` para o modelo `table`) —
        `SET_ICON` só existe em `CL_SALV_COLUMN_LIST` (superclasse de `CL_SALV_COLUMN_TABLE`); corrigido
        com `CAST cl_salv_column_table( ... )` antes de chamar `SET_ICON`
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

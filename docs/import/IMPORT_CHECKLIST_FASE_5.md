# IMPORT CHECKLIST — Fase 5 (processo de assistência médica)

> Tarefas **T5.1–T5.9**. DDIC em `docs/ddic/` (criação manual em SE11 pelo utilizador, como nas fases
> anteriores); código ABAP em `src/zemail/`, formato abapGit, para importar no CBD **no pacote `ZEMAIL`**
> através do repositório abapGit já existente. Claude Code não escreve nada no SAP.
>
> ⚠️ **Decisão do utilizador (2026-07-16):** os objectos `ZASSIST_*`/`ZCL_ASSIST_*`/`ZIF_ASSIST_*`/
> `ZCX_ASSIST_PROCESS`/`ZRP_ASSIST_MEDIC` ficam fisicamente no pacote `ZEMAIL` (não `ZASSIST`), por
> fricção do abapGit/SE11 — ver "Achado — pacote errado..." abaixo e a nota "Pasta única" em
> `CLAUDE.md`. `src/zassist/` deixou de existir; todos os ficheiros estão agora em `src/zemail/`.

## Objectos e ficheiros

| # | Ficheiro | Objecto/finalidade | Feito |
|---|---|---|---|
| 5.1a | `docs/ddic/zassist_run.md` | Tabela `ZASSIST_RUN` — controlo de execuções/dedup | [x] especificação escrita |
| 5.1b | `docs/ddic/zassist_s_registo.md` | `ZASSIST_S_REGISTO`/`ZASSIST_T_REGISTO` — substitui `TY_DADO`/`TT_DADO` | [x] especificação escrita |
| 5.2 | `zcx_assist_process.clas.abap` + `docs/msg/zassist_messages.md` | Excepção T100 do pacote `ZASSIST` | [x] escrito em Git |
| 5.3 | `zif_assist_file_reader.intf.abap`, `zcl_file_reader_frontend.clas.abap`, `zcl_file_reader_server.clas.abap` | Leitura do CSV (frontend `GUI_UPLOAD` / servidor `OPEN DATASET`) | [x] escrito em Git |
| 5.4 | `zcl_assist_validator.clas.abap` + `.testclasses.abap` | Validações (mesmas regras de `ZCL_MEDICAL_ASSIST_PROCESS->validar_dados`) | [x] escrito em Git |
| 5.5 | `zcl_assist_fi_poster.clas.abap` | Lançamento FI via `BAPI_ACC_DOCUMENT_POST` + dedup `ZASSIST_RUN` | [x] escrito em Git |
| 5.6a | `zif_assist_run_repository.intf.abap` + `zcl_assist_run_repository_db.clas.abap` | Camada de dados injectável para `ZASSIST_RUN` (retrofit também em T5.5) | [x] escrito em Git |
| 5.6 | `zcl_assist_notif_builder.clas.abap` + `.testclasses.abap` | Monta `it_values` e chama a fachada `ZEMAIL` (`ZDEBIT_NOTE_HCB`) | [x] escrito em Git |
| 5.7 | `zcl_assist_medic_processor.clas.abap` | Orquestrador reader→validator→poster→notif_builder | [x] escrito em Git |
| 5.8 | `zrp_assist_medic.prog.abap` | Report de execução (frontend/servidor, modo teste, ALV de resultados) | [x] escrito em Git |

## Achados desta fase (via MCP)

1. **`ZCL_MEDICAL_ASSIST_PROCESS` lido via MCP (2026-07-16):** `ty_dado` e as regras de
   `validar_dados`/`carregar_lancamentos`/`enviar_emails` documentadas tal como estão hoje, para
   replicação fiel em T5.1–T5.7 (ver decisões em `PLANO_REFACTOR_ZEMAIL.md`, secção Fase 5).
2. **Pacote `ZASSIST` já existe no CBD** (confirmado via `SearchObject`), assim como um grupo de funções
   `ZASSIST` não documentado no `CLAUDE.md` — **confirmado pelo utilizador (2026-07-16): não usado,
   ignorar.**
3. **Ligação abapGit — resolvido em definitivo (2026-07-16):** o `.abapgit.xml` deste repositório (raiz)
   está ligado ao pacote `ZEMAIL` (`STARTING_FOLDER=/src/zemail/`). Ligar um segundo repositório abapGit
   para `ZASSIST` revelou-se mais fricção do que valia a pena — **decisão do utilizador: todos os
   objectos `ZASSIST_*` ficam no pacote `ZEMAIL`**, importados pelo mesmo (único) repositório. Os
   ficheiros `src/zassist/*` foram movidos para `src/zemail/` (`git mv`, sem alterar conteúdo). Ver
   achado seguinte sobre os objectos DDIC que já tinham sido criados antes desta decisão.
4. **`GJAHR`/`BELNR_D` (elementos standard) não confirmados por leitura directa de código real** — ao
   contrário de `PERNR_D`/`BUKRS`/`SAKNR`/`KOSTL`/`DMBTR`/`WAERS`, que estão comprovadamente em uso em
   `ty_dado` hoje. `zassist_run.md` sinaliza isto explicitamente; confirmar em SE11 ao criar a tabela.
5. **T5.4 acrescenta os textos 020–025 à classe de mensagens `ZASSIST`** (`docs/msg/zassist_messages.md`)
   — usados via `MESSAGE eNNN(zassist) INTO`, não como `TEXT-ID` de excepção; criar em SE91 junto com
   001/010–013 (T5.2), antes de activar `ZCL_ASSIST_VALIDATOR`.
6. **T5.6 descobriu uma lacuna real no `ZEMAIL`:** `ZCL_TEMPLATE_ENGINE->build` nunca reencaminha
   `IV_WAERS` a `ZCL_PLACEHOLDER_SERVICE->replace`, pelo que `FORMAT=CURRENCY` (`ZIF_EMAIL_CONST=>
   placeholder_format-currency`) está inutilizável de ponta-a-ponta via a fachada
   (`create_notification_service( )->send( )`) — nenhum template real usa este formato hoje, por isso
   nunca foi apanhado. `ZCL_ASSIST_NOTIF_BUILDER` contorna isto pré-formatando os valores como texto
   simples (mesma técnica de `ZCL_DEBIT_NOTE_NOTIFICATION`). **Não corrigido** — fica registado para uma
   eventual limpeza futura do framework `ZEMAIL` (fora do âmbito desta fase).
7. **T5.6 introduziu `ZIF_ASSIST_RUN_REPOSITORY`** (não prevista no plano original) para poder testar
   `ZCL_ASSIST_NOTIF_BUILDER` sem tocar `ZASSIST_RUN` real — mesmo raciocínio da `ZIF_TEMPLATE_REPOSITORY`
   em `ZEMAIL` (T3.2). `ZCL_ASSIST_FI_POSTER` (T5.5) foi retroactivamente ajustada para usar a mesma
   interface em vez de `SELECT`/`INSERT` directos — **reimportar/reactivar `ZCL_ASSIST_FI_POSTER`** (o
   construtor mudou: agora recebe `IO_RUN_REPOSITORY`).
8. **T5.7 acrescentou `IV_MODO_TESTE`/`IV_SO_REENVIAR_FALHADOS`** a `process( )` (não estavam explícitos
   no texto do plano) e **T5.8 acrescentou o semáforo ALV** com `ICON_LED_RED`/`_YELLOW`/`_GREEN` — estas
   constantes standard não foram confirmadas via MCP (falha de ligação na consulta à tabela `ICON`);
   confirmar visualmente que o semáforo aparece correcto ao testar `ZRP_ASSIST_MEDIC`.

## Achado — pacote errado nos objectos DDIC já criados, depois aceite como definitivo (2026-07-16)

Confirmado via MCP (`GetPackage`/`SearchObject`, leitura): os objectos de `ZASSIST_RUN`/
`ZASSIST_S_REGISTO` criados pelo utilizador (domínios+elementos `ZASSIST_REFERENCIA`,
`ZASSIST_DOCUMENTO`, `ZASSIST_EMAIL_STATUS`, a tabela `ZASSIST_RUN`, a estrutura `ZASSIST_S_REGISTO`)
foram criados no pacote `ZEMAIL`, não `ZASSIST`. Uma primeira tentativa de reatribuição via SE11 →
Object Directory Entry **não surtiu efeito** (confirmado via MCP: os objectos continuaram em `ZEMAIL`
mesmo depois do utilizador reportar tê-los reatribuído — possivelmente a mudança não foi guardada com
transporte, ou o campo certo não foi alterado). Em vez de insistir com SE03 (mass change), **o
utilizador decidiu aceitar `ZEMAIL` como pacote definitivo para todos os objectos `ZASSIST_*`** — ver
achado 3 acima e a nota "Pasta única" em `CLAUDE.md`. Dois objectos entretanto também criados
(`ZASSIST_T_REGISTO`, classe de mensagens `ZASSIST`) já foram criados directamente em `ZEMAIL`, o que
agora está correcto.

- [x] Decisão tomada e documentada (`CLAUDE.md`, `PLANO_REFACTOR_ZEMAIL.md`, este ficheiro).
- [x] Ficheiros `src/zassist/*` movidos para `src/zemail/` via `git mv` (sem alteração de conteúdo).

## Confirmação e fecho do gate

- [ ] Confirmar em PFCG/SU21 os campos reais de `P_ORGIN` (`INFTY`/`SUBTY`/`PERSA`/`PERSG`/`PERSK`/
      `VDSK1`/`ACTVT`) usados em `ZCL_ASSIST_NOTIF_BUILDER->send_notifications` — não confirmáveis via
      MCP (sem ferramenta para objectos de autorização); baseados em conhecimento SAP HR padrão.
- [x] `ZASSIST_RUN`, `ZASSIST_S_REGISTO`, `ZASSIST_T_REGISTO` criados em SE11 (pacote `ZEMAIL`).
- [x] Classe de mensagens `ZASSIST` criada em SE91 (pacote `ZEMAIL`) — **confirmar que inclui os textos
      020–025 de T5.4**, além de 001/010–013 (T5.2).
- [ ] Utilizador importa/activa os 11 objectos de código agora em `src/zemail/` via abapGit (pacote
      `ZEMAIL`, mesmo repositório único já ligado): `ZCX_ASSIST_PROCESS`, `ZIF_ASSIST_FILE_READER`,
      `ZCL_FILE_READER_FRONTEND`, `ZCL_FILE_READER_SERVER`, `ZCL_ASSIST_VALIDATOR`,
      `ZIF_ASSIST_RUN_REPOSITORY`, `ZCL_ASSIST_RUN_REPOSITORY_DB`, `ZCL_ASSIST_FI_POSTER`,
      `ZCL_ASSIST_NOTIF_BUILDER`, `ZCL_ASSIST_MEDIC_PROCESSOR`, `ZRP_ASSIST_MEDIC`.
- [ ] Claude Code confirma via MCP que os objectos existem e estão activos em `ZEMAIL`.
- [ ] Utilizador corre ABAP Unit no CBD (T5.4/T5.6 têm testes).
- [ ] Utilizador testa `ZRP_ASSIST_MEDIC` em modo teste com o CSV de exemplo (preparado em T6.3, ou um
      subconjunto reaproveitado aqui se disponível mais cedo).
- [ ] Confirmar via MCP (where-used) que nenhuma classe `ZCL_EMAIL_*`/`ZCL_TEMPLATE_*`/`ZIF_EMAIL_*`
      (framework `ZEMAIL`) referencia uma classe `ZCL_ASSIST_*` (regra arquitectural invariável —
      dependência de código, não de pacote; ver nota "Pasta única" em `CLAUDE.md`).
- [ ] `PLANO_REFACTOR_ZEMAIL.md` — secção "Estado actual": marcar Fase 5 como fechada.
- [ ] Fase 6 (validação final) pode então arrancar.

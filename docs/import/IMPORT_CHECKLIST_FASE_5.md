# IMPORT CHECKLIST — Fase 5 (Pacote ZASSIST)

> Tarefas **T5.1–T5.9**. DDIC em `docs/ddic/` (criação manual em SE11 pelo utilizador, como nas fases
> anteriores); código ABAP em `src/zassist/`, formato abapGit, para importar no CBD no pacote
> **`ZASSIST`** (já existe). Claude Code não escreve nada no SAP.

## Objectos e ficheiros

| # | Ficheiro | Objecto/finalidade | Feito |
|---|---|---|---|
| 5.1a | `docs/ddic/zassist_run.md` | Tabela `ZASSIST_RUN` — controlo de execuções/dedup | [x] especificação escrita |
| 5.1b | `docs/ddic/zassist_s_registo.md` | `ZASSIST_S_REGISTO`/`ZASSIST_T_REGISTO` — substitui `TY_DADO`/`TT_DADO` | [x] especificação escrita |
| 5.2 | `zcx_assist_process.clas.abap` + `docs/msg/zassist_messages.md` | Excepção T100 do pacote `ZASSIST` | [x] escrito em Git |
| 5.3 | `zif_assist_file_reader.intf.abap`, `zcl_file_reader_frontend.clas.abap`, `zcl_file_reader_server.clas.abap` | Leitura do CSV (frontend `GUI_UPLOAD` / servidor `OPEN DATASET`) | [ ] |
| 5.4 | `zcl_assist_validator.clas.abap` + `.testclasses.abap` | Validações (mesmas regras de `ZCL_MEDICAL_ASSIST_PROCESS->validar_dados`) | [ ] |
| 5.5 | `zcl_assist_fi_poster.clas.abap` | Lançamento FI via `BAPI_ACC_DOCUMENT_POST` + dedup `ZASSIST_RUN` | [ ] |
| 5.6 | `zcl_assist_notif_builder.clas.abap` + `.testclasses.abap` | Monta `it_values` e chama a fachada `ZEMAIL` (`ZDEBIT_NOTE_HCB`) | [ ] |
| 5.7 | `zcl_assist_medic_processor.clas.abap` | Orquestrador reader→validator→poster→notif_builder | [ ] |
| 5.8 | `zrp_assist_medic.prog.abap` | Report de execução (frontend/servidor, modo teste, ALV de resultados) | [ ] |

## Achados desta fase (via MCP)

1. **`ZCL_MEDICAL_ASSIST_PROCESS` lido via MCP (2026-07-16):** `ty_dado` e as regras de
   `validar_dados`/`carregar_lancamentos`/`enviar_emails` documentadas tal como estão hoje, para
   replicação fiel em T5.1–T5.7 (ver decisões em `PLANO_REFACTOR_ZEMAIL.md`, secção Fase 5).
2. **Pacote `ZASSIST` já existe no CBD** (confirmado via `SearchObject`), assim como um grupo de funções
   `ZASSIST` não documentado no `CLAUDE.md` — **confirmado pelo utilizador (2026-07-16): não usado,
   ignorar.**
3. **Ligação abapGit:** o `.abapgit.xml` deste repositório (raiz) já está ligado ao pacote `ZEMAIL`
   (`STARTING_FOLDER=/src/zemail/`). `ZASSIST` é um pacote independente — vai precisar de uma **segunda
   ligação de repositório abapGit** no CBD (mesmo URL do GitHub com uma pasta de início diferente, ou um
   repositório GitHub separado) antes de se poder importar `src/zassist/`. Não bloqueia a escrita de
   código agora — só relevante no momento de importar.
3. **`GJAHR`/`BELNR_D` (elementos standard) não confirmados por leitura directa de código real** — ao
   contrário de `PERNR_D`/`BUKRS`/`SAKNR`/`KOSTL`/`DMBTR`/`WAERS`, que estão comprovadamente em uso em
   `ty_dado` hoje. `zassist_run.md` sinaliza isto explicitamente; confirmar em SE11 ao criar a tabela.

## Confirmação e fecho do gate

- [ ] Utilizador cria `ZASSIST_RUN`, `ZASSIST_S_REGISTO`, `ZASSIST_T_REGISTO` em SE11 (secção 5.1).
- [ ] Utilizador cria a classe de mensagens `ZASSIST` em SE91 (T5.2).
- [ ] Utilizador importa/activa os objectos `src/zassist/` via abapGit (pacote `ZASSIST`).
- [ ] Claude Code confirma via MCP que os objectos existem e estão activos em `ZASSIST`.
- [ ] Utilizador corre ABAP Unit no CBD (T5.4/T5.6 têm testes).
- [ ] Utilizador testa `ZRP_ASSIST_MEDIC` em modo teste com o CSV de exemplo (preparado em T6.3, ou um
      subconjunto reaproveitado aqui se disponível mais cedo).
- [ ] Confirmar via MCP que nenhum objecto `ZEMAIL` referencia `ZASSIST` (regra arquitectural invariável).
- [ ] `PLANO_REFACTOR_ZEMAIL.md` — secção "Estado actual": marcar Fase 5 como fechada.
- [ ] Fase 6 (validação final) pode então arrancar.

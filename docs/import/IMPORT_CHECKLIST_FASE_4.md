# IMPORT CHECKLIST — Fase 4 (Templates e manutenção ZEMAIL)

> Tarefa **T4.4**. Programas em `src/zemail/`, formato abapGit (mesmo padrão das Fases 2–3) — importar
> via abapGit no CBD, pacote **`ZEMAIL`**. Templates HTML em `templates/` (não são objectos SAP, servem de
> input para `ZEMAIL_TMPL_LOAD`, T4.1). Claude Code não escreve nada no SAP nem carrega templates.

## Objectos e ficheiros

| # | Ficheiro | Objecto/finalidade | Feito |
|---|---|---|---|
| 4.1 | `zemail_tmpl_load.prog.abap` + `.prog.xml` | `ZEMAIL_TMPL_LOAD` — carregar HTML de ficheiro para nova versão Rascunho | [ ] |
| 4.2a | `templates/zhcb_master.html` | Moldura HCB (não é objecto SAP — input do `ZEMAIL_TMPL_LOAD`) | [ ] |
| 4.2b | `templates/zhcb_debit_note.html` | Corpo da nota de débito (idem) | [ ] |
| 4.3 | `zemail_tmpl_maint.prog.abap` + `.prog.xml` | `ZEMAIL_TMPL_MAINT` — SALV de manutenção (pré-visualizar/testar/activar) | [ ] |

`ZCL_EMAIL_FACTORY` foi alterada nesta fase (novo método `create_sender`) — reimportar/reactivar
também esse objecto (já existente desde a Fase 3).

## Achados desta fase (via MCP, após reconexão do abap-adt)

1. **`ZLOAD_EMAIL_TEMPLATE` (programa substituído) lido via MCP:** fazia `DELETE` de todo o conteúdo
   anterior do `ZTMPL_CONTENT` para o `TEMPLATE_ID`, depois reinseria com fragmentação em blocos de 255
   caracteres (`ZSEQ` sequencial), sem qualquer noção de versão/rascunho/activo. `ZEMAIL_TMPL_LOAD`
   (T4.1) substitui isto por: 1 registo `STRING` (sem fragmentação, graças ao tipo embutido `string` do
   `ZEMAIL_TMPL_CNT-CONTENT`), como nova versão `ESTADO='R'` com número sequencial — o conteúdo anterior
   nunca é apagado, fica disponível para consulta/rollback via `ZEMAIL_TMPL_MAINT`.
2. **`ZTMPL_CONTENT` lido via MCP (160 linhas, `ZTEMPLATE_ID='ZDEBIT_NOTE_HCB'`):**
   - **Já usa `{{...}}`** em todos os placeholders (`{{REF}}`, `{{DATA}}`, `{{TABLE_ROWS}}`,
     `{{TOTAL_VALOR}}`, `{{TOTAL_DEBITO}}`) — **não havia variáveis num formato antigo para converter**,
     ao contrário do que o texto do plano assumia. Confirmado por leitura directa, não por suposição.
   - **Sem separação master/child** — é um único documento HTML monolítico. A divisão para
     `zhcb_master.html`/`zhcb_debit_note.html` foi feita nos limites das secções já comentadas no próprio
     HTML original (`<!-- 1. CABECALHO PRETO -->` até `<!-- 9. RODAPE -->` → moldura; `<!-- 2 + 3.
     TITULO E SAUDACAO -->` até `<!-- 8. ASSINATURA -->` → corpo, injectado em `{{BODY}}`).
   - **3 pontos de junção sem `ZSEQ` intermédio** (o algoritmo antigo de fragmentação a 255 caracteres
     cortou a meio de palavras/atributos): `ZSEQ` 83→84 (frase cortada a meio), 123→124 (atributo
     `stroke="f"` cortado), 130→131 (`line-height` cortado). Reconstituídos sem quebra de linha nesses
     três pontos; confirmados visualmente porque o texto só faz sentido gramatical/sintáctico assim.
   - **Sem nenhuma tag `<img>`** — a marca "HCB" no cabeçalho é texto estilizado, não uma imagem. **O
     problema do "logo quebrado" mencionado no plano não se aplica ao conteúdo actualmente activo em
     produção.** A capacidade de anexos inline (`ZCL_EMAIL_RENDERER`/`ZCL_EMAIL_SENDER_BCS`, Fase 3) fica
     implementada e pronta, mas não é exercida por nenhum template real neste momento.
3. **`ZEMAIL_TMPL_MAINT` (T4.3):** escolhida a opção "download `.html`" para pré-visualização em vez de
   embutir `CL_GUI_HTML_VIEWER` (que exigiria um ecrã/container próprio — complexidade extra não
   justificada para um utilitário de manutenção). Verificadas via MCP as assinaturas de `CL_SALV_TABLE`
   (`FACTORY`), `CL_SALV_FUNCTIONS` (`ADD_FUNCTION`), `CL_SALV_EVENTS`/`CL_SALV_EVENTS_TABLE`
   (`ADDED_FUNCTION`), `CL_GUI_FRONTEND_SERVICES` (`FILE_SAVE_DIALOG`/`GUI_DOWNLOAD`) e
   `BAPI_USER_GET_DETAIL` (obter o e-mail do utilizador actual via SU01, para "enviar teste").
4. **`ZCL_EMAIL_FACTORY=>create_sender( )`** — método novo, não previsto no plano original. Necessário
   porque `ZIF_EMAIL_SERVICE~send` só resolve a versão **activa** de um template; a acção "enviar teste"
   de `ZEMAIL_TMPL_MAINT` precisa de testar a versão **seleccionada na ALV** (que pode ser um rascunho
   ainda não activado), pelo que monta a mensagem directamente (reaproveitando `ZCL_TEMPLATE_REPOSITORY_DB`
   para resolver a moldura) e envia via um `ZIF_EMAIL_SENDER` isolado, sem passar pelo motor de resolução
   de versão activa.

## Confirmação e fecho do gate

- [ ] Utilizador cria o cabeçalho `ZEMAIL_TMPL` para `ZDEBIT_NOTE_HCB` em `ZEMAIL_CONFIG`... na verdade em
      `ZEMAIL_TMPL` (SM30/SE16, se ainda não existir) e para o template de moldura (`master_id` em branco).
- [ ] Utilizador executa `ZEMAIL_TMPL_LOAD` com `templates/zhcb_master.html` (`TEMPLATE_ID` da moldura,
      `SPRAS='P'`) e depois com `templates/zhcb_debit_note.html` (`TEMPLATE_ID='ZDEBIT_NOTE_HCB'`,
      `MASTER_ID` apontando para a moldura, `SPRAS='P'`).
- [ ] Utilizador activa ambas as versões carregadas via `ZEMAIL_TMPL_MAINT` (acção "Activar").
- [ ] Utilizador testa "Pré-visualizar" (download `.html`, confirmar visualmente no browser) e "Enviar
      teste" (confirmar recepção com HTML renderizado, sem `{{` por resolver visível).
- [ ] Utilizador importa/activa `ZEMAIL_TMPL_LOAD`, `ZEMAIL_TMPL_MAINT` e a `ZCL_EMAIL_FACTORY` actualizada
      via abapGit.
- [ ] Claude Code confirma via MCP que os 2 programas existem em `ZEMAIL`.
- [ ] `PLANO_REFACTOR_ZEMAIL.md` — secção "Estado actual": marcar Fase 4 como fechada, com a data de
      confirmação do utilizador.
- [ ] Fase 5 (migração do processo ZASSIST) pode então arrancar.

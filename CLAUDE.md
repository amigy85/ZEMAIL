# CLAUDE.md — Projecto ZASSIST_MEDIC / Framework ZEMAIL

## Contexto do projecto

Refactoração da solução SAP de Notas de Débito de Assistência Médica da HCB (Hidroeléctrica de Cahora Bassa) num framework corporativo reutilizável de e-mails HTML.

- **Sistema alvo:** SAP ECC on-premise, ABAP 7.40 — sintaxe 7.40 apenas (sem 7.50+: nada de `CL_SMTG_EMAIL_API`, etc.)
- **Ambiente:** CBD/010 (`vhhdbcbdci.sap.hcb.co.mz:44300`, HTTPS)
- **Este repositório Git é o local de trabalho.** Todo o código ABAP é produzido aqui, em formato abapGit, e importado no SAP pelo utilizador.

## Estrutura do repositório (alvo)

O repositório começa vazio (apenas este ficheiro e `PLANO_REFACTOR_ZEMAIL.md`) e as pastas abaixo são criadas tarefa a tarefa, conforme o plano:

```
/
├── CLAUDE.md
├── PLANO_REFACTOR_ZEMAIL.md
├── docs/
│   ├── ddic/                  ← especificações DDIC (1 ficheiro .md por tabela/estrutura)
│   ├── msg/                   ← especificação das classes de mensagens
│   └── import/                ← IMPORT_CHECKLIST_FASE_N.md por fase
├── src/
│   ├── zemail/                ← pacote ZEMAIL em formato abapGit
│   └── zassist/                ← pacote ZASSIST em formato abapGit
└── templates/                 ← HTML carregado via ZEMAIL_TMPL_LOAD
```

## Comandos

Não há build/lint/test locais — este é um repositório de fontes ABAP para importação via abapGit, não um projecto com toolchain própria.

- **Sintaxe/estilo:** revisão estática manual contra as "Convenções de código" abaixo (não há linter local).
- **ABAP Unit e ATC:** correm exclusivamente no CBD, depois do utilizador importar e activar os objectos — nunca localmente. Ver secção "Testes".
- **MCP ABAP (leitura):** usar para consultar assinaturas standard, campos DDIC e fontes Z existentes antes de escrever código — nunca para criar/alterar/activar.

## ⚠️ Modelo de acesso ao SAP (fundamental)

Os MCP servers ABAP (`abap-adt` / `abap-adt-api`) estão em modo **APENAS LEITURA**:

- **PODE:** ler fontes de objectos Z existentes (ZCL_BAL_LOGGER, ZCL_MEDICAL_ASSIST_PROCESS, ZTMPL_CONTENT...), consultar assinaturas de classes standard (CL_BCS, CL_BCS_CONVERT, CL_MIME_REPOSITORY_API), verificar campos DDIC (PA0105, T100...), fazer where-used, confirmar se um nome de objecto já existe no CBD.
- **NÃO PODE:** criar, alterar, activar, transportar ou executar objectos no SAP. Se uma chamada de escrita falhar ou parecer disponível, **não insistir nem contornar** — a escrita no SAP é sempre feita pelo utilizador.
- Ciclo de trabalho: **consultar via MCP → escrever em Git → utilizador importa/activa no CBD → utilizador confirma → fase fecha.**

## Fonte de verdade das tarefas

O plano de execução completo está em **`PLANO_REFACTOR_ZEMAIL.md`** (mesma pasta). Regras:

1. Executar as tarefas **pela ordem** (T1.1 → T6.5), seguindo o "Fluxo por tarefa" definido no plano. Não saltar fases.
2. Antes de cada tarefa: reler a secção do plano + "Regras globais"; consultar via MCP o que for necessário (não escrever assinaturas standard de memória).
3. Ao concluir: marcar `- [x]` no plano, actualizar o `docs/import/IMPORT_CHECKLIST_FASE_N.md` e fazer commit (`feat(zemail): T3.2 ZCL_TEMPLATE_PROVIDER_DB`).
4. Uma **fase** só fecha quando o utilizador confirmar que os objectos foram importados e activados no CBD e (quando aplicável) que os ABAP Unit passaram lá. Até essa confirmação, pode continuar-se a escrever código em Git, assumindo as definições do plano como contrato.
5. Não implementar nada do "Fora de âmbito", mesmo que pareça útil.
6. Em caso de ambiguidade ou conflito com o sistema real (nome já existe, campo diferente do previsto), **parar e perguntar**.

## Formato dos ficheiros (abapGit)

- Classes: `nome.clas.abap`; testes locais SEMPRE em ficheiro separado `nome.clas.testclasses.abap` (erro conhecido do projecto: testes dentro do .clas.abap partem a importação abapGit).
- Interfaces: `nome.intf.abap` · Reports: `nome.prog.abap`
- DDIC e classes de mensagens: especificação em `docs/ddic/` e `docs/msg/` (criação manual em SE11/SE91 pelo utilizador) — não gerar XML abapGit.
- Templates HTML em `templates/` (carregados via ZEMAIL_TMPL_LOAD).

## Regras de arquitectura (invioláveis)

- `ZEMAIL` **nunca** referencia objectos `ZASSIST` (dependência unidireccional ZASSIST → ZEMAIL).
- Dependências injectadas por construtor; composição por omissão só na `ZCL_EMAIL_FACTORY`.
- Consumidores dependem de interfaces (`ZIF_*`), nunca de classes concretas do framework (excepto a factory).
- Placeholders: `{{NOME}}` / `{{TAB:NOME}}`. E-mail nunca sai com placeholder por resolver.
- Excepções sempre com `IF_T100_MESSAGE` (classes de mensagens `ZEMAIL` / `ZASSIST`). Proibido lançar excepções com strings soltas.
- Zero literais mágicos: constantes em `ZIF_EMAIL_CONST`; parâmetros (subtipo PA0105, remetente...) em `ZEMAIL_CONFIG`.

## Convenções de código

- **Clean ABAP:** métodos ≤ 25 linhas de lógica; um nível de abstracção por método; nomes por intenção em inglês (`resolve_inline_images`), comentários e mensagens em **português**.
- Sintaxe moderna 7.40 onde clarifica: `VALUE #( )`, `DATA(...)`, string templates.
- Prefixos: `lv_/lt_/ls_/lo_` locais, `mv_/mt_/ms_/mo_` atributos, `iv_/it_/is_/io_` parâmetros.
- Tabelas internas `HASHED`/`SORTED` para lookups em loop; **nunca** SELECT dentro de LOOP.
- Um único `RETURNING` por método sempre que possível; atributos `READ-ONLY` por omissão.
- `AUTHORITY-CHECK` obrigatório antes de PA0105 (`P_ORGIN`) e de lançamentos FI (`F_BKPF_BUK`).
- `COMMIT WORK` proibido dentro de classes do framework ZEMAIL — responsabilidade do chamador.

## Testes

- ABAP Unit criado **na mesma tarefa** que a classe, no ficheiro `.clas.testclasses.abap`.
- Test doubles via interfaces (`ZIF_TEMPLATE_PROVIDER`, `ZIF_EMAIL_SENDER`, `ZIF_LOGGER`) — **proibido** `LOCAL FRIENDS` e acesso a estado privado.
- Risk level HARMLESS, duration SHORT; nenhum teste toca na BD real nem envia e-mails.
- Os testes **correm no CBD**, não localmente — o resultado é reportado pelo utilizador no gate de cada fase.

## O que NÃO fazer

- Não tentar escrever no SAP via MCP em circunstância alguma.
- Não alterar nem apagar os objectos da solução actual (`ZCL_EMAIL_TEMPLATE`, `ZCL_EMAIL_SERVICE`, `ZCL_DEBIT_NOTE_NOTIFICATION`, `ZCL_MEDICAL_ASSIST_PROCESS`, `ZRP_ASSIST_PROCESSOR_EXEC`, `ZTMPL_CONTENT`) — servem de referência de leitura e ficam intactos até ao ciclo em paralelo ser aprovado.
- Não criar ficheiros fora da estrutura de pastas definida sem confirmar.
- Não usar `WWW_HTML_MERGER`, SO10 nem fragmentação CHAR 255 para templates.
- Não inventar nomes/assinaturas de objectos standard de memória: verificar via MCP antes de usar.

## Estado actual

- [ ] Fase 1 — DDIC ZEMAIL (especificações docs/ddic/) — gate: criados em SE11/SE91
      Todos os 26 objectos confirmados via MCP em 2026-07-14, mas ainda no pacote local `$TEMPCAI-S2`
      (decisão do utilizador: construir tudo primeiro, migrar para `ZEMAIL` depois). Fase só fecha
      quando essa migração for confirmada.
- [x] Fase 2 — Excepções e interfaces — gate: importados/activados no CBD
      Confirmado via MCP em 2026-07-14: os 8 objectos (3 excepções + 5 interfaces) existem, activos,
      já no pacote definitivo `ZEMAIL` (importados via abapGit a partir de
      github.com/amigy85/ZEMAIL). Sem ABAP Unit aplicável nesta fase (excepções/interfaces sem lógica).
- [ ] Fase 3 — Núcleo do framework — gate: activados + ABAP Unit verdes no CBD
      Objectos todos activos em `ZEMAIL` (confirmado via MCP). Validação end-to-end parcial feita via
      `ZEMAIL_TMPL_MAINT` "Enviar teste" (`ZCL_EMAIL_FACTORY=>create_sender`, `ZCL_TEMPLATE_REPOSITORY_DB`,
      `ZCL_EMAIL_SENDER_BCS` — e-mail recebido com sucesso, 2026-07-16). Falta: ABAP Unit reportado pelo
      utilizador e teste do caminho completo `create_notification_service( )->send( )`.
- [x] Fase 4 — Templates e manutenção — gate: templates carregados e activados
      Confirmado 2026-07-16: `ZHCB_MASTER`/`ZDEBIT_NOTE_HCB` carregados via `ZEMAIL_TMPL_LOAD` e
      activados via `ZEMAIL_TMPL_MAINT`; e-mail de teste recebido com moldura+corpo renderizados.
- [ ] Fase 5 — Pacote ZASSIST — gate: activados + ABAP Unit verdes no CBD
- [ ] Fase 6 — Validação final (ATC, ponta-a-ponta, SOST)

(Actualizar esta lista e os checkboxes do plano à medida que as fases fecham. Registar em cada fase a data de confirmação do utilizador.)

# CLAUDE.md — Projecto ZASSIST_MEDIC / Framework ZEMAIL

## Contexto do projecto

Refactoração da solução SAP de Notas de Débito de Assistência Médica da HCB (Hidroeléctrica de Cahora Bassa) num framework corporativo reutilizável de e-mails HTML.

- **Sistema alvo:** SAP ECC on-premise, ABAP 7.40 — sintaxe 7.40 apenas (sem 7.50+: nada de `CL_SMTG_EMAIL_API`, etc.)
- ⚠️ **Descoberto em 2026-07-16 (Fase 5, `ZRP_ASSIST_MEDIC`):** o CBD rejeita `FILTER` ("Operador não
  previsto") — indício de estar numa support package de 7.40 anterior à SP08, que introduziu
  `FILTER`/`REDUCE`/`FOR ... WHERE`/`BASE` em constructor expressions. **Evitar estas quatro construções
  em código novo** (usar `LOOP`/`READ TABLE`/`APPEND` em vez disso); `VALUE`/`COND`/`SWITCH`/`NEW`/`CONV`/
  string templates/`VALUE #( (...) (...) )` continuam confirmados a compilar (Fases 2–4).
- ⚠️ **Descoberto em 2026-07-16 (`ZCL_ASSIST_FI_POSTER`):** `CALL FUNCTION` (interface clássica de
  function module) **não aceita uma chamada de método em nenhuma posição de parâmetro**
  (`EXPORTING`/`IMPORTING`/`TABLES`) — só uma variável já calculada ou uma constructor expression
  (`VALUE`/`COND`/...). `documentheader = build_header( ... )` e `toyear = year_from_csv_date( ... )`
  dispararam ambos "No method can be specified in the current position". **Regra para código novo:**
  antes de qualquer `CALL FUNCTION`, pré-calcular cada valor que vier de uma chamada de método numa
  variável simples (`DATA(lv_x) = metodo( ... ).`) e só depois referenciar essa variável no
  `CALL FUNCTION`. Isto não se aplica a chamadas `obj->metodo( ... )` (sintaxe OO moderna), só ao
  `CALL FUNCTION` procedimental.
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
│   └── zemail/                ← todo o código-fonte, incluindo os objectos ZCX_ASSIST_*/ZIF_ASSIST_*/
│                                 ZCL_ASSIST_*/ZRP_ASSIST_MEDIC (ver nota "Pasta única" abaixo)
└── templates/                 ← HTML carregado via ZEMAIL_TMPL_LOAD
```

### ⚠️ Pasta única `src/zemail/` (decisão do utilizador, 2026-07-16)

O repositório Git só está ligado a **um** repositório abapGit no CBD (`.abapgit.xml` na raiz, `NAME=ZEMAIL`,
`STARTING_FOLDER=/src/zemail/`). Ligar um segundo repositório para o pacote `ZASSIST` revelou-se mais
fricção do que valia a pena nesta fase — **decisão: todos os objectos `ZASSIST_*`/`ZCL_ASSIST_*`/
`ZIF_ASSIST_*`/`ZCX_ASSIST_PROCESS`/`ZRP_ASSIST_MEDIC` (DDIC e código) ficam fisicamente no pacote SAP
`ZEMAIL`, e os ficheiros correspondentes vivem em `src/zemail/` (não existe mais `src/zassist/`)**.

Isto é uma acomodação de ferramentas (abapGit/SE11), **não** uma alteração de arquitectura: a regra
"`ZEMAIL` nunca referencia objectos `ZASSIST`" continua válida ao nível do código ABAP (nenhuma classe
`ZCL_EMAIL_*`/`ZCL_TEMPLATE_*`/etc. pode chamar uma classe `ZCL_ASSIST_*`) — só deixou de haver
separação física de pacote/pasta. Se no futuro se justificar separar de novo (ex. transporte
independente do `ZASSIST`), os objectos `ZASSIST_*` teriam de ser reatribuídos de pacote (SE03) e os
ficheiros movidos de volta para uma pasta própria.

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

- `ZEMAIL` **nunca** referencia objectos `ZASSIST` (dependência unidireccional ZASSIST → ZEMAIL) — regra
  sobre dependência de código (nenhuma classe do framework `ZEMAIL` chama uma classe `ZCL_ASSIST_*`),
  independente de os objectos `ZASSIST_*` partilharem fisicamente o pacote/pasta `ZEMAIL` (ver nota
  "Pasta única" acima).
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
- [x] Fase 3 — Núcleo do framework — gate: activados + ABAP Unit verdes no CBD
      Fechada 2026-07-16. Objectos todos activos em `ZEMAIL`; ABAP Unit de T3.2/T3.3/T3.4 verdes (depois
      de corrigido `ZCL_PLACEHOLDER_SERVICE=>build_data_rows`, `WRITE ... TO` não aceita alvo `STRING`);
      `BAL_SUBOBJECT=EMAIL_SEND` registado em SLG0 e os 6 registos de `ZEMAIL_CONFIG` inseridos; caminho
      completo `create_notification_service( )->send( )` validado de ponta a ponta via `ZEMAIL_TMPL_MAINT`
      "Enviar teste" sobre a versão activa de `ZDEBIT_NOTE_HCB` — e-mail recebido com sucesso.
- [x] Fase 4 — Templates e manutenção — gate: templates carregados e activados
      Confirmado 2026-07-16: `ZHCB_MASTER`/`ZDEBIT_NOTE_HCB` carregados via `ZEMAIL_TMPL_LOAD` e
      activados via `ZEMAIL_TMPL_MAINT`; e-mail de teste recebido com moldura+corpo renderizados.
- [ ] Fase 5 — Processo de assistência médica (código em `src/zemail/`, pacote `ZEMAIL` — ver nota
      "Pasta única") — gate: activados + ABAP Unit verdes no CBD
      Código escrito em Git (T5.1–T5.8). DDIC (`ZASSIST_RUN`, `ZASSIST_S_REGISTO`, `ZASSIST_T_REGISTO`,
      classe de mensagens `ZASSIST`) criado no CBD, no pacote `ZEMAIL` (decisão do utilizador,
      2026-07-16). Falta: importar/activar os 11 objectos de código, ABAP Unit (T5.4/T5.6) e teste
      manual de `ZRP_ASSIST_MEDIC`.
- [ ] Fase 6 — Validação final (ATC, ponta-a-ponta, SOST)

(Actualizar esta lista e os checkboxes do plano à medida que as fases fecham. Registar em cada fase a data de confirmação do utilizador.)

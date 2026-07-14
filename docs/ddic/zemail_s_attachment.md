# ZEMAIL_S_ATTACHMENT / ZEMAIL_T_ATTACHMENT + campo ATTACHMENTS (SE11)

> Especificação para criação/alteração manual em SE11 pelo utilizador. Claude Code não escreve DDIC no
> SAP. Pré-requisito de **T3.5** (`ZCL_EMAIL_RENDERER`), adiado da Fase 1 por decisão do utilizador
> (2026-07-10) e retomado agora (2026-07-14) para desbloquear T3.5/T3.6.

## Objectivo

Suporte DDIC para anexos inline (imagens `cid:` resolvidas do MIME Repository por `ZCL_EMAIL_RENDERER`,
T3.5, e anexadas via `ADD_ATTACHMENT` em `ZCL_EMAIL_SENDER_BCS`, T3.6). Estrutura mínima já antecipada em
`docs/ddic/zemail_estruturas.md` (T1.4) quando este trabalho ainda estava planeado para a Fase 1.

## `ZEMAIL_S_ATTACHMENT` (Data Type → Structure)

Um anexo inline resolvido, referenciado no HTML via `cid:`.

| Campo | Tipo | Elemento de dados / Domínio | Descrição |
|---|---|---|---|
| CONTENT_ID | CHAR40 | `ZEMAIL_CONTENT_ID` (novo) | Identificador usado em `cid:` no HTML (ex.: `logo_hcb`) |
| CONTENT | RAWSTRING | tipo embutido `xstring` | Conteúdo binário do anexo, lido do MIME Repository |
| MIMETYPE | CHAR128 | `W3CONTTYPE` (standard, já confirmado existente via MCP em T1.4) | Tipo MIME (ex.: `image/png`) |

### Domínio/elemento de dados novo a criar (antes da estrutura)

**`ZEMAIL_CONTENT_ID`** — domínio `CHAR(40)`; elemento de dados homónimo, rótulo "Content-ID Anexo".

Reutilizar: `W3CONTTYPE` (standard — não criar).

## `ZEMAIL_T_ATTACHMENT` (Data Type → Table Type)

Table type, linha `ZEMAIL_S_ATTACHMENT`, **Standard Table**, sem chave definida (iteração sequencial ao
montar os anexos na mensagem BCS, T3.6).

## Alteração a `ZEMAIL_S_MESSAGE` (estrutura já activa desde a Fase 1)

Acrescentar um componente novo à estrutura existente **directamente em SE11** (não é `APPEND STRUCTURE` —
essa técnica é para enriquecer tabelas/estruturas standard sem tocar no original; `ZEMAIL_S_MESSAGE` é uma
estrutura Z própria, edita-se directamente):

| Campo | Tipo | Elemento de dados / Domínio | Descrição |
|---|---|---|---|
| ATTACHMENTS | `ZEMAIL_T_ATTACHMENT` | table type (acima) | Anexos inline resolvidos por `ZCL_EMAIL_RENDERER` (pode ser vazia) |

Ordem: criar `ZEMAIL_CONTENT_ID` → `ZEMAIL_S_ATTACHMENT` → `ZEMAIL_T_ATTACHMENT` → só depois acrescentar
`ATTACHMENTS` a `ZEMAIL_S_MESSAGE` e reactivar esta última (e tudo o que dela depende: `ZIF_EMAIL_SENDER`,
`ZCL_TEMPLATE_ENGINE`, etc. — reactivação em cascata automática do SE11/SE80, sem impacto no código já
escrito, pois nenhuma classe actual lê ou escreve `ATTACHMENTS` ainda).

## Pacote / transporte

- **Pacote:** `ZEMAIL` (já existe desde a Fase 2 — diferente da Fase 1, que ainda está em `$TEMPCAI-S2`
  aguardando migração). Criar estes objectos directamente em `ZEMAIL`.
- **Camada de transporte:** `ZEMAIL` (mesma decidida para o pacote).

## Dependências

- **Depende de:** `ZEMAIL_S_MESSAGE` (Fase 1, T1.4 — já activa em `ZEMAIL`... na verdade em
  `$TEMPCAI-S2`, ver nota abaixo).
- **Usado por:** `ZCL_EMAIL_RENDERER` (T3.5), `ZCL_EMAIL_SENDER_BCS` (T3.6).

## ⚠️ Nota — inconsistência de pacote entre Fase 1 e Fase 3

`ZEMAIL_S_MESSAGE` foi criada na Fase 1 e está hoje em `$TEMPCAI-S2` (pacote local, aguardando migração
combinada — ver `docs/import/IMPORT_CHECKLIST_FASE_1.md`). As classes da Fase 3 (`ZCL_TEMPLATE_ENGINE`,
etc.) já foram criadas directamente em `ZEMAIL` e referenciam `ZEMAIL_S_MESSAGE` sem problema — o nome do
pacote de um tipo DDIC não afecta a sua visibilidade para código ABAP noutro pacote, apenas transporte e
organização. Ainda assim, **`ZEMAIL_CONTENT_ID`, `ZEMAIL_S_ATTACHMENT` e `ZEMAIL_T_ATTACHMENT` devem ser
criados directamente em `ZEMAIL`** (não em `$TEMPCAI-S2`), para não aumentar o volume da migração da Fase 1
que ainda está pendente.

# Estruturas e Table Types ZEMAIL (SE11 — Data Type)

> Especificação para criação manual em SE11 pelo utilizador. Claude Code não escreve DDIC no SAP.
> Tarefa do plano: **T1.4** (Fase 1). Verificado via MCP (leitura) em 2026-07-10: sem colisão de nomes
> `ZEMAIL*` no CBD. Elementos standard reutilizados (`AD_SMTPADR`, `AD_NAME1`, `SYSUUID_X`) confirmados
> existentes via MCP; assinatura de `CL_BCS` confirmada via MCP (ver nota sobre `SEND_ID`). `ZEMAIL_S_ATTACHMENT`/
> `ZEMAIL_T_ATTACHMENT` (e o elemento `W3CONTTYPE` que usariam) ficam fora desta fase — decisão do
> utilizador, ver nota após "Ordem de criação recomendada".

## Ordem de criação recomendada

Os domínios/elementos de dados novos primeiro, depois as estruturas simples, por fim as que dependem de
table types de outras estruturas:

1. Domínios/elementos novos (secção seguinte)
2. `ZEMAIL_S_TEMPLATE`
3. `ZEMAIL_S_RECIPIENT` → `ZEMAIL_T_RECIPIENT`
4. `ZEMAIL_S_PLACEHOLDER` → `ZEMAIL_T_PLACEHOLDER`
5. `ZEMAIL_S_MESSAGE` (usa `ZEMAIL_T_RECIPIENT`; sem `ATTACHMENTS` por agora — ver nota)
6. `ZEMAIL_S_SEND_RESULT`

> **Decisão do utilizador (2026-07-10):** `ZEMAIL_S_ATTACHMENT`/`ZEMAIL_T_ATTACHMENT` — o suporte DDIC
> para a lista de anexos inline que `ZCL_EMAIL_RENDERER` (T3.5) vai devolver — **não são criados nesta
> fase**. O plano (T1.4) também não os nomeia explicitamente; ficam para serem especificados e criados
> como sub-tarefa de T3.5, quando o `ZCL_EMAIL_RENDERER` for implementado. Consequência directa:
> `ZEMAIL_S_MESSAGE` fica **sem o campo `ATTACHMENTS`** nesta fase (ver nota nessa secção) — mesmo o
> plano pedindo esse campo em T1.4; o campo será acrescentado por `APPEND STRUCTURE`/edição em SE11
> durante T3.5, com reactivação da estrutura nessa altura.

## Domínios / elementos de dados novos a criar

1. **`ZEMAIL_RECIPIENT_TYPE`** — domínio `CHAR(3)`, **valores fixos**: `TO`, `CC`, `BCC`. Elemento de
   dados homónimo, rótulo "Tipo Destinatário". Os três valores devem ser espelhados como constantes em
   `ZIF_EMAIL_CONST` (T2.4).
2. **`ZEMAIL_PLACEHOLDER_NAME`** — domínio `CHAR(30)`. Elemento de dados homónimo, rótulo "Nome
   Placeholder". Guarda o nome **sem** os delimitadores `{{ }}` (ex.: `NOME`, não `{{NOME}}`); a sintaxe
   regex `[A-Z0-9_:]+` de validação (T3.3) aplica-se ao conteúdo deste campo.
3. **`ZEMAIL_PLACEHOLDER_FORMAT`** — domínio `CHAR(1)`, **valores fixos** (conforme T1.4 do plano):
   - `' '` (espaço) — texto simples, sem formatação
   - `D` — data (conversão DDMMYYYY → formato do utilizador, regra em `ZCL_PLACEHOLDER_SERVICE`, T3.3)
   - `C` — moeda (formatação por `WAERS`, regra em `ZCL_PLACEHOLDER_SERVICE`, T3.3)

   Elemento de dados homónimo, rótulo "Formato Placeholder".
4. **`ZEMAIL_ESTADO_ENVIO`** — domínio `CHAR(1)`, **valores fixos**: `S` (Sucesso), `E` (Erro) — mesma
   convenção já usada para `ZASSIST_RUN-EMAIL_STATUS` (T5.1/T5.6), garantindo um único vocabulário de
   estado de envio em todo o projecto. Elemento de dados homónimo, rótulo "Estado Envio E-mail".

Reutilizar (standard, confirmados via MCP): `AD_SMTPADR` (endereço SMTP — já usado em
`ZCL_DEBIT_NOTE_NOTIFICATION`/`ZCL_EMAIL_SERVICE`), `AD_NAME1` (nome de exibição — idem), `SYSUUID_X`
(identificador do pedido de envio BCS — ver nota sobre `SEND_ID`). `MANDT` não se aplica (estruturas, não
tabelas). `W3CONTTYPE` (tipo MIME) fica reservado para quando `ZEMAIL_S_ATTACHMENT` for criado em T3.5 —
não é necessário nesta fase.

## `ZEMAIL_S_TEMPLATE`

Resultado de `ZIF_TEMPLATE_PROVIDER->get_template( )` (T2.5) — conteúdo resolvido de um template numa
versão/idioma específicos, incluindo o conteúdo da moldura quando aplicável.

| Campo | Tipo | Elemento de dados / Domínio | Descrição |
|---|---|---|---|
| TEMPLATE_ID | CHAR30 | `ZEMAIL_TEMPLATE_ID` (T1.1) | Identificador do template pedido |
| SPRAS | LANG1 | `SPRAS` (standard) | Idioma efectivamente resolvido (pode diferir do pedido, se houve fallback) |
| VERSAO | NUMC4 | `ZEMAIL_VERSAO` (T1.2) | Versão activa resolvida |
| SUBJECT | STRING | tipo embutido `string` | Assunto (com placeholders por resolver) |
| CONTENT | STRING | tipo embutido `string` | Corpo HTML do template (child), com placeholders por resolver |
| MASTER_CONTENT | STRING | tipo embutido `string` | HTML da moldura (master), contendo `{{BODY}}`; vazio se este template não usa moldura |

Estrutura simples (flat), sem componentes de tabela.

## `ZEMAIL_S_RECIPIENT` + `ZEMAIL_T_RECIPIENT`

Um destinatário de e-mail (TO/CC/BCC).

| Campo | Tipo | Elemento de dados / Domínio | Descrição |
|---|---|---|---|
| ADDRESS | CHAR241 | `AD_SMTPADR` (standard) | Endereço de e-mail |
| VISIBLE_NAME | CHAR40 | `AD_NAME1` (standard) | Nome de exibição (ex.: "João Silva") |
| RECIPIENT_TYPE | CHAR3 | `ZEMAIL_RECIPIENT_TYPE` (novo) | `TO` / `CC` / `BCC` |

> Nome do campo: `RECIPIENT_TYPE`, não `TYPE` — `TYPE` é palavra reservada ABAP e não deve ser usada como
> nome de componente (evita necessidade de `esc_type` ou similar nos consumidores).

**`ZEMAIL_T_RECIPIENT`** — table type, linha `ZEMAIL_S_RECIPIENT`, **Standard Table**, sem chave definida
(key category "Standard/Default Key" não é relevante aqui — usada apenas para iteração sequencial pelos
consumidores, nunca para lookup por chave).

## `ZEMAIL_S_PLACEHOLDER` + `ZEMAIL_T_PLACEHOLDER`

Um par nome/valor a substituir no template (para `{{NOME}}` simples — a substituição de tabelas
`{{TAB:NOME}}` é feita por `replace_table( )` recebendo `ANY TABLE` directamente, T3.3, não por esta
estrutura).

| Campo | Tipo | Elemento de dados / Domínio | Descrição |
|---|---|---|---|
| NAME | CHAR30 | `ZEMAIL_PLACEHOLDER_NAME` (novo) | Nome do placeholder, sem `{{ }}` |
| VALUE | STRING | tipo embutido `string` | Valor a inserir (antes de qualquer formatação D/C) |
| FORMAT | CHAR1 | `ZEMAIL_PLACEHOLDER_FORMAT` (novo) | `' '` / `D` / `C` |

**`ZEMAIL_T_PLACEHOLDER`** — table type, linha `ZEMAIL_S_PLACEHOLDER`, **Standard Table**, chave
não-única sobre `NAME` (documental — os consumidores, ex. `ZCL_PLACEHOLDER_SERVICE`, podem reindexar
internamente em `HASHED TABLE` para performance de substituição).

## `ZEMAIL_S_MESSAGE`

Mensagem totalmente montada (moldura + child + placeholders resolvidos), pronta para
`ZIF_EMAIL_SENDER->send( is_message )` (T2.6).

| Campo | Tipo | Elemento de dados / Domínio | Descrição |
|---|---|---|---|
| SUBJECT | STRING | tipo embutido `string` | Assunto final, sem placeholders por resolver |
| BODY_HTML | STRING | tipo embutido `string` | Corpo HTML final (moldura injectada), sem placeholders por resolver |
| RECIPIENTS | `ZEMAIL_T_RECIPIENT` | table type (acima) | Lista de destinatários TO/CC/BCC |
| SENDER | CHAR241 | `AD_SMTPADR` (standard) | Remetente; se vazio, `ZCL_EMAIL_SENDER_BCS` usa `ZEMAIL_CONFIG-SENDER_ADDRESS` (T1.3/T3.6) |

> **`ATTACHMENTS` fica de fora nesta fase** (decisão do utilizador, 2026-07-10) — `ZEMAIL_S_ATTACHMENT`/
> `ZEMAIL_T_ATTACHMENT` só serão especificados e criados em T3.5. Até lá, `ZEMAIL_S_MESSAGE` não suporta
> anexos inline; `ZCL_EMAIL_SENDER_BCS` (T3.6) não deve assumir a existência deste campo enquanto T3.5 não
> o acrescentar (via `APPEND STRUCTURE` em SE11 + reactivação). Registar esta dependência explicitamente
> na tarefa T3.5 quando essa fase for iniciada.

## `ZEMAIL_S_SEND_RESULT`

Resultado devolvido por `ZIF_EMAIL_SERVICE->send( )` (T2.8) ao chamador (ex.: `ZCL_ASSIST_NOTIF_BUILDER`,
T5.6).

| Campo | Tipo | Elemento de dados / Domínio | Descrição |
|---|---|---|---|
| SEND_ID | RAW16 | `SYSUUID_X` (standard) | Identificador do pedido de envio BCS — ver nota abaixo |
| STATUS | CHAR1 | `ZEMAIL_ESTADO_ENVIO` (novo) | `S` / `E` |
| MESSAGE | STRING | tipo embutido `string` | Detalhe (texto de erro, ou confirmação de enfileiramento) |

### Nota — correcção à assinatura de `CL_BCS` usada em `SEND_ID`

O plano (T3.6) descreve "Devolver `send_request->send_request_id( )`". **Esse método não existe em
`CL_BCS`** — confirmado via MCP (lista completa de métodos públicos da classe). O identificador correcto
do pedido de envio persistido é o método **`OID( )`**, que devolve `SYSUUID_X` (`RAISING CX_SEND_REQ_BCS`).
`SEND_ID` acima foi tipado como `SYSUUID_X` para reflectir isto. **Acção de acompanhamento:** ao chegar a
T3.6, `ZCL_EMAIL_SENDER_BCS` deve chamar `mo_send_request->oid( )`, não `send_request_id( )`; o texto do
plano será corrigido nessa altura (ou já corrigido nesta sessão — ver commit).

## Pacote / transporte

- **Pacote:** `ZEMAIL` (ainda não existe no CBD — mesma observação de T1.1/T1.2/T1.3).
- **Camada de transporte:** a mesma decidida em T1.1.

## Dependências

- **Depende de:** `ZEMAIL_TEMPLATE_ID` e `ZEMAIL_VERSAO` (elementos criados em T1.1/T1.2, reutilizados em
  `ZEMAIL_S_TEMPLATE`).
- **Usado por:** `ZIF_TEMPLATE_PROVIDER`, `ZIF_EMAIL_SENDER`, `ZIF_EMAIL_SERVICE` (T2.5/T2.6/T2.8) e todas
  as classes do núcleo do framework (Fase 3).

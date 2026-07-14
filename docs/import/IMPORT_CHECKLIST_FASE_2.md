# IMPORT CHECKLIST — Fase 2 (Excepções e interfaces ZEMAIL)

> Tarefa **T2.9**. Ficheiros em `src/zemail/` escritos em Git, com metadados abapGit (`.clas.xml`/
> `.intf.xml`) para importação directa via abapGit no CBD — decisão do utilizador (2026-07-14),
> **diferente da Fase 1**: estes objectos vão directamente para o pacote **`ZEMAIL`** (não para
> `$TEMPCAI-S2`). Claude Code não escreve nada no SAP nem faz o pull.
>
> **Repositório remoto:** `https://github.com/amigy85/ZEMAIL.git` — código enviado (`git push`) pelo
> Claude Code (acção confirmada pelo utilizador); o **pull no CBD via abapGit é sempre feito pelo
> utilizador**.
>
> **Gate da Fase 2 (definido no plano):** importação abapGit / colagem em SE24-SE80 confirmada pelo
> utilizador.

## ⚠️ Pré-requisito crítico — criar o pacote `ZEMAIL` ANTES do pull

Verificado a partir do código-fonte real do abapGit (`zcl_abapgit_object_devc.clas.abap`,
`github.com/abapGit/abapGit`): o ficheiro `package.devc.xml` **nunca transporta a camada de transporte**
(campo `KORRFLAG`) — esse campo é explicitamente limpo (`CLEAR`) antes de serializar, e ignorado ao
actualizar um pacote já existente. Um exemplo real do próprio repositório abapGit (`src/package.devc.xml`)
confirma isto: só tem `<CTEXT>`, nada mais.

**Consequência prática:** se o pacote `ZEMAIL` não existir antes do pull, o abapGit tenta criá-lo do zero
e a camada de transporte pode ficar indefinida/errada. **Por isso:**

1. Criar o pacote `ZEMAIL` manualmente em **SE21** (ou SE80), com:
   - Camada de transporte: **`ZEMAIL`** (confirmado pelo utilizador, 2026-07-13/14)
   - Descrição: "Framework de e-mail HTML reutilizável (ZEMAIL)"
2. **Só depois** fazer o pull do repositório `https://github.com/amigy85/ZEMAIL.git` no abapGit,
   apontando para este pacote já existente.

## Ficheiros abapGit gerados

| Ficheiro | Objecto/finalidade | Feito |
|---|---|---|
| `.abapgit.xml` (raiz do repo) | Descritor do repositório: `NAME=ZEMAIL`, `STARTING_FOLDER=/src/zemail/`, `FOLDER_LOGIC=PREFIX`, `MASTER_LANGUAGE=P` | [ ] |
| `src/zemail/package.devc.xml` | Metadados do pacote `ZEMAIL` (só `CTEXT` — ver nota acima sobre transporte) | [ ] |
| `src/zemail/*.clas.xml` (×3) | Metadados `VSEOCLASS` para as 3 classes de excepção | [ ] |
| `src/zemail/*.intf.xml` (×5) | Metadados `VSEOINTERF` para os 5 interfaces | [ ] |

Formato de todos os ficheiros verificado directamente contra exemplos reais do próprio repositório
abapGit (`src/objects/zcl_abapgit_object_devc.clas.xml`, `src/objects/zif_abapgit_object.intf.xml`),
não escrito de memória.

## Ordem de criação (dependências)

| # | Ficheiro | Objecto | Depende de | Feito |
|---|---|---|---|---|
| 2.1 | `zcx_email.clas.abap` | `ZCX_EMAIL` | `CX_STATIC_CHECK`, `IF_T100_MESSAGE` (standard) | [ ] |
| 2.2 | `zcx_template.clas.abap` | `ZCX_TEMPLATE` | `ZCX_EMAIL` (2.1) + `ZEMAIL_TEMPLATE_ID`, `ZEMAIL_PLACEHOLDER_NAME` (Fase 1) | [ ] |
| 2.3 | `zcx_email_send.clas.abap` | `ZCX_EMAIL_SEND` | `ZCX_EMAIL` (2.1) + `AD_SMTPADR` (standard) | [ ] |
| 2.4 | `zif_email_const.intf.abap` | `ZIF_EMAIL_CONST` | `ZEMAIL_ESTADO_VERSAO`, `ZEMAIL_RECIPIENT_TYPE`, `ZEMAIL_PLACEHOLDER_FORMAT`, `ZEMAIL_ESTADO_ENVIO` (Fase 1) | [ ] |
| 2.5 | `zif_template_provider.intf.abap` | `ZIF_TEMPLATE_PROVIDER` | `ZCX_TEMPLATE` (2.2) + `ZEMAIL_S_TEMPLATE`, `ZEMAIL_TEMPLATE_ID`, `ZEMAIL_VERSAO`, `SPRAS` | [ ] |
| 2.6 | `zif_email_sender.intf.abap` | `ZIF_EMAIL_SENDER` | `ZCX_EMAIL_SEND` (2.3) + `ZEMAIL_S_MESSAGE`, `SYSUUID_X` | [ ] |
| 2.7 | `zif_logger.intf.abap` | `ZIF_LOGGER` | `CX_ROOT` (standard) | [ ] |
| 2.8 | `zif_email_service.intf.abap` | `ZIF_EMAIL_SERVICE` | `ZCX_EMAIL` (2.1) + `ZEMAIL_T_RECIPIENT`, `ZEMAIL_T_PLACEHOLDER`, `ZEMAIL_S_SEND_RESULT`, `ZEMAIL_TEMPLATE_ID` | [ ] |

## Decisões tomadas nesta tarefa (fora do texto literal do plano)

1. **`ZCX_EMAIL_SEND-MV_CONTENT_ID`** tipado como `string`, não como um elemento `ZEMAIL_CONTENT_ID` —
   esse domínio só será criado em T3.5 (decisão da Fase 1). Ajustar o tipo do atributo nessa altura, se
   se preferir alinhar com o domínio definitivo.
2. **`ZIF_EMAIL_CONST`** inclui um quarto grupo de constantes, `send_status` (`S`/`E`), além dos três
   pedidos literalmente no plano (`version_status`, `recipient_type`, `placeholder_format`) — necessário
   para `ZEMAIL_ESTADO_ENVIO` não virar literal mágico em `ZEMAIL_S_SEND_RESULT-STATUS` (regra "zero
   literais mágicos").
3. **`ZIF_EMAIL_SERVICE~send( )`, parâmetro `it_tables`:** o plano não definia o tipo concreto. Definido
   como `tt_table_placeholder` (tipo local ao próprio interface): tabela de `NAME` (nome do placeholder
   `{{TAB:NAME}}`) + `DATA TYPE REF TO DATA` (referência genérica, porque cada chamador passa uma tabela
   interna de tipo próprio, resolvida por RTTI em `ZCL_PLACEHOLDER_SERVICE->replace_table`, T3.3). Não
   existia — e não faria sentido criar — um tipo DDIC fixo para isto.

## Confirmação e fecho do gate

- [ ] Pacote `ZEMAIL` criado manualmente em SE21 com camada de transporte `ZEMAIL` (ver secção acima).
- [ ] Utilizador faz o pull do repositório `https://github.com/amigy85/ZEMAIL.git` via abapGit no CBD,
      apontando para o pacote `ZEMAIL` já existente, e activa os 8 objectos.
- [ ] Claude Code confirma via MCP (leitura) que os 8 objectos existem **no pacote `ZEMAIL`**.
- [ ] `PLANO_REFACTOR_ZEMAIL.md` — secção "Estado actual": marcar Fase 2 como fechada, com a data de
      confirmação do utilizador.
- [ ] Fase 3 (núcleo do framework) pode então arrancar.

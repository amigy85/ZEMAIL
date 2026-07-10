# ZEMAIL_TMPL — Tabela de cabeçalho de template (SE11)

> Especificação para criação manual em SE11 pelo utilizador. Claude Code não escreve DDIC no SAP.
> Tarefa do plano: **T1.1** (Fase 1). Verificado via MCP (leitura) em 2026-07-10: não existe `ZEMAIL_TMPL`
> nem qualquer objecto `ZEMAIL*` no CBD — sem colisão de nomes. Também não existe ainda o pacote `ZEMAIL`.

## Objectivo

Cabeçalho lógico de um template de e-mail: identifica o template, a que moldura (master) pertence
e metadados de categorização/estado. **Não guarda HTML** — o conteúdo (assunto/corpo, por idioma e
versão) fica em `ZEMAIL_TMPL_CNT` (T1.2), referenciando esta tabela por `TEMPLATE_ID`.

## Definição da tabela

- **Nome:** `ZEMAIL_TMPL`
- **Descrição curta:** Cabeçalho de template de e-mail (ZEMAIL)
- **Delivery class:** A (tabela de aplicação / dados mestre — mantida pelo programa `ZEMAIL_TMPL_MAINT`, T4.3)
- **Data class (Tech. Settings):** APPL1
- **Size category:** 0 (poucos registos esperados — um template por caso de uso de negócio)
- **Buffering:** não activar nesta fase. `ZCL_TEMPLATE_PROVIDER_DB` (T3.2) já faz cache em memória por
  execução; reconsiderar buffering de tabela só se justificado por ST05 mais tarde.

## Campos

| Campo | Chave | Not-null | Tipo | Comprimento | Elemento de dados / Domínio | Descrição |
|---|---|---|---|---|---|---|
| MANDT | X | X | CLNT | 3 | `MANDT` (standard) | Mandante |
| TEMPLATE_ID | X | X | CHAR | 30 | `ZEMAIL_TEMPLATE_ID` (novo) | Identificador único do template (ex.: `ZHCB_DEBIT_NOTE`) |
| MASTER_ID | | | CHAR | 30 | `ZEMAIL_TEMPLATE_ID` (reutilizar) | Template usado como moldura; vazio = este template não é injectado noutro (é auto-suficiente ou é ele próprio a moldura) |
| DESCRICAO | | | CHAR | 60 | `ZEMAIL_DESCRICAO` (novo) | Descrição legível, uso interno/manutenção |
| CATEGORIA | | | CHAR | 1 | `ZEMAIL_CATEGORIA` (novo) | Categoria de negócio do template — sem valores fixos definidos nesta fase |
| ACTIVO | | | CHAR | 1 | `XFELD` (standard) | `'X'` = elegível para uso pelo `ZIF_TEMPLATE_PROVIDER`; `' '` = desactivado |

**Chave primária:** `MANDT` + `TEMPLATE_ID`

## Domínios / elementos de dados novos a criar (antes da tabela)

1. **`ZEMAIL_TEMPLATE_ID`** — domínio `CHAR(30)`; elemento de dados homónimo, rótulo curto "ID Template".
   Reutilizado em `TEMPLATE_ID` e `MASTER_ID`.
2. **`ZEMAIL_DESCRICAO`** — domínio `CHAR(60)`; elemento de dados homónimo, rótulo "Descrição Template".
3. **`ZEMAIL_CATEGORIA`** — domínio `CHAR(1)`; sem valores fixos por agora (podem ser adicionados depois
   sem impacto estrutural na tabela).

Reutilizar objectos standard: `MANDT`, `XFELD` — não criar novos para estes.

## Regras de negócio (validadas em ABAP, não no DDIC)

- Não implementar `MASTER_ID → TEMPLATE_ID` como foreign key técnica do dicionário nesta fase (evitaria
  depender da ordem de carga dos registos). Validar em `ZCL_TEMPLATE_PROVIDER_DB` (T3.2) e/ou no programa
  de manutenção (T4.3) que, quando preenchido, `MASTER_ID` aponta para um `TEMPLATE_ID` existente e activo.
- `ACTIVO = 'X'` é o único critério de elegibilidade para o provider resolver o template.
- Um template com `MASTER_ID` vazio não é injectado no `{{BODY}}` de outro (tipicamente é a própria
  moldura, ex.: `ZHCB_MASTER`).

## Dados iniciais (referência — não criados por esta especificação)

Pelo menos um registo master (ex.: `TEMPLATE_ID = 'ZHCB_MASTER'`, `MASTER_ID = ''`, `ACTIVO = 'X'`) será
carregado via `ZEMAIL_TMPL_LOAD` na Fase 4 (T4.1/T4.2), não inserido manualmente aqui.

## Pacote / transporte

- **Pacote:** `ZEMAIL` — **não existe ainda no CBD** (confirmado via MCP); o utilizador deve criá-lo antes
  ou durante esta tarefa.
- **Camada de transporte:** confirmar com o utilizador se deve seguir a mesma usada pelo pacote `ZASSIST`.

## Dependências

- **Depende de:** nada — primeira tabela da Fase 1.
- **Usado por:** `ZEMAIL_TMPL_CNT` (T1.2, referência lógica por `TEMPLATE_ID`), `ZCL_TEMPLATE_PROVIDER_DB`
  (T3.2), `ZEMAIL_TMPL_LOAD` (T4.1), `ZEMAIL_TMPL_MAINT` (T4.3).

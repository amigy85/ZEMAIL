# ZASSIST — Classe de mensagens (SE91)

> Especificação para criação manual em SE91 pelo utilizador. Claude Code não escreve objectos no SAP.
> Tarefa do plano: **T5.2** (Fase 5). Substitui `ZCX_DEBIT_NOTE_ERROR` (lida via MCP — excepção
> `cx_static_check` com uma única `MV_MESSAGE TYPE string` livre, sem `IF_T100_MESSAGE`), que é
> exactamente o anti-padrão que a regra "Excepções sempre com IF_T100_MESSAGE... proibido lançar
> excepções com strings soltas" (`CLAUDE.md`) proíbe de repetir.

## Classe de mensagens

- **Nome:** `ZASSIST`
- **Descrição curta:** Mensagens do processo de assistência médica (pacote ZASSIST)
- **Pacote:** `ZASSIST` (já existe no CBD, confirmado via MCP)

## Mensagens

| Nº | Texto (PT, máx. 73 car.) | Variáveis | `TEXT-ID` | Atributo(s) |
|---|---|---|---|---|
| `001` | `Erro inesperado no processo ZASSIST: &1` | &1 = detalhe do erro capturado | `UNEXPECTED_ERROR` | `MV_DETAIL` |
| `010` | `Erro ao ler o ficheiro &1: &2` | &1 = nome do ficheiro, &2 = detalhe/subrc | `FILE_READ_ERROR` | `MV_FILENAME`, `MV_DETAIL` |
| `011` | `Falha ao obter número de documento (intervalo &1)` | &1 = número do intervalo de numeração | `NUMBER_RANGE_ERROR` | `MV_NR_RANGE` |
| `012` | `Registo já processado: referência &1, colaborador &2` | &1 = referência, &2 = pernr | `DUPLICATE_RUN` | `MV_REFERENCIA`, `MV_PERNR` |
| `013` | `Erro ao lançar documento FI (colaborador &1): &2` | &1 = pernr, &2 = detalhe do erro BAPI | `FI_POSTING_ERROR` | `MV_PERNR`, `MV_DETAIL` |
| `020` | `PERNR em branco` | — | *(sem excepção — ver nota)* | — |
| `021` | `Valor inválido (deve ser > 0)` | — | *(sem excepção)* | — |
| `022` | `Conta G/L em branco` | — | *(sem excepção)* | — |
| `023` | `Centro de Custo em branco` | — | *(sem excepção)* | — |
| `024` | `Data de lançamento em branco` | — | *(sem excepção)* | — |
| `025` | `Empresa (BUKRS) em branco` | — | *(sem excepção)* | — |

> **Nota sobre 020–025 (T5.4):** não são `TEXT-ID` de `ZCX_ASSIST_PROCESS` — são erros de *validação*
> (esperados, não excepcionais), reportados como colecção `BAPIRET2` por `ZCL_ASSIST_VALIDATOR`, não como
> excepção lançada. Usadas via `MESSAGE e020(zassist) INTO lv_text` (clássico, com `INTO` para obter o
> texto T100 sem exibir popup), depois `sy-msgty`/`sy-msgid`/`sy-msgno` alimentam o `BAPIRET2`. Mesmos 6
> textos de `ZCL_MEDICAL_ASSIST_PROCESS->validar_dados` (lida via MCP), sem alteração de redacção.

> Corresponde exactamente aos pontos onde `ZCL_MEDICAL_ASSIST_PROCESS` hoje levanta
> `ZCX_DEBIT_NOTE_ERROR` com uma string livre (`upload_dados` → ficheiro; `carregar_lancamentos` →
> intervalo de numeração e erro de BAPI, lido via MCP) mais o cenário novo `DUPLICATE_RUN`, que a versão
> actual não tem (não existia `ZASSIST_RUN` para detectar duplicados — ver `docs/ddic/zassist_run.md`,
> T5.1).

## Padrão de declaração (referência para T5.2)

Uma única classe `ZCX_ASSIST_PROCESS` (não uma hierarquia, ao contrário do `ZEMAIL`) com 5 constantes
`TEXT-ID`, seguindo o mesmo padrão `IF_T100_MESSAGE` de `ZCX_EMAIL`/`ZCX_TEMPLATE`:

```abap
CONSTANTS:
  BEGIN OF file_read_error,
    msgid TYPE symsgid VALUE 'ZASSIST',
    msgno TYPE symsgno VALUE '010',
    attr1 TYPE scx_attrname VALUE 'MV_FILENAME',
    attr2 TYPE scx_attrname VALUE 'MV_DETAIL',
    attr3 TYPE scx_attrname VALUE '',
    attr4 TYPE scx_attrname VALUE '',
  END OF file_read_error.
```

## Dependências

- **Depende de:** nada (classe de mensagens independente no DDIC).
- **Usado por:** `ZCX_ASSIST_PROCESS` (T5.2) e, por consequência, `ZCL_FILE_READER_FRONTEND`/
  `ZCL_FILE_READER_SERVER` (T5.3), `ZCL_ASSIST_FI_POSTER` (T5.5), `ZCL_ASSIST_MEDIC_PROCESSOR` (T5.7).

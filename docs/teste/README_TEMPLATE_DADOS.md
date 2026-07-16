# Template de dados — carregamento ZASSIST (`ZRP_ASSIST_MEDIC`)

`zassist_dados_template.txt` — ficheiro separado por **tabs** (não vírgulas), 15 colunas, sem cabeçalho
na versão final a carregar (a primeira linha deste template tem os nomes das colunas só para facilitar a
edição no Excel — **apagar essa linha antes de carregar**, senão o `PERNR` da linha de cabeçalho seria
lido como um registo inválido).

## Como editar

1. Abrir `zassist_dados_template.txt` no Excel: **Dados → Obter Dados → De Ficheiro → De Texto/CSV**,
   escolher delimitador **Tabulação**.
2. Preencher uma linha por registo (uma linha pode corresponder a uma despesa; um colaborador com várias
   despesas aparece em várias linhas com o mesmo `REFERENCIA`+`PERNR`).
3. Apagar a linha de cabeçalho.
4. **Guardar como → Texto (delimitado por tabulações) (\*.txt)**.
5. Carregar via `ZRP_ASSIST_MEDIC` (opção "Ficheiro local").

## Colunas (ordem fixa — `ZCL_FILE_READER_FRONTEND`/`ZCL_FILE_READER_SERVER` mapeiam por posição)

| # | Coluna | Tipo/Formato | Nota |
|---|---|---|---|
| 1 | PERNR | NUMC8 | Número de pessoal |
| 2 | NOME | texto | Nome do colaborador |
| 3 | NATUREZA | texto | Natureza da despesa médica |
| 4 | BENEFICIARIO | texto | Nome do beneficiário (colaborador ou dependente) |
| 5 | CONTA | CHAR10 | Conta G/L da despesa |
| 6 | CENTRO_CUSTO | CHAR10 | Centro de custo |
| 7 | BUKRS | CHAR4 | Empresa |
| 8 | DATA | DDMMYYYY | Data de lançamento |
| 9 | DOC_DAT | DDMMYYYY | Data do documento |
| 10 | VALOR | decimal (`.` como separador) | Valor de débito do colaborador |
| 11 | VAL_HCB | decimal | Parte HCB do custo |
| 12 | DEBITO | decimal | Valor total debitado mostrado no e-mail |
| 13 | DOCUMENTO | — | **Deixar sempre em branco** — preenchido automaticamente pelo `ZCL_ASSIST_FI_POSTER` após o lançamento FI. A coluna tem de existir (vazia) para não desalinhar `REFERENCIA`/`WAERS` a seguir. |
| 14 | REFERENCIA | CHAR20 | Referência de negócio (mostrada no e-mail; usada para detectar duplicados) |
| 15 | WAERS | CHAR5 | Moeda — se em branco, assume `MZN` por omissão |

## Nota sobre encoding

O template está em UTF-8 (acentos correctos: João, Médica). Ao reabrir no Excel confirmar o encoding
UTF-8 no assistente de importação; ao gravar como texto delimitado por tabulações, o Excel normalmente
converte para o codepage ANSI do Windows — isto é normal e não afecta o `GUI_UPLOAD`.

## Ficheiro de teste com cenários (Fase 6, T6.3)

Este template é um ponto de partida para dados reais. O ficheiro `docs/teste/csv_exemplo.txt` (3
registos: 1 válido, 1 inválido, 1 duplicado em `ZASSIST_RUN`) exigido pelo gate da Fase 6 é um artefacto
diferente, especificamente desenhado para exercitar os 3 estados no `ZRP_ASSIST_MEDIC` — ainda por criar.

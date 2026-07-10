# ZEMAIL — Classe de mensagens (SE91)

> Especificação para criação manual em SE91 pelo utilizador. Claude Code não escreve objectos no SAP.
> Tarefa do plano: **T1.5** (Fase 1). Mapeamento pensado para ser copiado directamente para as
> declarações `TEXT-ID` das excepções em `ZCX_EMAIL` (T2.1), `ZCX_TEMPLATE` (T2.2) e `ZCX_EMAIL_SEND`
> (T2.3) — ver secção "Padrão de declaração" no fim.

## Classe de mensagens

- **Nome:** `ZEMAIL`
- **Descrição curta:** Mensagens do framework de e-mail HTML (ZEMAIL)
- **Pacote:** `ZEMAIL` (ainda não existe no CBD — mesma observação das tarefas anteriores de Fase 1)
- **Camada de transporte:** a mesma decidida em T1.1

## Numeração

Numeração com espaçamento por classe de excepção, para deixar espaço a novos textos sem renumerar:

| Intervalo | Classe de excepção |
|---|---|
| `001`–`009` | `ZCX_EMAIL` (raiz — erros genéricos/envolvidos) |
| `010`–`019` | `ZCX_TEMPLATE` |
| `020`–`029` | `ZCX_EMAIL_SEND` |

## Mensagens

| Nº | Texto (PT, máx. 73 car.) | Variáveis | Classe / `TEXT-ID` | Atributo(s) sugerido(s) |
|---|---|---|---|---|
| `001` | `Erro inesperado no framework ZEMAIL: &1` | &1 = detalhe (texto do erro original capturado) | `ZCX_EMAIL` / `UNEXPECTED_ERROR` | `MV_DETAIL` |
| `010` | `Template &1 não encontrado ou sem versão activa` | &1 = template_id | `ZCX_TEMPLATE` / `NOT_FOUND` | `MV_TEMPLATE_ID` |
| `011` | `Conteúdo do template &1 inválido (vazio ou moldura sem {{BODY}})` | &1 = template_id | `ZCX_TEMPLATE` / `INVALID_CONTENT` | `MV_TEMPLATE_ID` |
| `012` | `Placeholder {{&2}} não resolvido no template &1` | &1 = template_id, &2 = nome do placeholder | `ZCX_TEMPLATE` / `UNRESOLVED_PLACEHOLDER` | `MV_TEMPLATE_ID`, `MV_PLACEHOLDER` |
| `020` | `Destinatário de e-mail inválido: &1` | &1 = endereço rejeitado | `ZCX_EMAIL_SEND` / `INVALID_RECIPIENT` | `MV_RECIPIENT` |
| `021` | `Erro ao enviar e-mail via BCS: &1` | &1 = texto do erro `CX_BCS` (`get_text( )`) | `ZCX_EMAIL_SEND` / `BCS_ERROR` | `MV_DETAIL` |
| `022` | `Erro ao resolver anexo inline &1: &2` | &1 = content-id, &2 = motivo | `ZCX_EMAIL_SEND` / `ATTACHMENT_ERROR` | `MV_CONTENT_ID`, `MV_DETAIL` |

> `010`/`011`/`012` usam exactamente os dois atributos já definidos no plano para `ZCX_TEMPLATE`
> (`MV_TEMPLATE_ID`, `MV_PLACEHOLDER`, T2.2) — `011` não precisa de segundo argumento porque as duas
> causas possíveis (vazio / moldura sem `{{BODY}}`) estão descritas no texto estático, não numa variável.
>
> `020`–`022`: o plano (T2.3) não fixa nomes de atributos para `ZCX_EMAIL_SEND` — `MV_RECIPIENT`,
> `MV_CONTENT_ID` e `MV_DETAIL` (reutilizado também em `001`/`021`) são sugestões a confirmar/ajustar
> quando essa classe for implementada; não bloqueiam a criação da classe de mensagens em SE91.

## Padrão de declaração nas classes de excepção (referência para T2.1–T2.3)

Cada texto acima corresponde a uma constante `TEXT-ID` na respectiva classe, seguindo o padrão standard
`IF_T100_MESSAGE`. Exemplo para `NOT_FOUND` em `ZCX_TEMPLATE` (T2.2):

```abap
CONSTANTS:
  BEGIN OF not_found,
    msgid TYPE symsgid VALUE 'ZEMAIL',
    msgno TYPE symsgno VALUE '010',
    attr1 TYPE scx_attrname VALUE 'MV_TEMPLATE_ID',
    attr2 TYPE scx_attrname VALUE '',
    attr3 TYPE scx_attrname VALUE '',
    attr4 TYPE scx_attrname VALUE '',
  END OF not_found.
```

O mesmo padrão aplica-se às restantes seis constantes, com `msgno` e `attrN` conforme a tabela acima.
`MV_TEMPLATE_ID` e `MV_PLACEHOLDER` (e os sugeridos para `ZCX_EMAIL_SEND`) são atributos públicos
`READ-ONLY` da respectiva classe de excepção, preenchidos no `RAISE EXCEPTION ... EXPORTING`.

## Dependências

- **Depende de:** nada (classe de mensagens independente no DDIC, mas semanticamente ligada às excepções
  de Fase 2).
- **Usado por:** `ZCX_EMAIL` (T2.1), `ZCX_TEMPLATE` (T2.2), `ZCX_EMAIL_SEND` (T2.3) e, por herança, todo o
  código do framework que levanta estas excepções (Fase 3 em diante).

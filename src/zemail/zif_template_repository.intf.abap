INTERFACE zif_template_repository
  PUBLIC.

  " Camada de dados pura (sem regras de negocio, sem excepcoes) por tras de
  " ZIF_TEMPLATE_PROVIDER. Existe para permitir doubles em teste (T3.2) sem
  " LOCAL FRIENDS: ZCL_TEMPLATE_PROVIDER_DB injecta esta interface e so faz
  " 1 chamada por (id, spras) gracas ao cache — o double prova isso contando
  " chamadas, sem tocar em ZEMAIL_TMPL/ZEMAIL_TMPL_CNT.
  TYPES:
    BEGIN OF ty_header,
      found     TYPE abap_bool,
      master_id TYPE zemail_template_id,
      activo    TYPE xfeld,
    END OF ty_header,

    BEGIN OF ty_content,
      found   TYPE abap_bool,
      versao  TYPE zemail_versao,
      subject TYPE string,
      content TYPE string,
    END OF ty_content.

  METHODS read_header
    IMPORTING
      iv_id            TYPE zemail_template_id
    RETURNING
      VALUE(rs_header) TYPE ty_header.

  " Devolve a versao ESTADO='A' mais alta para (iv_id, iv_langu); RS_CONTENT-FOUND
  " = abap_false se nao existir nenhuma versao activa nesse idioma.
  METHODS read_active_content
    IMPORTING
      iv_id             TYPE zemail_template_id
      iv_langu          TYPE spras
    RETURNING
      VALUE(rs_content) TYPE ty_content.

  " Devolve uma versao especifica, independentemente do ESTADO (usado para
  " pre-visualizacao de rascunhos em ZEMAIL_TMPL_MAINT, T4.3).
  METHODS read_content_by_version
    IMPORTING
      iv_id             TYPE zemail_template_id
      iv_langu          TYPE spras
      iv_versao         TYPE zemail_versao
    RETURNING
      VALUE(rs_content) TYPE ty_content.

ENDINTERFACE.

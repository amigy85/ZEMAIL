INTERFACE zif_template_provider
  PUBLIC.

  METHODS get_template
    IMPORTING
      iv_id             TYPE zemail_template_id
      iv_langu          TYPE spras
      iv_versao         TYPE zemail_versao OPTIONAL
    RETURNING
      VALUE(rs_template) TYPE zemail_s_template
    RAISING
      zcx_template.

  METHODS exists
    IMPORTING
      iv_id    TYPE zemail_template_id
      iv_langu TYPE spras
    RETURNING
      VALUE(rv_exists) TYPE abap_bool.

ENDINTERFACE.

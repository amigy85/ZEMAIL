INTERFACE zif_email_service
  PUBLIC.

  " Um placeholder de tabela ({{TAB:NAME}}) nomeado: DATA é uma referência
  " genérica porque cada chamador passa uma tabela interna de tipo próprio
  " (resolvida por RTTI em ZCL_PLACEHOLDER_SERVICE->replace_table, T3.3).
  TYPES:
    BEGIN OF ty_table_placeholder,
      name TYPE zemail_placeholder_name,
      data TYPE REF TO data,
    END OF ty_table_placeholder,
    tt_table_placeholder TYPE STANDARD TABLE OF ty_table_placeholder WITH DEFAULT KEY.

  METHODS send
    IMPORTING
      iv_template_id  TYPE zemail_template_id
      iv_langu        TYPE spras
      it_recipients   TYPE zemail_t_recipient
      it_values       TYPE zemail_t_placeholder
      it_tables       TYPE tt_table_placeholder OPTIONAL
    RETURNING
      VALUE(rs_result) TYPE zemail_s_send_result
    RAISING
      zcx_email.

ENDINTERFACE.

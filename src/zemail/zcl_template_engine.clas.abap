CLASS zcl_template_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS constructor
      IMPORTING
        io_provider            TYPE REF TO zif_template_provider
        io_placeholder_service TYPE REF TO zcl_placeholder_service.

    " Injecta o child em {{BODY}} da moldura (se houver), substitui
    " {{TAB:NAME}} e {{NAME}} no corpo E no assunto, e valida que nao
    " sobra nenhum placeholder por resolver. IT_TABLES usa o mesmo tipo
    " definido em ZIF_EMAIL_SERVICE (NAME + DATA TYPE REF TO DATA).
    METHODS build
      IMPORTING
        iv_template_id    TYPE zemail_template_id
        iv_langu          TYPE spras
        it_values         TYPE zemail_t_placeholder
        it_tables         TYPE zif_email_service=>tt_table_placeholder OPTIONAL
      RETURNING
        VALUE(rs_message) TYPE zemail_s_message
      RAISING
        zcx_template.

  PRIVATE SECTION.

    DATA mo_provider    TYPE REF TO zif_template_provider.
    DATA mo_placeholder TYPE REF TO zcl_placeholder_service.

    METHODS replace_body_in_master
      IMPORTING
        iv_master      TYPE string
        iv_child       TYPE string
      RETURNING
        VALUE(rv_html) TYPE string.

    METHODS apply_tables
      IMPORTING
        iv_html        TYPE string
        it_tables      TYPE zif_email_service=>tt_table_placeholder
      RETURNING
        VALUE(rv_html) TYPE string.

ENDCLASS.


CLASS zcl_template_engine IMPLEMENTATION.

  METHOD constructor.
    mo_provider    = io_provider.
    mo_placeholder = io_placeholder_service.
  ENDMETHOD.

  METHOD build.
    DATA(ls_template) = mo_provider->get_template( iv_id = iv_template_id iv_langu = iv_langu ).

    DATA(lv_body) = COND string(
      WHEN ls_template-master_content IS NOT INITIAL
      THEN replace_body_in_master( iv_master = ls_template-master_content iv_child = ls_template-content )
      ELSE ls_template-content ).

    lv_body = apply_tables( iv_html = lv_body it_tables = it_tables ).
    lv_body = mo_placeholder->replace( iv_html = lv_body it_values = it_values ).

    DATA(lv_subject) = mo_placeholder->replace( iv_html = ls_template-subject it_values = it_values ).

    mo_placeholder->check_unresolved( iv_html = lv_body iv_template_id = iv_template_id ).
    mo_placeholder->check_unresolved( iv_html = lv_subject iv_template_id = iv_template_id ).

    rs_message-subject   = lv_subject.
    rs_message-body_html = lv_body.
  ENDMETHOD.

  METHOD replace_body_in_master.
    rv_html = iv_master.
    REPLACE ALL OCCURRENCES OF `{{BODY}}` IN rv_html WITH iv_child.
  ENDMETHOD.

  METHOD apply_tables.
    rv_html = iv_html.

    LOOP AT it_tables INTO DATA(ls_table).
      ASSIGN ls_table-data->* TO FIELD-SYMBOL(<lt_data>).
      CHECK sy-subrc = 0.

      rv_html = mo_placeholder->replace_table(
        iv_html = rv_html
        iv_name = ls_table-name
        it_data = <lt_data> ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

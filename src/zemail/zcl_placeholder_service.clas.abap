CLASS zcl_placeholder_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " IV_STRICT_MODE vem de ZEMAIL_CONFIG-STRICT_MODE, resolvido pelo
    " chamador (ZCL_EMAIL_FACTORY, T3.8) — esta classe nao le ZEMAIL_CONFIG.
    METHODS constructor
      IMPORTING
        iv_strict_mode TYPE abap_bool.

    " Substitui {{NAME}} pelos valores em IT_VALUES. Escapa HTML por omissao
    " (protege contra dados de negocio com caracteres HTML); IV_ESCAPE_HTML
    " = abap_false para desactivar. IV_WAERS aplica-se a todos os valores
    " com FORMAT = moeda nesta chamada (um e-mail tem tipicamente 1 moeda).
    METHODS replace
      IMPORTING
        iv_html        TYPE string
        it_values      TYPE zemail_t_placeholder
        iv_waers       TYPE waers OPTIONAL
        iv_escape_html TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rv_html) TYPE string.

    " Substitui {{TAB:NAME}} por um <table> HTML gerado por RTTI a partir
    " de IT_DATA (uma linha = uma <tr>; nomes de campo = cabecalho <th>).
    METHODS replace_table
      IMPORTING
        iv_html        TYPE string
        iv_name        TYPE zemail_placeholder_name
        it_data        TYPE ANY TABLE
      RETURNING
        VALUE(rv_html) TYPE string.

    METHODS check_unresolved
      IMPORTING
        iv_html        TYPE string
        iv_template_id TYPE zemail_template_id
      RAISING
        zcx_template.

  PRIVATE SECTION.

    DATA mv_strict_mode TYPE abap_bool.

    METHODS format_value
      IMPORTING
        is_value       TYPE zemail_s_placeholder
        iv_waers       TYPE waers
        iv_escape_html TYPE abap_bool
      RETURNING
        VALUE(rv_text) TYPE string.

    " Converte data DDMMYYYY (convencao usada nos dados de negocio deste
    " projecto, ex. CSV da assistencia medica) para o formato do utilizador
    " (SY-DATFM, via WRITE TO).
    METHODS format_date
      IMPORTING
        iv_value       TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS format_currency
      IMPORTING
        iv_amount      TYPE string
        iv_waers       TYPE waers
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS build_table_html
      IMPORTING
        it_data        TYPE ANY TABLE
      RETURNING
        VALUE(rv_html) TYPE string.

    METHODS build_header_row
      IMPORTING
        it_components  TYPE abap_component_tab
      RETURNING
        VALUE(rv_html) TYPE string.

    METHODS build_data_rows
      IMPORTING
        it_data        TYPE ANY TABLE
        it_components  TYPE abap_component_tab
      RETURNING
        VALUE(rv_html) TYPE string.

ENDCLASS.


CLASS zcl_placeholder_service IMPLEMENTATION.

  METHOD constructor.
    mv_strict_mode = iv_strict_mode.
  ENDMETHOD.

  METHOD replace.
    rv_html = iv_html.

    LOOP AT it_values INTO DATA(ls_value).
      DATA(lv_tag) = `{{` && ls_value-name && `}}`.
      DATA(lv_display) = format_value(
        is_value       = ls_value
        iv_waers       = iv_waers
        iv_escape_html = iv_escape_html ).

      REPLACE ALL OCCURRENCES OF lv_tag IN rv_html WITH lv_display.
    ENDLOOP.
  ENDMETHOD.

  METHOD replace_table.
    DATA(lv_tag) = `{{TAB:` && iv_name && `}}`.

    rv_html = iv_html.
    CHECK rv_html CS lv_tag.

    DATA(lv_table_html) = build_table_html( it_data ).
    REPLACE ALL OCCURRENCES OF lv_tag IN rv_html WITH lv_table_html.
  ENDMETHOD.

  METHOD check_unresolved.
    CHECK mv_strict_mode = abap_true.

    FIND REGEX '\{\{[A-Z0-9_:]+\}\}' IN iv_html
      MATCH OFFSET DATA(lv_offset)
      MATCH LENGTH DATA(lv_length).
    CHECK sy-subrc = 0.

    " Offset/length de acesso a subcadeia tem de ser variável simples, não
    " expressão aritmética inline (iv_html+lv_offset+2(...) não compila).
    DATA(lv_name_off) = lv_offset + 2.
    DATA(lv_name_len) = lv_length - 4.
    DATA(lv_placeholder) = iv_html+lv_name_off(lv_name_len).

    RAISE EXCEPTION TYPE zcx_template
      EXPORTING
        textid         = zcx_template=>unresolved_placeholder
        iv_template_id = iv_template_id
        iv_placeholder = CONV #( lv_placeholder ).
  ENDMETHOD.

  METHOD format_value.
    DATA(lv_text) = SWITCH string( is_value-format
      WHEN zif_email_const=>placeholder_format-date     THEN format_date( is_value-value )
      WHEN zif_email_const=>placeholder_format-currency THEN format_currency(
                                                                 iv_amount = is_value-value
                                                                 iv_waers  = iv_waers )
      ELSE is_value-value ).

    rv_text = COND #( WHEN iv_escape_html = abap_true
                       THEN escape( val = lv_text format = cl_abap_format=>e_html_text )
                       ELSE lv_text ).
  ENDMETHOD.

  METHOD format_date.
    CHECK strlen( iv_value ) = 8.

    DATA(lv_dats) = CONV d( iv_value+4(4) && iv_value+2(2) && iv_value(2) ).
    DATA lv_char TYPE char10.
    WRITE lv_dats TO lv_char.
    rv_text = lv_char.
  ENDMETHOD.

  METHOD format_currency.
    DATA(lv_amount) = CONV dmbtr( iv_amount ).
    DATA lv_char TYPE char30.
    WRITE lv_amount TO lv_char CURRENCY iv_waers.
    CONDENSE lv_char.
    rv_text = lv_char && ` ` && iv_waers.
  ENDMETHOD.

  METHOD build_table_html.
    DATA(lo_line_type) = CAST cl_abap_structdescr(
      CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( it_data ) )->get_table_line_type( ) ).

    DATA(lt_components) = lo_line_type->get_components( ).

    rv_html = `<table>`
           && build_header_row( lt_components )
           && build_data_rows( it_data = it_data it_components = lt_components )
           && `</table>`.
  ENDMETHOD.

  METHOD build_header_row.
    rv_html = `<tr>`.
    LOOP AT it_components INTO DATA(ls_component).
      rv_html = rv_html && `<th>` && ls_component-name && `</th>`.
    ENDLOOP.
    rv_html = rv_html && `</tr>`.
  ENDMETHOD.

  METHOD build_data_rows.
    LOOP AT it_data ASSIGNING FIELD-SYMBOL(<ls_line>).
      rv_html = rv_html && `<tr>`.

      LOOP AT it_components INTO DATA(ls_component).
        ASSIGN COMPONENT ls_component-name OF STRUCTURE <ls_line> TO FIELD-SYMBOL(<lv_field>).
        CHECK sy-subrc = 0.

        " WRITE ... TO só aceita alvo C/N/D/T, nunca STRING — string template
        " formata qualquer tipo elementar sem essa restrição.
        DATA(lv_text) = |{ <lv_field> }|.
        rv_html = rv_html && `<td>` && escape( val = lv_text format = cl_abap_format=>e_html_text ) && `</td>`.
      ENDLOOP.

      rv_html = rv_html && `</tr>`.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

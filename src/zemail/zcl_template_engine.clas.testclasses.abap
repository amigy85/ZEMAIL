CLASS ltd_template_provider DEFINITION FOR TESTING.

  PUBLIC SECTION.

    INTERFACES zif_template_provider.

    DATA ms_template TYPE zemail_s_template.

ENDCLASS.


CLASS ltd_template_provider IMPLEMENTATION.

  METHOD zif_template_provider~get_template.
    rs_template = ms_template.
  ENDMETHOD.

  METHOD zif_template_provider~exists.
    rv_exists = abap_true.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_template_engine DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    DATA mo_provider TYPE REF TO ltd_template_provider.
    DATA mo_cut      TYPE REF TO zcl_template_engine.

    METHODS setup.
    METHODS master_e_child       FOR TESTING RAISING cx_static_check.
    METHODS so_child             FOR TESTING RAISING cx_static_check.
    METHODS assunto_com_placeholder FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_template_engine IMPLEMENTATION.

  METHOD setup.
    mo_provider = NEW ltd_template_provider( ).
    mo_cut = NEW zcl_template_engine(
      io_provider            = mo_provider
      io_placeholder_service = NEW zcl_placeholder_service( iv_strict_mode = abap_false ) ).
  ENDMETHOD.

  METHOD master_e_child.
    mo_provider->ms_template = VALUE #(
      template_id    = 'ZHCB_TEST'
      spras          = 'P'
      subject        = 'Assunto {{NOME}}'
      content        = '<p>Ola {{NOME}}</p>'
      master_content = '<html>{{BODY}}</html>' ).

    DATA(ls_message) = mo_cut->build(
      iv_template_id = 'ZHCB_TEST'
      iv_langu       = 'P'
      it_values      = VALUE #( ( name = 'NOME' value = 'Joao' format = zif_email_const=>placeholder_format-plain ) ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_message-body_html exp = '<html><p>Ola Joao</p></html>' ).
    cl_abap_unit_assert=>assert_equals( act = ls_message-subject   exp = 'Assunto Joao' ).
  ENDMETHOD.

  METHOD so_child.
    mo_provider->ms_template = VALUE #(
      template_id = 'ZHCB_TEST'
      spras       = 'P'
      subject     = 'Assunto'
      content     = '<p>Ola {{NOME}}</p>' ).

    DATA(ls_message) = mo_cut->build(
      iv_template_id = 'ZHCB_TEST'
      iv_langu       = 'P'
      it_values      = VALUE #( ( name = 'NOME' value = 'Maria' format = zif_email_const=>placeholder_format-plain ) ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_message-body_html exp = '<p>Ola Maria</p>' ).
  ENDMETHOD.

  METHOD assunto_com_placeholder.
    mo_provider->ms_template = VALUE #(
      template_id = 'ZHCB_TEST'
      spras       = 'P'
      subject     = 'Ref. {{REF}}'
      content     = '<p>Sem placeholders aqui</p>' ).

    DATA(ls_message) = mo_cut->build(
      iv_template_id = 'ZHCB_TEST'
      iv_langu       = 'P'
      it_values      = VALUE #( ( name = 'REF' value = 'NDH-2026-001' format = zif_email_const=>placeholder_format-plain ) ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_message-subject exp = 'Ref. NDH-2026-001' ).
  ENDMETHOD.

ENDCLASS.

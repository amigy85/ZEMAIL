CLASS ltc_placeholder_service DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    DATA mo_cut TYPE REF TO zcl_placeholder_service.

    METHODS setup.
    METHODS escalar               FOR TESTING RAISING cx_static_check.
    METHODS escape_html           FOR TESTING RAISING cx_static_check.
    METHODS formato_data          FOR TESTING RAISING cx_static_check.
    METHODS formato_moeda         FOR TESTING RAISING cx_static_check.
    METHODS tabela_por_rtti       FOR TESTING RAISING cx_static_check.
    METHODS placeholder_por_resolver FOR TESTING RAISING cx_static_check.
    METHODS sem_strict_mode_nao_levanta FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_placeholder_service IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_placeholder_service( iv_strict_mode = abap_true ).
  ENDMETHOD.

  METHOD escalar.
    DATA(lt_values) = VALUE zemail_t_placeholder(
      ( name = 'NOME' value = 'Joao' format = zif_email_const=>placeholder_format-plain ) ).

    DATA(lv_html) = mo_cut->replace( iv_html = `Ola {{NOME}}!` it_values = lt_values ).

    cl_abap_unit_assert=>assert_equals( act = lv_html exp = `Ola Joao!` ).
  ENDMETHOD.

  METHOD escape_html.
    DATA(lt_values) = VALUE zemail_t_placeholder(
      ( name = 'NOME' value = '<script>' format = zif_email_const=>placeholder_format-plain ) ).

    DATA(lv_html) = mo_cut->replace( iv_html = `{{NOME}}` it_values = lt_values ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_html NS '<script>' ) ).
  ENDMETHOD.

  METHOD formato_data.
    DATA(lt_values) = VALUE zemail_t_placeholder(
      ( name = 'DATA' value = '29062026' format = zif_email_const=>placeholder_format-date ) ).

    DATA(lv_html) = mo_cut->replace( iv_html = `{{DATA}}` it_values = lt_values ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS '2026' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html NS '29062026' ) ).
  ENDMETHOD.

  METHOD formato_moeda.
    DATA(lt_values) = VALUE zemail_t_placeholder(
      ( name = 'VALOR' value = '1500' format = zif_email_const=>placeholder_format-currency ) ).

    DATA(lv_html) = mo_cut->replace(
      iv_html   = `{{VALOR}}`
      it_values = lt_values
      iv_waers  = 'MZN' ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS 'MZN' ) ).
  ENDMETHOD.

  METHOD tabela_por_rtti.
    TYPES: BEGIN OF ty_linha,
             natureza TYPE string,
             valor    TYPE string,
           END OF ty_linha.
    DATA lt_linhas TYPE STANDARD TABLE OF ty_linha WITH DEFAULT KEY.
    lt_linhas = VALUE #( ( natureza = 'Consulta' valor = '100' )
                         ( natureza = 'Exame'    valor = '200' ) ).

    DATA(lv_html) = mo_cut->replace_table(
      iv_html = `<body>{{TAB:ITENS}}</body>`
      iv_name = 'ITENS'
      it_data = lt_linhas ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS '<table>' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS 'Consulta' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS 'Exame' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html NS '{{TAB:ITENS}}' ) ).
  ENDMETHOD.

  METHOD placeholder_por_resolver.
    TRY.
        mo_cut->check_unresolved( iv_html = `{{FOO}}` iv_template_id = 'ZHCB_TEST' ).
        cl_abap_unit_assert=>fail( 'Devia ter levantado ZCX_TEMPLATE' ).
      CATCH zcx_template INTO DATA(lx_template).
        cl_abap_unit_assert=>assert_equals(
          act = lx_template->if_t100_message~t100key-msgno
          exp = zcx_template=>unresolved_placeholder-msgno ).
        cl_abap_unit_assert=>assert_equals( act = lx_template->mv_placeholder exp = 'FOO' ).
    ENDTRY.
  ENDMETHOD.

  METHOD sem_strict_mode_nao_levanta.
    DATA(lo_lenient) = NEW zcl_placeholder_service( iv_strict_mode = abap_false ).
    lo_lenient->check_unresolved( iv_html = `{{FOO}}` iv_template_id = 'ZHCB_TEST' ).
  ENDMETHOD.

ENDCLASS.

CLASS ltd_repository DEFINITION FOR TESTING.

  PUBLIC SECTION.

    INTERFACES zif_template_repository.

    DATA mv_header_calls  TYPE i.
    DATA mv_content_calls TYPE i.
    DATA ms_header        TYPE zif_template_repository=>ty_header.

    METHODS add_content
      IMPORTING
        iv_langu   TYPE spras
        is_content TYPE zif_template_repository=>ty_content.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_entry,
        langu   TYPE spras,
        content TYPE zif_template_repository=>ty_content,
      END OF ty_entry.

    DATA mt_content TYPE HASHED TABLE OF ty_entry WITH UNIQUE KEY langu.

ENDCLASS.


CLASS ltd_repository IMPLEMENTATION.

  METHOD add_content.
    INSERT VALUE ty_entry( langu = iv_langu content = is_content ) INTO TABLE mt_content.
  ENDMETHOD.

  METHOD zif_template_repository~read_header.
    mv_header_calls = mv_header_calls + 1.
    rs_header = ms_header.
  ENDMETHOD.

  METHOD zif_template_repository~read_active_content.
    mv_content_calls = mv_content_calls + 1.
    READ TABLE mt_content WITH TABLE KEY langu = iv_langu INTO DATA(ls_entry).
    IF sy-subrc = 0.
      rs_content = ls_entry-content.
    ENDIF.
  ENDMETHOD.

  METHOD zif_template_repository~read_content_by_version.
    " Não usado nestes testes (T4.3 pré-visualização fica fora do âmbito de T3.2).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_template_provider_db DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    DATA mo_repository TYPE REF TO ltd_repository.
    DATA mo_cut        TYPE REF TO zif_template_provider.

    METHODS setup.
    METHODS template_encontrado    FOR TESTING RAISING cx_static_check.
    METHODS fallback_idioma        FOR TESTING RAISING cx_static_check.
    METHODS not_found              FOR TESTING RAISING cx_static_check.
    METHODS cache_sem_segunda_leitura FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_template_provider_db IMPLEMENTATION.

  METHOD setup.
    mo_repository = NEW ltd_repository( ).
    mo_cut = NEW zcl_template_provider_db(
      iv_fallback_langu = 'P'
      io_repository     = mo_repository ).
  ENDMETHOD.

  METHOD template_encontrado.
    mo_repository->ms_header = VALUE #( found = abap_true activo = abap_true ).
    mo_repository->add_content(
      iv_langu   = 'P'
      is_content = VALUE #( found = abap_true versao = '0001' subject = 'Assunto' content = 'Corpo' ) ).

    DATA(ls_result) = mo_cut->get_template( iv_id = 'ZHCB_TEST' iv_langu = 'P' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-subject exp = 'Assunto' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-content exp = 'Corpo' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-spras   exp = 'P' ).
  ENDMETHOD.

  METHOD fallback_idioma.
    mo_repository->ms_header = VALUE #( found = abap_true activo = abap_true ).
    mo_repository->add_content(
      iv_langu   = 'P'
      is_content = VALUE #( found = abap_true versao = '0001' subject = 'Assunto PT' content = 'Corpo PT' ) ).

    DATA(ls_result) = mo_cut->get_template( iv_id = 'ZHCB_TEST' iv_langu = 'E' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-spras   exp = 'P' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-content exp = 'Corpo PT' ).
  ENDMETHOD.

  METHOD not_found.
    mo_repository->ms_header = VALUE #( found = abap_false ).

    TRY.
        mo_cut->get_template( iv_id = 'ZHCB_INEXISTENTE' iv_langu = 'P' ).
        cl_abap_unit_assert=>fail( 'Devia ter levantado ZCX_TEMPLATE' ).
      CATCH zcx_template INTO DATA(lx_template).
        cl_abap_unit_assert=>assert_equals(
          act = lx_template->if_t100_message~t100key-msgno
          exp = zcx_template=>not_found-msgno ).
    ENDTRY.
  ENDMETHOD.

  METHOD cache_sem_segunda_leitura.
    mo_repository->ms_header = VALUE #( found = abap_true activo = abap_true ).
    mo_repository->add_content(
      iv_langu   = 'P'
      is_content = VALUE #( found = abap_true versao = '0001' subject = 'Assunto' content = 'Corpo' ) ).

    mo_cut->get_template( iv_id = 'ZHCB_TEST' iv_langu = 'P' ).
    mo_cut->get_template( iv_id = 'ZHCB_TEST' iv_langu = 'P' ).

    cl_abap_unit_assert=>assert_equals( act = mo_repository->mv_header_calls  exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repository->mv_content_calls exp = 1 ).
  ENDMETHOD.

ENDCLASS.

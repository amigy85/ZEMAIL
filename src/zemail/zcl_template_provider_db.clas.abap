CLASS zcl_template_provider_db DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_template_provider.

    " IV_FALLBACK_LANGU vem de ZEMAIL_CONFIG-FALLBACK_LANGU, resolvido pelo
    " chamador (ZCL_EMAIL_FACTORY, T3.8) — esta classe nao le ZEMAIL_CONFIG.
    METHODS constructor
      IMPORTING
        iv_fallback_langu TYPE spras
        io_repository     TYPE REF TO zif_template_repository OPTIONAL.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_cache_key,
        id    TYPE zemail_template_id,
        langu TYPE spras,
      END OF ty_cache_key,

      BEGIN OF ty_cache_entry,
        key      TYPE ty_cache_key,
        template TYPE zemail_s_template,
      END OF ty_cache_entry.

    DATA mo_repository     TYPE REF TO zif_template_repository.
    DATA mv_fallback_langu TYPE spras.
    DATA mt_cache          TYPE HASHED TABLE OF ty_cache_entry WITH UNIQUE KEY key.

    METHODS resolve_active
      IMPORTING
        iv_id              TYPE zemail_template_id
        iv_langu           TYPE spras
      RETURNING
        VALUE(rs_template) TYPE zemail_s_template
      RAISING
        zcx_template.

    " Ignora ACTIVO/ESTADO de proposito: usada para pre-visualizar rascunhos
    " em ZEMAIL_TMPL_MAINT (T4.3), nao para resolucao normal de envio.
    METHODS resolve_specific_version
      IMPORTING
        iv_id              TYPE zemail_template_id
        iv_langu           TYPE spras
        iv_versao          TYPE zemail_versao
      RETURNING
        VALUE(rs_template) TYPE zemail_s_template
      RAISING
        zcx_template.

    METHODS load_master_content
      IMPORTING
        iv_master_id      TYPE zemail_template_id
        iv_langu          TYPE spras
      RETURNING
        VALUE(rv_content) TYPE string
      RAISING
        zcx_template.

    METHODS validate_content
      IMPORTING
        iv_id        TYPE zemail_template_id
        iv_content   TYPE string
        iv_is_master TYPE abap_bool
      RAISING
        zcx_template.

ENDCLASS.


CLASS zcl_template_provider_db IMPLEMENTATION.

  METHOD constructor.
    mv_fallback_langu = iv_fallback_langu.
    mo_repository = COND #( WHEN io_repository IS BOUND
                             THEN io_repository
                             ELSE NEW zcl_template_repository_db( ) ).
  ENDMETHOD.

  METHOD zif_template_provider~get_template.
    IF iv_versao IS SUPPLIED.
      rs_template = resolve_specific_version(
        iv_id     = iv_id
        iv_langu  = iv_langu
        iv_versao = iv_versao ).
      RETURN.
    ENDIF.

    DATA(ls_key) = VALUE ty_cache_key( id = iv_id langu = iv_langu ).
    READ TABLE mt_cache WITH TABLE KEY key = ls_key ASSIGNING FIELD-SYMBOL(<ls_cache>).
    IF sy-subrc = 0.
      rs_template = <ls_cache>-template.
      RETURN.
    ENDIF.

    rs_template = resolve_active( iv_id = iv_id iv_langu = iv_langu ).

    INSERT VALUE ty_cache_entry( key = ls_key template = rs_template ) INTO TABLE mt_cache.
  ENDMETHOD.

  METHOD zif_template_provider~exists.
    DATA(ls_content) = mo_repository->read_active_content( iv_id = iv_id iv_langu = iv_langu ).
    rv_exists = ls_content-found.
  ENDMETHOD.

  METHOD resolve_active.
    DATA(ls_header) = mo_repository->read_header( iv_id ).
    IF ls_header-found = abap_false OR ls_header-activo <> abap_true.
      RAISE EXCEPTION TYPE zcx_template
        EXPORTING
          textid         = zcx_template=>not_found
          iv_template_id = iv_id.
    ENDIF.

    DATA(lv_resolved_langu) = iv_langu.
    DATA(ls_content) = mo_repository->read_active_content( iv_id = iv_id iv_langu = iv_langu ).

    IF ls_content-found = abap_false.
      lv_resolved_langu = mv_fallback_langu.
      ls_content = mo_repository->read_active_content( iv_id = iv_id iv_langu = lv_resolved_langu ).
    ENDIF.

    IF ls_content-found = abap_false.
      RAISE EXCEPTION TYPE zcx_template
        EXPORTING
          textid         = zcx_template=>not_found
          iv_template_id = iv_id.
    ENDIF.

    validate_content( iv_id = iv_id iv_content = ls_content-content iv_is_master = abap_false ).

    rs_template-template_id = iv_id.
    rs_template-spras       = lv_resolved_langu.
    rs_template-versao      = ls_content-versao.
    rs_template-subject     = ls_content-subject.
    rs_template-content     = ls_content-content.

    IF ls_header-master_id IS NOT INITIAL.
      rs_template-master_content = load_master_content(
        iv_master_id = ls_header-master_id
        iv_langu     = lv_resolved_langu ).
    ENDIF.
  ENDMETHOD.

  METHOD resolve_specific_version.
    DATA(ls_header) = mo_repository->read_header( iv_id ).
    IF ls_header-found = abap_false.
      RAISE EXCEPTION TYPE zcx_template
        EXPORTING
          textid         = zcx_template=>not_found
          iv_template_id = iv_id.
    ENDIF.

    DATA(ls_content) = mo_repository->read_content_by_version(
      iv_id     = iv_id
      iv_langu  = iv_langu
      iv_versao = iv_versao ).

    IF ls_content-found = abap_false.
      RAISE EXCEPTION TYPE zcx_template
        EXPORTING
          textid         = zcx_template=>not_found
          iv_template_id = iv_id.
    ENDIF.

    validate_content( iv_id = iv_id iv_content = ls_content-content iv_is_master = abap_false ).

    rs_template-template_id = iv_id.
    rs_template-spras       = iv_langu.
    rs_template-versao      = ls_content-versao.
    rs_template-subject     = ls_content-subject.
    rs_template-content     = ls_content-content.

    IF ls_header-master_id IS NOT INITIAL.
      rs_template-master_content = load_master_content(
        iv_master_id = ls_header-master_id
        iv_langu     = iv_langu ).
    ENDIF.
  ENDMETHOD.

  METHOD load_master_content.
    DATA(ls_content) = mo_repository->read_active_content( iv_id = iv_master_id iv_langu = iv_langu ).

    IF ls_content-found = abap_false.
      ls_content = mo_repository->read_active_content(
        iv_id    = iv_master_id
        iv_langu = mv_fallback_langu ).
    ENDIF.

    IF ls_content-found = abap_false.
      RAISE EXCEPTION TYPE zcx_template
        EXPORTING
          textid         = zcx_template=>not_found
          iv_template_id = iv_master_id.
    ENDIF.

    validate_content( iv_id = iv_master_id iv_content = ls_content-content iv_is_master = abap_true ).

    rv_content = ls_content-content.
  ENDMETHOD.

  METHOD validate_content.
    IF iv_content IS INITIAL.
      RAISE EXCEPTION TYPE zcx_template
        EXPORTING
          textid         = zcx_template=>invalid_content
          iv_template_id = iv_id.
    ENDIF.

    IF iv_is_master = abap_true AND NOT iv_content CS '{{BODY}}'.
      RAISE EXCEPTION TYPE zcx_template
        EXPORTING
          textid         = zcx_template=>invalid_content
          iv_template_id = iv_id.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

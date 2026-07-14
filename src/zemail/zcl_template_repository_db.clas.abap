CLASS zcl_template_repository_db DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_template_repository.

ENDCLASS.


CLASS zcl_template_repository_db IMPLEMENTATION.

  METHOD zif_template_repository~read_header.
    SELECT SINGLE master_id, activo
      FROM zemail_tmpl
      WHERE template_id = @iv_id
      INTO ( @rs_header-master_id, @rs_header-activo ).

    rs_header-found = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD zif_template_repository~read_active_content.
    SELECT versao, subject, content
      FROM zemail_tmpl_cnt
      WHERE template_id = @iv_id
        AND spras       = @iv_langu
        AND estado      = @zif_email_const=>version_status-active
      ORDER BY versao DESCENDING
      INTO TABLE @DATA(lt_rows)
      UP TO 1 ROWS.

    IF lines( lt_rows ) = 1.
      rs_content-versao  = lt_rows[ 1 ]-versao.
      rs_content-subject = lt_rows[ 1 ]-subject.
      rs_content-content = lt_rows[ 1 ]-content.
      rs_content-found   = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD zif_template_repository~read_content_by_version.
    SELECT SINGLE versao, subject, content
      FROM zemail_tmpl_cnt
      WHERE template_id = @iv_id
        AND spras       = @iv_langu
        AND versao      = @iv_versao
      INTO ( @rs_content-versao, @rs_content-subject, @rs_content-content ).

    rs_content-found = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

ENDCLASS.

REPORT zemail_tmpl_load.

PARAMETERS:
  p_file   TYPE rlgrap-filename OBLIGATORY,
  p_tmplid TYPE zemail_template_id OBLIGATORY,
  p_langu  TYPE spras OBLIGATORY DEFAULT sy-langu,
  p_subj   TYPE string OBLIGATORY.

CLASS lcl_tmpl_loader DEFINITION.

  PUBLIC SECTION.

    METHODS run
      IMPORTING
        iv_file    TYPE rlgrap-filename
        iv_tmplid  TYPE zemail_template_id
        iv_langu   TYPE spras
        iv_subject TYPE string.

  PRIVATE SECTION.

    METHODS header_exists
      IMPORTING
        iv_tmplid        TYPE zemail_template_id
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    METHODS read_file
      IMPORTING
        iv_file           TYPE rlgrap-filename
      RETURNING
        VALUE(rv_content) TYPE string.

    METHODS next_version
      IMPORTING
        iv_tmplid        TYPE zemail_template_id
        iv_langu         TYPE spras
      RETURNING
        VALUE(rv_versao) TYPE zemail_versao.

    METHODS save_draft
      IMPORTING
        iv_tmplid  TYPE zemail_template_id
        iv_langu   TYPE spras
        iv_versao  TYPE zemail_versao
        iv_subject TYPE string
        iv_content TYPE string.

ENDCLASS.


CLASS lcl_tmpl_loader IMPLEMENTATION.

  METHOD run.
    IF header_exists( iv_tmplid ) = abap_false.
      MESSAGE |Template { iv_tmplid } não existe em ZEMAIL_TMPL — criar o cabeçalho primeiro.| TYPE 'E'.
      RETURN.
    ENDIF.

    DATA(lv_content) = read_file( iv_file ).
    IF lv_content IS INITIAL.
      MESSAGE 'Ficheiro vazio ou erro ao ler — nada foi gravado.' TYPE 'E'.
      RETURN.
    ENDIF.

    DATA(lv_versao) = next_version( iv_tmplid = iv_tmplid iv_langu = iv_langu ).

    save_draft(
      iv_tmplid  = iv_tmplid
      iv_langu   = iv_langu
      iv_versao  = lv_versao
      iv_subject = iv_subject
      iv_content = lv_content ).

    MESSAGE |Versão { lv_versao } (Rascunho) gravada para { iv_tmplid } / { iv_langu }.| TYPE 'S'.
  ENDMETHOD.

  METHOD header_exists.
    SELECT SINGLE @abap_true
      FROM zemail_tmpl
      WHERE template_id = @iv_tmplid
      INTO @rv_exists.
  ENDMETHOD.

  METHOD read_file.
    DATA lt_lines TYPE STANDARD TABLE OF string.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename            = iv_file
        filetype            = 'ASC'
        has_field_separator = abap_false
      CHANGING
        data_tab            = lt_lines
      EXCEPTIONS
        file_open_error         = 1
        file_read_error         = 2
        no_batch                = 3
        gui_refuse_filetransfer = 4
        invalid_type            = 5
        no_authority            = 6
        OTHERS                  = 7 ).
    CHECK sy-subrc = 0.

    LOOP AT lt_lines INTO DATA(lv_line).
      rv_content = rv_content && lv_line && cl_abap_char_utilities=>newline.
    ENDLOOP.
  ENDMETHOD.

  METHOD next_version.
    SELECT SINGLE MAX( versao )
      FROM zemail_tmpl_cnt
      WHERE template_id = @iv_tmplid
        AND spras       = @iv_langu
      INTO @DATA(lv_max).

    rv_versao = lv_max + 1.
  ENDMETHOD.

  METHOD save_draft.
    DATA lv_timestamp TYPE zemail_tmpl_cnt-changed_at.
    GET TIME STAMP FIELD lv_timestamp.

    INSERT zemail_tmpl_cnt FROM VALUE #(
      mandt       = sy-mandt
      template_id = iv_tmplid
      spras       = iv_langu
      versao      = iv_versao
      estado      = zif_email_const=>version_status-draft
      subject     = iv_subject
      content     = iv_content
      changed_by  = sy-uname
      changed_at  = lv_timestamp ).
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_tmpl_loader( )->run(
    iv_file    = p_file
    iv_tmplid  = p_tmplid
    iv_langu   = p_langu
    iv_subject = p_subj ).

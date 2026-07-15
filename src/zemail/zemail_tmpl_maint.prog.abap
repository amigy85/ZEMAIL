REPORT zemail_tmpl_maint.

TYPE-POOLS icon.

PARAMETERS p_tmplid TYPE zemail_template_id OBLIGATORY.

CLASS lcl_tmpl_maint DEFINITION.

  PUBLIC SECTION.

    METHODS run
      IMPORTING
        iv_tmplid TYPE zemail_template_id.

  PRIVATE SECTION.

    CONSTANTS:
      c_fc_preview  TYPE salv_de_function VALUE 'PREVIEW',
      c_fc_sendtest TYPE salv_de_function VALUE 'SENDTEST',
      c_fc_activate TYPE salv_de_function VALUE 'ACTIVATE'.

    DATA mv_tmplid   TYPE zemail_template_id.
    DATA mt_versions TYPE STANDARD TABLE OF zemail_tmpl_cnt WITH DEFAULT KEY.
    DATA mo_alv      TYPE REF TO cl_salv_table.

    METHODS load_versions.
    METHODS display_alv.
    METHODS add_custom_functions.

    METHODS on_added_function FOR EVENT added_function OF cl_salv_events_table
      IMPORTING e_salv_function.

    METHODS get_selected_row
      RETURNING
        VALUE(rs_version) TYPE zemail_tmpl_cnt.

    METHODS build_preview_html
      IMPORTING
        is_version     TYPE zemail_tmpl_cnt
      RETURNING
        VALUE(rv_html) TYPE string.

    " Substitui cada {{NOME}}/{{TAB:NOME}} por [NOME]/[TAB:NOME] — pré-
    " visualização genérica, sem assumir nomes de campos de nenhum negócio
    " específico (o framework é reutilizável para outros templates).
    METHODS placeholder_example_text
      IMPORTING
        iv_html        TYPE string
      RETURNING
        VALUE(rv_html) TYPE string.

    METHODS do_preview
      IMPORTING
        is_version TYPE zemail_tmpl_cnt.

    METHODS do_sendtest
      IMPORTING
        is_version TYPE zemail_tmpl_cnt.

    METHODS do_activate
      IMPORTING
        is_version TYPE zemail_tmpl_cnt.

    METHODS current_user_email
      RETURNING
        VALUE(rv_email) TYPE ad_smtpadr.

ENDCLASS.


CLASS lcl_tmpl_maint IMPLEMENTATION.

  METHOD run.
    mv_tmplid = iv_tmplid.
    load_versions( ).

    IF mt_versions IS INITIAL.
      MESSAGE |Nenhuma versão encontrada para { iv_tmplid }.| TYPE 'I'.
      RETURN.
    ENDIF.

    display_alv( ).
  ENDMETHOD.

  METHOD load_versions.
    SELECT *
      FROM zemail_tmpl_cnt
      WHERE template_id = @mv_tmplid
      ORDER BY spras, versao DESCENDING
      INTO TABLE @mt_versions.
  ENDMETHOD.

  METHOD display_alv.
    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = mo_alv
          CHANGING  t_table      = mt_versions ).
      CATCH cx_salv_msg.
        MESSAGE 'Erro ao construir o ALV.' TYPE 'E'.
        RETURN.
    ENDTRY.

    add_custom_functions( ).
    SET HANDLER on_added_function FOR mo_alv->get_event( ).

    mo_alv->get_functions( )->set_all( abap_true ).
    mo_alv->get_selections( )->set_selection_mode( if_salv_c_selection_mode=>row_column ).

    mo_alv->display( ).
  ENDMETHOD.

  METHOD add_custom_functions.
    TRY.
        mo_alv->get_functions( )->add_function(
          name     = c_fc_preview
          icon     = icon_display
          text     = 'Pré-visualizar'
          tooltip  = 'Pré-visualizar versão seleccionada (download .html)'
          position = if_salv_c_function_position=>right_of_salv_functions ).

        mo_alv->get_functions( )->add_function(
          name     = c_fc_sendtest
          icon     = icon_mail
          text     = 'Enviar teste'
          tooltip  = 'Enviar e-mail de teste para o utilizador actual'
          position = if_salv_c_function_position=>right_of_salv_functions ).

        mo_alv->get_functions( )->add_function(
          name     = c_fc_activate
          icon     = icon_okay
          text     = 'Activar'
          tooltip  = 'Activar esta versão (desactiva a anterior no mesmo idioma)'
          position = if_salv_c_function_position=>right_of_salv_functions ).
      CATCH cx_salv_existing cx_salv_wrong_call.
    ENDTRY.
  ENDMETHOD.

  METHOD on_added_function.
    DATA(ls_version) = get_selected_row( ).
    IF ls_version IS INITIAL.
      MESSAGE 'Seleccione uma versão primeiro.' TYPE 'I'.
      RETURN.
    ENDIF.

    CASE e_salv_function.
      WHEN c_fc_preview.
        do_preview( ls_version ).
      WHEN c_fc_sendtest.
        do_sendtest( ls_version ).
      WHEN c_fc_activate.
        do_activate( ls_version ).
    ENDCASE.
  ENDMETHOD.

  METHOD get_selected_row.
    DATA(lt_rows) = mo_alv->get_selections( )->get_selected_rows( ).
    CHECK lines( lt_rows ) = 1.

    READ TABLE mt_versions INTO rs_version INDEX lt_rows[ 1 ].
  ENDMETHOD.

  METHOD build_preview_html.
    DATA(lo_repo)   = NEW zcl_template_repository_db( ).
    DATA(ls_header) = lo_repo->read_header( mv_tmplid ).

    DATA(lv_content) = is_version-content.

    IF ls_header-master_id IS NOT INITIAL.
      DATA(ls_master) = lo_repo->read_active_content(
        iv_id    = ls_header-master_id
        iv_langu = is_version-spras ).

      IF ls_master-found = abap_true.
        DATA(lv_master_content) = ls_master-content.
        REPLACE ALL OCCURRENCES OF `{{BODY}}` IN lv_master_content WITH lv_content.
        lv_content = lv_master_content.
      ENDIF.
    ENDIF.

    rv_html = placeholder_example_text( lv_content ).
  ENDMETHOD.

  METHOD placeholder_example_text.
    rv_html = iv_html.

    FIND ALL OCCURRENCES OF REGEX '\{\{[A-Z0-9_:]+\}\}' IN rv_html RESULTS DATA(lt_matches).
    SORT lt_matches BY offset DESCENDING.

    LOOP AT lt_matches INTO DATA(ls_match).
      DATA(lv_name) = rv_html+ls_match-offset+2(ls_match-length-4).
      REPLACE SECTION OFFSET ls_match-offset LENGTH ls_match-length
        OF rv_html WITH |[{ lv_name }]|.
    ENDLOOP.
  ENDMETHOD.

  METHOD do_preview.
    DATA(lv_html) = build_preview_html( is_version ).
    DATA(lv_filename) = |zemail_preview_{ mv_tmplid }_{ is_version-spras }_{ is_version-versao }.html|.
    DATA lv_path     TYPE string.
    DATA lv_fullpath TYPE string.

    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING
        window_title      = 'Guardar pré-visualização'
        default_extension = 'html'
        default_file_name = lv_filename
      CHANGING
        filename          = lv_filename
        path              = lv_path
        fullpath          = lv_fullpath
      EXCEPTIONS
        OTHERS            = 1 ).

    CHECK sy-subrc = 0 AND lv_fullpath IS NOT INITIAL.

    DATA(lt_lines) = cl_bcs_convert=>string_to_soli( lv_html ).

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        filename = lv_fullpath
        filetype = 'ASC'
      CHANGING
        data_tab = lt_lines
      EXCEPTIONS
        OTHERS   = 1 ).

    IF sy-subrc = 0.
      MESSAGE |Pré-visualização gravada em { lv_fullpath }.| TYPE 'S'.
    ELSE.
      MESSAGE 'Erro ao gravar o ficheiro de pré-visualização.' TYPE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD do_sendtest.
    DATA(lv_email) = current_user_email( ).
    IF lv_email IS INITIAL.
      MESSAGE 'Endereço de e-mail do utilizador actual não encontrado (ver SU01).' TYPE 'E'.
      RETURN.
    ENDIF.

    DATA(ls_message) = VALUE zemail_s_message(
      subject    = |[TESTE] { is_version-subject }|
      body_html  = build_preview_html( is_version )
      recipients = VALUE #( ( address        = lv_email
                              visible_name   = sy-uname
                              recipient_type = zif_email_const=>recipient_type-to_addr ) ) ).

    TRY.
        zcl_email_factory=>create_sender( )->send( ls_message ).
        MESSAGE |Teste enviado para { lv_email }.| TYPE 'S'.
      CATCH zcx_email_send INTO DATA(lx_send).
        MESSAGE |Erro ao enviar teste: { lx_send->get_text( ) }| TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD do_activate.
    IF is_version-estado = zif_email_const=>version_status-active.
      MESSAGE 'Esta versão já está activa.' TYPE 'I'.
      RETURN.
    ENDIF.

    UPDATE zemail_tmpl_cnt
      SET estado = @zif_email_const=>version_status-obsolete
      WHERE template_id = @mv_tmplid
        AND spras       = @is_version-spras
        AND estado      = @zif_email_const=>version_status-active.

    UPDATE zemail_tmpl_cnt
      SET estado = @zif_email_const=>version_status-active
      WHERE template_id = @mv_tmplid
        AND spras       = @is_version-spras
        AND versao      = @is_version-versao.

    COMMIT WORK.

    load_versions( ).
    mo_alv->refresh( ).

    MESSAGE |Versão { is_version-versao } activada para { is_version-spras }.| TYPE 'S'.
  ENDMETHOD.

  METHOD current_user_email.
    DATA ls_address TYPE bapiaddr3.
    DATA lt_return   TYPE STANDARD TABLE OF bapiret2.

    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username = sy-uname
      IMPORTING
        address  = ls_address
      TABLES
        return   = lt_return.

    rv_email = ls_address-e_mail.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_tmpl_maint( )->run( p_tmplid ).

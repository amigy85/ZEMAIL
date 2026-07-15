REPORT zemail_tmpl_maint.

PARAMETERS p_tmplid TYPE zemail_template_id OBLIGATORY.

" Popup de escolha de acção — SELECTION-SCREEN sub-ecrã (puro texto, sem
" objecto Dynpro/Screen Painter), invocado via CALL SELECTION-SCREEN.
" Mesma técnica usada pelo próprio abapGit para o seu popup de login
" (ZABAPGIT_PASSWORD_DIALOG, classe LCL_PASSWORD_DIALOG).
SELECTION-SCREEN BEGIN OF SCREEN 1002 TITLE tt_1002.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) tc_prev FOR FIELD p_c_prev.
PARAMETERS p_c_prev RADIOBUTTON GROUP acao DEFAULT 'X'.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) tc_test FOR FIELD p_c_test.
PARAMETERS p_c_test RADIOBUTTON GROUP acao.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) tc_activ FOR FIELD p_cactiv.
PARAMETERS p_cactiv RADIOBUTTON GROUP acao.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF SCREEN 1002.


CLASS lcl_action_popup DEFINITION FINAL.

  PUBLIC SECTION.

    CONSTANTS c_dynnr TYPE sy-dynnr VALUE '1002'.

    " 'P' pré-visualizar, 'T' enviar teste, 'A' activar, ' ' cancelado
    CLASS-METHODS popup
      RETURNING
        VALUE(rv_action) TYPE char1.

ENDCLASS.


CLASS lcl_action_popup IMPLEMENTATION.

  METHOD popup.
    tt_1002  = 'Escolha uma acção'.
    tc_prev  = 'Pré-visualizar (download .html)'.
    tc_test  = 'Enviar e-mail de teste para mim'.
    tc_activ = 'Activar esta versão'.

    p_c_prev = abap_true.
    p_c_test = abap_false.
    p_cactiv = abap_false.

    " CALL SELECTION-SCREEN devolve sy-subrc = 0 se o utilizador confirmou
    " (F8/check) e <> 0 se cancelou — não depende de adivinhar o SY-UCOMM
    " exacto do botão de confirmação (esse era o problema da versão
    " anterior, baseada em AT SELECTION-SCREEN + WHEN 'OK').
    CALL SELECTION-SCREEN c_dynnr STARTING AT 30 5 ENDING AT 90 12.

    CHECK sy-subrc = 0.

    IF p_c_prev = abap_true.
      rv_action = 'P'.
    ELSEIF p_c_test = abap_true.
      rv_action = 'T'.
    ELSEIF p_cactiv = abap_true.
      rv_action = 'A'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_tmpl_maint DEFINITION.

  PUBLIC SECTION.

    METHODS run
      IMPORTING
        iv_tmplid TYPE zemail_template_id.

  PRIVATE SECTION.

    DATA mv_tmplid   TYPE zemail_template_id.
    DATA mt_versions TYPE STANDARD TABLE OF zemail_tmpl_cnt WITH DEFAULT KEY.
    DATA mo_alv      TYPE REF TO cl_salv_table.

    METHODS load_versions.
    METHODS display_alv.

    " Duplo-clique não está sujeito à restrição GRID-only que afecta
    " CL_SALV_FUNCTIONS->ADD_FUNCTION (ver histórico desta tarefa) —
    " funciona no modo fullscreen simples, sem container nem ecrã próprio.
    METHODS on_double_click FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row.

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

    SET HANDLER on_double_click FOR mo_alv->get_event( ).

    mo_alv->get_functions( )->set_all( abap_true ).
    mo_alv->get_selections( )->set_selection_mode( if_salv_c_selection_mode=>row_column ).

    mo_alv->display( ).
  ENDMETHOD.

  METHOD on_double_click.
    CHECK row > 0.
    READ TABLE mt_versions INTO DATA(ls_version) INDEX row.
    CHECK sy-subrc = 0.

    DATA(lv_action) = lcl_action_popup=>popup( ).

    CASE lv_action.
      WHEN 'P'.
        do_preview( ls_version ).
      WHEN 'T'.
        do_sendtest( ls_version ).
      WHEN 'A'.
        do_activate( ls_version ).
        load_versions( ).
        mo_alv->refresh( ).
    ENDCASE.
  ENDMETHOD.

  METHOD build_preview_html.
    " Tipado pela interface: READ_HEADER/READ_ACTIVE_CONTENT são implementações
    " de ZIF_TEMPLATE_REPOSITORY e não ficam acessíveis via uma variável tipada
    " pela classe concreta (sem ALIASES) — só através da referência à interface.
    DATA lo_repo TYPE REF TO zif_template_repository.
    lo_repo = NEW zcl_template_repository_db( ).

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

    " O offset/length do acesso a subcadeia tem de ser uma variável simples,
    " não uma expressão aritmética inline (ex.: rv_html+off+2(len-4) não
    " compila) — por isso calculados à parte em LV_OFF/LV_LEN.
    DATA lv_off TYPE i.
    DATA lv_len TYPE i.

    LOOP AT lt_matches INTO DATA(ls_match).
      lv_off = ls_match-offset + 2.
      lv_len = ls_match-length - 4.
      DATA(lv_name) = rv_html+lv_off(lv_len).

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

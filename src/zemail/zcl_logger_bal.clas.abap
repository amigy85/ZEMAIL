CLASS zcl_logger_bal DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_logger.

    METHODS constructor
      IMPORTING
        iv_object    TYPE balobj_d
        iv_subobject TYPE balsubobj
        iv_extnumber TYPE balnrext OPTIONAL.

  PRIVATE SECTION.

    DATA mv_log_handle TYPE balloghndl.

    METHODS add_message
      IMPORTING
        iv_type    TYPE symsgty
        iv_message TYPE string.

ENDCLASS.


CLASS zcl_logger_bal IMPLEMENTATION.

  METHOD constructor.
    DATA(ls_log) = VALUE bal_s_log(
      object    = iv_object
      subobject = iv_subobject
      extnumber = iv_extnumber
      aldate    = sy-datum
      altime    = sy-uzeit
      aluser    = sy-uname ).

    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log      = ls_log
      IMPORTING
        e_log_handle = mv_log_handle
      EXCEPTIONS
        log_header_inconsistent = 1
        OTHERS                  = 2.
  ENDMETHOD.

  METHOD zif_logger~info.
    add_message( iv_type = 'S' iv_message = iv_text ).
  ENDMETHOD.

  METHOD zif_logger~warning.
    add_message( iv_type = 'W' iv_message = iv_text ).
  ENDMETHOD.

  METHOD zif_logger~error.
    DATA(lv_full) = iv_text.

    IF ix_exc IS BOUND.
      lv_full = COND #(
        WHEN lv_full IS NOT INITIAL
        THEN |{ lv_full }: { ix_exc->get_text( ) }|
        ELSE ix_exc->get_text( ) ).
    ENDIF.

    add_message( iv_type = 'E' iv_message = lv_full ).
  ENDMETHOD.

  METHOD zif_logger~save.
    CHECK mv_log_handle IS NOT INITIAL.
    DATA(lt_handles) = VALUE bal_t_logh( ( mv_log_handle ) ).

    CALL FUNCTION 'BAL_DB_SAVE'
      EXPORTING
        i_t_log_handle = lt_handles
      EXCEPTIONS
        OTHERS         = 1.
  ENDMETHOD.

  METHOD add_message.
    CHECK mv_log_handle IS NOT INITIAL.

    " Mensagem livre 00/001 do BAL só suporta 4 variáveis de 50 caracteres
    " cada; dividir em blocos evita truncar mensagens com mais de 50
    " caracteres para apenas MSGV1 (limitação conhecida da solução actual).
    DATA(lv_rest) = iv_message.

    DATA(lv_v1) = COND symsgv( WHEN strlen( lv_rest ) > 50 THEN lv_rest(50) ELSE lv_rest ).
    lv_rest = COND string( WHEN strlen( lv_rest ) > 50 THEN lv_rest+50 ELSE `` ).

    DATA(lv_v2) = COND symsgv( WHEN strlen( lv_rest ) > 50 THEN lv_rest(50) ELSE lv_rest ).
    lv_rest = COND string( WHEN strlen( lv_rest ) > 50 THEN lv_rest+50 ELSE `` ).

    DATA(lv_v3) = COND symsgv( WHEN strlen( lv_rest ) > 50 THEN lv_rest(50) ELSE lv_rest ).
    lv_rest = COND string( WHEN strlen( lv_rest ) > 50 THEN lv_rest+50 ELSE `` ).

    DATA(lv_v4) = COND symsgv( WHEN strlen( lv_rest ) > 50 THEN lv_rest(50) ELSE lv_rest ).

    DATA(ls_msg) = VALUE bal_s_msg(
      msgty = iv_type
      msgid = '00'
      msgno = '001'
      msgv1 = lv_v1
      msgv2 = lv_v2
      msgv3 = lv_v3
      msgv4 = lv_v4 ).

    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        i_log_handle = mv_log_handle
        i_s_msg      = ls_msg
      EXCEPTIONS
        OTHERS       = 1.
  ENDMETHOD.

ENDCLASS.

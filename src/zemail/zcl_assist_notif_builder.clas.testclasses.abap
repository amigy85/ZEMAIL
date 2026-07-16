CLASS ltd_email_service DEFINITION FOR TESTING.

  PUBLIC SECTION.

    INTERFACES zif_email_service.

    DATA mv_fail_for TYPE ad_smtpadr.
    DATA mt_sent_to  TYPE STANDARD TABLE OF ad_smtpadr WITH DEFAULT KEY.
    DATA mt_values   TYPE zemail_t_placeholder.

ENDCLASS.


CLASS ltd_email_service IMPLEMENTATION.

  METHOD zif_email_service~send.
    DATA(lv_addr) = it_recipients[ 1 ]-address.
    mt_values = it_values.

    IF lv_addr = mv_fail_for.
      RAISE EXCEPTION TYPE zcx_email.
    ENDIF.

    APPEND lv_addr TO mt_sent_to.
    rs_result-status = zif_email_const=>send_status-success.
  ENDMETHOD.

ENDCLASS.


CLASS ltd_run_repository DEFINITION FOR TESTING.

  PUBLIC SECTION.

    INTERFACES zif_assist_run_repository.

    TYPES:
      BEGIN OF ty_status_call,
        referencia TYPE zassist_referencia,
        pernr      TYPE pernr_d,
        status     TYPE zassist_email_status,
      END OF ty_status_call,
      tt_status_call TYPE STANDARD TABLE OF ty_status_call WITH DEFAULT KEY.

    DATA mt_status_calls TYPE tt_status_call.

ENDCLASS.


CLASS ltd_run_repository IMPLEMENTATION.

  METHOD zif_assist_run_repository~find.
    " Nao usado por ZCL_ASSIST_NOTIF_BUILDER — devolve sempre vazio.
  ENDMETHOD.

  METHOD zif_assist_run_repository~insert.
    " Nao usado por ZCL_ASSIST_NOTIF_BUILDER.
  ENDMETHOD.

  METHOD zif_assist_run_repository~update_email_status.
    APPEND VALUE #( referencia = iv_referencia pernr = iv_pernr status = iv_status )
      TO mt_status_calls.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_assist_notif_builder DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
  FINAL.

  PRIVATE SECTION.

    DATA mo_cut          TYPE REF TO zcl_assist_notif_builder.
    DATA mo_email_double TYPE REF TO ltd_email_service.
    DATA mo_run_double   TYPE REF TO ltd_run_repository.

    METHODS setup.

    METHODS empregado_base
      RETURNING
        VALUE(rs_emp) TYPE zcl_assist_notif_builder=>ty_employee.

    METHODS envia_com_sucesso_actualiza_status FOR TESTING RAISING cx_static_check.
    METHODS sem_email_marca_erro_sem_enviar    FOR TESTING RAISING cx_static_check.
    METHODS erro_no_envio_marca_status_erro    FOR TESTING RAISING cx_static_check.
    METHODS placeholders_incluem_totais        FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_assist_notif_builder IMPLEMENTATION.

  METHOD setup.
    mo_email_double = NEW ltd_email_service( ).
    mo_run_double   = NEW ltd_run_repository( ).

    mo_cut = NEW zcl_assist_notif_builder(
      io_email_service  = mo_email_double
      io_run_repository = mo_run_double
      iv_pa0105_subtype = '0010' ).
  ENDMETHOD.

  METHOD empregado_base.
    rs_emp = VALUE #(
      pernr      = '00001234'
      email      = 'colaborador@hcb.co.mz'
      nome       = 'Joao Manuel'
      referencia = 'REF-2026-001'
      data_doc   = '01072026'
      bukrs      = '1000'
      waers      = 'MZN'
      lines      = VALUE #( ( natureza = 'Consulta' beneficiario = 'Joao Manuel' valor = '100.00' debito = '50.00' ) )
      total_valor  = '100.00'
      total_debito = '50.00' ).
  ENDMETHOD.

  METHOD envia_com_sucesso_actualiza_status.
    DATA(lt_employees) = VALUE zcl_assist_notif_builder=>tt_employees( ( empregado_base( ) ) ).

    DATA(lt_result) = mo_cut->send_to_employees( lt_employees ).

    cl_abap_unit_assert=>assert_equals( act = lines( mo_email_double->mt_sent_to ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_result[ 1 ]-status
      exp = zif_email_const=>send_status-success ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_run_double->mt_status_calls[ 1 ]-status
      exp = zif_email_const=>send_status-success ).
  ENDMETHOD.

  METHOD sem_email_marca_erro_sem_enviar.
    DATA(ls_emp) = empregado_base( ).
    CLEAR ls_emp-email.
    DATA(lt_employees) = VALUE zcl_assist_notif_builder=>tt_employees( ( ls_emp ) ).

    DATA(lt_result) = mo_cut->send_to_employees( lt_employees ).

    cl_abap_unit_assert=>assert_initial( mo_email_double->mt_sent_to ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_result[ 1 ]-status
      exp = zif_email_const=>send_status-error ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_run_double->mt_status_calls[ 1 ]-status
      exp = zif_email_const=>send_status-error ).
  ENDMETHOD.

  METHOD erro_no_envio_marca_status_erro.
    DATA(ls_emp) = empregado_base( ).
    mo_email_double->mv_fail_for = ls_emp-email.
    DATA(lt_employees) = VALUE zcl_assist_notif_builder=>tt_employees( ( ls_emp ) ).

    DATA(lt_result) = mo_cut->send_to_employees( lt_employees ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_result[ 1 ]-status
      exp = zif_email_const=>send_status-error ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_run_double->mt_status_calls[ 1 ]-status
      exp = zif_email_const=>send_status-error ).
  ENDMETHOD.

  METHOD placeholders_incluem_totais.
    DATA(lt_employees) = VALUE zcl_assist_notif_builder=>tt_employees( ( empregado_base( ) ) ).

    mo_cut->send_to_employees( lt_employees ).

    DATA(lv_total_valor) = mo_email_double->mt_values[ name = 'TOTAL_VALOR' ]-value.
    cl_abap_unit_assert=>assert_true( xsdbool( lv_total_valor CS 'MZN' ) ).

    DATA(lv_rows) = mo_email_double->mt_values[ name = 'TABLE_ROWS' ]-value.
    cl_abap_unit_assert=>assert_true( xsdbool( lv_rows CS '<tr>' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_rows CS 'Consulta' ) ).
  ENDMETHOD.

ENDCLASS.

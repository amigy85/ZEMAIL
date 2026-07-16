CLASS zcl_assist_notif_builder DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS c_template_id TYPE zemail_template_id VALUE 'ZDEBIT_NOTE_HCB'.

    TYPES:
      BEGIN OF ty_result,
        pernr   TYPE pernr_d,
        nome    TYPE ad_name1,
        email   TYPE ad_smtpadr,
        status  TYPE zassist_email_status,
        message TYPE string,
      END OF ty_result,
      tt_result TYPE STANDARD TABLE OF ty_result WITH DEFAULT KEY,

      BEGIN OF ty_debit_line,
        natureza     TYPE string,
        beneficiario TYPE string,
        valor        TYPE dmbtr,
        debito       TYPE dmbtr,
      END OF ty_debit_line,
      tt_debit_lines TYPE STANDARD TABLE OF ty_debit_line WITH DEFAULT KEY,

      " Publico (nao apenas interno) para que os testes (T5.6) possam
      " construir directamente colaboradores ja resolvidos e chamar
      " SEND_TO_EMPLOYEES sem passar por AUTHORITY-CHECK/PA0105 reais
      " (ver SEND_NOTIFICATIONS) — mesmo raciocinio de nao tocar na BD
      " real em testes que levou a extrair ZIF_ASSIST_RUN_REPOSITORY.
      BEGIN OF ty_employee,
        pernr        TYPE pernr_d,
        email        TYPE ad_smtpadr,
        nome         TYPE ad_name1,
        referencia   TYPE zassist_referencia,
        data_doc     TYPE char8,
        bukrs        TYPE bukrs,
        waers        TYPE waers,
        lines        TYPE tt_debit_lines,
        total_valor  TYPE dmbtr,
        total_debito TYPE dmbtr,
      END OF ty_employee,
      tt_employees TYPE HASHED TABLE OF ty_employee WITH UNIQUE KEY pernr.

    " IO_EMAIL_SERVICE (ZIF_EMAIL_SERVICE, do framework ZEMAIL — dependencia
    " unidireccional ZASSIST->ZEMAIL permitida) e IO_RUN_REPOSITORY
    " injectados, para poder testar com duplos (T5.6). IV_PA0105_SUBTYPE
    " vem de ZEMAIL_CONFIG-PA0105_SUBTYPE, resolvido pelo orquestrador
    " (T5.7) — esta classe nao le ZEMAIL_CONFIG.
    METHODS constructor
      IMPORTING
        io_email_service  TYPE REF TO zif_email_service
        io_run_repository TYPE REF TO zif_assist_run_repository
        iv_pa0105_subtype TYPE subty.

    " Agrupa por PERNR os registos ja lancados (IS_POSTED = true) de
    " IT_DADOS, faz AUTHORITY-CHECK P_ORGIN e resolve o e-mail via PA0105
    " (1 SELECT bulk) — depois delega o envio em si a SEND_TO_EMPLOYEES.
    " Efeitos reais (autorizacao + BD) nao isolaveis sem duplos pesados —
    " sem ABAP Unit directo, mesma razao de T5.5; a logica de envio
    " propriamente dita e testada via SEND_TO_EMPLOYEES.
    METHODS send_notifications
      IMPORTING
        it_dados         TYPE zassist_t_registo
      RETURNING
        VALUE(rt_result) TYPE tt_result.

    " Envia 1 e-mail por colaborador ja resolvido (e-mail incluido) via
    " ZDEBIT_NOTE_HCB; actualiza ZASSIST_RUN-EMAIL_STATUS (S/E) por
    " REFERENCIA+PERNR, para permitir reenvio sem relancar o FI. Cada
    " colaborador processado dentro do seu proprio TRY/CATCH — uma falha
    " nunca interrompe os restantes. Publico e testavel com duplos de
    " ZIF_EMAIL_SERVICE/ZIF_ASSIST_RUN_REPOSITORY (T5.6).
    METHODS send_to_employees
      IMPORTING
        it_employees     TYPE tt_employees
      RETURNING
        VALUE(rt_result) TYPE tt_result.

  PRIVATE SECTION.

    DATA mo_email_service  TYPE REF TO zif_email_service.
    DATA mo_run_repository TYPE REF TO zif_assist_run_repository.
    DATA mv_pa0105_subtype TYPE subty.

    METHODS build_employee_map
      IMPORTING
        it_dados            TYPE zassist_t_registo
      RETURNING
        VALUE(rt_employees) TYPE tt_employees.

    METHODS load_emails_bulk
      CHANGING
        ct_employees TYPE tt_employees.

    METHODS send_to_employee
      IMPORTING
        is_employee      TYPE ty_employee
      RETURNING
        VALUE(rs_result) TYPE ty_result.

    METHODS build_values
      IMPORTING
        is_employee      TYPE ty_employee
      RETURNING
        VALUE(rt_values) TYPE zemail_t_placeholder.

    METHODS build_table_rows
      IMPORTING
        it_lines       TYPE tt_debit_lines
        iv_currency    TYPE waers
      RETURNING
        VALUE(rv_rows) TYPE string.

    METHODS build_single_row
      IMPORTING
        is_line       TYPE ty_debit_line
        iv_is_even    TYPE abap_bool
        iv_currency   TYPE waers
      RETURNING
        VALUE(rv_row) TYPE string.

    " Formato fixo DD/MM/YYYY e moeda "valor CUR" — nao os formatos
    " embutidos FORMAT=DATE/CURRENCY do ZEMAIL (ZCL_PLACEHOLDER_SERVICE):
    " FORMAT=DATE respeita o SY-DATFM de quem executa o lote (errado para
    " um e-mail externo, que deve ter o mesmo aspecto seja quem for a
    " correr o relatorio); FORMAT=CURRENCY nunca recebe IV_WAERS, porque
    " ZCL_TEMPLATE_ENGINE->build nao o reencaminha a ZCL_PLACEHOLDER_SERVICE
    " ->replace — lacuna existente no framework ZEMAIL (Fase 3, ja fechada),
    " nao corrigida aqui. Os dois valores sao pre-formatados aqui, tal como
    " ZCL_DEBIT_NOTE_NOTIFICATION (lida via MCP) ja fazia, e passados como
    " placeholders FORMAT=PLAIN.
    METHODS format_amount
      IMPORTING
        iv_amount      TYPE dmbtr
        iv_currency    TYPE waers
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS format_date
      IMPORTING
        iv_date_raw    TYPE char8
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_assist_notif_builder IMPLEMENTATION.

  METHOD constructor.
    mo_email_service  = io_email_service.
    mo_run_repository = io_run_repository.
    mv_pa0105_subtype = iv_pa0105_subtype.
  ENDMETHOD.

  METHOD send_notifications.
    DATA(lt_employees) = build_employee_map(
      VALUE #( FOR ls_dado IN it_dados WHERE ( is_posted = abap_true ) ( ls_dado ) ) ).

    AUTHORITY-CHECK OBJECT 'P_ORGIN'
      ID 'INFTY' FIELD '0105'
      ID 'SUBTY' FIELD mv_pa0105_subtype
      ID 'PERSA' FIELD '*'
      ID 'PERSG' FIELD '*'
      ID 'PERSK' FIELD '*'
      ID 'VDSK1' FIELD '*'
      ID 'ACTVT' FIELD '03'.

    CHECK sy-subrc = 0.

    load_emails_bulk( CHANGING ct_employees = lt_employees ).

    rt_result = send_to_employees( lt_employees ).
  ENDMETHOD.

  METHOD send_to_employees.
    LOOP AT it_employees INTO DATA(ls_emp).
      APPEND send_to_employee( ls_emp ) TO rt_result.
    ENDLOOP.
  ENDMETHOD.

  METHOD send_to_employee.
    rs_result = VALUE #( pernr = is_employee-pernr nome = is_employee-nome email = is_employee-email ).

    IF is_employee-email IS INITIAL.
      rs_result-status  = zif_email_const=>send_status-error.
      rs_result-message = |PERNR { is_employee-pernr }: e-mail não encontrado em PA0105 (subtipo { mv_pa0105_subtype } ).|.
      mo_run_repository->update_email_status(
        iv_referencia = is_employee-referencia
        iv_pernr      = is_employee-pernr
        iv_status     = zif_email_const=>send_status-error ).
      RETURN.
    ENDIF.

    TRY.
        mo_email_service->send(
          iv_template_id = c_template_id
          iv_langu       = sy-langu
          it_recipients  = VALUE #( ( address        = is_employee-email
                                       visible_name   = is_employee-nome
                                       recipient_type = zif_email_const=>recipient_type-to_addr ) )
          it_values      = build_values( is_employee ) ).

        rs_result-status = zif_email_const=>send_status-success.

      CATCH zcx_email INTO DATA(lx_email).
        rs_result-status  = zif_email_const=>send_status-error.
        rs_result-message = lx_email->get_text( ).
    ENDTRY.

    mo_run_repository->update_email_status(
      iv_referencia = is_employee-referencia
      iv_pernr      = is_employee-pernr
      iv_status     = rs_result-status ).
  ENDMETHOD.

  METHOD build_employee_map.
    LOOP AT it_dados INTO DATA(ls_dado).
      READ TABLE rt_employees WITH TABLE KEY pernr = ls_dado-pernr
        ASSIGNING FIELD-SYMBOL(<ls_emp>).

      IF sy-subrc <> 0.
        INSERT VALUE ty_employee(
          pernr      = ls_dado-pernr
          nome       = ls_dado-nome
          referencia = ls_dado-referencia
          data_doc   = ls_dado-data
          bukrs      = ls_dado-bukrs
          waers      = ls_dado-waers )
          INTO TABLE rt_employees ASSIGNING <ls_emp>.
      ENDIF.

      APPEND VALUE ty_debit_line(
        natureza     = ls_dado-natureza
        beneficiario = ls_dado-beneficiario
        valor        = ls_dado-valor
        debito       = ls_dado-debito )
        TO <ls_emp>-lines.

      <ls_emp>-total_valor  = <ls_emp>-total_valor  + ls_dado-valor.
      <ls_emp>-total_debito = <ls_emp>-total_debito + ls_dado-debito.
    ENDLOOP.
  ENDMETHOD.

  METHOD load_emails_bulk.
    DATA lt_pernrs TYPE SORTED TABLE OF pernr_d WITH UNIQUE KEY table_line.
    LOOP AT ct_employees ASSIGNING FIELD-SYMBOL(<ls_e>).
      INSERT <ls_e>-pernr INTO TABLE lt_pernrs.
    ENDLOOP.

    CHECK lt_pernrs IS NOT INITIAL.

    " Campo USRID_LONG confirmado em ZCL_DEBIT_NOTE_NOTIFICATION->
    " load_emails_bulk (lido via MCP) — subtipo de e-mail em PA0105.
    SELECT pernr, usrid_long AS email
      FROM pa0105
      FOR ALL ENTRIES IN @lt_pernrs
      WHERE pernr = @lt_pernrs-table_line
        AND subty = @mv_pa0105_subtype
        AND endda >= @sy-datum
        AND begda <= @sy-datum
      INTO TABLE @DATA(lt_emails).

    LOOP AT lt_emails INTO DATA(ls_email).
      READ TABLE ct_employees WITH TABLE KEY pernr = ls_email-pernr
        ASSIGNING FIELD-SYMBOL(<ls_emp>).
      IF sy-subrc = 0 AND <ls_emp>-email IS INITIAL.
        <ls_emp>-email = ls_email-email.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_values.
    rt_values = VALUE #(
      ( name = 'REF'          value = is_employee-referencia
        format = zif_email_const=>placeholder_format-plain )
      ( name = 'DATA'         value = format_date( is_employee-data_doc )
        format = zif_email_const=>placeholder_format-plain )
      ( name = 'TABLE_ROWS'   value = build_table_rows( it_lines = is_employee-lines iv_currency = is_employee-waers )
        format = zif_email_const=>placeholder_format-plain )
      ( name = 'TOTAL_VALOR'  value = format_amount( iv_amount = is_employee-total_valor  iv_currency = is_employee-waers )
        format = zif_email_const=>placeholder_format-plain )
      ( name = 'TOTAL_DEBITO' value = format_amount( iv_amount = is_employee-total_debito iv_currency = is_employee-waers )
        format = zif_email_const=>placeholder_format-plain ) ).
  ENDMETHOD.

  METHOD build_table_rows.
    DATA lv_index TYPE i VALUE 1.
    LOOP AT it_lines INTO DATA(ls_line).
      DATA(lv_is_even) = COND abap_bool( WHEN lv_index MOD 2 = 0 THEN abap_true ELSE abap_false ).
      rv_rows = rv_rows && build_single_row(
        is_line     = ls_line
        iv_is_even  = lv_is_even
        iv_currency = iv_currency ).
      lv_index = lv_index + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_single_row.
    " Estilo replicado byte-a-byte de ZCL_DEBIT_NOTE_NOTIFICATION->
    " build_single_row (lido via MCP) — mesmo aspecto visual do e-mail actual.
    DATA(lv_bg) = COND string( WHEN iv_is_even = abap_true THEN '#f5f5fa' ELSE '#ffffff' ).

    DATA(lv_cell) =
      `style="padding:10px; font-family:Arial,Helvetica,sans-serif;` &&
      ` font-size:13px; color:#333333; background-color:` && lv_bg &&
      `; border-bottom:1px solid #ededf3;"`.

    DATA(lv_cell_r) =
      `style="padding:10px; font-family:Arial,Helvetica,sans-serif;` &&
      ` font-size:13px; color:#333333; background-color:` && lv_bg &&
      `; border-bottom:1px solid #ededf3; text-align:right; white-space:nowrap;"`.

    rv_row =
      `<tr>` &&
      `<td class="tbl-cell" ` && lv_cell && `>` && is_line-natureza     && `</td>` &&
      `<td class="tbl-cell" ` && lv_cell && `>` && is_line-beneficiario && `</td>` &&
      `<td class="tbl-cell" ` && lv_cell_r && `>` &&
        format_amount( iv_amount = is_line-valor  iv_currency = iv_currency ) &&
      `</td>` &&
      `<td class="tbl-cell" ` && lv_cell_r && `>` &&
        format_amount( iv_amount = is_line-debito iv_currency = iv_currency ) &&
      `</td>` &&
      `</tr>`.
  ENDMETHOD.

  METHOD format_amount.
    DATA lv_char TYPE char30.
    WRITE iv_amount TO lv_char CURRENCY iv_currency NO-SIGN.
    CONDENSE lv_char.
    rv_text = lv_char && ` ` && iv_currency.
  ENDMETHOD.

  METHOD format_date.
    CHECK strlen( iv_date_raw ) = 8.
    rv_text = iv_date_raw(2) && '/' && iv_date_raw+2(2) && '/' && iv_date_raw+4(4).
  ENDMETHOD.

ENDCLASS.

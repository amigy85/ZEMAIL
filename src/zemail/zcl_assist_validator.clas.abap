CLASS zcl_assist_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Reutiliza a estrutura standard BAPIRET2 (universal, pacote SBF_BAPI),
    " mas com um table type proprio — os table types BAPIRET2_T/BAPIRET2TAB
    " que existem no sistema pertencem a componentes funcionais nao
    " relacionados (SDFM, JSDI, COM_PRODUCT_API...), nao sao de uso geral.
    TYPES tt_bapiret2 TYPE STANDARD TABLE OF bapiret2 WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_result,
        pernr    TYPE pernr_d,
        messages TYPE tt_bapiret2,
      END OF ty_result,
      tt_result TYPE STANDARD TABLE OF ty_result WITH DEFAULT KEY.

    " Valida cada registo de CT_DADOS (todas as regras, nao só a primeira a
    " falhar — ao contrário do ELSEIF em cadeia de ZCL_MEDICAL_ASSIST_PROCESS
    " ->validar_dados, lido via MCP) e marca IS_VALID/MESSAGE nele, para os
    " consumidores seguintes do pipeline (T5.5/T5.6/T5.7). Devolve também
    " uma colecção BAPIRET2 tipada por registo, para reporte detalhado na
    " ALV (T5.8) — em vez da flag solta + string única de hoje.
    METHODS validate
      CHANGING
        ct_dados         TYPE zassist_t_registo
      RETURNING
        VALUE(rt_result) TYPE tt_result.

  PRIVATE SECTION.

    METHODS validate_registo
      IMPORTING
        is_dado          TYPE zassist_s_registo
      RETURNING
        VALUE(rt_return) TYPE tt_bapiret2.

    METHODS append_message
      IMPORTING
        iv_text   TYPE string
      CHANGING
        ct_return TYPE tt_bapiret2.

ENDCLASS.


CLASS zcl_assist_validator IMPLEMENTATION.

  METHOD validate.
    LOOP AT ct_dados ASSIGNING FIELD-SYMBOL(<ls_dado>).
      DATA(lt_return) = validate_registo( <ls_dado> ).

      <ls_dado>-is_valid = xsdbool( lt_return IS INITIAL ).

      IF <ls_dado>-is_valid = abap_false.
        CLEAR <ls_dado>-message.
        LOOP AT lt_return INTO DATA(ls_msg).
          <ls_dado>-message = COND #(
            WHEN <ls_dado>-message IS INITIAL THEN ls_msg-message
            ELSE <ls_dado>-message && `; ` && ls_msg-message ).
        ENDLOOP.

        APPEND VALUE #( pernr = <ls_dado>-pernr messages = lt_return ) TO rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_registo.
    DATA lv_text TYPE string.

    IF is_dado-pernr IS INITIAL.
      MESSAGE e020(zassist) INTO lv_text.
      append_message( EXPORTING iv_text = lv_text CHANGING ct_return = rt_return ).
    ENDIF.

    IF is_dado-valor <= 0.
      MESSAGE e021(zassist) INTO lv_text.
      append_message( EXPORTING iv_text = lv_text CHANGING ct_return = rt_return ).
    ENDIF.

    IF is_dado-conta IS INITIAL.
      MESSAGE e022(zassist) INTO lv_text.
      append_message( EXPORTING iv_text = lv_text CHANGING ct_return = rt_return ).
    ENDIF.

    IF is_dado-centro_custo IS INITIAL.
      MESSAGE e023(zassist) INTO lv_text.
      append_message( EXPORTING iv_text = lv_text CHANGING ct_return = rt_return ).
    ENDIF.

    IF is_dado-data IS INITIAL.
      MESSAGE e024(zassist) INTO lv_text.
      append_message( EXPORTING iv_text = lv_text CHANGING ct_return = rt_return ).
    ENDIF.

    IF is_dado-bukrs IS INITIAL.
      MESSAGE e025(zassist) INTO lv_text.
      append_message( EXPORTING iv_text = lv_text CHANGING ct_return = rt_return ).
    ENDIF.
  ENDMETHOD.

  METHOD append_message.
    APPEND VALUE bapiret2(
      type    = sy-msgty
      id      = sy-msgid
      number  = sy-msgno
      message = iv_text ) TO ct_return.
  ENDMETHOD.

ENDCLASS.

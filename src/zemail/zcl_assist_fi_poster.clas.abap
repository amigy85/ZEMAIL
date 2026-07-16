CLASS zcl_assist_fi_poster DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " IO_RUN_REPOSITORY injectado (ZIF_ASSIST_RUN_REPOSITORY, T5.6) — a
    " mesma razao da ZIF_TEMPLATE_REPOSITORY em ZEMAIL (T3.2): permite
    " testar esta classe com um duplo, sem tocar na BD real.
    METHODS constructor
      IMPORTING
        io_run_repository TYPE REF TO zif_assist_run_repository.

    " Lanca um documento FI por registo valido e ainda nao lancado de
    " CT_DADOS — mesmo mapeamento de BAPI_ACC_DOCUMENT_POST de
    " ZCL_MEDICAL_ASSIST_PROCESS->carregar_lancamentos (lido via MCP).
    " Antes de cada lancamento: verifica ZASSIST_RUN (dedup por
    " REFERENCIA+PERNR, reaproveita o documento se ja existir) e faz
    " AUTHORITY-CHECK F_BKPF_BUK (ACTVT 01). Sucesso -> INSERT ZASSIST_RUN
    " + BAPI_TRANSACTION_COMMIT na mesma LUW; erro -> ROLLBACK, marca o
    " registo com a mensagem de erro e continua com os restantes (nunca
    " aborta o lote inteiro).
    METHODS post
      CHANGING
        ct_dados TYPE zassist_t_registo.

  PRIVATE SECTION.

    DATA mo_run_repository TYPE REF TO zif_assist_run_repository.

    TYPES:
      tt_accountgl      TYPE STANDARD TABLE OF bapiacgl09 WITH DEFAULT KEY,
      tt_accountpayable TYPE STANDARD TABLE OF bapiacap09 WITH DEFAULT KEY,
      tt_currencyamount TYPE STANDARD TABLE OF bapiaccr09 WITH DEFAULT KEY,
      tt_extension      TYPE STANDARD TABLE OF bapiparex  WITH DEFAULT KEY.

    CONSTANTS c_nr_range_nr  TYPE inri-nrrangenr VALUE '43'.
    CONSTANTS c_nr_object    TYPE nrobj          VALUE 'RF_BELEG'.
    CONSTANTS c_nr_subobject TYPE string         VALUE 'HCB'.
    CONSTANTS c_obj_type     TYPE string         VALUE 'ZBKPF'.
    CONSTANTS c_obj_sys      TYPE string         VALUE 'SAPPRD'.
    CONSTANTS c_bus_act      TYPE string         VALUE 'RFBU'.
    CONSTANTS c_doc_type     TYPE blart          VALUE '63'.
    CONSTANTS c_sp_gl_ind    TYPE string         VALUE 'T'.
    CONSTANTS c_alloc_nmbr   TYPE dzuonr         VALUE 'PHINDU'.
    " TODO herdado de ZCL_MEDICAL_ASSIST_PROCESS (lido via MCP): confirmar
    " fornecedor 0000021670 (fornecedor mestre da clinica HCB) com a
    " equipa FI — nao resolvido nesta migracao, so replicado tal e qual.
    CONSTANTS c_hcb_vendor   TYPE lfa1-lifnr     VALUE '0000021670'.

    METHODS post_registo
      CHANGING
        cs_dado TYPE zassist_s_registo.

    METHODS next_document_number
      IMPORTING
        iv_date_raw      TYPE char8
      RETURNING
        VALUE(rv_number) TYPE zassist_documento
      RAISING
        zcx_assist_process.

    METHODS build_header
      IMPORTING
        iv_documento     TYPE zassist_documento
        is_dado          TYPE zassist_s_registo
      RETURNING
        VALUE(rs_header) TYPE bapiache09.

    METHODS build_gl_line
      IMPORTING
        is_dado      TYPE zassist_s_registo
      RETURNING
        VALUE(rt_gl) TYPE tt_accountgl.

    METHODS build_payable_lines
      IMPORTING
        is_dado           TYPE zassist_s_registo
      RETURNING
        VALUE(rt_payable) TYPE tt_accountpayable.

    METHODS build_amounts
      IMPORTING
        is_dado           TYPE zassist_s_registo
      RETURNING
        VALUE(rt_amounts) TYPE tt_currencyamount.

    METHODS build_extension
      RETURNING
        VALUE(rt_extension) TYPE tt_extension.

    METHODS csv_date_to_sap
      IMPORTING
        iv_date_raw    TYPE char8
      RETURNING
        VALUE(rv_date) TYPE char8.

    METHODS year_from_csv_date
      IMPORTING
        iv_date_raw    TYPE char8
      RETURNING
        VALUE(rv_year) TYPE char4.

    METHODS period_from_csv_date
      IMPORTING
        iv_date_raw   TYPE char8
      RETURNING
        VALUE(rv_per) TYPE monat.

ENDCLASS.


CLASS zcl_assist_fi_poster IMPLEMENTATION.

  METHOD constructor.
    mo_run_repository = io_run_repository.
  ENDMETHOD.

  METHOD post.
    LOOP AT ct_dados ASSIGNING FIELD-SYMBOL(<ls_dado>)
      WHERE is_valid = abap_true AND is_posted = abap_false.

      post_registo( CHANGING cs_dado = <ls_dado> ).
    ENDLOOP.
  ENDMETHOD.

  METHOD post_registo.
    DATA(ls_run) = mo_run_repository->find(
      iv_referencia = cs_dado-referencia
      iv_pernr      = cs_dado-pernr ).

    IF ls_run IS NOT INITIAL.
      cs_dado-is_posted = abap_true.
      cs_dado-documento = ls_run-belnr.
      cs_dado-message   = |Já processado anteriormente (documento { ls_run-belnr }).|.
      RETURN.
    ENDIF.

    AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
      ID 'BUKRS' FIELD cs_dado-bukrs
      ID 'ACTVT' FIELD '01'.

    IF sy-subrc <> 0.
      cs_dado-message = |Sem autorização para lançar em { cs_dado-bukrs }.|.
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_documento) = next_document_number( cs_dado-data ).

        " Parametros TABLES do CALL FUNCTION (interface classica) so
        " aceitam uma variavel de tabela ja declarada — nao aceitam
        " expressoes (chamadas de metodo) nem DATA(...) inline.
        DATA(lt_gl)       = build_gl_line( cs_dado ).
        DATA(lt_payable)  = build_payable_lines( cs_dado ).
        DATA(lt_amounts)  = build_amounts( cs_dado ).
        DATA(lt_ext)      = build_extension( ).
        DATA lt_return TYPE STANDARD TABLE OF bapiret2.

        CALL FUNCTION 'BAPI_ACC_DOCUMENT_POST'
          EXPORTING
            documentheader = build_header( iv_documento = lv_documento is_dado = cs_dado )
          TABLES
            accountgl      = lt_gl
            accountpayable = lt_payable
            currencyamount = lt_amounts
            extension2     = lt_ext
            return         = lt_return.

        IF line_exists( lt_return[ type = 'E' ] ) OR line_exists( lt_return[ type = 'A' ] ).
          CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

          DATA(lv_detail) = COND string(
            WHEN line_exists( lt_return[ type = 'E' ] ) THEN lt_return[ type = 'E' ]-message
            ELSE lt_return[ type = 'A' ]-message ).

          cs_dado-message = |Erro ao lançar documento FI: { lv_detail }|.
          RETURN.
        ENDIF.

        DATA lv_timestamp TYPE zassist_run-created_at.
        GET TIME STAMP FIELD lv_timestamp.

        mo_run_repository->insert( VALUE zassist_run(
          referencia = cs_dado-referencia
          pernr      = cs_dado-pernr
          belnr      = lv_documento
          bukrs      = cs_dado-bukrs
          gjahr      = year_from_csv_date( cs_dado-data )
          created_at = lv_timestamp ) ).

        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            wait = abap_true.

        cs_dado-is_posted = abap_true.
        cs_dado-documento = lv_documento.

      CATCH zcx_assist_process cx_root INTO DATA(lx_error).
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
        cs_dado-message = |Erro inesperado ao lançar documento FI: { lx_error->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD next_document_number.
    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr = c_nr_range_nr
        object      = c_nr_object
        subobject   = c_nr_subobject
        toyear      = year_from_csv_date( iv_date_raw )
      IMPORTING
        number      = rv_number
      EXCEPTIONS
        OTHERS      = 1.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_assist_process
        EXPORTING
          textid      = zcx_assist_process=>number_range_error
          iv_nr_range = c_nr_range_nr.
    ENDIF.
  ENDMETHOD.

  METHOD build_header.
    rs_header = VALUE bapiache09(
      doc_type   = c_doc_type
      comp_code  = is_dado-bukrs
      obj_type   = c_obj_type
      username   = sy-uname
      obj_key    = iv_documento
      obj_sys    = c_obj_sys
      bus_act    = c_bus_act
      fisc_year  = year_from_csv_date( is_dado-data )
      fis_period = period_from_csv_date( is_dado-data )
      ref_doc_no = is_dado-referencia
      doc_date   = csv_date_to_sap( is_dado-doc_dat )
      pstng_date = csv_date_to_sap( is_dado-data )
      header_txt = |Assistência Médica - { iv_documento }| ).
  ENDMETHOD.

  METHOD build_gl_line.
    rt_gl = VALUE #( ( itemno_acc = '0000000001'
                       gl_account = is_dado-conta
                       item_text  = 'Assistência Médica HCB'
                       comp_code  = is_dado-bukrs
                       fis_period = period_from_csv_date( is_dado-data )
                       fisc_year  = year_from_csv_date( is_dado-data )
                       pstng_date = csv_date_to_sap( is_dado-data )
                       costcenter = is_dado-centro_custo ) ).
  ENDMETHOD.

  METHOD build_payable_lines.
    " Regra de negocio actual (ZCL_MEDICAL_ASSIST_PROCESS, lida via MCP):
    " o colaborador tambem existe como fornecedor, com o PERNR convertido
    " para o formato de numero de fornecedor.
    DATA vendor_no TYPE lfa1-lifnr.
    UNPACK is_dado-pernr TO vendor_no.

    rt_payable = VALUE #(
      ( itemno_acc = '0000000002'
        vendor_no  = vendor_no
        comp_code  = is_dado-bukrs
        sp_gl_ind  = c_sp_gl_ind
        alloc_nmbr = c_alloc_nmbr
        item_text  = |Débito Colaborador { is_dado-pernr }| )
      ( itemno_acc = '0000000003'
        vendor_no  = c_hcb_vendor
        comp_code  = is_dado-bukrs
        alloc_nmbr = c_alloc_nmbr
        item_text  = 'Clínica HCB — Débito Total' ) ).
  ENDMETHOD.

  METHOD build_amounts.
    DATA(lv_total) = is_dado-val_hcb + is_dado-valor.

    rt_amounts = VALUE #(
      ( itemno_acc = '0000000001' currency = is_dado-waers amt_doccur =   is_dado-val_hcb )
      ( itemno_acc = '0000000002' currency = is_dado-waers amt_doccur =   is_dado-valor   )
      ( itemno_acc = '0000000003' currency = is_dado-waers amt_doccur = - lv_total        ) ).
  ENDMETHOD.

  METHOD build_extension.
    rt_extension = VALUE #(
      ( structure = 'POSTING_KEY' valuepart1 = '0000000001' valuepart2 = '40' )
      ( structure = 'POSTING_KEY' valuepart1 = '0000000002' valuepart2 = '29' )
      ( structure = 'POSTING_KEY' valuepart1 = '0000000003' valuepart2 = '31' ) ).
  ENDMETHOD.

  METHOD csv_date_to_sap.
    CHECK strlen( iv_date_raw ) = 8.
    rv_date = iv_date_raw+4(4) && iv_date_raw+2(2) && iv_date_raw(2).
  ENDMETHOD.

  METHOD year_from_csv_date.
    CHECK strlen( iv_date_raw ) = 8.
    rv_year = iv_date_raw+4(4).
  ENDMETHOD.

  METHOD period_from_csv_date.
    CHECK strlen( iv_date_raw ) = 8.
    rv_per = iv_date_raw+2(2).
  ENDMETHOD.

ENDCLASS.

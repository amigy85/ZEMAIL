REPORT zrp_assist_medic.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE tb1.

SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(28) tc_front FOR FIELD p_front.
PARAMETERS p_front RADIOBUTTON GROUP orig DEFAULT 'X'.
SELECTION-SCREEN COMMENT 32(28) tc_serv FOR FIELD p_serv.
PARAMETERS p_serv RADIOBUTTON GROUP orig.
SELECTION-SCREEN END OF LINE.

PARAMETERS p_file TYPE rlgrap-filename OBLIGATORY.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_teste AS CHECKBOX.
SELECTION-SCREEN COMMENT 4(60) tc_teste FOR FIELD p_teste.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_reenv AS CHECKBOX.
SELECTION-SCREEN COMMENT 4(60) tc_reenv FOR FIELD p_reenv.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b1.

INITIALIZATION.
  tb1      = 'Assistência Médica HCB'.
  tc_front = 'Ficheiro local (frontend)'.
  tc_serv  = 'Ficheiro no servidor'.
  tc_teste = 'Modo teste (só valida, não lança nem envia)'.
  tc_reenv = 'Reenviar apenas e-mails ainda sem sucesso'.


AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  DATA: lt_files TYPE filetable,
        lv_rc    TYPE i.

  cl_gui_frontend_services=>file_open_dialog(
    EXPORTING
      window_title      = 'Selecionar arquivo de dados'
      default_extension = 'txt'
      file_filter       = 'Arquivos TXT (*.txt)|*.txt|CSV (*.csv)|*.csv'
    CHANGING
      file_table        = lt_files
      rc                = lv_rc
    EXCEPTIONS
      OTHERS            = 1 ).

  IF sy-subrc = 0 AND lv_rc > 0.
    READ TABLE lt_files INTO p_file INDEX 1.
  ENDIF.


CLASS lcl_report DEFINITION.

  PUBLIC SECTION.

    METHODS run
      IMPORTING
        iv_frontend             TYPE abap_bool
        iv_file                 TYPE rlgrap-filename
        iv_modo_teste           TYPE abap_bool
        iv_so_reenviar_falhados TYPE abap_bool.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_alv_line.
        INCLUDE TYPE zcl_assist_medic_processor=>ty_result.
    TYPES:
        semaforo TYPE icon_d,
      END OF ty_alv_line.
    TYPES tt_alv_line TYPE STANDARD TABLE OF ty_alv_line WITH DEFAULT KEY.

    METHODS build_reader
      IMPORTING
        iv_frontend      TYPE abap_bool
      RETURNING
        VALUE(ro_reader) TYPE REF TO zif_assist_file_reader.

    METHODS display_alv
      IMPORTING
        it_result TYPE zcl_assist_medic_processor=>tt_result.

    METHODS format_columns
      IMPORTING
        io_columns TYPE REF TO cl_salv_columns_table.

    " ICON_LED_RED/YELLOW/GREEN — constantes standard do grupo de tipos
    " ICON, largamente usadas em semaforos ALV; nao confirmadas via MCP
    " nesta tarefa (falha de ligacao na consulta à tabela ICON) — a
    " confirmar se o semaforo nao aparecer correctamente.
    METHODS status_icon
      IMPORTING
        iv_status      TYPE string
      RETURNING
        VALUE(rv_icon) TYPE icon_d.

ENDCLASS.


CLASS lcl_report IMPLEMENTATION.

  METHOD run.
    " sy-batch forca sempre o leitor de servidor, independentemente da
    " selecao no ecra — um job em background nao tem frontend GUI
    " (GUI_UPLOAD dispararia NO_BATCH).
    DATA(lv_frontend) = COND abap_bool( WHEN sy-batch = abap_true THEN abap_false ELSE iv_frontend ).

    DATA(lo_processor) = NEW zcl_assist_medic_processor( build_reader( lv_frontend ) ).

    TRY.
        DATA(lt_result) = lo_processor->process(
          iv_file                 = CONV #( iv_file )
          iv_modo_teste           = iv_modo_teste
          iv_so_reenviar_falhados = iv_so_reenviar_falhados ).

        display_alv( lt_result ).

      CATCH zcx_assist_process INTO DATA(lx_error).
        MESSAGE lx_error->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD build_reader.
    ro_reader = COND #(
      WHEN iv_frontend = abap_true THEN NEW zcl_file_reader_frontend( )
      ELSE NEW zcl_file_reader_server( ) ).
  ENDMETHOD.

  METHOD display_alv.
    DATA lt_alv TYPE tt_alv_line.

    LOOP AT it_result INTO DATA(ls_result).
      APPEND INITIAL LINE TO lt_alv ASSIGNING FIELD-SYMBOL(<ls_alv>).
      MOVE-CORRESPONDING ls_result TO <ls_alv>.
      <ls_alv>-semaforo = status_icon( ls_result-status ).
    ENDLOOP.

    IF lt_alv IS INITIAL.
      MESSAGE 'Nenhum registo para mostrar.' TYPE 'I'.
      RETURN.
    ENDIF.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = DATA(lo_alv)
          CHANGING  t_table      = lt_alv ).
      CATCH cx_salv_msg.
        MESSAGE 'Erro ao construir o ALV.' TYPE 'E'.
        RETURN.
    ENDTRY.

    TRY.
        lo_alv->get_columns( )->set_column_position( columnname = 'SEMAFORO' position = 1 ).

        " GET_COLUMN devolve TYPE REF TO CL_SALV_COLUMN (classe base, sem
        " SET_ICON) mesmo para um ALV em tabela, onde o objecto real
        " criado internamente e sempre CL_SALV_COLUMN_TABLE (confirmado
        " via MCP, metodo ADD_COLUMN de CL_SALV_COLUMNS) — precisa de
        " downcast explicito para aceder a SET_ICON (definido em
        " CL_SALV_COLUMN_LIST, superclasse de CL_SALV_COLUMN_TABLE).
        DATA(lo_column) = CAST cl_salv_column_table( lo_alv->get_columns( )->get_column( 'SEMAFORO' ) ).
        lo_column->set_icon( abap_true ).
        lo_column->set_short_text( ' ' ).
        lo_column->set_medium_text( ' ' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    format_columns( lo_alv->get_columns( ) ).

    lo_alv->get_functions( )->set_all( abap_true ).
    lo_alv->display( ).
  ENDMETHOD.

  METHOD format_columns.
    " STATUS/MENSAGEM sao STRING simples (sem elemento de dados) — sem
    " rotulo explicito, o SALV mostraria o nome tecnico do campo em vez
    " de um cabecalho legivel. BELNR (ZASSIST_DOCUMENTO) tem elemento de
    " dados mas sem rotulos de campo preenchidos em SE11 — definido aqui
    " tambem, para nao depender disso.
    io_columns->set_optimize( abap_true ).

    TRY.
        io_columns->get_column( 'PERNR' )->set_medium_text( 'Nº Pessoal' ).
        io_columns->get_column( 'NOME' )->set_medium_text( 'Nome' ).
        io_columns->get_column( 'BELNR' )->set_medium_text( 'Documento FI' ).
        io_columns->get_column( 'EMAIL' )->set_medium_text( 'E-mail' ).
        io_columns->get_column( 'STATUS' )->set_medium_text( 'Estado' ).
        io_columns->get_column( 'MENSAGEM' )->set_medium_text( 'Mensagem' ).
        io_columns->get_column( 'MENSAGEM' )->set_long_text( 'Mensagem / Detalhe' ).
      CATCH cx_salv_not_found.
    ENDTRY.
  ENDMETHOD.

  METHOD status_icon.
    rv_icon = SWITCH #( iv_status
      WHEN 'E-mail enviado'          THEN icon_led_green
      WHEN 'Erro no lançamento'      THEN icon_led_red
      WHEN 'Erro no envio de e-mail' THEN icon_led_red
      ELSE icon_led_yellow ).
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_report( )->run(
    iv_frontend             = p_front
    iv_file                 = p_file
    iv_modo_teste           = p_teste
    iv_so_reenviar_falhados = p_reenv ).

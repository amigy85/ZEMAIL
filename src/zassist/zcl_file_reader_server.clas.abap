CLASS zcl_file_reader_server DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_assist_file_reader.

  PRIVATE SECTION.

    " Conversao explicita campo-a-campo (nao MOVE implicito directo do
    " SPLIT) para que o comportamento numerico seja o mesmo, seja qual
    " for a forma como o SPLIT trata os operandos — mantém simetria com
    " o caminho GUI_UPLOAD (T4.x), que faz a mesma conversao internamente.
    METHODS split_line
      IMPORTING
        iv_line        TYPE string
      RETURNING
        VALUE(rs_dado) TYPE zassist_s_registo.

ENDCLASS.


CLASS zcl_file_reader_server IMPLEMENTATION.

  METHOD zif_assist_file_reader~read.
    OPEN DATASET iv_file FOR INPUT IN TEXT MODE ENCODING DEFAULT.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_assist_process
        EXPORTING
          textid      = zcx_assist_process=>file_read_error
          iv_filename = iv_file
          iv_detail   = |subrc { sy-subrc }|.
    ENDIF.

    DATA lv_line TYPE string.

    DO.
      READ DATASET iv_file INTO lv_line.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.

      CHECK lv_line IS NOT INITIAL.
      APPEND split_line( lv_line ) TO rt_dados.
    ENDDO.

    CLOSE DATASET iv_file.
  ENDMETHOD.

  METHOD split_line.
    SPLIT iv_line AT cl_abap_char_utilities=>horizontal_tab INTO
      DATA(lv_pernr) DATA(lv_nome) DATA(lv_natureza) DATA(lv_beneficiario)
      DATA(lv_conta) DATA(lv_centro_custo) DATA(lv_bukrs) DATA(lv_data)
      DATA(lv_doc_dat) DATA(lv_valor) DATA(lv_val_hcb) DATA(lv_debito)
      DATA(lv_documento) DATA(lv_referencia) DATA(lv_waers).

    rs_dado = VALUE zassist_s_registo(
      pernr        = CONV #( lv_pernr )
      nome         = lv_nome
      natureza     = lv_natureza
      beneficiario = lv_beneficiario
      conta        = CONV #( lv_conta )
      centro_custo = CONV #( lv_centro_custo )
      bukrs        = CONV #( lv_bukrs )
      data         = lv_data
      doc_dat      = lv_doc_dat
      valor        = CONV #( lv_valor )
      val_hcb      = CONV #( lv_val_hcb )
      debito       = CONV #( lv_debito )
      documento    = lv_documento
      referencia   = lv_referencia
      waers        = CONV #( lv_waers ) ).
  ENDMETHOD.

ENDCLASS.

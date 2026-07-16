CLASS zcl_file_reader_frontend DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_assist_file_reader.

ENDCLASS.


CLASS zcl_file_reader_frontend IMPLEMENTATION.

  METHOD zif_assist_file_reader~read.
    " Mesma chamada/parametros de ZCL_MEDICAL_ASSIST_PROCESS->upload_dados
    " (lida via MCP) — passar ZASSIST_T_REGISTO directamente a DATA_TAB
    " deixa o GUI_UPLOAD converter cada coluna de texto para o tipo do
    " campo da estrutura (tal como já acontece hoje em produção).
    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename                = CONV #( iv_file )
        filetype                = 'ASC'
        has_field_separator     = abap_true
      CHANGING
        data_tab                = rt_dados
      EXCEPTIONS
        file_open_error         = 1
        file_read_error         = 2
        no_batch                = 3
        gui_refuse_filetransfer = 4
        invalid_type            = 5
        no_authority            = 6
        OTHERS                  = 7 ).

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_assist_process
        EXPORTING
          textid      = zcx_assist_process=>file_read_error
          iv_filename = iv_file
          iv_detail   = |subrc { sy-subrc }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

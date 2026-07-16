INTERFACE zif_assist_file_reader
  PUBLIC.

  " Le o ficheiro CSV (separado por tabs) e devolve os registos tal como
  " estao no ficheiro — sem validar nem normalizar (isso e feito por
  " ZCL_ASSIST_VALIDATOR e pelo orquestrador, T5.4/T5.7).
  METHODS read
    IMPORTING
      iv_file         TYPE string
    RETURNING
      VALUE(rt_dados) TYPE zassist_t_registo
    RAISING
      zcx_assist_process.

ENDINTERFACE.

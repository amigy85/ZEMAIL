INTERFACE zif_assist_run_repository
  PUBLIC.

  " Camada de dados injectavel para ZASSIST_RUN — mesma razao da
  " ZIF_TEMPLATE_REPOSITORY em ZEMAIL (T3.2): permite testar
  " ZCL_ASSIST_FI_POSTER/ZCL_ASSIST_NOTIF_BUILDER com um duplo, sem tocar
  " na BD real nem recorrer a LOCAL FRIENDS.
  METHODS find
    IMPORTING
      iv_referencia TYPE zassist_referencia
      iv_pernr      TYPE pernr_d
    RETURNING
      VALUE(rs_run) TYPE zassist_run.

  METHODS insert
    IMPORTING
      is_run TYPE zassist_run.

  METHODS update_email_status
    IMPORTING
      iv_referencia TYPE zassist_referencia
      iv_pernr      TYPE pernr_d
      iv_status     TYPE zassist_email_status.

ENDINTERFACE.

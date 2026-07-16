CLASS zcl_assist_run_repository_db DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_assist_run_repository.

ENDCLASS.


CLASS zcl_assist_run_repository_db IMPLEMENTATION.

  METHOD zif_assist_run_repository~find.
    SELECT SINGLE * FROM zassist_run
      WHERE referencia = @iv_referencia
        AND pernr      = @iv_pernr
      INTO @rs_run.
  ENDMETHOD.

  METHOD zif_assist_run_repository~insert.
    INSERT zassist_run FROM is_run.
  ENDMETHOD.

  METHOD zif_assist_run_repository~update_email_status.
    UPDATE zassist_run
      SET email_status = iv_status
      WHERE referencia = iv_referencia
        AND pernr      = iv_pernr.
  ENDMETHOD.

ENDCLASS.

INTERFACE zif_logger
  PUBLIC.

  METHODS info
    IMPORTING
      iv_text TYPE string.

  METHODS warning
    IMPORTING
      iv_text TYPE string.

  METHODS error
    IMPORTING
      iv_text TYPE string OPTIONAL
      ix_exc  TYPE REF TO cx_root OPTIONAL.

  METHODS save.

ENDINTERFACE.

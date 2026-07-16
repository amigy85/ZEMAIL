CLASS zcx_assist_process DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_t100_message.

    CONSTANTS:
      BEGIN OF unexpected_error,
        msgid TYPE symsgid VALUE 'ZASSIST',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE 'MV_DETAIL',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF unexpected_error,

      BEGIN OF file_read_error,
        msgid TYPE symsgid VALUE 'ZASSIST',
        msgno TYPE symsgno VALUE '010',
        attr1 TYPE scx_attrname VALUE 'MV_FILENAME',
        attr2 TYPE scx_attrname VALUE 'MV_DETAIL',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF file_read_error,

      BEGIN OF number_range_error,
        msgid TYPE symsgid VALUE 'ZASSIST',
        msgno TYPE symsgno VALUE '011',
        attr1 TYPE scx_attrname VALUE 'MV_NR_RANGE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF number_range_error,

      BEGIN OF duplicate_run,
        msgid TYPE symsgid VALUE 'ZASSIST',
        msgno TYPE symsgno VALUE '012',
        attr1 TYPE scx_attrname VALUE 'MV_REFERENCIA',
        attr2 TYPE scx_attrname VALUE 'MV_PERNR',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF duplicate_run,

      BEGIN OF fi_posting_error,
        msgid TYPE symsgid VALUE 'ZASSIST',
        msgno TYPE symsgno VALUE '013',
        attr1 TYPE scx_attrname VALUE 'MV_PERNR',
        attr2 TYPE scx_attrname VALUE 'MV_DETAIL',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF fi_posting_error.

    DATA mv_filename   TYPE string     READ-ONLY.
    DATA mv_nr_range   TYPE inri-nrrangenr READ-ONLY.
    DATA mv_referencia TYPE zassist_referencia READ-ONLY.
    DATA mv_pernr      TYPE pernr_d    READ-ONLY.
    DATA mv_detail     TYPE string     READ-ONLY.

    METHODS constructor
      IMPORTING
        textid         LIKE if_t100_message=>t100key OPTIONAL
        previous       LIKE previous OPTIONAL
        iv_filename    TYPE string OPTIONAL
        iv_nr_range    TYPE inri-nrrangenr OPTIONAL
        iv_referencia  TYPE zassist_referencia OPTIONAL
        iv_pernr       TYPE pernr_d OPTIONAL
        iv_detail      TYPE string OPTIONAL.

ENDCLASS.


CLASS zcx_assist_process IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).

    mv_filename   = iv_filename.
    mv_nr_range   = iv_nr_range.
    mv_referencia = iv_referencia.
    mv_pernr      = iv_pernr.
    mv_detail     = iv_detail.

    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS zcx_email_send DEFINITION
  PUBLIC
  INHERITING FROM zcx_email
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF invalid_recipient,
        msgid TYPE symsgid VALUE 'ZEMAIL',
        msgno TYPE symsgno VALUE '020',
        attr1 TYPE scx_attrname VALUE 'MV_RECIPIENT',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF invalid_recipient,

      BEGIN OF bcs_error,
        msgid TYPE symsgid VALUE 'ZEMAIL',
        msgno TYPE symsgno VALUE '021',
        attr1 TYPE scx_attrname VALUE 'MV_DETAIL',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bcs_error,

      BEGIN OF attachment_error,
        msgid TYPE symsgid VALUE 'ZEMAIL',
        msgno TYPE symsgno VALUE '022',
        attr1 TYPE scx_attrname VALUE 'MV_CONTENT_ID',
        attr2 TYPE scx_attrname VALUE 'MV_DETAIL',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF attachment_error.

    DATA mv_recipient  TYPE ad_smtpadr READ-ONLY.
    " CHAR livre em vez de ZEMAIL_CONTENT_ID: esse dominio so sera criado em
    " T3.5, junto com ZEMAIL_S_ATTACHMENT (decisao do utilizador, Fase 1).
    DATA mv_content_id TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        textid        LIKE if_t100_message=>t100key OPTIONAL
        previous      LIKE previous OPTIONAL
        iv_recipient  TYPE ad_smtpadr OPTIONAL
        iv_content_id TYPE string OPTIONAL
        iv_detail     TYPE string OPTIONAL.

ENDCLASS.


CLASS zcx_email_send IMPLEMENTATION.

  METHOD constructor.
    super->constructor(
      textid    = textid
      previous  = previous
      iv_detail = iv_detail ).

    mv_recipient  = iv_recipient.
    mv_content_id = iv_content_id.
  ENDMETHOD.

ENDCLASS.

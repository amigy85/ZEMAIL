CLASS zcx_template DEFINITION
  PUBLIC
  INHERITING FROM zcx_email
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF not_found,
        msgid TYPE symsgid VALUE 'ZEMAIL',
        msgno TYPE symsgno VALUE '010',
        attr1 TYPE scx_attrname VALUE 'MV_TEMPLATE_ID',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF not_found,

      BEGIN OF invalid_content,
        msgid TYPE symsgid VALUE 'ZEMAIL',
        msgno TYPE symsgno VALUE '011',
        attr1 TYPE scx_attrname VALUE 'MV_TEMPLATE_ID',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF invalid_content,

      BEGIN OF unresolved_placeholder,
        msgid TYPE symsgid VALUE 'ZEMAIL',
        msgno TYPE symsgno VALUE '012',
        attr1 TYPE scx_attrname VALUE 'MV_TEMPLATE_ID',
        attr2 TYPE scx_attrname VALUE 'MV_PLACEHOLDER',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF unresolved_placeholder.

    DATA mv_template_id TYPE zemail_template_id READ-ONLY.
    DATA mv_placeholder  TYPE zemail_placeholder_name READ-ONLY.

    METHODS constructor
      IMPORTING
        textid         LIKE if_t100_message=>t100key OPTIONAL
        previous       LIKE previous OPTIONAL
        iv_template_id TYPE zemail_template_id OPTIONAL
        iv_placeholder TYPE zemail_placeholder_name OPTIONAL.

ENDCLASS.


CLASS zcx_template IMPLEMENTATION.

  METHOD constructor.
    super->constructor(
      textid   = textid
      previous = previous ).

    mv_template_id = iv_template_id.
    mv_placeholder = iv_placeholder.
  ENDMETHOD.

ENDCLASS.

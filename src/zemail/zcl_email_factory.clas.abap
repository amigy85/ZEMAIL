CLASS zcl_email_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Composição por omissão do framework ZEMAIL: provider DB + serviço de
    " placeholders + engine + renderer + emissor BCS + logger BAL, ligados
    " pelos parâmetros de ZEMAIL_CONFIG. Único ponto do framework que lê
    " ZEMAIL_CONFIG (regra "composição só na factory").
    CLASS-METHODS create_notification_service
      RETURNING
        VALUE(ri_service) TYPE REF TO zif_email_service.

  PRIVATE SECTION.

    TYPES tt_config TYPE HASHED TABLE OF zemail_config WITH UNIQUE KEY param.

    CLASS-METHODS read_config
      RETURNING
        VALUE(rt_config) TYPE tt_config.

    CLASS-METHODS get_value
      IMPORTING
        it_config       TYPE tt_config
        iv_param        TYPE zemail_config_param
      RETURNING
        VALUE(rv_valor) TYPE zemail_config_valor.

ENDCLASS.


CLASS zcl_email_factory IMPLEMENTATION.

  METHOD create_notification_service.
    DATA(lt_config) = read_config( ).

    DATA(lo_provider) = NEW zcl_template_provider_db(
      iv_fallback_langu = CONV #( get_value(
        it_config = lt_config
        iv_param  = zif_email_const=>config_param-fallback_langu ) ) ).

    DATA(lo_placeholder) = NEW zcl_placeholder_service(
      iv_strict_mode = xsdbool( get_value(
        it_config = lt_config
        iv_param  = zif_email_const=>config_param-strict_mode ) = abap_true ) ).

    DATA(lo_engine) = NEW zcl_template_engine(
      io_provider            = lo_provider
      io_placeholder_service = lo_placeholder ).

    DATA(lo_renderer) = NEW zcl_email_renderer( ).

    DATA(lo_logger) = NEW zcl_logger_bal(
      iv_object    = CONV #( get_value(
        it_config = lt_config
        iv_param  = zif_email_const=>config_param-bal_object ) )
      iv_subobject = CONV #( get_value(
        it_config = lt_config
        iv_param  = zif_email_const=>config_param-bal_subobject ) )
      iv_extnumber = |Run { sy-datum } { sy-uzeit } { sy-uname }| ).

    DATA(lo_sender) = NEW zcl_email_sender_bcs(
      iv_sender_address = CONV #( get_value(
        it_config = lt_config
        iv_param  = zif_email_const=>config_param-sender_address ) ) ).

    ri_service = NEW zcl_notification_service(
      io_engine   = lo_engine
      io_renderer = lo_renderer
      io_sender   = lo_sender
      io_logger   = lo_logger ).
  ENDMETHOD.

  METHOD read_config.
    SELECT * FROM zemail_config INTO TABLE @rt_config.
  ENDMETHOD.

  METHOD get_value.
    READ TABLE it_config WITH TABLE KEY param = iv_param INTO DATA(ls_config).
    IF sy-subrc = 0.
      rv_valor = ls_config-valor.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

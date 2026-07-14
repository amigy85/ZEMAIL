CLASS zcl_notification_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_email_service.

    " IT_IMAGES: imagens inline (ex.: logo HCB) resolvidas em TODOS os
    " e-mails enviados por esta instância — decidido por quem compõe o
    " serviço (ZCL_EMAIL_FACTORY, T3.8), não fixo nesta classe.
    METHODS constructor
      IMPORTING
        io_engine   TYPE REF TO zcl_template_engine
        io_renderer TYPE REF TO zcl_email_renderer
        io_sender   TYPE REF TO zif_email_sender
        io_logger   TYPE REF TO zif_logger
        it_images   TYPE zcl_email_renderer=>tt_image_map OPTIONAL.

  PRIVATE SECTION.

    DATA mo_engine   TYPE REF TO zcl_template_engine.
    DATA mo_renderer TYPE REF TO zcl_email_renderer.
    DATA mo_sender   TYPE REF TO zif_email_sender.
    DATA mo_logger   TYPE REF TO zif_logger.
    DATA mt_images   TYPE zcl_email_renderer=>tt_image_map.

ENDCLASS.


CLASS zcl_notification_service IMPLEMENTATION.

  METHOD constructor.
    mo_engine   = io_engine.
    mo_renderer = io_renderer.
    mo_sender   = io_sender.
    mo_logger   = io_logger.
    mt_images   = it_images.
  ENDMETHOD.

  METHOD zif_email_service~send.
    TRY.
        DATA(ls_message) = mo_engine->build(
          iv_template_id = iv_template_id
          iv_langu       = iv_langu
          it_values      = it_values
          it_tables      = it_tables ).

        ls_message-recipients = it_recipients.

        IF mt_images IS NOT INITIAL.
          ls_message-attachments = mo_renderer->resolve_inline_images( mt_images ).
        ENDIF.

        rs_result-send_id = mo_sender->send( ls_message ).
        rs_result-status  = zif_email_const=>send_status-success.
        rs_result-message = |E-mail enfileirado para { lines( it_recipients ) } destinatario(s).|.

        mo_logger->info( |Template { iv_template_id }: { rs_result-message }| ).

      CATCH zcx_email INTO DATA(lx_email).
        mo_logger->error(
          iv_text = |Falha ao enviar e-mail (template { iv_template_id })|
          ix_exc  = lx_email ).
        RAISE EXCEPTION lx_email.

      CATCH cx_root INTO DATA(lx_root).
        mo_logger->error(
          iv_text = |Erro inesperado ao enviar e-mail (template { iv_template_id })|
          ix_exc  = lx_root ).
        RAISE EXCEPTION TYPE zcx_email
          EXPORTING
            textid    = zcx_email=>unexpected_error
            iv_detail = lx_root->get_text( )
            previous  = lx_root.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

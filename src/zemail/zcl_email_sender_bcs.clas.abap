CLASS zcl_email_sender_bcs DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_email_sender.

    " IV_SENDER_ADDRESS vem de ZEMAIL_CONFIG-SENDER_ADDRESS, resolvido pelo
    " chamador (ZCL_EMAIL_FACTORY, T3.8) — esta classe nao le ZEMAIL_CONFIG.
    " Usado só quando IS_MESSAGE-SENDER (T2.6) vier vazio.
    METHODS constructor
      IMPORTING
        iv_sender_address TYPE ad_smtpadr.

  PRIVATE SECTION.

    DATA mv_sender_address TYPE ad_smtpadr.

    METHODS build_document
      IMPORTING
        is_message         TYPE zemail_s_message
      RETURNING
        VALUE(ro_document) TYPE REF TO cl_document_bcs
      RAISING
        zcx_email_send.

    " Anexa cada imagem inline com um cabeçalho &BCS_CID=<content_id>,
    " tecnica confirmada no fonte de CL_DOCUMENT_BCS (uso interno de
    " CP_CID) para permitir referencias <img src="cid:..."> no HTML.
    METHODS add_inline_attachments
      IMPORTING
        io_document    TYPE REF TO cl_document_bcs
        it_attachments TYPE zemail_t_attachment
      RAISING
        zcx_email_send.

    METHODS add_recipients
      IMPORTING
        io_request    TYPE REF TO cl_bcs
        it_recipients TYPE zemail_t_recipient
      RAISING
        zcx_email_send.

ENDCLASS.


CLASS zcl_email_sender_bcs IMPLEMENTATION.

  METHOD constructor.
    mv_sender_address = iv_sender_address.
  ENDMETHOD.

  METHOD zif_email_sender~send.
    DATA(lo_document) = build_document( is_message ).
    add_inline_attachments( io_document = lo_document it_attachments = is_message-attachments ).

    TRY.
        DATA(lo_request) = cl_bcs=>create_persistent( ).
        lo_request->set_document( lo_document ).

        add_recipients( io_request = lo_request it_recipients = is_message-recipients ).

        DATA(lv_sender) = COND ad_smtpadr(
          WHEN is_message-sender IS NOT INITIAL THEN is_message-sender ELSE mv_sender_address ).
        lo_request->set_sender( cl_cam_address_bcs=>create_internet_address( lv_sender ) ).

        lo_request->set_send_immediately( abap_false ).
        lo_request->send( i_with_error_screen = abap_false ).

        rv_send_id = lo_request->oid( ).

      CATCH cx_send_req_bcs cx_address_bcs INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_email_send
          EXPORTING
            textid    = zcx_email_send=>bcs_error
            iv_detail = lx_error->get_text( )
            previous  = lx_error.
    ENDTRY.
  ENDMETHOD.

  METHOD build_document.
    DATA(lt_body) = cl_bcs_convert=>string_to_soli( is_message-body_html ).

    TRY.
        ro_document = cl_document_bcs=>create_document(
          i_type    = 'HTM'
          i_subject = CONV so_obj_des( is_message-subject )
          i_text    = lt_body ).
      CATCH cx_document_bcs INTO DATA(lx_doc).
        RAISE EXCEPTION TYPE zcx_email_send
          EXPORTING
            textid    = zcx_email_send=>bcs_error
            iv_detail = lx_doc->get_text( )
            previous  = lx_doc.
    ENDTRY.
  ENDMETHOD.

  METHOD add_inline_attachments.
    LOOP AT it_attachments INTO DATA(ls_attachment).
      DATA(lo_header) = cl_bcs_objhead=>create( ).
      lo_header->set_conttype( ls_attachment-mimetype ).
      APPEND VALUE soli( line = cl_document_bcs=>cp_cid && ls_attachment-content_id )
        TO lo_header->mt_objhead.

      TRY.
          io_document->add_attachment(
            i_attachment_type    = 'BIN'
            i_attachment_subject = CONV #( ls_attachment-content_id )
            i_att_content_hex    = cl_bcs_convert=>xstring_to_solix( ls_attachment-content )
            i_attachment_header  = lo_header->mt_objhead ).
        CATCH cx_document_bcs INTO DATA(lx_doc).
          RAISE EXCEPTION TYPE zcx_email_send
            EXPORTING
              textid        = zcx_email_send=>attachment_error
              iv_content_id = CONV #( ls_attachment-content_id )
              iv_detail     = lx_doc->get_text( )
              previous      = lx_doc.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD add_recipients.
    LOOP AT it_recipients INTO DATA(ls_recipient).
      TRY.
          DATA(lo_address) = cl_cam_address_bcs=>create_internet_address(
            i_address_string = ls_recipient-address
            i_address_name   = ls_recipient-visible_name ).

          io_request->add_recipient(
            i_recipient  = lo_address
            i_copy       = xsdbool( ls_recipient-recipient_type = zif_email_const=>recipient_type-cc )
            i_blind_copy = xsdbool( ls_recipient-recipient_type = zif_email_const=>recipient_type-bcc ) ).

        CATCH cx_address_bcs cx_send_req_bcs INTO DATA(lx_error).
          RAISE EXCEPTION TYPE zcx_email_send
            EXPORTING
              textid       = zcx_email_send=>invalid_recipient
              iv_recipient = ls_recipient-address
              previous     = lx_error.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

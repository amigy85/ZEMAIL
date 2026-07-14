CLASS zcl_email_renderer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_image_map,
        content_id TYPE zemail_content_id,
        mime_path  TYPE string,
      END OF ty_image_map,
      tt_image_map TYPE STANDARD TABLE OF ty_image_map WITH DEFAULT KEY.

    " Le cada imagem indicada em IT_IMAGES do MIME Repository (caminho
    " configuravel por entrada — ex.: content_id = 'logo_hcb', mime_path =
    " '/SAP/PUBLIC/ZHCB/logo_hcb.png' — decidido pelo chamador, nao fixo
    " nesta classe) e devolve a lista de anexos inline prontos para
    " ZIF_EMAIL_SENDER (via ZEMAIL_S_MESSAGE-ATTACHMENTS).
    METHODS resolve_inline_images
      IMPORTING
        it_images             TYPE tt_image_map
      RETURNING
        VALUE(rt_attachments) TYPE zemail_t_attachment
      RAISING
        zcx_email_send.

  PRIVATE SECTION.

    METHODS read_mime
      IMPORTING
        iv_content_id        TYPE zemail_content_id
        iv_mime_path         TYPE string
      RETURNING
        VALUE(rs_attachment) TYPE zemail_s_attachment
      RAISING
        zcx_email_send.

ENDCLASS.


CLASS zcl_email_renderer IMPLEMENTATION.

  METHOD resolve_inline_images.
    LOOP AT it_images INTO DATA(ls_image).
      APPEND read_mime( iv_content_id = ls_image-content_id iv_mime_path = ls_image-mime_path )
        TO rt_attachments.
    ENDLOOP.
  ENDMETHOD.

  METHOD read_mime.
    DATA(lo_api) = cl_mime_repository_api=>get_api( ).
    DATA lv_content  TYPE xstring.
    DATA lv_mimetype TYPE w3conttype.

    lo_api->get(
      EXPORTING
        i_url              = iv_mime_path
      IMPORTING
        e_content          = lv_content
        e_mime_type        = lv_mimetype
      EXCEPTIONS
        parameter_missing  = 1
        error_occured      = 2
        not_found          = 3
        permission_failure = 4
        OTHERS             = 5 ).

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_email_send
        EXPORTING
          textid        = zcx_email_send=>attachment_error
          iv_content_id = CONV #( iv_content_id )
          iv_detail     = |MIME Repository, subrc { sy-subrc }: { iv_mime_path }|.
    ENDIF.

    rs_attachment-content_id = iv_content_id.
    rs_attachment-content    = lv_content.
    rs_attachment-mimetype   = lv_mimetype.
  ENDMETHOD.

ENDCLASS.

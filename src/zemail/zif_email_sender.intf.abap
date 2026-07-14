INTERFACE zif_email_sender
  PUBLIC.

  METHODS send
    IMPORTING
      is_message        TYPE zemail_s_message
    RETURNING
      VALUE(rv_send_id) TYPE sysuuid_x
    RAISING
      zcx_email_send.

ENDINTERFACE.

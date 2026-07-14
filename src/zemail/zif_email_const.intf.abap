INTERFACE zif_email_const
  PUBLIC.

  CONSTANTS:
    " Estados de versão de conteúdo (ZEMAIL_TMPL_CNT-ESTADO)
    BEGIN OF version_status,
      draft    TYPE zemail_estado_versao VALUE 'R',
      active   TYPE zemail_estado_versao VALUE 'A',
      obsolete TYPE zemail_estado_versao VALUE 'O',
    END OF version_status,

    " Tipos de destinatário (ZEMAIL_S_RECIPIENT-RECIPIENT_TYPE)
    BEGIN OF recipient_type,
      to_addr TYPE zemail_recipient_type VALUE 'TO',
      cc      TYPE zemail_recipient_type VALUE 'CC',
      bcc     TYPE zemail_recipient_type VALUE 'BCC',
    END OF recipient_type,

    " Formatos de placeholder (ZEMAIL_S_PLACEHOLDER-FORMAT)
    BEGIN OF placeholder_format,
      plain    TYPE zemail_placeholder_format VALUE ' ',
      date     TYPE zemail_placeholder_format VALUE 'D',
      currency TYPE zemail_placeholder_format VALUE 'C',
    END OF placeholder_format,

    " Estados de envio (ZEMAIL_S_SEND_RESULT-STATUS)
    BEGIN OF send_status,
      success TYPE zemail_estado_envio VALUE 'S',
      error   TYPE zemail_estado_envio VALUE 'E',
    END OF send_status.

ENDINTERFACE.

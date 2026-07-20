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
    " HTML: valor ja e HTML construido (ex.: linhas <tr>...</tr>) — nunca
    " escapado, ao contrario de PLAIN/DATE/CURRENCY (texto de negocio,
    " sempre escapado por omissao contra injeccao de HTML).
    BEGIN OF placeholder_format,
      plain    TYPE zemail_placeholder_format VALUE ' ',
      date     TYPE zemail_placeholder_format VALUE 'D',
      currency TYPE zemail_placeholder_format VALUE 'C',
      html     TYPE zemail_placeholder_format VALUE 'H',
    END OF placeholder_format,

    " Estados de envio (ZEMAIL_S_SEND_RESULT-STATUS)
    BEGIN OF send_status,
      success TYPE zemail_estado_envio VALUE 'S',
      error   TYPE zemail_estado_envio VALUE 'E',
    END OF send_status,

    " Nomes dos parametros de ZEMAIL_CONFIG (usado só por ZCL_EMAIL_FACTORY,
    " T3.8 — único ponto do framework que lê ZEMAIL_CONFIG). BAL_SUBOBJECT
    " é um parametro novo, adicionado agora (nao fazia parte da lista
    " original de T1.3) porque ZEMAIL_CONFIG so tinha BAL_OBJECT e o logger
    " precisa tambem de um subobjecto BAL.
    BEGIN OF config_param,
      sender_address TYPE zemail_config_param VALUE 'SENDER_ADDRESS',
      fallback_langu TYPE zemail_config_param VALUE 'FALLBACK_LANGU',
      strict_mode    TYPE zemail_config_param VALUE 'STRICT_MODE',
      bal_object     TYPE zemail_config_param VALUE 'BAL_OBJECT',
      bal_subobject  TYPE zemail_config_param VALUE 'BAL_SUBOBJECT',
      pa0105_subtype TYPE zemail_config_param VALUE 'PA0105_SUBTYPE',
    END OF config_param.

ENDINTERFACE.

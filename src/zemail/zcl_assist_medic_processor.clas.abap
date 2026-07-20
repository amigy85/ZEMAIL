CLASS zcl_assist_medic_processor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_result,
        pernr    TYPE pernr_d,
        nome     TYPE ad_name1,
        belnr    TYPE zassist_documento,
        email    TYPE ad_smtpadr,
        status   TYPE string,
        mensagem TYPE string,
      END OF ty_result,
      tt_result TYPE STANDARD TABLE OF ty_result WITH DEFAULT KEY.

    " IO_READER e escolhido pelo chamador (frontend/servidor, T5.8 —
    " ZIF_ASSIST_FILE_READER, T5.3); todos os restantes colaboradores sao
    " compostos internamente — unico ponto do pacote ZASSIST que le
    " ZEMAIL_CONFIG (PA0105_SUBTYPE) e ZCL_EMAIL_FACTORY, mesma regra
    " "composicao so na factory" que ZCL_EMAIL_FACTORY ja segue em ZEMAIL.
    METHODS constructor
      IMPORTING
        io_reader TYPE REF TO zif_assist_file_reader.

    " Executa o pipeline completo: ler -> default de moeda -> validar ->
    " lancar FI -> notificar por e-mail. IV_MODO_TESTE termina logo apos a
    " validacao (nunca lanca nem envia). IV_SO_REENVIAR_FALHADOS restringe
    " a notificacao aos colaboradores cujo ZASSIST_RUN-EMAIL_STATUS ainda
    " nao seja 'sucesso' (permite reenviar sem relancar o FI, que o
    " ZCL_ASSIST_FI_POSTER ja trata de forma idempotente).
    METHODS process
      IMPORTING
        iv_file                 TYPE string
        iv_modo_teste           TYPE abap_bool DEFAULT abap_false
        iv_so_reenviar_falhados TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rt_result)        TYPE tt_result
      RAISING
        zcx_assist_process.

  PRIVATE SECTION.

    CONSTANTS c_bal_object    TYPE balobj_d  VALUE 'ZDEBIT_NOTE'.
    CONSTANTS c_bal_subobject TYPE balsubobj VALUE 'FI_POST'.

    " Logo HCB embutido inline via CID (T3.5/T3.6, ZCL_EMAIL_RENDERER/
    " ZCL_EMAIL_SENDER_BCS) — caminho no MIME Repository carregado
    " manualmente pelo utilizador via SE80 (Claude Code nao escreve no SAP).
    CONSTANTS c_logo_content_id TYPE zemail_content_id VALUE 'logo_hcb'.
    CONSTANTS c_logo_mime_path  TYPE string VALUE '/SAP/PUBLIC/ZHCB/logo_hcb.png'.

    DATA mo_reader        TYPE REF TO zif_assist_file_reader.
    DATA mo_validator      TYPE REF TO zcl_assist_validator.
    DATA mo_poster         TYPE REF TO zcl_assist_fi_poster.
    DATA mo_notif_builder  TYPE REF TO zcl_assist_notif_builder.
    DATA mo_run_repository TYPE REF TO zif_assist_run_repository.
    DATA mo_logger         TYPE REF TO zif_logger.

    METHODS read_pa0105_subtype
      RETURNING
        VALUE(rv_subtype) TYPE subty.

    METHODS default_currency
      CHANGING
        ct_dados TYPE zassist_t_registo.

    METHODS filter_ja_enviados
      IMPORTING
        it_dados        TYPE zassist_t_registo
      RETURNING
        VALUE(rt_dados) TYPE zassist_t_registo.

    METHODS build_result
      IMPORTING
        it_dados          TYPE zassist_t_registo
        it_email_results  TYPE zcl_assist_notif_builder=>tt_result
      RETURNING
        VALUE(rt_result)  TYPE tt_result.

    METHODS determine_status
      IMPORTING
        is_dado          TYPE zassist_s_registo
        is_email         TYPE zcl_assist_notif_builder=>ty_result
      RETURNING
        VALUE(rv_status) TYPE string.

ENDCLASS.


CLASS zcl_assist_medic_processor IMPLEMENTATION.

  METHOD constructor.
    mo_reader    = io_reader.
    mo_validator = NEW zcl_assist_validator( ).

    DATA(lo_run_repository) = NEW zcl_assist_run_repository_db( ).
    mo_run_repository = lo_run_repository.

    mo_poster = NEW zcl_assist_fi_poster( io_run_repository = lo_run_repository ).

    mo_notif_builder = NEW zcl_assist_notif_builder(
      io_email_service  = zcl_email_factory=>create_notification_service(
        it_images = VALUE #( ( content_id = c_logo_content_id mime_path = c_logo_mime_path ) ) )
      io_run_repository = lo_run_repository
      iv_pa0105_subtype = read_pa0105_subtype( ) ).

    mo_logger = NEW zcl_logger_bal(
      iv_object    = c_bal_object
      iv_subobject = c_bal_subobject
      iv_extnumber = |Run { sy-datum } { sy-uzeit } { sy-uname }| ).
  ENDMETHOD.

  METHOD process.
    DATA(lt_dados) = mo_reader->read( iv_file ).
    mo_logger->info( |{ lines( lt_dados ) } registo(s) carregado(s) de '{ iv_file }'.| ).

    default_currency( CHANGING ct_dados = lt_dados ).

    mo_validator->validate( CHANGING ct_dados = lt_dados ).
    DATA(lv_validos) = 0.
    LOOP AT lt_dados TRANSPORTING NO FIELDS WHERE is_valid = abap_true.
      lv_validos = lv_validos + 1.
    ENDLOOP.
    mo_logger->info( |Validação: { lv_validos } válido(s), { lines( lt_dados ) - lv_validos } inválido(s).| ).

    IF iv_modo_teste = abap_true.
      rt_result = build_result( it_dados = lt_dados it_email_results = VALUE #( ) ).
      mo_logger->info( 'Modo teste: terminado após validação (sem lançamento nem envio).' ).
      mo_logger->save( ).
      RETURN.
    ENDIF.

    mo_poster->post( CHANGING ct_dados = lt_dados ).
    DATA(lv_postados) = 0.
    LOOP AT lt_dados TRANSPORTING NO FIELDS WHERE is_posted = abap_true.
      lv_postados = lv_postados + 1.
    ENDLOOP.
    mo_logger->info( |Lançamento FI: { lv_postados } documento(s) lançado(s) (novo ou já existente).| ).

    DATA(lt_para_notificar) = COND zassist_t_registo(
      WHEN iv_so_reenviar_falhados = abap_true THEN filter_ja_enviados( lt_dados )
      ELSE lt_dados ).

    DATA(lt_email_results) = mo_notif_builder->send_notifications( lt_para_notificar ).

    " COMMIT WORK e proibido dentro das classes do framework ZEMAIL
    " (responsabilidade do chamador, CLAUDE.md) — sem isto, a entrada do
    " pedido de envio BCS (fila SOST/SCOT) nunca fica persistida,
    " exigindo reprocessamento manual (mensagem SO672).
    COMMIT WORK.

    DATA(lv_enviados) = 0.
    LOOP AT lt_email_results TRANSPORTING NO FIELDS WHERE status = zif_email_const=>send_status-success.
      lv_enviados = lv_enviados + 1.
    ENDLOOP.
    mo_logger->info( |Notificação: { lv_enviados } e-mail(s) enviado(s) de { lines( lt_email_results ) } tentativa(s).| ).

    rt_result = build_result( it_dados = lt_dados it_email_results = lt_email_results ).

    mo_logger->save( ).
  ENDMETHOD.

  METHOD read_pa0105_subtype.
    SELECT SINGLE valor FROM zemail_config
      WHERE param = @zif_email_const=>config_param-pa0105_subtype
      INTO @DATA(lv_valor).

    rv_subtype = lv_valor.
  ENDMETHOD.

  METHOD default_currency.
    LOOP AT ct_dados ASSIGNING FIELD-SYMBOL(<ls_dado>) WHERE waers IS INITIAL.
      <ls_dado>-waers = 'MZN'.
    ENDLOOP.
  ENDMETHOD.

  METHOD filter_ja_enviados.
    LOOP AT it_dados INTO DATA(ls_dado) WHERE is_posted = abap_true.
      DATA(ls_run) = mo_run_repository->find(
        iv_referencia = ls_dado-referencia
        iv_pernr      = ls_dado-pernr ).

      CHECK ls_run-email_status <> zif_email_const=>send_status-success.

      APPEND ls_dado TO rt_dados.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_result.
    LOOP AT it_dados INTO DATA(ls_dado).
      DATA(ls_email) = VALUE zcl_assist_notif_builder=>ty_result( ).
      READ TABLE it_email_results INTO ls_email WITH KEY pernr = ls_dado-pernr.

      APPEND VALUE #(
        pernr    = ls_dado-pernr
        nome     = ls_dado-nome
        belnr    = ls_dado-documento
        email    = ls_email-email
        status   = determine_status( is_dado = ls_dado is_email = ls_email )
        mensagem = COND #( WHEN ls_email-message IS NOT INITIAL THEN ls_email-message ELSE ls_dado-message ) )
        TO rt_result.
    ENDLOOP.
  ENDMETHOD.

  METHOD determine_status.
    rv_status = COND #(
      WHEN is_dado-is_valid  = abap_false                                     THEN 'Inválido'
      WHEN is_dado-is_posted = abap_false                                     THEN 'Erro no lançamento'
      WHEN is_email-status   = zif_email_const=>send_status-success           THEN 'E-mail enviado'
      WHEN is_email-status   = zif_email_const=>send_status-error             THEN 'Erro no envio de e-mail'
      ELSE 'Lançado' ).
  ENDMETHOD.

ENDCLASS.

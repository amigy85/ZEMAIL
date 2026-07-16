CLASS ltc_assist_validator DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
  FINAL.

  PRIVATE SECTION.

    DATA mo_cut TYPE REF TO zcl_assist_validator.

    METHODS setup.

    METHODS registo_valido_passa           FOR TESTING RAISING cx_static_check.
    METHODS pernr_em_branco                FOR TESTING RAISING cx_static_check.
    METHODS valor_invalido                 FOR TESTING RAISING cx_static_check.
    METHODS conta_em_branco                FOR TESTING RAISING cx_static_check.
    METHODS centro_custo_em_branco         FOR TESTING RAISING cx_static_check.
    METHODS data_em_branco                 FOR TESTING RAISING cx_static_check.
    METHODS bukrs_em_branco                FOR TESTING RAISING cx_static_check.
    METHODS varias_falhas_no_mesmo_registo FOR TESTING RAISING cx_static_check.

    METHODS registo_base
      RETURNING
        VALUE(rs_dado) TYPE zassist_s_registo.

ENDCLASS.


CLASS ltc_assist_validator IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_assist_validator( ).
  ENDMETHOD.

  METHOD registo_base.
    rs_dado = VALUE #(
      pernr        = '00001234'
      conta        = '0000400000'
      centro_custo = '1000'
      bukrs        = '1000'
      data         = '01072026'
      valor        = '150.00' ).
  ENDMETHOD.

  METHOD registo_valido_passa.
    DATA(lt_dados) = VALUE zassist_t_registo( ( registo_base( ) ) ).

    DATA(lt_result) = mo_cut->validate( CHANGING ct_dados = lt_dados ).

    cl_abap_unit_assert=>assert_true( lt_dados[ 1 ]-is_valid ).
    cl_abap_unit_assert=>assert_initial( lt_result ).
  ENDMETHOD.

  METHOD pernr_em_branco.
    DATA(ls_dado) = registo_base( ).
    CLEAR ls_dado-pernr.
    DATA(lt_dados) = VALUE zassist_t_registo( ( ls_dado ) ).

    DATA(lt_result) = mo_cut->validate( CHANGING ct_dados = lt_dados ).

    cl_abap_unit_assert=>assert_false( lt_dados[ 1 ]-is_valid ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_result[ 1 ]-messages ) exp = 1 ).
  ENDMETHOD.

  METHOD valor_invalido.
    DATA(ls_dado) = registo_base( ).
    ls_dado-valor = 0.
    DATA(lt_dados) = VALUE zassist_t_registo( ( ls_dado ) ).

    mo_cut->validate( CHANGING ct_dados = lt_dados ).

    cl_abap_unit_assert=>assert_false( lt_dados[ 1 ]-is_valid ).
  ENDMETHOD.

  METHOD conta_em_branco.
    DATA(ls_dado) = registo_base( ).
    CLEAR ls_dado-conta.
    DATA(lt_dados) = VALUE zassist_t_registo( ( ls_dado ) ).

    mo_cut->validate( CHANGING ct_dados = lt_dados ).

    cl_abap_unit_assert=>assert_false( lt_dados[ 1 ]-is_valid ).
  ENDMETHOD.

  METHOD centro_custo_em_branco.
    DATA(ls_dado) = registo_base( ).
    CLEAR ls_dado-centro_custo.
    DATA(lt_dados) = VALUE zassist_t_registo( ( ls_dado ) ).

    mo_cut->validate( CHANGING ct_dados = lt_dados ).

    cl_abap_unit_assert=>assert_false( lt_dados[ 1 ]-is_valid ).
  ENDMETHOD.

  METHOD data_em_branco.
    DATA(ls_dado) = registo_base( ).
    CLEAR ls_dado-data.
    DATA(lt_dados) = VALUE zassist_t_registo( ( ls_dado ) ).

    mo_cut->validate( CHANGING ct_dados = lt_dados ).

    cl_abap_unit_assert=>assert_false( lt_dados[ 1 ]-is_valid ).
  ENDMETHOD.

  METHOD bukrs_em_branco.
    DATA(ls_dado) = registo_base( ).
    CLEAR ls_dado-bukrs.
    DATA(lt_dados) = VALUE zassist_t_registo( ( ls_dado ) ).

    mo_cut->validate( CHANGING ct_dados = lt_dados ).

    cl_abap_unit_assert=>assert_false( lt_dados[ 1 ]-is_valid ).
  ENDMETHOD.

  METHOD varias_falhas_no_mesmo_registo.
    DATA(ls_dado) = registo_base( ).
    CLEAR: ls_dado-pernr, ls_dado-conta.
    DATA(lt_dados) = VALUE zassist_t_registo( ( ls_dado ) ).

    DATA(lt_result) = mo_cut->validate( CHANGING ct_dados = lt_dados ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_result[ 1 ]-messages ) exp = 2 ).
  ENDMETHOD.

ENDCLASS.

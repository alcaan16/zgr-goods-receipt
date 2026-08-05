CLASS ltc_deviation DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS reports_no_deviation_if_exact   FOR TESTING.
    METHODS detects_weight_shortage           FOR TESTING.
    METHODS detects_weight_surplus            FOR TESTING.
    METHODS calculates_percentage             FOR TESTING.
    METHODS respects_tolerance                FOR TESTING.
    METHODS flags_beyond_tolerance            FOR TESTING.
    METHODS handles_zero_expected             FOR TESTING.
    METHODS caps_extreme_percentage           FOR TESTING.
ENDCLASS.


CLASS ltc_deviation IMPLEMENTATION.

  METHOD reports_no_deviation_if_exact.
    DATA(result) = zcl_gr_deviation=>calculate( expected = '750.000'
                                                received = '750.000' ).

    cl_abap_unit_assert=>assert_equals( exp = 0 act = result-absolute ).
    cl_abap_unit_assert=>assert_false( result-has_deviation ).
  ENDMETHOD.

  METHOD detects_weight_shortage.
    " Caso real de la entrada de demo: faltan 47,5 kg de panceta
    DATA(result) = zcl_gr_deviation=>calculate( expected = '750.000'
                                                received = '702.500' ).

    cl_abap_unit_assert=>assert_equals( exp = CONV zcl_gr_deviation=>ty_quantity( '-47.500' )
                                        act = result-absolute ).
    cl_abap_unit_assert=>assert_true( result-is_shortage ).
    cl_abap_unit_assert=>assert_true( result-has_deviation ).
  ENDMETHOD.

  METHOD detects_weight_surplus.
    DATA(result) = zcl_gr_deviation=>calculate( expected = '700.000'
                                                received = '712.000' ).

    cl_abap_unit_assert=>assert_equals( exp = CONV zcl_gr_deviation=>ty_quantity( '12.000' )
                                        act = result-absolute ).
    cl_abap_unit_assert=>assert_false( result-is_shortage ).
  ENDMETHOD.

  METHOD calculates_percentage.
    DATA(result) = zcl_gr_deviation=>calculate( expected = '750.000'
                                                received = '702.500' ).

    cl_abap_unit_assert=>assert_equals( exp = CONV zcl_gr_deviation=>ty_percent( '-6.33' )
                                        act = result-percent ).
  ENDMETHOD.

  METHOD respects_tolerance.
    " Merma de 1,8 kg sobre 750: -0,24%, dentro de una tolerancia del 1%
    DATA(result) = zcl_gr_deviation=>calculate( expected          = '750.000'
                                                received          = '748.200'
                                                tolerance_percent = '1.00' ).

    cl_abap_unit_assert=>assert_false(
      act = result-has_deviation
      msg = 'Una merma dentro de tolerancia no es una desviacion' ).
  ENDMETHOD.

  METHOD flags_beyond_tolerance.
    DATA(result) = zcl_gr_deviation=>calculate( expected          = '750.000'
                                                received          = '702.500'
                                                tolerance_percent = '1.00' ).

    cl_abap_unit_assert=>assert_true( result-has_deviation ).
  ENDMETHOD.

  METHOD handles_zero_expected.
    " Mercancia que no venia anunciada en el documento de entrada
    DATA(result) = zcl_gr_deviation=>calculate( expected = 0
                                                received = '120.000' ).

    cl_abap_unit_assert=>assert_equals( exp = 0 act = result-percent ).
    cl_abap_unit_assert=>assert_true( result-has_deviation ).
  ENDMETHOD.

  METHOD caps_extreme_percentage.
    " El campo de la posicion es DEC(5,2): sin recorte, esto reventaria
    DATA(result) = zcl_gr_deviation=>calculate( expected = '1.000'
                                                received = '1000.000' ).

    cl_abap_unit_assert=>assert_equals( exp = zcl_gr_deviation=>max_percent
                                        act = result-percent ).
  ENDMETHOD.

ENDCLASS.



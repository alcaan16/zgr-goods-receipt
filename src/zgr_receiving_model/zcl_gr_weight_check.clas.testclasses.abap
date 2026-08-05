CLASS ltc_weight_check DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS accepts_weight_within_range      FOR TESTING.
    METHODS calculates_average_per_unit      FOR TESTING.
    METHODS detects_scale_error              FOR TESTING.
    METHODS detects_counting_error           FOR TESTING.
    METHODS accepts_exactly_at_minimum       FOR TESTING.
    METHODS accepts_exactly_at_maximum       FOR TESTING.
    METHODS skips_check_for_fixed_weight     FOR TESTING.
    METHODS skips_check_without_units        FOR TESTING.
ENDCLASS.


CLASS ltc_weight_check IMPLEMENTATION.

  METHOD accepts_weight_within_range.
    " Pollo entero: 500 piezas, 748,2 kg -> 1,496 kg por pieza, rango 1,1-1,9
    DATA(result) = zcl_gr_weight_check=>check( quantity_units = '500.000'
                                               total_weight   = '748.200'
                                               min_per_unit   = '1.100'
                                               max_per_unit   = '1.900' ).

    cl_abap_unit_assert=>assert_true( result-is_plausible ).
    cl_abap_unit_assert=>assert_equals( exp = zcl_gr_weight_check=>verdict-plausible
                                        act = result-verdict ).
  ENDMETHOD.

  METHOD calculates_average_per_unit.
    DATA(result) = zcl_gr_weight_check=>check( quantity_units = '320.000'
                                               total_weight   = '1137.200'
                                               min_per_unit   = '2.000'
                                               max_per_unit   = '3.200' ).

    cl_abap_unit_assert=>assert_equals(
      exp = CONV zcl_gr_weight_check=>ty_quantity( '3.554' )
      act = result-average_weight ).
  ENDMETHOD.

  METHOD detects_scale_error.
    " 320 pechugas de pavo y 6.500 kg en bascula: 20,3 kg por pieza.
    " No es una desviacion, es un error. Y solo se ve aqui.
    DATA(result) = zcl_gr_weight_check=>check( quantity_units = '320.000'
                                               total_weight   = '6500.000'
                                               min_per_unit   = '2.000'
                                               max_per_unit   = '3.200' ).

    cl_abap_unit_assert=>assert_false( result-is_plausible ).
    cl_abap_unit_assert=>assert_equals( exp = zcl_gr_weight_check=>verdict-above_max
                                        act = result-verdict ).
  ENDMETHOD.

  METHOD detects_counting_error.
    " Peso correcto pero conteo inflado: 0,25 kg por pieza
    DATA(result) = zcl_gr_weight_check=>check( quantity_units = '3000.000'
                                               total_weight   = '750.000'
                                               min_per_unit   = '1.100'
                                               max_per_unit   = '1.900' ).

    cl_abap_unit_assert=>assert_false( result-is_plausible ).
    cl_abap_unit_assert=>assert_equals( exp = zcl_gr_weight_check=>verdict-below_min
                                        act = result-verdict ).
  ENDMETHOD.

  METHOD accepts_exactly_at_minimum.
    DATA(result) = zcl_gr_weight_check=>check( quantity_units = '100.000'
                                               total_weight   = '110.000'
                                               min_per_unit   = '1.100'
                                               max_per_unit   = '1.900' ).

    cl_abap_unit_assert=>assert_true( result-is_plausible ).
  ENDMETHOD.

  METHOD accepts_exactly_at_maximum.
    DATA(result) = zcl_gr_weight_check=>check( quantity_units = '100.000'
                                               total_weight   = '190.000'
                                               min_per_unit   = '1.100'
                                               max_per_unit   = '1.900' ).

    cl_abap_unit_assert=>assert_true( result-is_plausible ).
  ENDMETHOD.

  METHOD skips_check_for_fixed_weight.
    " Bandeja de 1 kg: material sin rango definido, no se comprueba
    DATA(result) = zcl_gr_weight_check=>check( quantity_units = '200.000'
                                               total_weight   = '200.000'
                                               min_per_unit   = 0
                                               max_per_unit   = 0 ).

    cl_abap_unit_assert=>assert_true( result-is_plausible ).
    cl_abap_unit_assert=>assert_equals( exp = zcl_gr_weight_check=>verdict-not_checked
                                        act = result-verdict ).
  ENDMETHOD.

  METHOD skips_check_without_units.
    " Sin unidades no hay division posible
    DATA(result) = zcl_gr_weight_check=>check( quantity_units = 0
                                               total_weight   = '500.000'
                                               min_per_unit   = '1.100'
                                               max_per_unit   = '1.900' ).

    cl_abap_unit_assert=>assert_equals( exp = zcl_gr_weight_check=>verdict-not_checked
                                        act = result-verdict ).
  ENDMETHOD.

ENDCLASS.



CLASS ltc_shelf_life DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS calculates_expiry_date   FOR TESTING.
    METHODS accepts_fresh_delivery              FOR TESTING.
    METHODS rejects_expired_delivery            FOR TESTING.
    METHODS rejects_expiring_today     FOR TESTING.
    METHODS rejects_insufficient_life     FOR TESTING.
    METHODS accepts_exactly_at_the_minimum      FOR TESTING.
    METHODS rounds_requirement_upwards          FOR TESTING.
    METHODS accepts_when_no_minimum_agreed      FOR TESTING.
ENDCLASS.


CLASS ltc_shelf_life IMPLEMENTATION.

  METHOD calculates_expiry_date.
    " Pollo entero: 8 dias de vida util desde produccion
    cl_abap_unit_assert=>assert_equals(
      exp = '20260811'
      act = zcl_gr_shelf_life=>expiry_date( production_date = '20260803'
                                            shelf_life_days = 8 ) ).
  ENDMETHOD.

  METHOD accepts_fresh_delivery.
    " Producido ayer, recibido hoy: 7 de 8 dias restantes, exigido 60% = 5 dias
    DATA(result) = zcl_gr_shelf_life=>evaluate( production_date = '20260803'
                                                receipt_date    = '20260804'
                                                shelf_life_days = 8
                                                min_percent     = 60 ).

    cl_abap_unit_assert=>assert_equals( exp = 7 act = result-remaining_days ).
    cl_abap_unit_assert=>assert_equals( exp = 5 act = result-required_days ).
    cl_abap_unit_assert=>assert_true( result-is_acceptable ).
  ENDMETHOD.

  METHOD rejects_expired_delivery.
    " Producido hace 10 dias, vida util de 8: llega caducado
    DATA(result) = zcl_gr_shelf_life=>evaluate( production_date = '20260725'
                                                receipt_date    = '20260804'
                                                shelf_life_days = 8
                                                min_percent     = 60 ).

    cl_abap_unit_assert=>assert_true( result-is_expired ).
    cl_abap_unit_assert=>assert_false( result-is_acceptable ).
  ENDMETHOD.

  METHOD rejects_expiring_today.
    " Caduca el mismo dia de la recepcion: no se acepta
    DATA(result) = zcl_gr_shelf_life=>evaluate( production_date = '20260727'
                                                receipt_date    = '20260804'
                                                shelf_life_days = 8
                                                min_percent     = 60 ).

    cl_abap_unit_assert=>assert_equals( exp = 0 act = result-remaining_days ).
    cl_abap_unit_assert=>assert_true( result-is_expired ).
  ENDMETHOD.

  METHOD rejects_insufficient_life.
    " No esta caducado, pero llega con 3 de 8 dias y se exige el 60% (5 dias).
    " Este es el caso que se discute en el muelle con el transportista.
    DATA(result) = zcl_gr_shelf_life=>evaluate( production_date = '20260730'
                                                receipt_date    = '20260804'
                                                shelf_life_days = 8
                                                min_percent     = 60 ).

    cl_abap_unit_assert=>assert_equals( exp = 3 act = result-remaining_days ).
    cl_abap_unit_assert=>assert_false( result-is_expired ).
    cl_abap_unit_assert=>assert_false( result-is_acceptable ).
  ENDMETHOD.

  METHOD accepts_exactly_at_the_minimum.
    " Justo en el limite: 5 dias restantes de un minimo de 5
    DATA(result) = zcl_gr_shelf_life=>evaluate( production_date = '20260801'
                                                receipt_date    = '20260804'
                                                shelf_life_days = 8
                                                min_percent     = 60 ).

    cl_abap_unit_assert=>assert_equals( exp = 5 act = result-remaining_days ).
    cl_abap_unit_assert=>assert_true( result-is_acceptable ).
  ENDMETHOD.

  METHOD rounds_requirement_upwards.
    " 10 dias al 55% son 5,5 dias: se exigen 6, no 5
    DATA(result) = zcl_gr_shelf_life=>evaluate( production_date = '20260804'
                                                receipt_date    = '20260804'
                                                shelf_life_days = 10
                                                min_percent     = 55 ).

    cl_abap_unit_assert=>assert_equals(
      exp = 6
      act = result-required_days
      msg = 'El requisito se redondea hacia arriba' ).
  ENDMETHOD.

  METHOD accepts_when_no_minimum_agreed.
    " Sin porcentaje pactado, basta con que no este caducado
    DATA(result) = zcl_gr_shelf_life=>evaluate( production_date = '20260730'
                                                receipt_date    = '20260804'
                                                shelf_life_days = 8
                                                min_percent     = 0 ).

    cl_abap_unit_assert=>assert_true( result-is_acceptable ).
  ENDMETHOD.

ENDCLASS.



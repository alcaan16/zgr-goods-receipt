CLASS ltc_batch_code DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS builds_code_from_date_and_seq FOR TESTING.
    METHODS pads_sequence_to_four_digits       FOR TESTING.
    METHODS handles_first_batch_of_the_day     FOR TESTING.
    METHODS handles_last_batch_of_the_day      FOR TESTING.
    METHODS clamps_sequence_below_one          FOR TESTING.
    METHODS cycles_sequence_over_maximum       FOR TESTING.
    METHODS next_sequence_increments           FOR TESTING.
    METHODS next_seq_restarts_at_maximum  FOR TESTING.
ENDCLASS.


CLASS ltc_batch_code IMPLEMENTATION.

  METHOD builds_code_from_date_and_seq.
    " El formato real de planta: 31 de julio de 2026, lote 198 del dia
    cl_abap_unit_assert=>assert_equals(
      exp = '202607310198'
      act = zcl_gr_batch_code=>build( reference_date = '20260731' sequence = 198 )
      msg = 'El codigo debe ser AAAAMMDD + secuencial de 4 digitos' ).
  ENDMETHOD.

  METHOD pads_sequence_to_four_digits.
    cl_abap_unit_assert=>assert_equals(
      exp = '202608040007'
      act = zcl_gr_batch_code=>build( reference_date = '20260804' sequence = 7 )
      msg = 'El secuencial se rellena con ceros a la izquierda' ).
  ENDMETHOD.

  METHOD handles_first_batch_of_the_day.
    cl_abap_unit_assert=>assert_equals(
      exp = '202601010001'
      act = zcl_gr_batch_code=>build( reference_date = '20260101' sequence = 1 ) ).
  ENDMETHOD.

  METHOD handles_last_batch_of_the_day.
    cl_abap_unit_assert=>assert_equals(
      exp = '202612319999'
      act = zcl_gr_batch_code=>build( reference_date = '20261231' sequence = 9999 ) ).
  ENDMETHOD.

  METHOD clamps_sequence_below_one.
    " Un secuencial invalido no debe producir un codigo corrupto
    cl_abap_unit_assert=>assert_equals(
      exp = '202608040001'
      act = zcl_gr_batch_code=>build( reference_date = '20260804' sequence = 0 ) ).
  ENDMETHOD.

  METHOD cycles_sequence_over_maximum.
    cl_abap_unit_assert=>assert_equals(
      exp = '202608040001'
      act = zcl_gr_batch_code=>build( reference_date = '20260804' sequence = 10000 ) ).
  ENDMETHOD.

  METHOD next_sequence_increments.
    cl_abap_unit_assert=>assert_equals(
      exp = 199
      act = zcl_gr_batch_code=>next_sequence( 198 ) ).
  ENDMETHOD.

  METHOD next_seq_restarts_at_maximum.
    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = zcl_gr_batch_code=>next_sequence( 9999 ) ).
  ENDMETHOD.

ENDCLASS.



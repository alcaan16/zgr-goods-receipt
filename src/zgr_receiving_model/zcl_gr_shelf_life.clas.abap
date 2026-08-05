CLASS zcl_gr_shelf_life DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_result,
        expiry_date    TYPE d,
        remaining_days TYPE i,
        required_days  TYPE i,
        is_expired     TYPE abap_boolean,
        is_acceptable  TYPE abap_boolean,
      END OF ty_result.

    "! Calcula la fecha de caducidad a partir de la fecha de produccion
    "! declarada por el proveedor y la vida util del material.
    CLASS-METHODS expiry_date
      IMPORTING production_date TYPE d
                shelf_life_days TYPE i
      RETURNING VALUE(result)   TYPE d.

    "! Evalua si la mercancia llega con vida util suficiente.
    "!
    "! En producto fresco no basta con que el producto no este caducado: se pacta
    "! con el proveedor un porcentaje minimo de vida util restante en el momento
    "! de la entrega. Un producto de 8 dias que llega con 2 no sirve, porque para
    "! cuando pase por produccion y llegue al cliente ya no tiene recorrido.
    "!
    "! @parameter min_percent | Porcentaje minimo de vida util restante exigido.
    CLASS-METHODS evaluate
      IMPORTING production_date TYPE d
                receipt_date    TYPE d
                shelf_life_days TYPE i
                min_percent     TYPE i
      RETURNING VALUE(result)   TYPE ty_result.

ENDCLASS.


CLASS zcl_gr_shelf_life IMPLEMENTATION.

  METHOD expiry_date.
    result = production_date + shelf_life_days.
  ENDMETHOD.


  METHOD evaluate.

    result-expiry_date = expiry_date( production_date = production_date
                                      shelf_life_days = shelf_life_days ).

    result-remaining_days = result-expiry_date - receipt_date.

    " Se redondea hacia arriba: si el minimo exige 4,2 dias, 4 no bastan
    DATA(exact_requirement) = CONV decfloat34( shelf_life_days ) * min_percent / 100.
    result-required_days = CONV i( ceil( exact_requirement ) ).

    result-is_expired = xsdbool( result-remaining_days <= 0 ).

    result-is_acceptable = xsdbool(     result-is_expired = abap_false
                                    AND result-remaining_days >= result-required_days ).

  ENDMETHOD.

ENDCLASS.



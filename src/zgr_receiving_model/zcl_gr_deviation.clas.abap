CLASS zcl_gr_deviation DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES ty_quantity TYPE p LENGTH 13 DECIMALS 3.
    TYPES ty_percent  TYPE p LENGTH 3  DECIMALS 2.

    TYPES:
      BEGIN OF ty_result,
        absolute      TYPE ty_quantity,
        percent       TYPE ty_percent,
        has_deviation TYPE abap_boolean,
        is_shortage   TYPE abap_boolean,
      END OF ty_result.

    "! Limite del campo DEC(5,2) de la posicion. Una desviacion mayor se
    "! recorta para no reventar el campo: el dato relevante en ese caso es
    "! la diferencia absoluta, no el porcentaje.
    CONSTANTS max_percent TYPE ty_percent VALUE '999.99'.

    "! Calcula la diferencia entre lo que dice el documento de entrada y lo
    "! que dicen el conteo y la bascula.
    "!
    "! Se guardan las dos magnitudes originales por separado y la diferencia
    "! se deriva: es lo que permite reconstruir despues que ocurrio, y es la
    "! base de cualquier reclamacion al proveedor.
    "!
    "! @parameter tolerance_percent | Margen admitido sin considerarlo desviacion.
    CLASS-METHODS calculate
      IMPORTING expected          TYPE ty_quantity
                received          TYPE ty_quantity
                tolerance_percent TYPE ty_percent DEFAULT 0
      RETURNING VALUE(result)     TYPE ty_result.

ENDCLASS.


CLASS zcl_gr_deviation IMPLEMENTATION.

  METHOD calculate.

    result-absolute = received - expected.
    result-is_shortage = xsdbool( result-absolute < 0 ).

    IF expected = 0.
      " Sin referencia no hay porcentaje posible. Hay desviacion si ha
      " entrado algo que no estaba anunciado.
      result-percent       = 0.
      result-has_deviation = xsdbool( result-absolute <> 0 ).
      RETURN.
    ENDIF.

    DATA(raw_percent) = CONV decfloat34( result-absolute ) / expected * 100.

    result-percent = COND ty_percent(
      WHEN raw_percent >  max_percent THEN max_percent
      WHEN raw_percent < -1 * max_percent THEN -1 * max_percent
      ELSE raw_percent ).

    result-has_deviation = xsdbool( abs( result-percent ) > tolerance_percent ).

  ENDMETHOD.

ENDCLASS.



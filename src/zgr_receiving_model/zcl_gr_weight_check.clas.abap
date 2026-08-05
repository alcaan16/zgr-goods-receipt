CLASS zcl_gr_weight_check DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES ty_quantity TYPE p LENGTH 13 DECIMALS 3.

    CONSTANTS:
      BEGIN OF verdict,
        plausible   TYPE string VALUE 'PLAUSIBLE',
        below_min   TYPE string VALUE 'BELOW_MIN',
        above_max   TYPE string VALUE 'ABOVE_MAX',
        not_checked TYPE string VALUE 'NOT_CHECKED',
      END OF verdict.

    TYPES:
      BEGIN OF ty_result,
        average_weight TYPE ty_quantity,
        is_plausible   TYPE abap_boolean,
        verdict        TYPE string,
      END OF ty_result.

    "! Comprueba que el peso medio por pieza esta dentro del rango del material.
    "!
    "! Es la validacion que separa una desviacion de un error. Si entran 320
    "! unidades de un producto cuya pieza pesa entre 2 y 3,2 kg y la bascula
    "! marca 6.500 kg, no hay merma ni exceso: hay un error de bascula o un
    "! error de conteo. Registrarlo contamina el stock y la trazabilidad, y
    "! solo se puede detectar en el momento de la entrada.
    "!
    "! Un rango sin definir (min y max a cero) desactiva la comprobacion:
    "! es el caso de los materiales de peso fijo.
    CLASS-METHODS check
      IMPORTING quantity_units TYPE ty_quantity
                total_weight   TYPE ty_quantity
                min_per_unit   TYPE ty_quantity
                max_per_unit   TYPE ty_quantity
      RETURNING VALUE(result)  TYPE ty_result.

ENDCLASS.


CLASS zcl_gr_weight_check IMPLEMENTATION.

  METHOD check.

    " Sin unidades no hay media posible, y sin rango no hay nada que comprobar
    IF quantity_units <= 0 OR ( min_per_unit = 0 AND max_per_unit = 0 ).
      result-verdict      = verdict-not_checked.
      result-is_plausible = abap_true.
      RETURN.
    ENDIF.

    result-average_weight = total_weight / quantity_units.

    result-verdict = COND string(
      WHEN min_per_unit > 0 AND result-average_weight < min_per_unit THEN verdict-below_min
      WHEN max_per_unit > 0 AND result-average_weight > max_per_unit THEN verdict-above_max
      ELSE verdict-plausible ).

    result-is_plausible = xsdbool( result-verdict = verdict-plausible ).

  ENDMETHOD.

ENDCLASS.


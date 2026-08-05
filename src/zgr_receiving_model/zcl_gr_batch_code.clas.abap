CLASS zcl_gr_batch_code DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES ty_batch_code TYPE c LENGTH 12.

    CONSTANTS max_sequence TYPE i VALUE 9999.

    "! Construye el codigo de lote interno de fabrica.
    "! Formato: AAAAMMDD + secuencial de 4 digitos (ej. 202607310198).
    "! Es la codificacion real usada en planta: la fecha permite localizar
    "! visualmente el dia de entrada sin consultar el sistema, y el secuencial
    "! distingue los lotes recibidos en esa misma jornada.
    "!
    "! @parameter reference_date | Fecha de referencia, normalmente la de recepcion.
    "! @parameter sequence       | Secuencial del dia, de 1 a 9999. Fuera de rango se cicla.
    CLASS-METHODS build
      IMPORTING reference_date TYPE d
                sequence      TYPE i
      RETURNING VALUE(result) TYPE ty_batch_code.

    "! Devuelve el siguiente secuencial libre a partir del ultimo usado.
    "! Al superar el maximo vuelve a 1: el codigo solo tiene que ser unico
    "! dentro del dia, no de forma absoluta.
    CLASS-METHODS next_sequence
      IMPORTING last_sequence TYPE i
      RETURNING VALUE(result) TYPE i.

ENDCLASS.


CLASS zcl_gr_batch_code IMPLEMENTATION.

  METHOD build.

    DATA(normalized) = COND i( WHEN sequence < 1              THEN 1
                               WHEN sequence > max_sequence   THEN sequence MOD max_sequence
                               ELSE sequence ).

    result = |{ reference_date DATE = RAW }| &&
             |{ normalized ALIGN = RIGHT PAD = '0' WIDTH = 4 }|.

  ENDMETHOD.


  METHOD next_sequence.

    result = COND i( WHEN last_sequence >= max_sequence THEN 1
                     ELSE last_sequence + 1 ).

  ENDMETHOD.

ENDCLASS.


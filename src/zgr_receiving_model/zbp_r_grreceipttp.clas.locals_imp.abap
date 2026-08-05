*"* Tipos locales de la clase de comportamiento ZBP_R_GRRECEIPTTP
*"* Pestaña "Local Types" del editor de clases de ADT.
*"*
*"* Los manejadores no calculan: leen datos, delegan en las clases de logica
*"* (ZCL_GR_*, con cobertura de ABAP Unit) y escriben el resultado.

CLASS lcl_const DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF receipt_status,
        draft     TYPE zgr_receipt-overall_status VALUE '1',
        in_review TYPE zgr_receipt-overall_status VALUE '2',
        posted    TYPE zgr_receipt-overall_status VALUE '3',
      END OF receipt_status,

      BEGIN OF item_status,
        ok        TYPE zgr_rec_item-item_status VALUE '1',
        deviation TYPE zgr_rec_item-item_status VALUE '2',
        accepted  TYPE zgr_rec_item-item_status VALUE '3',
      END OF item_status,

      BEGIN OF batch_status,
        free       TYPE zgr_batch-batch_status VALUE '1',
        blocked    TYPE zgr_batch-batch_status VALUE '2',
        inspection TYPE zgr_batch-batch_status VALUE '3',
      END OF batch_status.

    "! Margen admitido antes de considerar que hay desviacion real.
    "! Por debajo de este porcentaje se trata como merma normal de transporte.
    CONSTANTS tolerance_percent TYPE p LENGTH 3 DECIMALS 2 VALUE '1.00'.
ENDCLASS.

CLASS lcl_const IMPLEMENTATION.
ENDCLASS.


CLASS lhc_Receipt DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Receipt RESULT result.

    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Receipt~setInitialStatus.

    METHODS setReceiptNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR Receipt~setReceiptNumber.

ENDCLASS.


CLASS lhc_Receipt IMPLEMENTATION.

  METHOD get_instance_authorizations.
    " Sin DCL: el proyecto no implementa control de autorizaciones.
    " Decision de alcance documentada en docs/decisiones-tecnicas.md.
  ENDMETHOD.


  METHOD setInitialStatus.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt
        FIELDS ( OverallStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(receipts).

    " Solo las que aun no tienen estado: una determinacion no debe pisar
    " un valor que ya se ha calculado
    DELETE receipts WHERE OverallStatus IS NOT INITIAL.
    CHECK receipts IS NOT INITIAL.

    MODIFY ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( FOR receipt IN receipts
                      ( %tky          = receipt-%tky
                        OverallStatus = lcl_const=>receipt_status-draft ) )
      REPORTED DATA(update_reported).

  ENDMETHOD.


  METHOD setReceiptNumber.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt
        FIELDS ( ReceiptNumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(receipts).

    DELETE receipts WHERE ReceiptNumber IS NOT INITIAL.
    CHECK receipts IS NOT INITIAL.

    " Numeracion correlativa sobre el maximo persistido.
    " Limitacion conocida: sin objeto de rango de numeros, dos usuarios
    " creando a la vez podrian obtener el mismo numero.
    SELECT MAX( receipt_number ) FROM zgr_receipt INTO @DATA(highest).
    DATA(next_number) = CONV i( highest ).

    DATA updates TYPE TABLE FOR UPDATE zr_grreceipttp.

    LOOP AT receipts INTO DATA(receipt).
      next_number = next_number + 1.
      APPEND VALUE #( %tky          = receipt-%tky
                      ReceiptNumber = |{ next_number ALIGN = RIGHT PAD = '0' WIDTH = 10 }| )
             TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt
        UPDATE FIELDS ( ReceiptNumber )
        WITH updates
      REPORTED DATA(update_reported).

  ENDMETHOD.

ENDCLASS.


CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS calculateDeviation FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calculateDeviation.

    METHODS calculateHeaderTotals FOR DETERMINE ON SAVE
      IMPORTING keys FOR Item~calculateHeaderTotals.

ENDCLASS.


CLASS lhc_Item IMPLEMENTATION.

  METHOD calculateDeviation.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    DATA updates TYPE TABLE FOR UPDATE zr_grreceipttp\\Item.

    LOOP AT items INTO DATA(item).

      " El peso manda: en producto de peso variable es la magnitud que se
      " reclama al proveedor. Las unidades se calculan igual, para el registro.
      DATA(weight) = zcl_gr_deviation=>calculate(
                       expected          = CONV #( item-WeightExpected )
                       received          = CONV #( item-WeightReceived )
                       tolerance_percent = lcl_const=>tolerance_percent ).

      DATA(quantity) = zcl_gr_deviation=>calculate(
                         expected = CONV #( item-QtyExpected )
                         received = CONV #( item-QtyReceived ) ).

      " Una desviacion ya aceptada no vuelve a marcarse como pendiente
      DATA(status) = COND #(
        WHEN item-ItemStatus = lcl_const=>item_status-accepted
          THEN lcl_const=>item_status-accepted
        WHEN weight-has_deviation = abap_true OR quantity-has_deviation = abap_true
          THEN lcl_const=>item_status-deviation
        ELSE lcl_const=>item_status-ok ).

      APPEND VALUE #( %tky            = item-%tky
                      QtyDeviation    = quantity-absolute
                      WeightDeviation = weight-absolute
                      DeviationPct    = weight-percent
                      ItemStatus      = status )
             TO updates.

    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( QtyDeviation WeightDeviation DeviationPct ItemStatus )
        WITH updates
      REPORTED DATA(update_reported).

  ENDMETHOD.


  METHOD calculateHeaderTotals.

    " Desde la posicion se sube a la cabecera y desde ahi se bajan todas las
    " posiciones hermanas: los totales son la suma de lo que hay, no un
    " acumulado que se va incrementando.
    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item BY \_Receipt
        FIELDS ( ReceiptUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(receipts).

    CHECK receipts IS NOT INITIAL.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt BY \_Item
        FIELDS ( QtyReceived WeightReceived BaseUnit WeightUnit )
        WITH CORRESPONDING #( receipts )
      RESULT DATA(all_items)
      LINK DATA(item_links).

    DATA updates TYPE TABLE FOR UPDATE zr_grreceipttp.

    LOOP AT receipts INTO DATA(receipt).

      DATA(total_quantity) = VALUE zgr_receipt-total_quantity( ).
      DATA(total_weight)   = VALUE zgr_receipt-total_weight( ).
      DATA(base_unit)      = VALUE zgr_receipt-total_unit( ).
      DATA(weight_unit)    = VALUE zgr_receipt-weight_unit( ).

      LOOP AT item_links INTO DATA(link) WHERE source-%tky = receipt-%tky.

        READ TABLE all_items INTO DATA(item) WITH KEY %tky = link-target-%tky.
        CHECK sy-subrc = 0.

        total_quantity = total_quantity + item-QtyReceived.
        total_weight   = total_weight   + item-WeightReceived.

        IF base_unit IS INITIAL.
          base_unit = item-BaseUnit.
        ENDIF.
        IF weight_unit IS INITIAL.
          weight_unit = item-WeightUnit.
        ENDIF.

      ENDLOOP.

      APPEND VALUE #( %tky          = receipt-%tky
                      TotalQuantity = total_quantity
                      TotalUnit     = base_unit
                      TotalWeight   = total_weight
                      WeightUnit    = weight_unit )
             TO updates.

    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt
        UPDATE FIELDS ( TotalQuantity TotalUnit TotalWeight WeightUnit )
        WITH updates
      REPORTED DATA(update_reported).

  ENDMETHOD.

ENDCLASS.


CLASS lhc_Batch DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS calculateBatchCode FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Batch~calculateBatchCode.

    METHODS calculateExpiryDate FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Batch~calculateExpiryDate.

ENDCLASS.


CLASS lhc_Batch IMPLEMENTATION.

  METHOD calculateBatchCode.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch
        FIELDS ( BatchNumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(batches).

    DELETE batches WHERE BatchNumber IS NOT INITIAL.
    CHECK batches IS NOT INITIAL.

    " La fecha del codigo es la de recepcion de la cabecera, no la del sistema:
    " un lote registrado al dia siguiente sigue perteneciendo a su descarga.
    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch BY \_Receipt
        FIELDS ( ReceiptDate )
        WITH CORRESPONDING #( batches )
      RESULT DATA(receipts)
      LINK DATA(receipt_links).

    DATA updates TYPE TABLE FOR UPDATE zr_grreceipttp\\Batch.

    LOOP AT batches INTO DATA(batch).

      READ TABLE receipt_links INTO DATA(link) WITH KEY source-%tky = batch-%tky.
      CHECK sy-subrc = 0.
      READ TABLE receipts INTO DATA(receipt) WITH KEY %tky = link-target-%tky.
      CHECK sy-subrc = 0.

      DATA(reference_date) = COND d( WHEN receipt-ReceiptDate IS INITIAL
                                       THEN cl_abap_context_info=>get_system_date( )
                                     ELSE receipt-ReceiptDate ).

      " Secuencial del dia sobre lo ya persistido, mas los que van en esta
      " misma transaccion. Limitacion conocida frente a concurrencia real.
      DATA pattern TYPE zgr_batch-batch_number.
      pattern = |{ reference_date DATE = RAW }%|.

      SELECT COUNT( * ) FROM zgr_batch
        WHERE batch_number LIKE @pattern
        INTO @DATA(existing).

      DATA(sequence) = zcl_gr_batch_code=>next_sequence( existing + lines( updates ) ).

      APPEND VALUE #( %tky        = batch-%tky
                      BatchNumber = zcl_gr_batch_code=>build(
                                      reference_date = reference_date
                                      sequence       = sequence ) )
             TO updates.

    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch
        UPDATE FIELDS ( BatchNumber )
        WITH updates
      REPORTED DATA(update_reported).

  ENDMETHOD.


  METHOD calculateExpiryDate.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch
        FIELDS ( ProductionDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(batches).

    DELETE batches WHERE ProductionDate IS INITIAL.
    CHECK batches IS NOT INITIAL.

    " La vida util es un dato del material, y el material esta en la posicion
    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch BY \_Item
        FIELDS ( MaterialId )
        WITH CORRESPONDING #( batches )
      RESULT DATA(items)
      LINK DATA(item_links).

    CHECK items IS NOT INITIAL.

    SELECT material_id, shelf_life_days
      FROM zgr_material
      FOR ALL ENTRIES IN @items
      WHERE material_id = @items-MaterialId
      INTO TABLE @DATA(materials).

    DATA updates TYPE TABLE FOR UPDATE zr_grreceipttp\\Batch.

    LOOP AT batches INTO DATA(batch).

      READ TABLE item_links INTO DATA(link) WITH KEY source-%tky = batch-%tky.
      CHECK sy-subrc = 0.
      READ TABLE items INTO DATA(item) WITH KEY %tky = link-target-%tky.
      CHECK sy-subrc = 0.
      READ TABLE materials INTO DATA(material) WITH KEY material_id = item-MaterialId.
      CHECK sy-subrc = 0 AND material-shelf_life_days > 0.

      APPEND VALUE #( %tky       = batch-%tky
                      ExpiryDate = zcl_gr_shelf_life=>expiry_date(
                                     production_date = batch-ProductionDate
                                     shelf_life_days = material-shelf_life_days ) )
             TO updates.

    ENDLOOP.

    CHECK updates IS NOT INITIAL.

    MODIFY ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch
        UPDATE FIELDS ( ExpiryDate )
        WITH updates
      REPORTED DATA(update_reported).

  ENDMETHOD.

ENDCLASS.



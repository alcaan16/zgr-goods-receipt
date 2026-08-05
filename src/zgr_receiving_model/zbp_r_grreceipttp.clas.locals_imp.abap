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

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Receipt RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Receipt RESULT result.

    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Receipt~setInitialStatus.

    METHODS setReceiptNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR Receipt~setReceiptNumber.

    METHODS validateSupplier FOR VALIDATE ON SAVE
      IMPORTING keys FOR Receipt~validateSupplier.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Receipt RESULT result.

    METHODS postReceipt FOR MODIFY
      IMPORTING keys FOR ACTION Receipt~postReceipt RESULT result.

ENDCLASS.


CLASS lhc_Receipt IMPLEMENTATION.

  METHOD get_global_authorizations.

    " Sin DCL: el proyecto no implementa control de autorizaciones. Los
    " manejadores conceden todo de forma explicita, que es distinto de no
    " implementarlos: RAP exige una respuesta, no el silencio.
    " Decision de alcance documentada en docs/decisiones-tecnicas.md.
    result-%create             = if_abap_behv=>auth-allowed.
    result-%update             = if_abap_behv=>auth-allowed.
    result-%delete             = if_abap_behv=>auth-allowed.
    result-%action-postReceipt = if_abap_behv=>auth-allowed.

  ENDMETHOD.


  METHOD get_instance_authorizations.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt
        FIELDS ( ReceiptUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(receipts).

    " Posiciones y lotes declaran su propia autorizacion: RAP exige un
    " manejador en la entidad sobre la que se comprueba la accion.
    result = VALUE #( FOR receipt IN receipts
                      ( %tky                = receipt-%tky
                        %update             = if_abap_behv=>auth-allowed
                        %delete             = if_abap_behv=>auth-allowed
                        %action-postReceipt = if_abap_behv=>auth-allowed ) ).

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

  METHOD validateSupplier.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt
        FIELDS ( SupplierId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(receipts).

    CHECK receipts IS NOT INITIAL.

    SELECT supplier_id, supplier_name, is_active
      FROM zgr_supplier
      FOR ALL ENTRIES IN @receipts
      WHERE supplier_id = @receipts-SupplierId
      INTO TABLE @DATA(suppliers).

    LOOP AT receipts INTO DATA(receipt).

      " Limpia mensajes previos de esta validacion antes de volver a evaluarla
      APPEND VALUE #( %tky        = receipt-%tky
                      %state_area = 'VALIDATE_SUPPLIER' )
             TO reported-receipt.

      READ TABLE suppliers INTO DATA(supplier)
           WITH KEY supplier_id = receipt-SupplierId.

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = receipt-%tky ) TO failed-receipt.
        APPEND VALUE #( %tky                = receipt-%tky
                        %state_area         = 'VALIDATE_SUPPLIER'
                        %element-SupplierId = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Proveedor { receipt-SupplierId } no existe| ) )
               TO reported-receipt.
        CONTINUE.
      ENDIF.

      IF supplier-is_active = abap_false.
        APPEND VALUE #( %tky = receipt-%tky ) TO failed-receipt.
        APPEND VALUE #( %tky                = receipt-%tky
                        %state_area         = 'VALIDATE_SUPPLIER'
                        %element-SupplierId = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Proveedor { receipt-SupplierId } dado de baja| ) )
               TO reported-receipt.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_instance_features.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt
        FIELDS ( OverallStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(receipts).

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt BY \_Item
        FIELDS ( ItemStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      LINK DATA(item_links).

    LOOP AT receipts INTO DATA(receipt).

      " Una entrada ya registrada no se vuelve a registrar
      DATA(can_post) = xsdbool( receipt-OverallStatus <> lcl_const=>receipt_status-posted ).

      " Y no se registra mientras haya discrepancias sin resolver:
      " esa decision la toma una persona, no el sistema
      IF can_post = abap_true.
        LOOP AT item_links INTO DATA(link) WHERE source-%tky = receipt-%tky.
          READ TABLE items INTO DATA(item) WITH KEY %tky = link-target-%tky.
          CHECK sy-subrc = 0.
          IF item-ItemStatus = lcl_const=>item_status-deviation.
            can_post = abap_false.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.

      APPEND VALUE #( %tky = receipt-%tky
                      %action-postReceipt = COND #( WHEN can_post = abap_true
                                                    THEN if_abap_behv=>fc-o-enabled
                                                    ELSE if_abap_behv=>fc-o-disabled ) )
             TO result.

    ENDLOOP.

  ENDMETHOD.


  METHOD postReceipt.

    MODIFY ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( FOR key IN keys
                      ( %tky          = key-%tky
                        OverallStatus = lcl_const=>receipt_status-posted ) )
      REPORTED DATA(update_reported).

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(receipts).

    result = VALUE #( FOR receipt IN receipts
                      ( %tky = receipt-%tky %param = receipt ) ).

  ENDMETHOD.

ENDCLASS.


CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS setItemNumber FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~setItemNumber.

    METHODS calculateDeviation FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calculateDeviation.

    METHODS calculateHeaderTotals FOR DETERMINE ON SAVE
      IMPORTING keys FOR Item~calculateHeaderTotals.

    METHODS validateMaterial FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateMaterial.

    METHODS validateQuantities FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateQuantities.

    METHODS validateWeightPlausibility FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateWeightPlausibility.

    METHODS validateBatchQuantities FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateBatchQuantities.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Item RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Item RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Item RESULT result.

    METHODS acceptDeviation FOR MODIFY
      IMPORTING keys FOR ACTION Item~acceptDeviation RESULT result.

ENDCLASS.


CLASS lhc_Item IMPLEMENTATION.

  METHOD setItemNumber.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item
        FIELDS ( ItemNumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(new_items).

    DELETE new_items WHERE ItemNumber IS NOT INITIAL.
    CHECK new_items IS NOT INITIAL.

    " Numeracion de 10 en 10, como en cualquier documento de SAP: deja hueco
    " para intercalar una posicion sin renumerar el resto.
    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item BY \_Receipt
        FIELDS ( ReceiptUuid )
        WITH CORRESPONDING #( new_items )
      RESULT DATA(receipts).

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Receipt BY \_Item
        FIELDS ( ItemNumber )
        WITH CORRESPONDING #( receipts )
      RESULT DATA(sibling_items).

    DATA(highest) = REDUCE i( INIT max = 0
                              FOR sibling IN sibling_items
                              NEXT max = COND #( WHEN sibling-ItemNumber > max
                                                 THEN sibling-ItemNumber
                                                 ELSE max ) ).

    DATA updates TYPE TABLE FOR UPDATE zr_grreceipttp\\Item.

    LOOP AT new_items INTO DATA(new_item).
      highest = highest + 10.
      APPEND VALUE #( %tky       = new_item-%tky
                      ItemNumber = highest )
             TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( ItemNumber )
        WITH updates
      REPORTED DATA(update_reported).

  ENDMETHOD.


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

  METHOD validateMaterial.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item
        FIELDS ( MaterialId ReceiptUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    CHECK items IS NOT INITIAL.

    SELECT material_id FROM zgr_material
      FOR ALL ENTRIES IN @items
      WHERE material_id = @items-MaterialId
      INTO TABLE @DATA(materials).

    LOOP AT items INTO DATA(item).

      APPEND VALUE #( %tky       = item-%tky
                      %path      = VALUE #( receipt-%tky = VALUE #(
                                     %key-ReceiptUuid = item-ReceiptUuid
                                     %is_draft        = item-%is_draft ) )
                      %state_area = 'VALIDATE_MATERIAL' ) TO reported-item.

      IF NOT line_exists( materials[ material_id = item-MaterialId ] ).
        APPEND VALUE #( %tky = item-%tky ) TO failed-item.
        APPEND VALUE #( %tky                = item-%tky
                        %path               = VALUE #( receipt-%tky = VALUE #(
                                                %key-ReceiptUuid = item-ReceiptUuid
                                                %is_draft        = item-%is_draft ) )
                        %state_area         = 'VALIDATE_MATERIAL'
                        %element-MaterialId = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Material { item-MaterialId } no existe| ) )
               TO reported-item.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD validateQuantities.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item
        FIELDS ( MaterialId QtyReceived WeightReceived ReceiptUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    CHECK items IS NOT INITIAL.

    SELECT material_id, material_name, catch_weight
      FROM zgr_material
      FOR ALL ENTRIES IN @items
      WHERE material_id = @items-MaterialId
      INTO TABLE @DATA(materials).

    LOOP AT items INTO DATA(item).

      APPEND VALUE #( %tky       = item-%tky
                      %path      = VALUE #( receipt-%tky = VALUE #(
                                     %key-ReceiptUuid = item-ReceiptUuid
                                     %is_draft        = item-%is_draft ) )
                      %state_area = 'VALIDATE_QUANTITIES' ) TO reported-item.

      IF item-QtyReceived <= 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-item.
        APPEND VALUE #( %tky                 = item-%tky
                        %path                = VALUE #( receipt-%tky = VALUE #(
                                                 %key-ReceiptUuid = item-ReceiptUuid
                                                 %is_draft        = item-%is_draft ) )
                        %state_area          = 'VALIDATE_QUANTITIES'
                        %element-QtyReceived = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |La cantidad recibida debe ser mayor que 0| ) )
               TO reported-item.
      ENDIF.

      READ TABLE materials INTO DATA(material)
           WITH KEY material_id = item-MaterialId.
      CHECK sy-subrc = 0.

      " En un material de peso variable, registrar solo unidades no dice nada:
      " 500 pollos pueden ser 550 kg o 950 kg. El peso es obligatorio.
      IF material-catch_weight = abap_true AND item-WeightReceived <= 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-item.
        APPEND VALUE #( %tky                    = item-%tky
                        %path                   = VALUE #( receipt-%tky = VALUE #(
                                                    %key-ReceiptUuid = item-ReceiptUuid
                                                    %is_draft        = item-%is_draft ) )
                        %state_area             = 'VALIDATE_QUANTITIES'
                        %element-WeightReceived = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Doble unidad de medida: peso obligatorio| ) )
               TO reported-item.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD validateWeightPlausibility.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item
        FIELDS ( MaterialId QtyReceived WeightReceived WeightUnit ReceiptUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    CHECK items IS NOT INITIAL.

    SELECT material_id, material_name, weight_per_unit_min, weight_per_unit_max
      FROM zgr_material
      FOR ALL ENTRIES IN @items
      WHERE material_id = @items-MaterialId
      INTO TABLE @DATA(materials).

    LOOP AT items INTO DATA(item).

      APPEND VALUE #( %tky       = item-%tky
                      %path      = VALUE #( receipt-%tky = VALUE #(
                                     %key-ReceiptUuid = item-ReceiptUuid
                                     %is_draft        = item-%is_draft ) )
                      %state_area = 'VALIDATE_PLAUSIBILITY' ) TO reported-item.

      READ TABLE materials INTO DATA(material)
           WITH KEY material_id = item-MaterialId.
      CHECK sy-subrc = 0.

      DATA(check_result) = zcl_gr_weight_check=>check(
                             quantity_units = CONV #( item-QtyReceived )
                             total_weight   = CONV #( item-WeightReceived )
                             min_per_unit   = CONV #( material-weight_per_unit_min )
                             max_per_unit   = CONV #( material-weight_per_unit_max ) ).

      CHECK check_result-is_plausible = abap_false.

      " Esto no es una desviacion: es un error de bascula o de conteo, y solo
      " se puede detectar en el momento de la entrada.
      DATA(detail) = COND string(
        WHEN check_result-verdict = zcl_gr_weight_check=>verdict-below_min
          THEN |min { material-weight_per_unit_min }|
        ELSE |max { material-weight_per_unit_max }| ).

      APPEND VALUE #( %tky = item-%tky ) TO failed-item.
      APPEND VALUE #( %tky                    = item-%tky
                      %path                   = VALUE #( receipt-%tky = VALUE #(
                                                  %key-ReceiptUuid = item-ReceiptUuid
                                                  %is_draft        = item-%is_draft ) )
                      %state_area             = 'VALIDATE_PLAUSIBILITY'
                      %element-QtyReceived    = if_abap_behv=>mk-on
                      %element-WeightReceived = if_abap_behv=>mk-on
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = |Peso medio { check_result-average_weight } | &&
                                          |{ item-WeightUnit }, { detail }| ) )
             TO reported-item.

    ENDLOOP.

  ENDMETHOD.


  METHOD validateBatchQuantities.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item
        FIELDS ( QtyReceived WeightReceived BaseUnit WeightUnit ReceiptUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    CHECK items IS NOT INITIAL.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item BY \_Batch
        FIELDS ( QtyUnits QtyWeight )
        WITH CORRESPONDING #( keys )
      RESULT DATA(batches)
      LINK DATA(batch_links).

    LOOP AT items INTO DATA(item).

      APPEND VALUE #( %tky       = item-%tky
                      %path      = VALUE #( receipt-%tky = VALUE #(
                                     %key-ReceiptUuid = item-ReceiptUuid
                                     %is_draft        = item-%is_draft ) )
                      %state_area = 'VALIDATE_BATCH_QTY' ) TO reported-item.

      " Sin lotes no hay nada que cuadrar: el lote se informa despues
      IF batch_links IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(total_units)  = VALUE zgr_batch-qty_units( ).
      DATA(total_weight) = VALUE zgr_batch-qty_weight( ).
      DATA(has_batches)  = abap_false.

      LOOP AT batch_links INTO DATA(link) WHERE source-%tky = item-%tky.
        READ TABLE batches INTO DATA(batch) WITH KEY %tky = link-target-%tky.
        CHECK sy-subrc = 0.
        has_batches  = abap_true.
        total_units  = total_units  + batch-QtyUnits.
        total_weight = total_weight + batch-QtyWeight.
      ENDLOOP.

      CHECK has_batches = abap_true.

      IF total_units <> item-QtyReceived OR total_weight <> item-WeightReceived.
        APPEND VALUE #( %tky = item-%tky ) TO failed-item.
        APPEND VALUE #( %tky        = item-%tky
                        %path       = VALUE #( receipt-%tky = VALUE #(
                                        %key-ReceiptUuid = item-ReceiptUuid
                                        %is_draft        = item-%is_draft ) )
                        %state_area = 'VALIDATE_BATCH_QTY'
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Lotes { total_units }/{ total_weight } | &&
                                            |vs posicion { item-QtyReceived }/{ item-WeightReceived }| ) )
               TO reported-item.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_global_authorizations.

    result-%update                 = if_abap_behv=>auth-allowed.
    result-%delete                 = if_abap_behv=>auth-allowed.
    result-%action-acceptDeviation = if_abap_behv=>auth-allowed.

  ENDMETHOD.


  METHOD get_instance_authorizations.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item
        FIELDS ( ItemUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(authorized_items).

    result = VALUE #( FOR item IN authorized_items
                      ( %tky                    = item-%tky
                        %update                 = if_abap_behv=>auth-allowed
                        %delete                 = if_abap_behv=>auth-allowed
                        %action-acceptDeviation = if_abap_behv=>auth-allowed ) ).

  ENDMETHOD.


  METHOD get_instance_features.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item
        FIELDS ( ItemStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    " Un boton que no hace nada es ruido: solo se ofrece aceptar la
    " desviacion cuando efectivamente hay una desviacion pendiente
    result = VALUE #( FOR item IN items
                      ( %tky = item-%tky
                        %action-acceptDeviation =
                          COND #( WHEN item-ItemStatus = lcl_const=>item_status-deviation
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ) ) ).

  ENDMETHOD.


  METHOD acceptDeviation.

    DATA updates TYPE TABLE FOR UPDATE zr_grreceipttp\\Item.

    " No se corrige el peso recibido: se deja constancia de que alguien con
    " criterio acepto la diferencia y por que motivo. Sobrescribir el dato
    " borraria la evidencia de la reclamacion al proveedor.
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky            = key-%tky
                      ItemStatus      = lcl_const=>item_status-accepted
                      DeviationReason = key-%param-ReasonId
                      DeviationNote   = key-%param-Note )
             TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( ItemStatus DeviationReason DeviationNote )
        WITH updates
      REPORTED DATA(update_reported).

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    result = VALUE #( FOR item IN items
                      ( %tky = item-%tky %param = item ) ).

  ENDMETHOD.

ENDCLASS.


CLASS lhc_Batch DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS calculateBatchCode FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Batch~calculateBatchCode.

    METHODS calculateExpiryDate FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Batch~calculateExpiryDate.

    METHODS validateExpiryDate FOR VALIDATE ON SAVE
      IMPORTING keys FOR Batch~validateExpiryDate.

    METHODS validateSupplierBatch FOR VALIDATE ON SAVE
      IMPORTING keys FOR Batch~validateSupplierBatch.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Batch RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Batch RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Batch RESULT result.

    METHODS blockBatch FOR MODIFY
      IMPORTING keys FOR ACTION Batch~blockBatch RESULT result.

    METHODS releaseBatch FOR MODIFY
      IMPORTING keys FOR ACTION Batch~releaseBatch RESULT result.

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

  METHOD validateExpiryDate.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch
        FIELDS ( ProductionDate ExpiryDate ItemUuid ReceiptUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(batches).

    CHECK batches IS NOT INITIAL.

    " La fecha de recepcion vive en la cabecera
    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch BY \_Receipt
        FIELDS ( ReceiptDate )
        WITH CORRESPONDING #( batches )
      RESULT DATA(receipts)
      LINK DATA(receipt_links).

    " La vida util y el minimo exigido son datos del material, en la posicion
    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch BY \_Item
        FIELDS ( MaterialId )
        WITH CORRESPONDING #( batches )
      RESULT DATA(items)
      LINK DATA(item_links).

    CHECK items IS NOT INITIAL.

    SELECT material_id, material_name, shelf_life_days, min_shelf_life_pct
      FROM zgr_material
      FOR ALL ENTRIES IN @items
      WHERE material_id = @items-MaterialId
      INTO TABLE @DATA(materials).

    LOOP AT batches INTO DATA(batch).

      APPEND VALUE #( %tky = batch-%tky
                      %path = VALUE #( receipt-%tky = VALUE #( %key-ReceiptUuid = batch-ReceiptUuid
                                                               %is_draft        = batch-%is_draft )
                                       item-%tky    = VALUE #( %key-ItemUuid    = batch-ItemUuid
                                                               %is_draft        = batch-%is_draft ) )
                      %state_area = 'VALIDATE_EXPIRY' ) TO reported-batch.

      READ TABLE item_links INTO DATA(item_link) WITH KEY source-%tky = batch-%tky.
      CHECK sy-subrc = 0.
      READ TABLE items INTO DATA(item) WITH KEY %tky = item_link-target-%tky.
      CHECK sy-subrc = 0.
      READ TABLE materials INTO DATA(material) WITH KEY material_id = item-MaterialId.
      CHECK sy-subrc = 0.

      READ TABLE receipt_links INTO DATA(receipt_link) WITH KEY source-%tky = batch-%tky.
      CHECK sy-subrc = 0.
      READ TABLE receipts INTO DATA(receipt) WITH KEY %tky = receipt_link-target-%tky.
      CHECK sy-subrc = 0.

      DATA(evaluation) = zcl_gr_shelf_life=>evaluate(
                           production_date = batch-ProductionDate
                           receipt_date    = receipt-ReceiptDate
                           shelf_life_days = material-shelf_life_days
                           min_percent     = CONV #( material-min_shelf_life_pct ) ).

      IF evaluation-is_expired = abap_true.
        APPEND VALUE #( %tky = batch-%tky ) TO failed-batch.
        APPEND VALUE #( %tky                    = batch-%tky
                        %path = VALUE #( receipt-%tky = VALUE #( %key-ReceiptUuid = batch-ReceiptUuid
                                                               %is_draft        = batch-%is_draft )
                                       item-%tky    = VALUE #( %key-ItemUuid    = batch-ItemUuid
                                                               %is_draft        = batch-%is_draft ) )
                        %state_area             = 'VALIDATE_EXPIRY'
                        %element-ProductionDate = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Lote caducado el { evaluation-expiry_date DATE = USER }| ) )
               TO reported-batch.
        CONTINUE.
      ENDIF.

      " No basta con que no este caducado: se pacta un porcentaje minimo de
      " vida util restante en el momento de la entrega.
      IF evaluation-is_acceptable = abap_false.
        APPEND VALUE #( %tky = batch-%tky ) TO failed-batch.
        APPEND VALUE #( %tky                    = batch-%tky
                        %path = VALUE #( receipt-%tky = VALUE #( %key-ReceiptUuid = batch-ReceiptUuid
                                                               %is_draft        = batch-%is_draft )
                                       item-%tky    = VALUE #( %key-ItemUuid    = batch-ItemUuid
                                                               %is_draft        = batch-%is_draft ) )
                        %state_area             = 'VALIDATE_EXPIRY'
                        %element-ProductionDate = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Vida util { evaluation-remaining_days } dias, | &&
                                            |minimo exigido { evaluation-required_days }| ) )
               TO reported-batch.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD validateSupplierBatch.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch
        FIELDS ( SupplierBatch ItemUuid ReceiptUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(batches).

    CHECK batches IS NOT INITIAL.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch BY \_Item
        FIELDS ( MaterialId )
        WITH CORRESPONDING #( batches )
      RESULT DATA(items)
      LINK DATA(item_links).

    CHECK items IS NOT INITIAL.

    SELECT material_id, material_name, batch_managed
      FROM zgr_material
      FOR ALL ENTRIES IN @items
      WHERE material_id = @items-MaterialId
      INTO TABLE @DATA(materials).

    LOOP AT batches INTO DATA(batch).

      APPEND VALUE #( %tky = batch-%tky
                      %path = VALUE #( receipt-%tky = VALUE #( %key-ReceiptUuid = batch-ReceiptUuid
                                                               %is_draft        = batch-%is_draft )
                                       item-%tky    = VALUE #( %key-ItemUuid    = batch-ItemUuid
                                                               %is_draft        = batch-%is_draft ) )
                      %state_area = 'VALIDATE_SUPPLIER_BATCH' ) TO reported-batch.

      CHECK batch-SupplierBatch IS INITIAL.

      READ TABLE item_links INTO DATA(link) WITH KEY source-%tky = batch-%tky.
      CHECK sy-subrc = 0.
      READ TABLE items INTO DATA(item) WITH KEY %tky = link-target-%tky.
      CHECK sy-subrc = 0.
      READ TABLE materials INTO DATA(material) WITH KEY material_id = item-MaterialId.
      CHECK sy-subrc = 0 AND material-batch_managed = abap_true.

      " Sin lote de proveedor la cadena de trazabilidad se rompe por el
      " extremo de origen: una retirada de producto no se podria acotar.
      APPEND VALUE #( %tky = batch-%tky ) TO failed-batch.
      APPEND VALUE #( %tky                   = batch-%tky
                      %path = VALUE #( receipt-%tky = VALUE #( %key-ReceiptUuid = batch-ReceiptUuid
                                                               %is_draft        = batch-%is_draft )
                                       item-%tky    = VALUE #( %key-ItemUuid    = batch-ItemUuid
                                                               %is_draft        = batch-%is_draft ) )
                      %state_area            = 'VALIDATE_SUPPLIER_BATCH'
                      %element-SupplierBatch = if_abap_behv=>mk-on
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = |Material por lote: lote proveedor obligatorio| ) )
             TO reported-batch.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_global_authorizations.

    result-%update              = if_abap_behv=>auth-allowed.
    result-%delete              = if_abap_behv=>auth-allowed.
    result-%action-blockBatch   = if_abap_behv=>auth-allowed.
    result-%action-releaseBatch = if_abap_behv=>auth-allowed.

  ENDMETHOD.


  METHOD get_instance_authorizations.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch
        FIELDS ( BatchUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(authorized_batches).

    result = VALUE #( FOR batch IN authorized_batches
                      ( %tky                    = batch-%tky
                        %update                 = if_abap_behv=>auth-allowed
                        %delete                 = if_abap_behv=>auth-allowed
                        %action-blockBatch      = if_abap_behv=>auth-allowed
                        %action-releaseBatch    = if_abap_behv=>auth-allowed ) ).

  ENDMETHOD.


  METHOD get_instance_features.

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch
        FIELDS ( BatchStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(batches).

    " Bloquear y liberar son excluyentes: solo se ofrece la que aplica
    result = VALUE #( FOR batch IN batches
                      ( %tky = batch-%tky
                        %action-blockBatch =
                          COND #( WHEN batch-BatchStatus = lcl_const=>batch_status-blocked
                                  THEN if_abap_behv=>fc-o-disabled
                                  ELSE if_abap_behv=>fc-o-enabled )
                        %action-releaseBatch =
                          COND #( WHEN batch-BatchStatus = lcl_const=>batch_status-free
                                  THEN if_abap_behv=>fc-o-disabled
                                  ELSE if_abap_behv=>fc-o-enabled ) ) ).

  ENDMETHOD.


  METHOD blockBatch.

    MODIFY ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch
        UPDATE FIELDS ( BatchStatus )
        WITH VALUE #( FOR key IN keys
                      ( %tky        = key-%tky
                        BatchStatus = lcl_const=>batch_status-blocked ) )
      REPORTED DATA(update_reported).

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(batches).

    result = VALUE #( FOR batch IN batches
                      ( %tky = batch-%tky %param = batch ) ).

  ENDMETHOD.


  METHOD releaseBatch.

    MODIFY ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch
        UPDATE FIELDS ( BatchStatus )
        WITH VALUE #( FOR key IN keys
                      ( %tky        = key-%tky
                        BatchStatus = lcl_const=>batch_status-free ) )
      REPORTED DATA(update_reported).

    READ ENTITIES OF zr_grreceipttp IN LOCAL MODE
      ENTITY Batch
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(batches).

    result = VALUE #( FOR batch IN batches
                      ( %tky = batch-%tky %param = batch ) ).

  ENDMETHOD.

ENDCLASS.


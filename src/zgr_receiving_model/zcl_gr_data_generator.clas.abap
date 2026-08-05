CLASS zcl_gr_data_generator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    METHODS clear_all.
    METHODS fill_master_data.
    METHODS fill_demo_receipts.

    " xco_cp=>uuid( )->value es la via liberada para ABAP Cloud.
    " Alternativa clasica: cl_system_uuid=>create_uuid_x16_static( ).
    METHODS new_uuid
      RETURNING VALUE(result) TYPE sysuuid_x16.
ENDCLASS.


CLASS zcl_gr_data_generator IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    clear_all( ).
    fill_master_data( ).
    fill_demo_receipts( ).

    SELECT COUNT(*) FROM zgr_supplier   INTO @DATA(suppliers).
    SELECT COUNT(*) FROM zgr_material   INTO @DATA(materials).
    SELECT COUNT(*) FROM zgr_dev_reason INTO @DATA(reasons).
    SELECT COUNT(*) FROM zgr_receipt    INTO @DATA(receipts).
    SELECT COUNT(*) FROM zgr_rec_item   INTO @DATA(items).
    SELECT COUNT(*) FROM zgr_batch      INTO @DATA(batches).

    out->write( |Datos de demo generados:| ).
    out->write( |  Proveedores .......... { suppliers }| ).
    out->write( |  Materiales ........... { materials }| ).
    out->write( |  Motivos de desviacion  { reasons }| ).
    out->write( |  Entradas ............. { receipts }| ).
    out->write( |  Posiciones ........... { items }| ).
    out->write( |  Lotes ................ { batches }| ).

  ENDMETHOD.


  METHOD clear_all.
    DELETE FROM zgr_uom.
    DELETE FROM zgr_batch_d.
    DELETE FROM zgr_rec_item_d.
    DELETE FROM zgr_receipt_d.
    DELETE FROM zgr_batch.
    DELETE FROM zgr_rec_item.
    DELETE FROM zgr_receipt.
    DELETE FROM zgr_material.
    DELETE FROM zgr_supplier.
    DELETE FROM zgr_dev_reason.

    COMMIT WORK.
  ENDMETHOD.


  METHOD fill_master_data.

    DATA uoms TYPE STANDARD TABLE OF zgr_uom WITH EMPTY KEY.
    uoms = VALUE #(
      ( uom_code = 'ST' description = 'Unidades / piezas'  uom_type = 'C' is_active = abap_true )
      ( uom_code = 'CAJ' description = 'Cajas'             uom_type = 'C' is_active = abap_true )
      ( uom_code = 'PAL' description = 'Palets'            uom_type = 'C' is_active = abap_true )
      ( uom_code = 'KG' description = 'Kilogramos'         uom_type = 'P' is_active = abap_true )
      ( uom_code = 'G'  description = 'Gramos'             uom_type = 'P' is_active = abap_true ) ).


    DATA suppliers TYPE STANDARD TABLE OF zgr_supplier WITH EMPTY KEY.
    suppliers = VALUE #(
      ( supplier_id = 'PROV001' supplier_name = 'Avicola del Sur, S.L.'      country = 'ES' is_active = abap_true )
      ( supplier_id = 'PROV002' supplier_name = 'Carnicas Guadalquivir, S.A.' country = 'ES' is_active = abap_true )
      ( supplier_id = 'PROV003' supplier_name = 'Pavos de Castilla, S.L.'     country = 'ES' is_active = abap_true )
      ( supplier_id = 'PROV004' supplier_name = 'Distribuciones Baja Ribera'  country = 'ES' is_active = abap_false ) ).

    " Los tres primeros son de doble unidad de medida: cada pieza pesa distinto.
    " El cuarto es de peso fijo, para que la validacion condicional se pueda probar.
    DATA materials TYPE STANDARD TABLE OF zgr_material WITH EMPTY KEY.
    materials = VALUE #(
      ( material_id = 'MAT001' material_name = 'Pollo entero fresco'
        base_unit = 'ST' weight_unit = 'KG' catch_weight = abap_true  batch_managed = abap_true
        shelf_life_days = 8  min_shelf_life_pct = 60
        weight_per_unit_min = '1.100' weight_per_unit_max = '1.900' )

      ( material_id = 'MAT002' material_name = 'Pechuga de pavo fresca'
        base_unit = 'ST' weight_unit = 'KG' catch_weight = abap_true  batch_managed = abap_true
        shelf_life_days = 10 min_shelf_life_pct = 60
        weight_per_unit_min = '2.000' weight_per_unit_max = '3.200' )

      ( material_id = 'MAT003' material_name = 'Panceta de cerdo'
        base_unit = 'ST' weight_unit = 'KG' catch_weight = abap_true  batch_managed = abap_true
        shelf_life_days = 12 min_shelf_life_pct = 55
        weight_per_unit_min = '3.500' weight_per_unit_max = '5.500' )

      ( material_id = 'MAT004' material_name = 'Bandeja muslo de pollo 1 kg'
        base_unit = 'ST' weight_unit = 'KG' catch_weight = abap_false batch_managed = abap_true
        shelf_life_days = 7  min_shelf_life_pct = 70
        weight_per_unit_min = '1.000' weight_per_unit_max = '1.000' ) ).

    DATA reasons TYPE STANDARD TABLE OF zgr_dev_reason WITH EMPTY KEY.
    reasons = VALUE #(
      ( reason_id = 'R001' description = 'Rotura o merma en transporte'      is_active = abap_true )
      ( reason_id = 'R002' description = 'Diferencia de peso en bascula'      is_active = abap_true )
      ( reason_id = 'R003' description = 'Temperatura fuera de rango'         is_active = abap_true )
      ( reason_id = 'R004' description = 'Diferencia de conteo de unidades'   is_active = abap_true )
      ( reason_id = 'R005' description = 'Documento de entrada incorrecto'    is_active = abap_true ) ).

    INSERT zgr_uom        FROM TABLE @uoms.
    INSERT zgr_supplier   FROM TABLE @suppliers.
    INSERT zgr_material   FROM TABLE @materials.
    INSERT zgr_dev_reason FROM TABLE @reasons.
    COMMIT WORK.

  ENDMETHOD.


  METHOD fill_demo_receipts.

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    " ---------- Entrada 1: conforme ----------
    DATA(receipt1_uuid) = new_uuid( ).
    DATA(item11_uuid)   = new_uuid( ).
    DATA(item12_uuid)   = new_uuid( ).

    " ---------- Entrada 2: con desviacion de peso ----------
    DATA(receipt2_uuid) = new_uuid( ).
    DATA(item21_uuid)   = new_uuid( ).

    DATA receipts TYPE STANDARD TABLE OF zgr_receipt WITH EMPTY KEY.
    receipts = VALUE #(
      ( receipt_uuid   = receipt1_uuid
        receipt_number = '0000000001'
        supplier_id    = 'PROV001'
        delivery_note  = 'ALB-2026-004812'
        receipt_date   = today
        plant_id       = '1000'
        overall_status = '1'
        total_quantity = '820.000'  total_unit  = 'ST'
        total_weight   = '1885.400' weight_unit = 'KG' )

      ( receipt_uuid   = receipt2_uuid
        receipt_number = '0000000002'
        supplier_id    = 'PROV002'
        delivery_note  = 'ALB-2026-004813'
        receipt_date   = today
        plant_id       = '1000'
        overall_status = '2'
        total_quantity = '160.000' total_unit  = 'ST'
        total_weight   = '702.500' weight_unit = 'KG' ) ).

    DATA items TYPE STANDARD TABLE OF zgr_rec_item WITH EMPTY KEY.
    items = VALUE #(
      ( item_uuid       = item11_uuid   receipt_uuid = receipt1_uuid
        item_number     = '0010'        material_id  = 'MAT001'
        qty_expected    = '500.000'     weight_expected = '750.000'
        qty_received    = '500.000'     weight_received = '748.200'
        base_unit       = 'ST'          weight_unit     = 'KG'
        qty_deviation   = '0.000'       weight_deviation = '-1.800'
        deviation_pct   = '-0.24'       item_status      = '1' )

      ( item_uuid       = item12_uuid   receipt_uuid = receipt1_uuid
        item_number     = '0020'        material_id  = 'MAT002'
        qty_expected    = '320.000'     weight_expected = '1140.000'
        qty_received    = '320.000'     weight_received = '1137.200'
        base_unit       = 'ST'          weight_unit     = 'KG'
        qty_deviation   = '0.000'       weight_deviation = '-2.800'
        deviation_pct   = '-0.25'       item_status      = '1' )

      " Desviacion de 47,5 kg: candidata a regularizacion con motivo
      ( item_uuid       = item21_uuid   receipt_uuid = receipt2_uuid
        item_number     = '0010'        material_id  = 'MAT003'
        qty_expected    = '160.000'     weight_expected = '750.000'
        qty_received    = '160.000'     weight_received = '702.500'
        base_unit       = 'ST'          weight_unit     = 'KG'
        qty_deviation   = '0.000'       weight_deviation = '-47.500'
        deviation_pct   = '-6.33'       item_status      = '2' ) ).

    " Codificacion de lote interno: AAAAMMDD + secuencial del dia
    DATA(day_prefix) = |{ today DATE = RAW }|.

    DATA batches TYPE STANDARD TABLE OF zgr_batch WITH EMPTY KEY.
    batches = VALUE #(
      ( batch_uuid   = new_uuid( )  item_uuid = item11_uuid
        batch_number = |{ day_prefix }0001|
        supplier_batch  = 'L-AVS-260803-A'
        production_date = today - 1  expiry_date = today + 7
        qty_units = '500.000' base_unit = 'ST'
        qty_weight = '748.200' weight_unit = 'KG'
        batch_status = '1' )

      ( batch_uuid   = new_uuid( )  item_uuid = item12_uuid
        batch_number = |{ day_prefix }0002|
        supplier_batch  = 'L-PVC-260802-K'
        production_date = today - 2  expiry_date = today + 8
        qty_units = '320.000' base_unit = 'ST'
        qty_weight = '1137.200' weight_unit = 'KG'
        batch_status = '1' )

      ( batch_uuid   = new_uuid( )  item_uuid = item21_uuid
        batch_number = |{ day_prefix }0003|
        supplier_batch  = 'L-CGQ-260801-3'
        production_date = today - 3  expiry_date = today + 9
        qty_units = '160.000' base_unit = 'ST'
        qty_weight = '702.500' weight_unit = 'KG'
        batch_status = '3' ) ).

    INSERT zgr_receipt  FROM TABLE @receipts.
    INSERT zgr_rec_item FROM TABLE @items.
    INSERT zgr_batch    FROM TABLE @batches.
    COMMIT WORK.

  ENDMETHOD.


  METHOD new_uuid.
    result = xco_cp=>uuid( )->value.
  ENDMETHOD.

ENDCLASS.


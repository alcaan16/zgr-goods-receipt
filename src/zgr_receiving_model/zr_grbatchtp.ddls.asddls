@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Entrada de mercancia - Lote'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_GRBatchTP
  as select from zgr_batch as Batch

  association to parent ZR_GRItemTP as _Item
    on $projection.ItemUuid = _Item.ItemUuid
{
  key batch_uuid            as BatchUuid,

      item_uuid             as ItemUuid,

      // Lote interno de fabrica: AAAAMMDD + secuencial
      batch_number          as BatchNumber,
      // Lote del proveedor: origen de la cadena de trazabilidad
      supplier_batch        as SupplierBatch,

      production_date       as ProductionDate,
      expiry_date           as ExpiryDate,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      qty_units             as QtyUnits,
      base_unit             as BaseUnit,

      @Semantics.quantity.unitOfMeasure: 'WeightUnit'
      qty_weight            as QtyWeight,
      weight_unit           as WeightUnit,

      batch_status          as BatchStatus,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Item
}

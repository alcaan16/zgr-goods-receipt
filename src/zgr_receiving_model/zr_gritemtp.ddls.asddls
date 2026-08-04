@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Entrada de mercancia - Posicion'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_GRItemTP
  as select from zgr_rec_item as Item

  composition [0..*] of ZR_GRBatchTP as _Batch

  association to parent ZR_GRReceiptTP as _Receipt
    on $projection.ReceiptUuid = _Receipt.ReceiptUuid

  association [0..1] to ZI_GRMaterial as _Material
    on $projection.MaterialId = _Material.MaterialId

  association [0..1] to ZI_GRDeviationReason as _DeviationReason
    on $projection.DeviationReason = _DeviationReason.ReasonId
{
  key item_uuid             as ItemUuid,

      receipt_uuid          as ReceiptUuid,
      item_number           as ItemNumber,
      material_id           as MaterialId,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      qty_expected          as QtyExpected,
      @Semantics.quantity.unitOfMeasure: 'WeightUnit'
      weight_expected       as WeightExpected,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      qty_received          as QtyReceived,
      @Semantics.quantity.unitOfMeasure: 'WeightUnit'
      weight_received       as WeightReceived,

      base_unit             as BaseUnit,
      weight_unit           as WeightUnit,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      qty_deviation         as QtyDeviation,
      @Semantics.quantity.unitOfMeasure: 'WeightUnit'
      weight_deviation      as WeightDeviation,
      deviation_pct         as DeviationPct,

      deviation_reason      as DeviationReason,
      deviation_note        as DeviationNote,
      item_status           as ItemStatus,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Receipt,
      _Batch,
      _Material,
      _DeviationReason
}

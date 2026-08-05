@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Entrada de mercancia - Cabecera (raiz)'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_GRReceiptTP
  as select from zgr_receipt as Receipt

  composition [0..*] of ZR_GRItemTP as _Item

  association [0..1] to ZI_GRSupplier as _Supplier
    on $projection.SupplierId = _Supplier.SupplierId
{
  key receipt_uuid          as ReceiptUuid,

      receipt_number        as ReceiptNumber,
      supplier_id           as SupplierId,
      delivery_note         as DeliveryNote,
      receipt_date          as ReceiptDate,
      plant_id              as PlantId,
      overall_status        as OverallStatus,

      total_quantity        as TotalQuantity,
      total_unit            as TotalUnit,
      total_weight          as TotalWeight,
      weight_unit           as WeightUnit,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Item,
      _Supplier
}

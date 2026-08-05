@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Entrada de mercancia - Lote - Proyeccion'
@Metadata.allowExtensions: true
define view entity ZC_GRBatchTP
  as projection on ZR_GRBatchTP
{
  key BatchUuid,

      ItemUuid,
      ReceiptUuid,
      BatchNumber,
      SupplierBatch,
      ProductionDate,
      ExpiryDate,

      QtyUnits,
      BaseUnit,
      QtyWeight,
      WeightUnit,

      BatchStatus,
      LocalLastChangedAt,

      /* Asociaciones */
      _Item : redirected to parent ZC_GRItemTP,
      _Receipt : redirected to ZC_GRReceiptTP
}

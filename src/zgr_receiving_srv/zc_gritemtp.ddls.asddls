@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Entrada de mercancia-Posicion-Proyec'
@Metadata.allowExtensions: true
define view entity ZC_GRItemTP
  as projection on ZR_GRItemTP
{
  key ItemUuid,

      ReceiptUuid,
      ItemNumber,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_GRMaterial', element: 'MaterialId' } }]
      @ObjectModel.text.element: ['MaterialName']
      MaterialId,
      _Material.MaterialName as MaterialName,

      QtyExpected,
      WeightExpected,
      QtyReceived,
      WeightReceived,

      BaseUnit,
      WeightUnit,

      QtyDeviation,
      WeightDeviation,
      DeviationPct,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_GRDeviationReason', element: 'ReasonId' } }]
      DeviationReason,
      DeviationNote,
      ItemStatus,

      LocalLastChangedAt,

      /* Asociaciones */
      _Receipt : redirected to parent ZC_GRReceiptTP,
      _Batch   : redirected to composition child ZC_GRBatchTP,
      _Material,
      _DeviationReason
}

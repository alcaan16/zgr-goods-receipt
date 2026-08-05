@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Entrada de mercancia - Proyeccion'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_GRReceiptTP
  provider contract transactional_query
  as projection on ZR_GRReceiptTP
{
  key ReceiptUuid,

      @Search.defaultSearchElement: true
      ReceiptNumber,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_GRSupplier', element: 'SupplierId' } }]
      @ObjectModel.text.element: ['SupplierName']
      SupplierId,
      _Supplier.SupplierName as SupplierName,

      @Search.defaultSearchElement: true
      DeliveryNote,

      ReceiptDate,
      PlantId,
      OverallStatus,

      TotalQuantity,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_GRUnitOfMeasure', element: 'UomCode' } }]
      TotalUnit,
      TotalWeight,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_GRUnitOfMeasure', element: 'UomCode' } }]
      WeightUnit,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Asociaciones */
      _Item : redirected to composition child ZC_GRItemTP,
      _Supplier
}

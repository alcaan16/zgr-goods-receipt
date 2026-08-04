@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Proveedor - vista de reutilizacion'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define view entity ZI_GRSupplier
  as select from zgr_supplier
{
      @Search.defaultSearchElement: true
  key supplier_id   as SupplierId,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      supplier_name as SupplierName,

      country       as Country,
      is_active     as IsActive
}

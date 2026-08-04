@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Motivo de desviacion - ayuda de busqueda'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_GRDeviationReason
  as select from zgr_dev_reason
{
      @Search.defaultSearchElement: true
  key reason_id   as ReasonId,

      @Search.defaultSearchElement: true
      description as Description,

      is_active   as IsActive
}

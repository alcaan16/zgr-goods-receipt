@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Unidad de medida - ayuda de busqueda'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_GRUnitOfMeasure
  as select from zgr_uom
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Unidad'
  key uom_code    as UomCode,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Descripcion'
      description as Description,

      // C cantidad / P peso. Permite filtrar la ayuda segun el campo
      uom_type    as UomType,
      is_active   as IsActive
}

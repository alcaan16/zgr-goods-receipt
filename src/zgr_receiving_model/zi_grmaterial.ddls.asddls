@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material - vista de reutilizacion'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define view entity ZI_GRMaterial
  as select from zgr_material
{
      @Search.defaultSearchElement: true
  key material_id         as MaterialId,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      material_name       as MaterialName,

      base_unit           as BaseUnit,
      weight_unit         as WeightUnit,

      // Material gestionado en dos unidades de medida a la vez.
      // Es el escenario que SAP cubre con Catch Weight Management.
      catch_weight        as IsCatchWeight,

      batch_managed       as IsBatchManaged,

      // Vida util total del producto, en dias
      shelf_life_days     as ShelfLifeDays,

      // Porcentaje minimo de vida util restante exigido al proveedor en recepcion
      min_shelf_life_pct  as MinShelfLifePct,

      // Rango admisible de peso por pieza. Fuera de rango = error de bascula o de conteo.
      weight_per_unit_min as WeightPerUnitMin,
      weight_per_unit_max as WeightPerUnitMax
}

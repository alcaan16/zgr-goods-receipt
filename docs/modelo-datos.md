# Modelo de datos

Árbol de composición de tres niveles. Cada entidad existe porque el proceso real la necesita, no
porque el modelo quede más bonito.

```
ZR_GRReceiptTP   Entrada de mercancía (raíz)
└── ZR_GRItemTP      Posición
    └── ZR_GRBatchTP     Lote
```

Fuera del árbol, tres vistas de reutilización sobre maestros simplificados:
`ZI_GRSupplier`, `ZI_GRMaterial`, `ZI_GRDeviationReason`.

---

## Entrada de mercancía — `zgr_receipt` / `ZR_GRReceiptTP`

| Campo | Por qué está |
|---|---|
| `ReceiptNumber` | Número de entrada asignado por el sistema |
| `SupplierId` | Proveedor |
| `DeliveryNote` | Número de albarán del proveedor. **Es el documento contra el que se verifica todo.** Sin él no hay recepción |
| `ReceiptDate` | Fecha de descarga; base para el cálculo de vida útil restante |
| `PlantId` | Centro |
| `OverallStatus` | `1` Borrador · `2` En revisión · `3` Registrada |
| `TotalQuantity` / `TotalUnit` | Total en unidades |
| `TotalWeight` / `WeightUnit` | Total en kilos |
| Campos administrativos | Los cinco de RAP. El ETag total vive en la raíz |

> Las dos parejas de total no son redundancia. En producto fresco, unidades y kilos son dos
> magnitudes independientes y ambas se reclaman por separado a un proveedor.

## Posición — `zgr_rec_item` / `ZR_GRItemTP`

| Campo | Por qué está |
|---|---|
| `MaterialId` | Material recibido |
| `QtyExpected` / `WeightExpected` | Lo que dice el albarán |
| `QtyReceived` / `WeightReceived` | Lo que dicen el conteo y la báscula |
| `QtyDeviation` / `WeightDeviation` / `DeviationPct` | Diferencia calculada, no tecleada |
| `DeviationReason` / `DeviationNote` | La regularización. Sin motivo no hay reclamación posible |
| `ItemStatus` | `1` Conforme · `2` Con desviación · `3` Desviación aceptada |

> Guardar esperado y recibido por separado, en vez de solo la diferencia, es lo que permite
> reconstruir después qué pasó. La diferencia es un dato derivado; los dos originales, no.

## Lote — `zgr_batch` / `ZR_GRBatchTP`

| Campo | Por qué está |
|---|---|
| `BatchNumber` | Lote interno de fábrica: `AAAAMMDD` + secuencial del día (ej. `202607310198`) |
| `SupplierBatch` | Lote del proveedor. **El eslabón que une la cadena hacia atrás** |
| `ProductionDate` | Fecha de producción declarada por el proveedor |
| `ExpiryDate` | Caducidad. Se calcula desde la vida útil del material, no se teclea |
| `QtyUnits` / `QtyWeight` | Las dos magnitudes también a nivel de lote |
| `BatchStatus` | `1` Libre · `2` Bloqueado · `3` En inspección |

> Que el lote sea una entidad propia y no dos campos en la posición es lo que hace posible partir
> una recepción de un mismo material en varios lotes con caducidades distintas. En una descarga
> real pasa constantemente.

---

## Maestros simplificados

### `zgr_material` / `ZI_GRMaterial`

El material es donde vive casi toda la inteligencia del proceso:

| Campo | Para qué sirve |
|---|---|
| `IsCatchWeight` | Marca el material gestionado en dos unidades. Activa la validación de peso obligatorio |
| `IsBatchManaged` | Activa la obligatoriedad del lote de proveedor |
| `ShelfLifeDays` | Vida útil total. Base del cálculo de caducidad |
| `MinShelfLifePct` | Porcentaje mínimo de vida útil restante exigido al proveedor en recepción |
| `WeightPerUnitMin` / `WeightPerUnitMax` | Rango admisible de peso por pieza. Base de la validación de plausibilidad |

### `zgr_supplier` / `ZI_GRSupplier`
Identificación y estado. Un proveedor inactivo no puede recibir mercancía.

### `zgr_dev_reason` / `ZI_GRDeviationReason`
Catálogo cerrado de motivos de desviación. Es la ayuda de búsqueda del parámetro de la acción de
regularización: si el motivo fuera texto libre, no se podría explotar después.

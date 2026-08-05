# Reglas de negocio

Cada regla de este documento sale de un problema que aparece en el muelle de descarga. Ninguna es
decorativa.

---

## Validations

### `validateSupplier` — Proveedor existe y está activo
Trivial pero necesaria: un proveedor dado de baja no puede aparecer en una entrada nueva.

### `validateMaterial` — Material existe
Ídem.

### `validateQuantities` — Cantidad positiva y peso obligatorio en doble unidad
Si `IsCatchWeight` está marcado, el peso es obligatorio y mayor que cero. En un material de peso
variable, registrar solo unidades no dice nada: 500 pollos pueden ser 550 kg o 950 kg.

**Este es el escenario que SAP cubre con Catch Weight Management.**

### `validateWeightPlausibility` — Peso medio por pieza dentro de rango
```
peso_medio = WeightReceived / QtyReceived
si peso_medio < WeightPerUnitMin  o  peso_medio > WeightPerUnitMax  →  error
```
La regla que no aparece en ningún ejemplo de tutorial. Si entran 320 unidades y 6.500 kg de un
producto cuya pieza pesa entre 2 y 3,2 kg, no hay una desviación: hay un error de báscula o un error
de conteo, y registrarlo contamina el stock y la trazabilidad.

Se detecta en el momento de la entrada o no se detecta nunca.

### `validateExpiryDate` — Caducidad válida y vida útil restante suficiente
Dos comprobaciones:
1. `ExpiryDate > ReceiptDate` — obvio.
2. Vida útil restante ≥ el mínimo pactado con el proveedor:
```
dias_restantes  = ExpiryDate - ReceiptDate
dias_requeridos = ShelfLifeDays × MinShelfLifePct / 100
si dias_restantes < dias_requeridos  →  error
```
Un producto con 8 días de vida útil que llega con 2 no sirve: para cuando pase por producción y
llegue al cliente, está caducado. Es una condición de compra, y aquí se comprueba sola.

### `validateSupplierBatch` — Lote de proveedor obligatorio si el material lo requiere
Si `IsBatchManaged`, sin lote de proveedor no hay entrada. Es el extremo de la cadena de
trazabilidad: sin él, una retirada de producto no se puede acotar y hay que retirar todo.

### `validateBatchQuantities` — Los lotes cuadran con la posición
La suma de `QtyUnits` y de `QtyWeight` de los lotes es igual a `QtyReceived` y `WeightReceived` de
la posición. Si no cuadra, hay mercancía sin asignar a ningún lote.

---

## Determinations

| Determination | Cuándo | Qué calcula |
|---|---|---|
| `setReceiptNumber` | on save, create | Número de entrada correlativo |
| `setItemNumber` | on modify, create | Número de posición, de 10 en 10 |
| `setInitialStatus` | on modify, create | Estado `1` Borrador |
| `calculateInternalBatchCode` | on modify, create de lote | `AAAAMMDD` + secuencial del día |
| `calculateExpiryDate` | on modify, create/update de fecha de producción | `ProductionDate + ShelfLifeDays` |
| `calculateDeviation` | on modify, create/update de cantidades | Desviación en unidades, en kg y en % |
| `calculateHeaderTotals` | on modify sobre posición y lote | Totales de cabecera en las dos unidades |

Ninguno de estos campos se teclea. Un campo calculado que además es editable es un campo que va a
estar mal tarde o temprano.

---

## Actions

| Acción | Ámbito | Efecto |
|---|---|---|
| `acceptDeviation` | Posición | Registra motivo (`ZI_GRDeviationReason`) y comentario; pasa la posición a `3` Desviación aceptada |
| `postReceipt` | Cabecera | Cierra la entrada y la pasa a `3` Registrada |
| `blockBatch` | Lote | Pasa el lote a `2` Bloqueado |
| `releaseBatch` | Lote | Devuelve el lote a `1` Libre |

`acceptDeviation` es la regularización. No corrige el peso: deja constancia de que alguien con
criterio decidió aceptar la diferencia y por qué motivo. Esa distinción importa — sobrescribir el
peso recibido borraría la evidencia de la reclamación.

---

## Feature control

| Regla | Motivo |
|---|---|
| `postReceipt` deshabilitada si hay posiciones en estado `2` | No se registra una entrada con discrepancias sin resolver |
| `acceptDeviation` oculta si la posición no tiene desviación | Un botón que no hace nada es ruido |
| Cantidades en solo lectura con la entrada registrada | Después de registrar, se corrige con un documento nuevo, no editando el anterior |

---

## Estructura del comportamiento

```
managed implementation in class zbp_r_grreceipttp unique;
strict ( 2 );
with draft;
```

Las tres entidades declaran `authorization master ( instance, global )`. La raíz es además
`lock master`; posiciones y lotes son `lock dependent by _Receipt`, apuntando directamente a la
raíz y no al padre inmediato, como exige RAP.

Con `strict ( 2 )` y draft activado, **todas las validaciones deben declararse dentro de la acción
`Prepare`** de la raíz, cualificadas con el alias de su entidad. Tiene sentido: `Prepare` es lo que
decide si un borrador puede activarse, así que RAP exige que quede explícito qué se comprueba en ese
momento.

```abap
  draft determine action Prepare
  {
    validation validateSupplier;
    validation Item~validateMaterial;
    validation Item~validateQuantities;
    validation Item~validateWeightPlausibility;
    validation Item~validateBatchQuantities;
    validation Batch~validateExpiryDate;
    validation Batch~validateSupplierBatch;
  }
```

---

## Lógica extraída a clases puras

Las cuatro clases siguientes no conocen RAP ni la base de datos. Reciben valores, devuelven
valores, y por eso se pueden probar con ABAP Unit sin levantar nada:

| Clase | Entrada | Salida |
|---|---|---|
| `zcl_gr_batch_code` | fecha, secuencial | código de lote `AAAAMMDD9999` |
| `zcl_gr_shelf_life` | fecha producción, vida útil, % mínimo, fecha recepción | caducidad + si cumple el mínimo |
| `zcl_gr_deviation` | esperado, recibido | desviación absoluta y porcentual |
| `zcl_gr_weight_check` | unidades, peso, rango por pieza | peso medio + si es plausible |

La implementación del comportamiento se limita a leer datos, llamar a estas clases y traducir el
resultado a mensajes de RAP. Es la separación que hace que la lógica se pueda probar.

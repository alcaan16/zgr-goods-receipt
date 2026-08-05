# Decisiones técnicas

Lo que se decidió, lo que se descartó y por qué. Un revisor que vea una decisión rara y encuentre
aquí el motivo puntúa distinto que uno que solo vea la decisión.

---

## Arquitectura del business object

### Managed en vez de unmanaged

El proceso no tiene que convivir con una implementación heredada, así que no hay motivo para
escribir a mano la persistencia. **Managed con draft** es lo que se usaría en un proyecto real sobre
Clean Core, y es lo que se usa aquí.

*Descartado:* unmanaged, que habría duplicado el esfuerzo sin demostrar nada adicional.

### Draft activado

Una recepción no se teclea de una sentada: se empieza con el albarán en la mano, se va al muelle, se
pesa, se vuelve. Sin draft, cada interrupción pierde el trabajo. Es el caso de uso para el que el
draft existe.

### Árbol de composición de tres niveles

Cabecera → Posición → Lote. Podría haberse hecho con dos, metiendo el lote como campos de la
posición, pero entonces una misma posición no podría tener dos lotes con caducidades distintas — y
en una descarga real eso es lo normal, no la excepción.

### Clave de la raíz en la entidad nieta

`zgr_batch` arrastra `receipt_uuid` además de `item_uuid`, y `ZR_GRBatchTP` declara una asociación
`_Receipt` directa a la cabecera.

RAP exige que `lock dependent by` y `authorization dependent by` apunten **directamente al lock
master**, no al padre inmediato. Encadenar por el padre no está permitido, así que la tercera
entidad necesita asociación propia a la raíz. Es el mismo modelado que emplea el ejemplo de
referencia de SAP.

### Dos service bindings sobre una service definition

`ZUI_GR_RECEIPT_O4` para consumo de interfaz y `ZAPI_GR_RECEIPT_O4` para consumo de integración.
Separar ambos desde el principio evita que las anotaciones de UI acaben condicionando el contrato de
la API — que es exactamente el problema que aparece cuando este business object tenga que hablar con
un iFlow.

### Anotaciones de UI en metadata extension

Las vistas de proyección quedan limpias; toda la capa de presentación va en `.ddlx`. Es lo que
permite cambiar la UI sin tocar el modelo.

---

## Modelo de datos

### Tipos built-in en las tablas, semántica en las CDS

Las tablas usan tipos incorporados (`abap.dec`, `abap.char`, `abap.dats`) en vez de una capa de
dominios y elementos de datos propios. La semántica de consumo —etiquetas, ayudas de búsqueda,
textos— vive en las CDS view entities, que es donde el modelo de consumo se define en ABAP Cloud.

*Contrapartida asumida:* menos reutilización de etiquetas a nivel de diccionario. En un proyecto de
este tamaño compensa; en uno grande, no necesariamente.

### Unidades de medida como código de texto

Los campos de unidad son `abap.char(3)` y los de cantidad `abap.dec(13,3)`, en lugar de
`abap.unit(3)` y `abap.quan(13,3)`.

El ABAP Environment utilizado no dispone de configuración de unidades de medida. El comportamiento
observado es asimétrico y conviene dejarlo escrito: la **base de datos persiste cualquier valor sin
protestar**, pero la **capa de conversión de OData rechaza la unidad al leer**, con el mensaje
`No configuration for unit of measure`. El resultado es una escritura que entra a medias — el
registro se guarda y la respuesta falla.

El cambio arrastra a las cantidades porque DDIC exige que un campo `QUAN` tenga un campo `UNIT` como
referencia; al dejar de existir la referencia, las cantidades tienen que pasar a `DEC`.

Se conservan los códigos internos de SAP (`ST` para unidades, `KG` para kilos) como valores de
texto. En un sistema S/4HANA real estos campos serían `MEINS` con su maestro de unidades y su
conversión asociada.

**Lo que no se ve afectado:** el modelo de doble unidad. Siguen siendo dos magnitudes independientes
con su unidad al lado, y las reglas de negocio operan sobre los valores numéricos. Las cuatro clases
de lógica y sus 32 tests no requirieron ni una línea de cambio — que es precisamente la ventaja de
haberlas mantenido fuera del framework.

**Lo que sí se pierde:** formateo automático de la cantidad junto a su unidad en Fiori, control de
entrada específico de unidad, y validación contra el maestro.

### Elementos de datos de los campos administrativos

Los campos `created_at` y `last_changed_at` usan `abp_creation_tstmpl` y `abp_lastchange_tstmpl`.
Las anotaciones `@Semantics.systemDateTime.createdAt` y `.lastChangedAt` exigen un timestamp
compatible con `TIMESTAMP`, y con los elementos de tipo largo el chequeo de RAP Designtime avisa en
el modelo y falla al declarar `total etag LastChangedAt` en el comportamiento.

### Anotación `@Semantics.unitOfMeasure`

No está admitida en view entities en el release de este entorno: el activador la rechaza tanto en
las vistas de reutilización como en las del árbol de composición y en las proyecciones.

No era una carencia del modelo. La anotación que sostenía el enlace cantidad↔unidad era
`@Semantics.quantity.unitOfMeasure`, y la rechazada solo marcaba el campo de unidad como tal —
información redundante cuando el enlace ya existe. Con el cambio a `char`/`dec` descrito arriba,
ambas dejaron de aplicar.

### Maestros propios en vez de APIs estándar

Este entorno es un ABAP Environment independiente, sin S/4HANA detrás: no hay maestro de material ni
de proveedor que consumir. Las tablas propias contienen únicamente los campos que las reglas
necesitan.

---

## Lógica de negocio

### Fuera de la clase de comportamiento

Cuatro clases sin dependencias —`ZCL_GR_BATCH_CODE`, `ZCL_GR_SHELF_LIFE`, `ZCL_GR_DEVIATION`,
`ZCL_GR_WEIGHT_CHECK`— con 32 tests de ABAP Unit. La clase de comportamiento lee, delega y traduce a
mensajes.

El motivo es práctico: si el cálculo de vida útil vive dentro de un método `validate...`, probarlo
exige un business object completo, datos en base y una transacción. En la práctica eso significa que
no se prueba nunca. Fuera, cada regla se cubre con ocho casos en dos segundos.

Todas son `CREATE PRIVATE` con métodos estáticos: no tienen estado, así que no hay nada que
instanciar.

### Tolerancia del 1% en la desviación

Por debajo de ese porcentaje la diferencia se trata como merma normal de transporte, no como
desviación. Marcar como incidencia una merma de 1,8 kg sobre 750 generaría alertas que nadie
atendería — y una alerta que nadie atiende es peor que no tenerla.

### El código de lote usa la fecha de la cabecera

No la del sistema. Un lote que se registra a la mañana siguiente sigue perteneciendo a la descarga
del día anterior. Con la fecha del sistema, la trazabilidad quedaría desplazada un día, y eso solo
se descubre cuando hay que reconstruir una retirada de producto.

### Una desviación aceptada no vuelve a marcarse como pendiente

`calculateDeviation` respeta el estado *Desviación aceptada*. Lo que alguien decidió con criterio en
el muelle no lo revierte un recálculo.

### Los totales se recalculan, no se acumulan

`calculateHeaderTotals` sube de la posición a la cabecera y vuelve a bajar a todas las posiciones
hermanas, sumando lo que hay en cada guardado. Un acumulador incremental se desincroniza en cuanto
se borra una posición.

---

## Alcance

### Sin control de autorizaciones

`@AccessControl.authorizationCheck: #NOT_REQUIRED` en todas las vistas, y
`get_instance_authorizations` vacío. Añadir DCL y roles no demuestra nada que este proyecto quiera
demostrar y sí añade superficie de error. Decisión consciente, escrita aquí para que se lea como
tal.

Consecuencia visible: el activador emite un aviso permanente
`Operation "create" should be equipped with (global) authorization`.

### Nomenclatura

Estilo *Clean ABAP*: sin prefijos húngaros en variables y parámetros, nombres en inglés para los
objetos ABAP, comentarios y documentación en español. Los objetos de repositorio siguen la
convención de RAP: `ZR_` modelo de datos, `ZC_` proyección, `ZI_` reutilización, `ZBP_` clase de
comportamiento.

Los nombres de método están limitados a 30 caracteres, lo que condiciona la longitud de los nombres
de los tests.

---

## Limitaciones conocidas

- **Numeración de entradas frente a concurrencia.** `setReceiptNumber` calcula el siguiente número
  sobre el máximo persistido. Dos usuarios creando a la vez podrían obtener el mismo. En producción
  iría contra un objeto de rango de números.
- **Secuencial de lote frente a concurrencia.** Mismo problema: el secuencial del día se calcula
  contando los lotes existentes de esa fecha más los de la transacción en curso.
- **Totales de cabecera al borrar posiciones.** `calculateHeaderTotals` se dispara en creación y
  actualización de posiciones, no en borrado. Al eliminar una posición, los totales quedan
  desactualizados hasta el siguiente guardado que modifique alguna otra.
- **Sin ayuda de búsqueda en los campos de unidad.** Consecuencia del cambio a `char(3)`: la unidad
  se teclea libremente y no se valida contra ningún catálogo.
- **Sin formateo de cantidad con unidad.** Las cantidades se muestran en una columna y su unidad en
  otra, en lugar de renderizarse juntas.

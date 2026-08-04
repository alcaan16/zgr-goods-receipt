# Decisiones técnicas

Lo que se decidió, lo que se descartó y por qué. Un revisor que vea una decisión rara y encuentre
aquí el motivo puntúa distinto que uno que solo vea la decisión.

---

## Managed en vez de unmanaged

El proceso no tiene que convivir con una implementación heredada, así que no hay motivo para
escribir a mano la persistencia. **Managed con draft** es lo que se usaría en un proyecto real
sobre Clean Core, y es lo que se usa aquí.

*Descartado:* unmanaged, que habría duplicado el esfuerzo sin demostrar nada adicional.

## Draft activado

Una recepción no se teclea de una sentada: se empieza con el albarán en la mano, se va al muelle,
se pesa, se vuelve. Sin draft, cada interrupción pierde el trabajo. Es el caso de uso para el que
el draft existe.

## Árbol de composición de tres niveles

Cabecera → Posición → Lote. Podría haberse hecho con dos, metiendo el lote como campos de la
posición, pero entonces una misma posición no podría tener dos lotes con caducidades distintas — y
en una descarga real eso es lo normal, no la excepción.

## Tipos built-in en las tablas, semántica en las CDS

Las tablas usan tipos incorporados (`abap.quan`, `abap.unit`, `abap.dats`) en vez de una capa de
dominios y elementos de datos propios. La semántica de consumo —etiquetas, unidades, ayudas de
búsqueda, textos— vive en las CDS view entities, que es donde el modelo de consumo se define en
ABAP Cloud.

*Contrapartida asumida:* menos reutilización de etiquetas a nivel de diccionario. En un proyecto de
este tamaño compensa; en uno grande, no necesariamente.

## Dos service bindings sobre una service definition

`ZUI_GR_RECEIPT_O4` para consumo de interfaz y `ZAPI_GR_RECEIPT_O4` para consumo de integración.
Separar ambos desde el principio evita que las anotaciones de UI acaben condicionando el contrato
de la API — que es exactamente el problema que aparece cuando este business object tenga que
hablar con un iFlow.

## Anotaciones de UI en metadata extension

Las vistas de proyección quedan limpias; toda la capa de presentación va en `.ddlx`. Es lo que
permite cambiar la UI sin tocar el modelo.

## Lógica de negocio fuera de la clase de comportamiento

Cuatro clases sin dependencias, con sus tests de ABAP Unit. La clase de comportamiento lee, delega
y traduce a mensajes. Poner el cálculo de vida útil dentro de un método `validate...` lo haría
imposible de probar sin un business object completo.

## Maestros propios en vez de APIs estándar

Este entorno es un ABAP Environment independiente, sin S/4HANA detrás: no hay maestro de material ni
de proveedor que consumir. Las tablas propias contienen únicamente los campos que las reglas
necesitan. Está documentado en el README como límite del proyecto, no disimulado.

## Sin control de autorizaciones

`@AccessControl.authorizationCheck: #NOT_REQUIRED` en todas las vistas. Añadir DCL y roles no
demuestra nada que este proyecto quiera demostrar y sí añade superficie de error. Decisión
consciente, escrita aquí para que se lea como tal.

## Nomenclatura

Estilo *Clean ABAP*: sin prefijos húngaros en variables y parámetros, nombres en inglés para los
objetos ABAP, comentarios y documentación en español. Los objetos de repositorio siguen la
convención de RAP: `ZR_` modelo de datos, `ZC_` proyección, `ZI_` reutilización, `ZBP_` clase de
comportamiento.

---

## Limitaciones conocidas

- **Secuencial de lote y concurrencia.** El secuencial del día se calcula contando los lotes
  existentes de esa fecha. Con dos usuarios creando lotes a la vez podría repetirse. En producción
  esto iría contra un objeto de rango de números.
- `TODO — añadir las que aparezcan. La lista de limitaciones conocidas es parte del entregable.`

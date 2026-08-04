# Entrada de mercancía con gestión de lote y doble unidad de medida

> ⚠️ **BORRADOR — repositorio privado hasta M6.** Los bloques marcados con `TODO` se completan a
> medida que avanzan los hitos. El repositorio no se hace público hasta que este aviso desaparezca
> y las capturas estén dentro.

Business object RAP sobre **SAP BTP ABAP Environment** que modela la recepción de mercancía en una
planta de industria cárnica: verificación contra documento de entrada, registro simultáneo en
unidades y kilos, asignación de lote con fecha de caducidad y regularización de discrepancias.

---

## 1. Qué problema resuelve

En una planta de producto fresco, una recepción no se cierra contando bultos. Cada palet entra con
dos cantidades a la vez —unidades y kilos— porque cada pieza pesa distinto, y ninguna de las dos se
puede deducir de la otra. A eso se suma que la mercancía llega con un lote de proveedor que hay que
enlazar con el lote interno de fábrica, y con una fecha de caducidad que decide el orden en que ese
producto va a salir después.

Cuando el peso de la báscula no cuadra con el del albarán, alguien tiene que decidir en el muelle si
eso es una merma asumible, un error de conteo o un problema con el proveedor — y dejarlo registrado
con un motivo, porque de ahí salen las reclamaciones.

Este proyecto modela ese proceso: **el que llevé durante ocho años en recepción**, ~30.000 kg y
unos 10 camiones diarios. Es el escenario que SAP cubre con Catch Weight Management, Batch
Management y control de SLED.

## 2. Stack y arquitectura

- **ABAP Cloud** sobre SAP BTP ABAP Environment (versión de lenguaje *ABAP for Cloud Development*)
- **RAP** — business object *managed*, con draft, sobre un árbol de composición de tres niveles
- **CDS view entities** para el modelo de datos y las vistas de reutilización
- **OData V4**, con dos service bindings sobre la misma service definition: uno de UI y uno de API
- Lógica de negocio extraída a **clases ABAP puras con ABAP Unit**, fuera de la implementación del
  comportamiento

```
Entrada de mercancía (raíz)
└── Posición
    └── Lote
```

## 3. Alcance técnico

### Implementado

`TODO — se rellena a partir de M4. No prometer aquí lo que aún no esté activado.`

### No implementado (y por qué)

- **No hay app Fiori Elements propia.** La interfaz que se ve en las capturas es la *preview* que
  genera el service binding a partir de las anotaciones de UI.
- **No hay integración con S/4HANA.** Los maestros de material y proveedor son tablas propias
  simplificadas, con solo los campos que las reglas de negocio necesitan.
- **No hay control de autorizaciones (DCL).** Las vistas van con
  `@AccessControl.authorizationCheck: #NOT_REQUIRED`. Es una decisión consciente de alcance, no un
  olvido: añadir roles no aporta nada a lo que este proyecto quiere demostrar.
- `TODO — limitaciones que aparezcan durante la construcción. Se escriben, no se esconden.`

## 4. Cómo ejecutarlo

`TODO — pasos reales, probados en limpio, a partir de M6.`

Guion previsto:
1. Clonar el repositorio en un paquete de un ABAP Environment vía abapGit (plugin para ADT).
2. Activar todo el paquete.
3. Ejecutar `ZCL_GR_DATA_GENERATOR` con *Run As → ABAP Application* para poblar maestros y datos de
   demo.
4. Abrir el service binding `ZUI_GR_RECEIPT_O4` y lanzar la *preview*.

## 5. Capturas

`TODO — M6:`
- Diagrama del modelo de datos
- Árbol de composición en la preview, con una posición mostrando unidades y kilos a la vez
- Un mensaje de validación disparándose
- La acción de aceptar desviación con su motivo
- Resultado del chequeo ATC
- Resultado de ABAP Unit

---

## Documentación

| Documento | Contenido |
|---|---|
| [`docs/modelo-datos.md`](docs/modelo-datos.md) | Entidades, campos y por qué cada uno existe |
| [`docs/reglas-negocio.md`](docs/reglas-negocio.md) | Determinations, validations y acciones |
| [`docs/decisiones-tecnicas.md`](docs/decisiones-tecnicas.md) | Decisiones de diseño y sus alternativas descartadas |

## Autor

Ángel Alférez Castro — SAP Developer (ABAP Cloud · BTP/CAP)
SAP Certified Associate: C_ABAPD · C_CPE · C_CPI

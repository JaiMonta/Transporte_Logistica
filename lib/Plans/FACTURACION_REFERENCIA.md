# Facturación — Referencia del Excel (liquidación semanal)

Documento de referencia del análisis de un archivo de liquidación semanal real,
usado para contrastar el motor de facturación del sistema. **No contiene código
ni datos de empresas/personas** (regla dura §1).

Fuente analizada: `LIQUIDACION ELIAGNYS.xlsm` (hoja semanal del transportista).

## Hojas del archivo

- **RELACIÓN** — detalle por **guía/viaje**: `Nº Guía(s) | Cliente | Destino |
  Región | Fecha | Pasta(Kgs) | Confites(Cjs) | Confites(Kgs) | Harina kg |
  Total Kgs | KGS PASTA | PEAJE | KG CARGA | Cap. | Tipo | Chofer |
  BASE DE FLETE | C (caleta) | M (mora) | D (desvío)`. Varias filas comparten el
  Nº de guía del viaje (cada fila = una entrega). El **Nº de guía** equivale a
  nuestro **manifiesto**.
- **FACTURAS** — factura **por cliente** con desglose:
  `FLETE + FLETE SECUNDARIO + REPARTO + DESVIO + PEAJE + MORA + FIN DE SEMANA`,
  subtotal/exento/IVA/total, y recuadro de control por cliente.
- **CALETAS EXT** — caletas de un proveedor externo (transportista tercero).
- **Imprimir** — versión imprimible de RELACIÓN.
- **CALCULOS** — simuladores de flete/caleta/reparto por **kilos de pasta**
  (`valor × (kilos / capacidad)` → prorrateo PASTAS vs NUCITA) y estructura de
  costos (cauchos, gasoil, gomas, costos fijos).
- **Tabulador** — tarifas.

## Conceptos: Excel vs. sistema

| Concepto | Excel | Sistema | Nota |
| --- | --- | --- | --- |
| Flete base por viaje/manifiesto | Sí | Sí | Coincide |
| Caleta (2 por guía) | Sí (col. C = 2) | Sí (2 × tarifa) | Coincide |
| **Flete secundario** | Sí | — | **Es la caleta con otro nombre** |
| Reparto | Sí | Sí | Coincide |
| Desvío | Sí | Sí (tramos) | Coincide |
| Mora | Sí | Sí | Coincide |
| Fin de semana | Sí | Sí (+5%) | Coincide |
| **Peaje** | Sí | No | Concepto del Excel; no implementado |
| Período | Semana lunes–domingo | Semana lunes–domingo | Coincide |
| Unidad facturada | Por **cliente** | Por **semana** (desglose por chofer) | Ver decisiones |

## Decisiones tomadas

1. **No facturar por cliente** por ahora: se mantiene **una factura semanal**
   (lunes→domingo) desglosada por chofer, con **un solo producto/cliente**. El
   esquema "por cliente" del Excel queda como referencia futura.
2. **"Flete secundario" = la caleta.** Si en el futuro se importa del Excel,
   mapear `FLETE SECUNDARIO → caleta`.
3. **Prorrateo diferido:** hoy no aplica (un producto). Cuando haya varios
   productos en un camión (pasta/confite/harina), el **peso principal es pasta**
   y el resto se reparte. Las **fórmulas están en la columna "flete"** del Excel.
4. **CALETAS EXT (proveedor externo): no necesario.**

## Pendiente futuro

- **Prorrateo multi-producto** (pasta principal, resto harina/confite) usando las
  fórmulas de la columna "flete" del Excel.
- **Peaje** como concepto, si llega a aplicar.
- **Facturación por cliente**, si se requiere además de la semanal.

# FLEETIQ — Driver OS & Control Central
## Presentación Ejecutiva y Flujo Operativo de la Plataforma
*Guía de Diapositivas para PowerPoint / Google Slides / Keynote*

---

### DIAPOSITIVA 1: Portada
- **Título**: FLEETIQ — Driver OS & Control Central
- **Subtítulo**: Plataforma Unificada de Telemetría Fría, Despacho, Liquidación 1099 y Facturación para Flotas de Transporte Terrestre.
- **Caso de Uso**: Armando Garza — *Owner-Operator & Administrador Dual de Flota*.
- **Elementos Visuales**:
  - Logotipo oficial de FLEETIQ.
  - Composición de interfaz dual: Monitor de escritorio (Web Desktop) y Smartphone (Flutter Material 3).
- **Notas del Orador**: "FLEETIQ resuelve la desconexión histórica entre el trabajo administrativo de oficina y la realidad operativa del chofer en carretera, unificando ambas funciones en tiempo real."

---

### DIAPOSITIVA 2: El Desafío Operativo del "Dual Driver"
- **Título**: El Problema del Dueño-Operador en Ruta
- **Puntos Clave**:
  - **Fricción de Roles**: El administrador pasa hasta el 60% de su jornada conduciendo y el 40% gestionando incidencias operativas desde la cabina.
  - **Pérdida de Comprobantes**: Tickets de casetas arrugados, firmas ilegibles y cartas porte en papel extraviadas.
  - **Zonas Ciegas sin Internet**: Pérdida de comunicación en tramos carreteros federales y naves industriales blindadas.
  - **Ciclos de Cobro Lentos**: Demoras de 15 a 30 días para liquidar a choferes 1099 y facturar a clientes comerciales por falta de PODs legibles.
- **Notas del Orador**: "Un dueño-operador no puede detener su camión para revisar hojas de cálculo complejas. Necesita una herramienta que le permita operar en segundos y sin riesgo al volante."

---

### DIAPOSITIVA 3: Arquitectura del Ecosistema FLEETIQ
- **Título**: Un Solo Sistema, Dos Entornos Optimizados
- **Estructura en 2 Columnas**:
  - **Columna 1: Panel Web Desktop (Control Central)**
    - Diseñado para oficina y escritorio.
    - Pantalla panorámica con tablas densas y split-view forense.
    - Timbrado masivo CFDI 4.0 y exportación bancaria ACH/SPEI.
    - Telemetría satelital multi-unidad en tiempo real.
  - **Columna 2: App Móvil (Flutter Material 3 - Driver OS)**
    - Ergonomía táctil para una sola mano con áreas de toque amplias (mínimo 48x48dp).
    - Modo dual Chofer / Administrador con switch rápido de perfil.
    - Arquitectura Offline-First con base de datos local SQLite/Drift cifrada.
    - OCR móvil con retroalimentación instantánea de calidad.
- **Notas del Orador**: "No es una simple adaptación web responsive; son dos interfaces creadas específicamente para las condiciones ergonómicas de cada momento de uso."

---

### DIAPOSITIVA 4: Flujo 1 — Despacho y Creación de Rutas
- **Título**: De Contrato a Hoja de Ruta en Minutos
- **Puntos Clave**:
  - **Asignación Rápida**: Vinculación de tractor, remolque y chofer contratista con verificación de licencia y Horas de Servicio (HOS).
  - **Balance Técnico y Cadena de Frío**:
    - Distribución de peso por ejes (cumplimiento DOT 52/48).
    - Calibración de temperatura para carga perecedera (-4°C Reefer).
  - **Economía del Despacho**: Cálculo automático de margen bruto (ej. $1,150 USD facturado / $380 USD pago contratista = 67% margen).
  - **Despacho Push**: Envío instantáneo a la terminal del chofer con notificación prioritaria.
- **Pantalla Asociada**: *Despacho y Asignación de Rutas (Desktop & Mobile)*.

---

### DIAPOSITIVA 5: Flujo 2 — En Cabina y Navegación ("Driver OS")
- **Título**: Ergonomía al Volante y Navegación Táctica
- **Puntos Clave**:
  - **Modo Dual Driver**: Monitoreo de telemetría de cabina (ThermoKing BLE, nivel de diésel 82%, HOS restante 05h 12m).
  - **Secuencia de Paradas del Día**: Lista cronológica de entregas con estatus en vivo (Recolectado, En Ruta, Pendiente).
  - **Navegación 1-Tap**: Conexión nativa hacia Google Maps y Waze con coordenadas exactas de muelles y accesos pesados.
  - **Geocercas de Arribo**: Botón inteligente "¡Llegué al Destino!" que notifica al cliente y abre la inspección de rampa.
- **Pantalla Asociada**: *Mi Cabina & Modo Dual Driver / Detalle de Entrega*.

---

### DIAPOSITIVA 6: Flujo 3 — Captura Digital de POD y OCR Forense
- **Título**: Digitalización Inmediata y Cero Papeles Perdidos
- **Puntos Clave**:
  - **Escaneo Guiado en Campo**: Alineación asistida por cámara, detección automática de márgenes y sello de almacén.
  - **Validación Forense al Instante**: Extracción de folio de manifiesto (#MN-8921), bultos entregados, firma digitalizada y temperatura de descarga (3.8°C).
  - **Cotejo Automatizado con SAT**: Match automático de la Carta Porte antes de que el chofer abandone las instalaciones.
  - **Panel de Auditoría Desktop**: Visor comparativo con zoom forense para aprobación en 1 clic de documentos dudosos.
- **Pantalla Asociada**: *Captura de Manifiesto y OCR Móvil / Manifiestos y Verificación OCR Desktop*.

---

### DIAPOSITIVA 7: Flujo 4 — Gestión Offline y Resiliencia en Ruta
- **Título**: Continuidad Operativa 100% Desconectada
- **Puntos Clave**:
  - **Base de Datos Local Cifrada**: SQLite / Drift con cifrado de grado militar; almacena firmas, sellos, bitácoras y fotos en cola local.
  - **Captura Telemática sin Red**: Enlace Bluetooth de baja energía (BLE) directo al sensor ThermoKing para certificar cadena de frío (-4.1°C).
  - **Pase de Caseta por QR Cifrado**: Generación de credencial QR en pantalla que los vigilantes de patio escanean sin requerir acceso a internet.
  - **Sincronización Transparente**: Desahogo automático de la cola de transacciones al detectar red celular 4G o Wi-Fi de terminal.
- **Pantalla Asociada**: *Gestión Offline y Sincronización Móvil*.

---

### DIAPOSITIVA 8: Flujo 5 — Aprobación de Extras y Viáticos en Tiempo Real
- **Título**: Auditoría Express de Casetas, Retenciones y Maniobras
- **Puntos Clave**:
  - **Reporte Rápido del Chofer**: Captura fotográfica de tickets con estampa de tiempo atómica y coordenadas GPS automáticas.
  - **Aprobación en 3 Segundos**: El administrador recibe una tarjeta resumida de auditoría con desglose de concepto ($45 USD por demora en rampa).
  - **Asignación Contable Transparente**: Los viáticos autorizados se indexan directamente al recibo quincenal del contratista 1099 sin doble captura manual.
- **Pantalla Asociada**: *Reportar Cargo Extra Móvil / Aprobaciones 1099 en Dashboard*.

---

### DIAPOSITIVA 9: Flujo 6 — Liquidación 1099 y Facturación Quincenal
- **Título**: Cierre Contable Automatizado y Timbrado Fiscal
- **Puntos Clave**:
  - **Liquidación Contratistas 1099**:
    - Cálculo de fletes base, viáticos y deducciones de pólizas/fianzas.
    - Emisión de recibos digitales con desglose por viaje completado.
    - Generación de archivo bancario para dispersión masiva vía ACH / SPEI.
  - **Facturación Comercial a Clientes**:
    - Agrupación quincenal por cliente corporativo (ej. Almacenes del Norte S.A. $26,490 USD).
    - Descarga de paquete maestro timbrado con ZIP de todos los PODs escaneados adjuntos.
- **Pantalla Asociada**: *Gestión de Pagos 1099 y Nómina Contratistas / Reportes Quincenales de Facturación*.

---

### DIAPOSITIVA 10: Resumen Ejecutivo, Beneficios y Stack Tecnológico
- **Título**: Resultados Operativos y Siguientes Pasos
- **Métricas de Impacto**:
  - **80% menos tiempo** en conciliación administrativa y cierres quincenales.
  - **100% de trazabilidad** en cadena de frío y firmas legales con sellado SHA-256.
  - **Cero pérdidas operativas** en zonas remotas gracias al motor offline SQLite.
  - **Aceleración de flujo de caja**: Reducción del ciclo de cobro comercial de 30 a 15 días con evidencias timbradas.
- **Arquitectura de Software**:
  - Front-end Móvil: Flutter (Material Design 3 / Drift ORM).
  - Front-end Web: React / Tailwind CSS / Data Visualization Suite.
  - Motor Central: Ingesta telemática BLE / GPS + Pipeline de Visión Computacional OCR.
- **Cierre / Contacto**: Preguntas y respuestas / Hoja de ruta de integración a ERP y SAT.

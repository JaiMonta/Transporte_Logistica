# Guía de Diseño y Especificación UI: FLEETIQ Driver OS & Control Central

Sistema de diseño unificado, arquitectura de información y especificación de interfaz para **FLEETIQ**, enfocado en la interoperabilidad entre el **Panel Web de Administración (Desktop)** y la **App de Operación en Campo / Modo Dual Chofer-Administrador (Mobile / Flutter M3)**.

---

## 1. Fundamentos de Marca y Dirección Visual

* **Nombre del Producto**: FLEETIQ (Control Central & Driver OS)
* **Propósito**: Gestión integral de flota de transporte refrigerado y seco, despacho de rutas, telemetría GPS, auditoría OCR de cartas porte / PODs, liquidación quincenal de contratistas 1099 y facturación fiscal a clientes comerciales.
* **Arquetipo de Usuario Clave**: Armando Garza (Owner-Operator / Administrador de Flota y Chofer en Ruta activo).
* **Filosofía Visual**: *Industrial Clarity & Tactical Density*. Alta legibilidad en condiciones de luz solar exterior, botones con áreas táctiles generosas para uso con guantes o en cabina, y jerarquía visual rigurosa para evitar errores operativos bajo fatiga.

---

## 2. Paleta de Colores y Tokens Semánticos (Design Tokens)

Basado en la paleta oficial del Design System `Field Logistics Driver OS`:

| Token | Hex / Valor | Rol y Aplicación |
| :--- | :--- | :--- |
| `primary` | `#1D4ED8` / `#2563EB` | Acciones principales, botones de confirmación, marca FLEETIQ |
| `primary-container` | `#E0E7FF` / `#EFF6FF` | Fondos de selección, chips de ruta activa, badges informativos |
| `on-primary` | `#FFFFFF` | Texto e iconos sobre fondos primarios |
| `surface` | `#FAFAFC` / `#FAF8FF` | Fondo general de aplicación (Clean Industrial Slate) |
| `surface-container-lowest` | `#FFFFFF` | Fondo de tarjetas, modales y paneles de datos |
| `surface-container-low` | `#F4F3F9` / `#F1F5F9` | Tablas alternas, inputs inactivos, divisores suaves |
| `outline` / `border` | `#E2E8F0` / `#D1D5DB` | Bordes sutiles para delimitar tarjetas y celdas |
| `success` / `status-ok` | `#059669` / `#10B981` | POD sellado, entrega completada, saldo liquidado, HOS en tiempo |
| `warning` / `alert-pending` | `#D97706` / `#F59E0B` | Demora en muelle, revisión pendiente, parada prioritaria, ticket por validar |
| `danger` / `critical` | `#DC2626` / `#EF4444` | Desvío no autorizado de geocerca, discrepancia OCR, falla mecánica |
| `reefer-cold` | `#0284C7` / `#0EA5E9` | Indicador de cadena de frío (-4°C a 4°C garantizados) |

---

## 3. Tipografía y Escala

* **Familia Tipográfica Principal**: `Space Grotesk`, sans-serif (para títulos, números, folios y KPIs técnicos).
* **Familia Tipográfica de Lectura / Cuerpos**: `Inter`, sans-serif (para notas, justificaciones y tablas densas).
* **Escala Tipográfica**:
  * **Display (KPIs Numéricos)**: 28px - 36px / Bold / Monospace tracking sutil.
  * **Título 1 (H1)**: 22px - 24px / SemiBold.
  * **Título 2 (H2 / Tarjetas)**: 16px - 18px / SemiBold.
  * **Cuerpo Principal (Body)**: 14px / Regular y Medium / Line-height 1.45.
  * **Etiquetas y Metadatos (Caption / Badge)**: 11px - 12px / Medium & Bold uppercase.

---

## 4. Componentes y Patrones UI (Flutter M3 & Web)

### 4.1 Componentes Móviles (Flutter / Material 3)
1. **Top App Bar Contextual**:
   * Altura: 64dp.
   * Elementos: Logotipo vectorial FLEETIQ, Badge de Terminal (`LAREDO TX`), Switch de alternancia de rol (`Admin Flota` / `Chofer TX-402`), campana de notificaciones y avatar de usuario.
2. **Bottom Navigation Bar (M3 NavigationBar)**:
   * 4 destinos principales fijos:
     - 🚚 `Despacho` (`/admin/despacho`)
     - 💵 `Pagos 1099` (`/admin/pagos`)
     - 🧾 `Facturación` (`/admin/facturacion`)
     - 🧭 `Flota / Mi Cabina` (`/admin/flota`)
   * Altura: 80dp, elevation 0, background `surface-container-lowest` con divider superior fino.
3. **Action Cards (Tarjetas de Tareas Táctiles)**:
   * Radio de curvatura: `12dp - 16dp`.
   * Padding interno: `16dp`.
   * Touch Targets mínimos: `48dp x 48dp` para todos los botones de acción rápida (*Aprobar*, *Rechazar*, *Navegar Ahora*).

### 4.2 Componentes Web Desktop
1. **Sidebar Lateral Persistente**:
   * Ancho: 260px.
   * Categorías agrupadas:
     - *Operaciones*: Dashboard General, Despacho de Rutas, Mapa GPS en Vivo.
     - *Documentación*: Manifiestos y OCR, Bitácora del Día.
     - *Administración*: Reportes Quincenales de Facturación, Gestión de Pagos 1099, Catálogo de Choferes y Flota.
2. **Paneles Divididos (Split-View)**:
   * Relación 60/40 para inspección:
     - Lado izquierdo: Lista de folios o tabla de contratistas.
     - Lado derecho: Visor forense de documento con lupa/zoom o pre-factura editable.

---

## 5. Matriz de Vistas y Rutas por Dispositivo

| Módulo Funcional | Desktop (Web) | Móvil (Flutter M3) |
| :--- | :--- | :--- |
| **Dashboard Operativo** | Panel panorámico con 6 widgets, alertas críticas y selector de turno. | Resumen vertical con KPIs compactos y tarjeta de parada inmediata. |
| **Despacho y Rutas** | Editor interactivo con balance de pesos, cálculo de refrigeración y mapa amplio. | Secuencia vertical de paradas con botón flotante y despacho en 1 toque. |
| **Monitoreo GPS** | Mapa satelital interactivo completo con telemetría lateral de 14 unidades. | Mapa móvil con marcadores dinámicos y ficha deslizable de unidad activa. |
| **Auditoría OCR** | Visor comparativo lado a lado (imagen física vs. campos SAT extraídos). | Tarjeta de validación de documento con recorte y botón de aprobación rápida. |
| **Pagos 1099** | Tabla masiva con desglose de honorarios, deducciones y exportación bancaria ACH. | Tarjetas de choferes con acordeón de extras y botón de emisión de recibo. |
| **Facturación Clientes** | Pre-facturas agrupadas por contrato comercial y timbrado SAT CFDI 4.0 masivo. | Tarjeta de cliente seleccionado con resumen de PODs y timbrado instantáneo. |
| **Modo Chofer (Cabina)** | N/A (Solo consulta en terminal de base). | Consola de conducción de alta concentración con GPS y botón de alerta. |

---

## 6. Principios de Interacción para el Rol Dual

1. **Persistencia de Estado**: Cambiar entre *Modo Administrador* y *Modo Chofer* no destruye formularios en progreso ni cancela la navegación GPS activa en segundo plano.
2. **Alertas No Intrusivas al Volante**: Durante la conducción detectada por telemetría (>15 km/h), las aprobaciones de flota no emiten modales intrusivos; se resumen en un micro-badge audible o accesible al llegar al destino.
3. **Flujo de Auditoría Rápida (1-Tap)**: Todas las solicitudes de viáticos o demoras en rampa contienen la foto del ticket físico, hora exacta y ubicación de geocerca verificada para permitir autorización en menos de 3 segundos.

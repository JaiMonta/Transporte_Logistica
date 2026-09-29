---
name: Field Logistics Driver OS
colors:
  surface: '#faf8ff'
  surface-dim: '#dad9e0'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f3f9'
  surface-container: '#eeedf4'
  surface-container-high: '#e8e7ee'
  surface-container-highest: '#e3e2e8'
  on-surface: '#1a1b20'
  on-surface-variant: '#444651'
  inverse-surface: '#2f3035'
  inverse-on-surface: '#f1f0f7'
  outline: '#747782'
  outline-variant: '#c4c6d2'
  surface-tint: '#3e5ca2'
  primary: '#3c5aa0'
  on-primary: '#ffffff'
  primary-container: '#5673bb'
  on-primary-container: '#fffdff'
  inverse-primary: '#b1c5ff'
  secondary: '#865223'
  on-secondary: '#ffffff'
  secondary-container: '#fdb880'
  on-secondary-container: '#784619'
  tertiary: '#00694f'
  on-tertiary: '#ffffff'
  tertiary-container: '#008565'
  on-tertiary-container: '#f8fff9'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dae2ff'
  primary-fixed-dim: '#b1c5ff'
  on-primary-fixed: '#001847'
  on-primary-fixed-variant: '#234489'
  secondary-fixed: '#ffdcc3'
  secondary-fixed-dim: '#fdb880'
  on-secondary-fixed: '#2f1500'
  on-secondary-fixed-variant: '#6a3b0d'
  tertiary-fixed: '#7df9cc'
  tertiary-fixed-dim: '#5fdcb1'
  on-tertiary-fixed: '#002116'
  on-tertiary-fixed-variant: '#00513c'
  background: '#faf8ff'
  on-background: '#1a1b20'
  surface-variant: '#e3e2e8'
typography:
  display-lg:
    fontFamily: Space Grotesk
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.03em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.01em
  title-lg:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  label-lg:
    fontFamily: Space Grotesk
    fontSize: 15px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-md:
    fontFamily: Space Grotesk
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.04em
  label-sm:
    fontFamily: Space Grotesk
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.06em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-sm: 0.75rem
  margin: 1rem
  margin-tablet: 1.5rem
  space-xs: 0.375rem
  space-sm: 0.75rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system is tailored for freight delivery operators, yard drivers, and long-haul transport workers operating under dynamic, demanding conditions: direct harsh sunlight on dashboard mounts, low-light night driving inside cabs, and single-handed interaction while wearing work gloves. 

The aesthetic is **Tactile High-Contrast Utility**. It fuses industrial clarity, rugged functionalism, and modern kinetic feedback. Rather than delicate or decorative elements, the system relies on high optical weight, unambiguous affordances, elevated physical planes, and oversized touch footprints. The tone is dependable, vigilant, and authoritative—instilling confidence during time-critical handoffs, route diversions, and cargo verification.

## Colors

The palette balances intense operational visibility with visual stamina. High-contrast pairings prevent glare washout in direct daylight while sustaining visual acuity in cab mounts.

- **Primary (`#5673BB` - Slate Steel Blue):** Commands primary transit actions, route focal points, interactive toggles, and primary navigation prompts (`Navegar`).
- **Secondary (`#CB8C58` - Industrial Amber):** Signals active workflows, intermediate stops, in-transit state tags, and immediate attention items without evoking panic.
- **Tertiary (`#2FB58D` - Emerald Compliance):** Denotes verified deliveries, successful scans, cleared checkpoints, and operational readiness.
- **Critical / Alerts (`#DC2626` - Crimson Hazard):** Flags exceptions, seal mismatches, delays, and critical equipment/safety alerts.
- **Neutrals & Surfaces:**
  - `Surface Base`: `#F8FAFC` (Anti-glare slate white for main background canvas).
  - `Card / Elevation Layer`: `#FFFFFF` (Crisp white for tactical card differentiation).
  - `Neutral Heavy`: `#0F172A` (Deep Slate Black for high-legibility headings, heavy borders, and icons).
  - `Neutral Muted`: `#475569` (Slate for subheads and ancillary technical metadata).
  - `Surface Border / Rim`: `#E2E8F0` (Structural perimeter bounding for card containers).

## Typography

The type scale utilizes **Space Grotesk** for headings, status pills, vehicle specs, and navigation instructions to provide an assertive, structured industrial presence with clear character distinction (crucial for distinguishing characters like `0` vs `O` and `1` vs `I`). 

Body text, manifest item details, and instructional copy employ **Hanken Grotesk** at a base medium weight (`500`) to safeguard legibility under direct glare and vehicle vibration. Thin weights under `500` are forbidden to prevent hairline washout. Numerical telemetry and ETA time stamps consistently apply tabular sizing conventions.

## Layout & Spacing

The structural strategy utilizes an ergonomic fluid grid system optimized primarily for standard mobile viewports (360px–430px) mounted in portrait cab docks, as well as rugged field tablets (768px–1024px) in landscape or portrait.

- **Mobile Rhythm:** 4-column fluid layout with a base `margin` of `1rem` (16px) and `gutter` of `1rem`. Internal container padding enforces minimum edge clearances of `space-md` (16px) to keep active touch zones away from bezel borders.
- **Tablet Dock Mode:** Reflows into a persistent split-screen 8-column layout (4 columns navigation telemetry / 4 columns freight stop roster).
- **Physical Hand Zones:** All high-frequency trigger elements are pinned to the bottom 40% of the screen height (the primary thumb engagement arc). Secondary references and metadata are parked in the upper 60%.

## Elevation & Depth

Visual hierarchy is maintained via tactile physical separation rather than subtle ambient washes. Because soft, low-contrast shadows disappear under intense cockpit sun glare, depth combines structural containment rings with directional, high-density physical shadows.

- **Base Canvas (`Level 0`):** Anti-glare background surface (`#F8FAFC`).
- **Resting Operational Cards (`Level 1`):** Pure white container (`#FFFFFF`), anchored by a 1.5px perimeter ring of `#E2E8F0` and a directional drop shadow: `0 3px 6px -1px rgba(15, 23, 42, 0.08), 0 2px 4px -2px rgba(15, 23, 42, 0.06)`.
- **Active / Dragged Waypoint Containers (`Level 2`):** Elevated physical presence with `0 10px 15px -3px rgba(15, 23, 42, 0.12), 0 4px 6px -4px rgba(15, 23, 42, 0.08)` and a perimeter ring of `#CBD5E1`.
- **Floating Action Deck & Navigation Anchors (`Level 3`):** Pinned persistent triggers, bottom sheets, and the main action hub utilize crisp structural float: `0 20px 25px -5px rgba(15, 23, 42, 0.18), 0 8px 10px -6px rgba(15, 23, 42, 0.12)`.

## Shapes

The design uses a calculated level `2` roundedness model. Base components employ `0.5rem` (8px) for inputs and card enclosures, scaling up to `1rem` (16px) on major waypoint modules and `rounded-full` (9999px) for status indicators and in-cab thumb buttons.

This geometry balances soft touch affordances with an engineered, industrial containment edge. Structural buttons never drop below 8px rounding, eliminating sharp corner friction while avoiding overly playful, toy-like forms.

## Components

### Buttons & Action Bars
- **Touch Target Dimensions:** All primary and secondary buttons enforce a strict minimum target height of `56px` (`3.5rem`) on mobile to support gloved operations. Micro-targets below 48px are strictly prohibited.
- **Primary Route CTA (`Navegar`):** Full-bleed or sticky bottom floating bar. Background: `#5673BB`, Text: `#FFFFFF`, Label style: `label-lg`, rounded-xl (`1rem`), with leading bold directional glyph.
- **Arrival Trigger (`Marcar llegada`):** Distinct split action or high-impact primary variant with tactile press scale (`transform: scale(0.98)`). Background: `#0F172A`, Text: `#FFFFFF`, border-bottom: 3px solid `#000000` to simulate a physical push deck.

### Status Pills & Badges
- **Shape & Sizing:** Fully rounded (`rounded-full`), minimum padding `6px 14px`, text set in `label-sm` (all caps, Space Grotesk).
- **Completed:** Background `#ECFDF5`, text `#065F46`, stroke `#A7F3D0` (Emerald).
- **In Progress:** Background `#FFF7ED`, text `#9A3412`, stroke `#FED7AA` (Industrial Amber).
- **Alert / Exception:** Background `#FEF2F2`, text `#991B1B`, stroke `#FECACA` (Crimson).

### Waypoint & Stop Cards
- **Structure:** White tactile surface (`#FFFFFF`), 1.5px border (`#E2E8F0`), padding `1.25rem`.
- **Arrangement:** Stop order counter (`01`, `02`, `03`) set in `headline-md` within an industrial slate badge. Waypoint title, delivery window, and package tally aligned on high-contrast rows.
- **Affordance:** Tapping the card activates immediate inline actions (Call Dispatch, View Manifest) without leaving the route sequence.

### Checkboxes & Confirmation Gates
- **Scale:** Minimum bounding size `28x28px` with an expanded interactive touch field of `52x52px`.
- **States:** Unchecked features a 2px high-contrast rim of `#94A3B8`. Checked snaps to solid `#5673BB` with a crisp `#FFFFFF` check icon, accompanied by haptic confirmation.

### Text & Telemetry Inputs
- **Height & Layout:** Height fixed at `56px`. Thick border (2px) in `#CBD5E1`, focusing immediately to `#5673BB` with an outer halo of 3px (`rgba(86, 115, 187, 0.15)`).
- **Driver Keyboard Mode:** Auto-triggers oversized numerical or capital pads tailored for seal codes, trailer plates, and fuel logs.

### Bottom Navigation Dock
- **Layout:** High-contrast bar anchored to the bottom edge, elevated at `Level 3`. Height `64px` plus device-safe inset.
- **Items:** 4 primary hubs (Ruta, Carga, Mensajes, Perfil). Active item marked by `#5673BB` icon fill with an elevated indicator pip; inactive items rendered in `#64748B`.
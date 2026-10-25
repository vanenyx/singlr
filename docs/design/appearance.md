# Singlr Appearance — materiales, color y tipografía (diseño técnico)

Sistema 05 de [Singlr 1.0](../singlr-1.0.md). Decisiones: P-005, P-006 (aprobación visual), P-016, P-019.
Estado: propuesta de Claude para implementar y revisar con el creador.

## 1. Sistema de materiales

Tres materiales, elegibles en Ajustes de Singlr (Apariencia → Material), con una **intensidad** común:

| Material | Dónde | Cómo |
| --- | --- | --- |
| Sólido | Siempre disponible; obligatorio con software rendering o «reducir transparencia» | Superficie opaca de los tokens (`Theme.raised/panel`) |
| Vidrio (glassmorphism) | Valor por defecto | Desenfoque del compositor (protocolo de blur de KWin vía `KWindowEffects`, ya usado: `singlrBlur`) + tinte translúcido |
| Liquid Glass (P-019) | Opcional | Vidrio + refracción en los bordes, brillo especular de borde y ligera dispersión, calculados por el compositor |

Se aplican solo a superficies flotantes y temporales del shell (dock, barra, paneles, lanzador, menús,
notificaciones, OSD). Las ventanas de aplicaciones no cambian de material.

**Intensidad (0–100):** controla a la vez la opacidad del tinte y la fuerza del desenfoque/refracción.
0 equivale a sólido. Respeta «reducir transparencia» de accesibilidad.

### Liquid Glass: efecto de KWin propio

El desenfoque de KWin no permite refracción. Se implementa un **efecto C++ de KWin**
`singlr-liquidglass`, fuera del árbol de KWin (como hacen otros efectos de terceros), con las
cabeceras de KWin 6.8 (`/usr/include/kwin`):

- Toma la región que ya declaran las superficies Singlr con el protocolo estándar de blur; solo actúa
  sobre ventanas del shell Singlr (layer-shell, `resourceClass == "singlr-shell"`).
- Pase de render: textura de fondo desenfocada (reutilizando el enfoque del efecto blur de KWin,
  GPL-2.0-or-later) + sombreador con SDF del rectángulo redondeado: desplazamiento de muestreo según
  la normal cerca del borde (refracción), realce especular en el borde superior e interior, y una
  dispersión cromática mínima. Sin ruido ni animación continua (P-016: coste cero en reposo).
- Parámetros en `kwinrc [Effect-singlrliquidglass]` (activado, intensidad), escritos por Ajustes con
  `KConfig::Notify` y aplicados en vivo (`reconfigure`). Activado solo en la sesión Singlr
  (`singlr_kwin.py` aplica/restaura, como la decoración).
- Acoplado a la versión de KWin: se recompila con cada versión soportada; el paquete declara
  `kwin` con versión compatible. Si el efecto no carga, el material cae a Vidrio.
- Medición obligatoria (P-016): GPU y tiempo de frame con y sin efecto en la laptop del creador
  (AMD + NVIDIA) antes de integrarlo.

## 2. Color de las aplicaciones

`tools/gen-color-schemes.py` genera **Singlr Dark/Light** (KDE color schemes) desde los tokens del
shell, para que apps y shell compartan paleta. Instalados y seleccionables; **no son el valor por
defecto hasta la revisión visual** (comparación en `review/apps-*.png`). Acento por defecto
provisional: índigo `#5e6ad2`. Tras aprobarlos: valor por defecto en `session/xdg/kdeglobals`,
paquetes de apariencia `dev.singlr.dark/light` y `KDEAppearance::setMode`.

## 3. Tipografía

El shell usa Inter (variable). Propuesta: **Inter como fuente del sistema en la sesión Singlr**
(`session/xdg/kdeglobals [General] font/menuFont/toolBarFont/smallestReadableFont`, valores por
defecto que el usuario puede cambiar), con el paquete de Arch `inter-font` como dependencia en vez
de copiarla. Monoespaciada: la de KDE (Hack) salvo decisión contraria. Pendiente de la revisión visual.

## 4. Revisión visual con el creador (P-006)

Una sesión con capturas lado a lado en ambos modos para aprobar: paleta y acento por defecto, esquema
de apps, tipografía del sistema, radios, intensidad por defecto del vidrio y aspecto de Liquid Glass.

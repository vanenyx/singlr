# Singlr Appearance — materiales, color y tipografía (diseño técnico)

Sistema 05 de [Singlr 1.0](../singlr-1.0.md). Decisiones: P-005, P-006 (aprobación visual), P-016, P-020, P-021.
Estado: propuesta de Claude para implementar y revisar con el creador.

## 1. Sistema de materiales

Dos materiales, elegibles en Ajustes de Singlr (Apariencia → Material), con una **intensidad** común:

| Material | Dónde | Cómo |
| --- | --- | --- |
| Sólido | Siempre disponible; obligatorio con software rendering o «reducir transparencia» | Superficie opaca de los tokens (`Theme.raised/panel`) |
| Vidrio (glassmorphism) | Valor por defecto | Desenfoque del compositor (protocolo de blur de KWin vía `KWindowEffects`, ya usado: `singlrBlur`) + tinte translúcido |

Se aplican solo a superficies flotantes y temporales del shell (dock, barra, paneles, lanzador, menús,
notificaciones, OSD). Las ventanas de aplicaciones no cambian de material.

**Intensidad (0–100):** controla a la vez la opacidad del tinte y la fuerza del desenfoque.
Propuesta T252: transmisión 0–85 % lineal en señal de pantalla, adaptación suave de luminancia local del
fondo para sostener AA sin placas ni contornos; sin plugin, curva conservadora 0–30 %. Vidrio
usa un pase de difusión y adaptación de luminancia; el blur nativo sigue como base fija.
Ver [justificación, evidencia y límites](../handoffs/T252-material-polish.md).
0 equivale a sólido. Respeta «reducir transparencia» de accesibilidad.

### Vidrio: pase de KWin

Pase C++ externo para KWin 6.8.1, limitado al shell. Difusión y adaptación de
luminancia local, sin refracción, dispersión ni especular (P-021). Cobertura SDF
premultiplicada en el contorno, escalada por el viewport. El radio se recupera de las filas de la región de blur rasterizada de forma
determinista por el shell (corrección T253); no hay canal D-Bus de geometría.

Se conserva el ID técnico `singlr-liquidglass` para mantener la reversión exacta del
journal/kwinrc existente. El nombre visible es Singlr Glass. Véanse [contrato,
compilación y límites](../../kwin/effects/singlr-liquidglass/README.md). Sin plugin se
usa Vidrio nativo con tinte conservador. Software o transparencia reducida usan Sólido.
La revisión visual y la medición GPU/frame time siguen pendientes de ejecución real.

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
de apps, tipografía del sistema, radios, intensidad por defecto del vidrio y suavidad de esquinas en el pase de Vidrio y su respaldo.

## 5. Iconos del dock (P-025 / T257)

Por decisión del creador se retira el punto de abierta. El icono se centra en la
altura del dock; su estado abierto sigue disponible para tecnologías de asistencia.

Propuesta técnica: compensar el espacio transparente de cada marca mediante
medida de alfa. Ajuste uniforme de tamaño y centro, un píxel lógico de respiro,
ampliación máxima de 1,5× para limitar fuentes patológicas. No recolorear, deformar,
poner todas las marcas en placas ni sustituir los originales. La igualdad del
contorno visible no garantiza igualdad perceptual de masa entre formas distintas.
La presentación queda para revisión del creador; no cambia tipografía ni materiales.

Se comparan estado anterior, caja uniforme y compensación visible en claro/oscuro
a 48/72 px. [Evidencia](../../tests/shell/evidence/t257/README.md).

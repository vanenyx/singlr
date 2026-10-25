# T252 — corrección tras la revisión de Claude

Codex 2 · misma rama · sin commit. Sustituye la solución de legibilidad de la
[entrega inicial](T252-material-polish.md). Claude comprobó en KWin que la intensidad
se distingue y Liquid muestra brillo; rechazó la placa negra en la búsqueda.
Sus [capturas originales](../../tests/shell/evidence/t252/nested-claude/glass-100.png)
se conservan intactas.

## Corrección

- Retiradas las dos placas opacas (lanzador y portapapeles) y los contornos de UiText/Icon.
  La búsqueda comparte el material del panel completo. Solo conserva el borde de foco
  transparente, con radio `Theme.radius`; no necesita una superficie propia adicional.
- El shader calcula luminancia **local del fondo desenfocado**, en RGB lineal SDR, después
  de difusión/refracción. Un hombro continuo de sexto orden reduce altas luminancias
  en oscuro y eleva las bajas en claro. Conserva prácticamente la pendiente original
  donde ya hay contraste. No hay umbral binario, placa, lectura GPU→CPU ni historia
  temporal. El ajuste pertenece al material y afecta al panel entero de forma local.
- La intensidad nominal sigue siendo lineal 0–85 %. El contraste modifica la transmisión
  efectiva según el fondo: blanco puro en oscuro y negro puro en claro requieren más
  tinte; no se puede mantener idéntica transmisión en esos extremos y a la vez AA con
  texto fijo. Los cinco niveles siguen separados sobre el fondo cálido del creador.
- Se incluye el tinte posterior de Qt en el cálculo: sus canales son <= .14 en oscuro
  y >= .90 en claro (verificados con los tokens reales). El shader reserva margen para
  cuantización y mantiene la luminancia compuesta dentro de **Y <= .115 / Y >= .42**.
  Texto secundario/tenue/acento y error usan tintas que pasan AA contra esa envolvente.
  Color de error adaptado en materiales translúcidos, sin alterar su variante sólida.
- Refracción 18→24 px lógicos (+33 %), banda 26→30 px y perfil algo más ancho;
  desplazamiento cero fuera de la banda. Centro limpio, mismo brillo y dispersión.
  Se mantienen 13 muestras, buffers existentes, dependencia de daño de 40 px y ausencia
  de relojes/repintado continuo. El blur nativo sigue siendo la base fija anterior.

La implementación no introduce APIs KWin nuevas: conserva las cabeceras comprobadas
6.8.1 y Qt 6.12.0. Referencia de contraste:
[WCAG 2.2, 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).
La fórmula protege los tokens en SDR y contraste por defecto; no certifica HDR,
perfiles ICC, todos los colores arbitrarios ni la gestión de color real de KWin.

## Verificación ejecutada y capturas

- QML claro y oscuro: **206 + 8 passed por modo, 0 failed, 3 skipped**. Incluye búsqueda
  editable, foco, radio y regresión explícita contra rellenos opacos en ambos campos.
  AA mínimo **4,676:1**, sin asumir contornos ni placas, incluyendo color de error.
- EGL ejecuta el GLSL de producción en llvmpipe y comprueba **2.937.600 píxeles compuestos**
  sobre blanco/negro/R/G/B/cálido, ambos materiales y seis intensidades (incluye 65).
  En esa muestra: máximo oscuro Y=.103079; mínimo claro Y=.486742.
- Matriz guardada: **180 fixtures EGL + 180 recortes**, fondo cálido original del creador,
  blanco y negro; temas claro/oscuro; lanzador, centro de control y portapapeles;
  Vidrio/Liquid; 0/25/50/75/100. [Comparador](../../tests/shell/evidence/t252/correction/index.html).
  El delta medio entre cuartos sobre el fondo cálido es 7,48–14,64 niveles RGB de 255.
  Son geometrías/materiales ilustrados con el shader real, **no capturas KWin ni widgets
  reales**; no incorporan su blur previo. Texto ilustrativo sin placas ni contornos.
- Factory/config del efecto, Python, CMake/staging y setup: resultados detallados en
  [verification.txt](../../tests/shell/evidence/t252/correction/verification.txt).

## Bloqueo de captura real y reproducción para Claude

Se volvió a intentar `tools/run-singlr.sh --duration 2`. El bus privado falla al crear
su socket: `Operation not permitted`; limpieza `remaining=[]`, configuración del host
`files_before=30 files_after=30 equal=True`. [Log](../../tests/shell/evidence/t252/correction/nested-probe.log).
No se ha cambiado ni recargado la sesión activa. **La nueva matriz de KWin sigue pendiente**;
las capturas de Claude corresponden a la entrega anterior, no validan esta corrección.

Arrancar un KWin **nuevo** con el build actual, como en [materials.md](../testing/materials.md),
y duración 1800 para completar la matriz. El helper solo modifica el perfil desechable:

```sh
cmake --build build --target singlr-material-image singlr-material-optics-test
python3 tools/material-review.py "$SINGLR_SESSION_FILE" \
  --matrix "$out/t252-correction" \
  --wallpaper '/home/sunw/Imágenes/mbJXlHJocOEiPzsHMfiLv.png'
```

Un solo comando recorre ambos temas, los tres fondos y los tres paneles. Genera los PNG
uniformes con QImage y escribe sus rutas exclusivamente en el config privado validado.
Abre el portapapeles con `toggleClipboard`; el recorte usa su región real de 760×542.
Guarda 180 capturas, recortes y diagnósticos de pases. Revisar también búsqueda con texto
escrito, placeholders y foco: no debe aparecer ningún parche rectangular ni contorno.
Comparar la refracción en los cuatro lados sobre detalle del fondo, no solo el brillo.
La aceptación visual y la medición P-016 de la entrega inicial continúan pendientes.

Para reproducir solo los fixtures sin compositor:

```sh
python3 tools/material-review.py --shader-fixture /tmp/t252-corrected-fixtures \
  --wallpaper '/home/sunw/Imágenes/mbJXlHJocOEiPzsHMfiLv.png'
```

# T262 / T262b — gestos de touchpad sin multitarea duplicada

26 oct 2026 · Codex 2 · `fix/t262-touchpad-gestures` · entrega para Claude.
Implementado y comprobado de forma aislada; commit a cargo de Claude según T262b.
No se modificaron la sesión activa ni sus archivos de configuración.

## Cambios y criterio

- **Encargo explícito:** `Plugins/overviewEnabled=false`, restaurando el valor
  original o su ausencia con el journal existente. Se aceptan journals anteriores
  a T262, incluidos los formatos anteriores a TabBox, materiales y esquina.
- **Solución técnica derivada:** `windowviewEnabled=false` elimina la otra vista
  de ventanas KDE accesible con Ctrl+F9/Ctrl+F10/Ctrl+F7, aunque no registra gestos
  de touchpad. Ambos efectos se descargan también en la ruta de aplicación en vivo.
- **P-030, explícita del creador en T262b:** 3 o 4 dedos arriba abren Singlr
  Overview; 3 o 4 abajo lo cierran. Los cuatro handlers instancian el mismo
  componente `OverviewSwipe`, que comparte progreso, activación y cancelación.
  El gesto de 3 abajo de `singlr-gestures` conserva su lógica y su latch inicial.
- **Desplazamiento natural: retirado por el creador.** Codex 2 lo implementó como
  default de sesión (`session/xdg/kcminputrc`, `[Libinput][Defaults][Touchpad]`).
  El creador decidió gestionarlo desde Ajustes del sistema de KDE
  (Touchpad → Desplazamiento invertido, ambos ejes) y no incluirlo en Singlr.
  Claude retiró el archivo, su instalación y su prueba antes del commit.
- Eliminados todos los helpers D-Bus y journal de touchpad de la primera
  iteración. Tampoco se modifica `Desktops/Rows`.

## Inventario de touchpad frente a P-015/P-030

Fuente del núcleo: [virtualdesktops.cpp, Plasma/6.8](https://github.com/KDE/kwin/blob/Plasma/6.8/src/virtualdesktops.cpp#L729),
contrastada con las seis llamadas en la libkwin instalada (`initShortcuts`,
`0x455c7b`, `0x455cc2`, `0x455d09`, `0x455d50`, `0x455da7`, `0x455dfe`).
Enums locales en `/usr/include/kwin/effect/globals.h`: Down=1, Left=2, Up=3, Right=4.

| Propietario | Gesto de touchpad | Resultado en Singlr |
| --- | --- | --- |
| KWin núcleo | 3 o 4 izquierda/derecha | Cambio de escritorio nativo, conservado (P-015) |
| KWin núcleo | 3 arriba/abajo | Cambio vertical solo si la rejilla tiene más de una fila; véase límite inferior |
| KDE Overview | 4 arriba, transición Overview→Grid; 4 abajo Grid, y gestos inversos para cerrar | Efecto deshabilitado; sustituido por Singlr |
| Singlr Overview | 3 o 4 arriba/abajo | Apertura/cierre con progreso compartido (P-015/P-030) |
| singlr-gestures | 3 abajo | Mostrar escritorio cuando Singlr Overview no estaba abierto; conservado |
| singlr-gestures | Pinza de 4 hacia dentro | Todas las apps; conservado |
| Zoom / Magnifier KDE | Pinza de 3 en ambos sentidos | Zoom de accesibilidad; no ocupa la pinza de 4 |
| Window View KDE | Ningún gesto touchpad registrado | Deshabilitado por sus atajos de multitarea duplicados |
| Efectos QML de animación y vidrio Singlr | Ningún handler de swipe/pinch | Sin nueva asignación |

[Overview de KDE](https://github.com/KDE/kwin/blob/Plasma/6.8/src/plugins/overview/overvieweffect.cpp#L32)
contrastado con `/usr/bin/kwin_wayland` (`0x10fcb1`, `0x10fcf2`, `0x10fd3d`);
`EffectTogglableGesture` registra también la dirección inversa.
[Zoom](https://github.com/KDE/kwin/blob/Plasma/6.8/src/plugins/zoom/zoom.cpp#L69)
y [Magnifier](https://github.com/KDE/kwin/blob/Plasma/6.8/src/plugins/magnifier/magnifier.cpp#L63):
las cuatro llamadas de pinza del ejecutable usan fingerCount=3.
Window View: constructor del ejecutable registra Qt `0x05000038/39/36`
(Ctrl+F9/F10/F7), sin llamadas de registro de swipe/pinch.
Los QML instalados y los de este checkout confirman los handlers de Singlr;
el plugin de vidrio no registra gestos.

**Cuatro dedos verticales:** no compiten con otro gesto que se conserve: el
núcleo solo registra cuatro dedos horizontales y Overview KDE queda deshabilitado.
No se añade mostrar escritorio con cuatro dedos abajo.

**Límite previo de P-015:** con varios escritorios y varias filas, los gestos
nativos de 3 arriba/abajo pueden coexistir con los de Singlr. El callback de KWin
comprueba `grid().height() > 1`; no existe aquí una clave para deshabilitar solo
esos dos registros. La configuración leída de este equipo indica Number=1,
Rows=1, por lo que actualmente son inertes. Se retiró Rows=1 del cambio para
conservar la distribución del usuario. Para soportar rejillas verticales sin
conflicto, proponer interceptar exclusivamente esos gestos en la integración
nativa con KWin, sin aplanar escritorios; requiere encargo y comprobación propios.
No se declara resuelta esa topología.

No se pudo consultar `loadedEffects` por el sandbox. El inventario es estático
sobre los binarios/QML instalados, la configuración de Plugins leída y los dos
efectos cargados que Claude confirmó en el encargo; no acredita la lista dinámica
completa de la sesión. La rama oficial Plasma/6.8 sirve de explicación; las
instrucciones del binario instalado fijan la evidencia de 6.8.1.

## Verificación ejecutada

- `python3 -m unittest discover -s tests/shell -p 'test_kwin.py' -q`:
  **20 pruebas, OK**. Incluye ausencia y true/false originales, restauración
  KConfig real, recuperación con proceso nuevo, journals antiguos y Rows intacto.
- `python3 -m unittest discover -s tests/shell -p 'test_session*.py' -q`:
  OK tras retirar las pruebas de touchpad (resultado de Claude en la integración).
- `python3 -m unittest discover -s tests/shell -p 'test_packaging.py' -q`:
  **5 pruebas, OK**, incluido puente nativo de recarga.
- `python3 -m unittest discover -s tests/shell -p 'test_build.py' -q`:
  **1 prueba, OK**, compilación, caché, concurrencia y recuperación de fallo.
- `kwin/effects/singlr-overview/tools/check-qml.sh`: **exit 0**,
  qmllint con tipos extraídos de libkwin y avisos de metadatos incompletos;
  compilación del componente real **Ready=1**. El intento inicial de qmllint
  sin el dump no resuelve org.kde.kwin y no se considera validación.
- `python3 scripts/check_setup.py`: **OK**.
- `python3 scripts/doctor.py`: inventario completado; Qt 6.12.0, KWin instalado.
- `git diff --check`: **OK**.

## Límites y entrega

Requiere actualizar el paquete y entrar de nuevo en Singlr para los handlers instalados. No se aplicó nada en vivo. Pendientes físicos:
progreso/cancelación de 3/4 dedos, pinza, mostrar escritorio
y regreso a Plasma. La compilación del componente no acredita esos recorridos.
El intento de bus privado en T262 falló al crear su socket (`Operation not
permitted`); no se afirma prueba KWin anidada. No se tocaron Session.qml,
ScreenSurfaces.qml ni shell/session/src.

Claude debe integrar P-030 en el registro de decisiones compartido y crear el
commit solicitado; T262b ordena no intentar escribir metadatos Git desde este sandbox.

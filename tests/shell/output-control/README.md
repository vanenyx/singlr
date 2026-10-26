# T261 — recuperación del dock al volver las salidas

Solución técnica derivada del encargo T261; no cambia decisiones visuales.

## Causa y corrección

Contratos comprobados en Arch: Qt 6.12.0, LayerShellQt 6.8.1-1 y KWin 6.8.1-2.
`/usr/include/LayerShellQt/window.h` declara `setCloseOnDismissed(bool)` como
método C++, sin propiedad QML. Las fuentes oficiales de esa versión confirman
[el valor predeterminado true](https://github.com/KDE/layer-shell-qt/blob/v6.8.1/src/interfaces/window.cpp)
y [la llamada a QWindow::close() al recibir closed](https://github.com/KDE/layer-shell-qt/blob/v6.8.1/src/qwaylandlayersurface.cpp).

Con `shown == true`, ese cierre oculta la ventana sin cambiar el estado del
Dock. La colocación anterior solo mostraba una ventana previamente visible.
`reveal()` tampoco producía una transición si el dock ya se consideraba mostrado.
La política de cierre es reproducible con la biblioteca instalada; la secuencia
Wayland concreta de la sesión del creador sigue sin reproducción en este entorno.

`System::placeOnScreen()` desactiva el cierre por dismissal antes de recrear la
superficie y conserva la visibilidad solicitada. Session registra dock y borde
al crearlos, y coloca de nuevo al cambiar inventario o pantalla efectiva. No
fuerza `reveal()`: conserva el dock autooculto. Los únicos consumidores persistentes
de `placeOnScreen` en Session son dock y borde; ScreenSurfaces posee las ventanas
por pantalla y las destruye al retirar su delegado. No se añaden temporizadores,
procesos residentes ni reinicios del shell.

La comprobación de pantalla/ventana de ScreenSurfaces se hace dentro de la
función diferida, cuando esos objetos aún pueden haber desaparecido.

## Pruebas reproducibles

Desde la raíz, después de compilar el proyecto (necesario para `build/qml`):

```sh
python3 tests/shell/output-control/test-lifecycle.py --before-ref 569f58a --output /tmp/t261-native-before.log
python3 tests/shell/output-control/test-lifecycle.py --output /tmp/t261-native-after.log
```

La primera orden debe fallar: prueba el System histórico y ScreenSurfaces
histórico en un staging temporal, sin cambiar el checkout. Las pruebas nativas
comprueban la política de dismissal, pantalla y visibilidad mostrada/oculta;
las QML ejercitan la desaparición de pantalla o ventana antes de `Qt.callLater`.
Se aíslan configuración, datos, caché, estado y buses. No prueban mapeo Wayland.

Para la prueba real en un KWin virtual **privado**, sin usar la sesión activa:

```sh
cmake -S tests/shell/output-control -B build/output-control
cmake --build build/output-control --parallel 2
python3 tests/shell/dock-resume-e2e.py --output /tmp/t261-wayland-after
```

El ejecutable predeterminado es `build/shell/session/singlr-shell`; `--binary`
permite pasar una compilación anterior para demostrar la regresión. Se necesita
esa comparación antes/después para aceptar la recuperación nativa. No basta
con ejecutar el test contra un binario histórico de procedencia desconocida.

El plugin auxiliar usa la ABI **exacta de KWin 6.8.1**, solo se construye bajo
petición y no tiene regla de instalación. Se descubre por `QT_PLUGIN_PATH`
exclusivo del compositor de prueba y exige VirtualBackend y la variable de
prueba. Su API retira **todas las salidas backend**, comprueba cuenta cero y crea
una salida nueva con nombre diferente. No simula solamente apagar una de dos
pantallas. Se comprueban dock mapeado, salida, geometría flotante/fija, borde de
autoocultado y continuidad del ocultado/revelado, con dos ciclos por combinación.
Los logs Wayland quedan guardados para examinar `closed` y errores QML.

## Evidencia ejecutada el 26 oct 2026

- Nativas/QML contra 569f58a: **3 correctas, 3 fallos esperados**: ambos casos
  de política de cierre y `ScreenSurfaces.qml:20 TypeError ... name ... null`.
- Mismas pruebas corregidas: **6 correctas, 0 fallos**, sin TypeError.
- `tools/test-qml.sh` y `tools/test-qml.sh --light`: **245 shell + 9 Ajustes
  correctas por modo, 0 fallos**; cinco capturas opcionales omitidas por modo.
- `tools/check-cmake.sh`: compilación, instalación DESTDIR y payload correctos.
  Caché existente con `SINGLR_BUILD_LIQUIDGLASS=OFF`; no verifica vidrio.
- CMake del auxiliar: plugin y ejecutable de regresión compilados correctamente.
- `python3 scripts/check_setup.py`, compilación sintáctica de los dos runners
  Python y `git diff --check`: correctos.
- E2E en KWin virtual privado, ejecutada por Claude fuera del sandbox:
  binario anterior (sin `setCloseOnDismissed`), **falla** con
  `Timeout: restored surface: floating-visible`; binario corregido, **PASS** en
  floating-visible, floating-autohide, fixed-visible y fixed-autohide.

Pendientes: comprobar el borde con entrada real y realizar suspensión física en una sesión
de prueba. El backend virtual no prueba kernel/DRM, GPU, PAM ni el ciclo físico
de suspensión. No se ha recargado ni modificado el shell/KWin de la sesión activa.

# T244 — indicadores y apariencia

Sin commit. Soluciones técnicas derivadas de P-005, P-010–P-017 y T-010; acabado visual pendiente de revisión del creador.

## Backends y comportamiento

- Teclado: `org.kde.plasma.workspace.keyboardlayout.KeyboardLayout`, el cliente estándar de `org.kde.keyboard` en Plasma 6.8.1. `private.keyboardindicator` solo expone estados de teclas/botones en esta versión. Oculto con cero/una distribución; clic o Espacio avanza; clic derecho, tecla Menú o Mayús+F10 muestra la lista. Ancho fijo y lista congelada mientras está abierta, con desplazamiento si supera diez entradas. Reutiliza la superficie de menús de la barra.
- Luz nocturna: `org.kde.plasma.workspace.dbus.Properties` contra servicio/interfaz `org.kde.KWin.NightLight`, ruta `/org/kde/KWin/NightLight`, y `brightnesscontrolplugin.NightLightInhibitor`, igual que el applet de brillo instalado. El interruptor suspende/reanuda la programación configurada; no libera inhibiciones ajenas. Si no está configurada, el engranaje abre `kcm_nightlight` para habilitarla. El singleton conserva la inhibición al descargar el centro de control. Indicador con las condiciones de Plasma: temperatura aplicada distinta de 6500 K mientras corre, o inhibición con temperatura objetivo distinta de 6500 K. La interfaz instalada no ofrece «hasta mañana» ni activación forzada: no se añade un temporizador propio.
- Pantallas: recuento de salidas **activas** de `Qt.application.screens`, proporcionadas por KWin. Con más de una se muestra el acceso al KCM estándar `kcm_kscreen` mediante `KCMLauncher`. No se detectan aquí conectores conectados pero deshabilitados. La fila reserva 36 px incluso al ocultarse; el panel mantiene 560 px y desplazamiento interno. No añade controles de brillo.

Contratos contrastados con los paquetes locales plasma-workspace/plasma-desktop/kwin/kscreen **6.8.1**, Qt **6.12.0**: `.qmltypes` instalados de keyboardlayout, keyboardindicator, brightnesscontrolplugin y workspace.dbus; `/usr/share/dbus-1/interfaces/org.kde.KWin.NightLight.xml`; QML del applet brightness extraído de sus recursos Qt instalados (NightLightItem.qml y main.qml). Referencia upstream: [NightLightItem.qml](https://invent.kde.org/plasma/plasma-workspace/-/blob/v6.8.1/applets/brightness/package/contents/ui/NightLightItem.qml).

## Apariencia y capturas

Tokens compartidos: texto tenue/placeholder con AA, opacidades claras que protegen lectura sobre fondos oscuros, vidrio oscuro que protege sobre fondos blancos, rojo de error legible. Conserva colores funcionales y sombras neutras. No se cambian paleta ni selección de apariencia en `apps/settings`: recibe los tokens de Singlr.Ui.

Bloqueo: sigue el `SystemPalette` del greeter KDE, incluido el acento; elimina el reloj y configuración de tema privados antiguos. Placeholder y selección del campo de contraseña usan tokens. No se cambia autenticación.

| Escenario | Antes oscuro | Después oscuro | Antes claro | Después claro |
| --- | --- | --- | --- | --- |
| Barra, dock, lanzador, control, notificación, OSD, portapapeles y menú | [PNG](before-dark-surfaces.png) | [PNG](after-dark-surfaces.png) | [PNG](before-light-surfaces.png) | [PNG](after-light-surfaces.png) |
| Bloqueo | [PNG](before-dark-lock.png) | [PNG](after-dark-lock.png) | [PNG](before-light-lock.png) | [PNG](after-light-lock.png) |
| Ajustes | [PNG](before-dark-settings.png) | [PNG](after-dark-settings.png) | [PNG](before-light-settings.png) | [PNG](after-light-settings.png) |

Renderizado nativo offscreen/software, BreezeDark/BreezeLight y todos los directorios XDG escribibles temporales; ambos buses desconectados con rutas temporales. El paquete del bloqueo se copia con sus fuentes al perfil temporal. El doble de authenticator solo contiene enums y los límites visuales del fixture; nunca PAM. Las capturas de superficies posteriores muestran datos simulados de dos teclados, luz activa y dos salidas. El resto de backends permanece desconectado. El reloj del bloqueo es real.

Los «antes» usan los archivos de producto de HEAD, con el mismo fixture nuevo; los «después», el árbol actual. Para repetir los «después»:

```bash
tools/test-qml.sh --capture after
tools/test-qml.sh --capture after --light
```

`--capture before` solo etiqueta la salida; requiere restaurar previamente el producto de referencia. No reconstruye HEAD por sí solo.

## Comprobaciones ejecutadas

- `tools/test-qml.sh`: 164 casos shell + 7 ajustes, cero fallos; un skip del capturador opcional.
- `tools/test-qml.sh --light`: mismos resultados.
- `tools/check-shell.sh`: PASS, qmllint sin avisos y carga offscreen con PNG temporal.
- `python3 -m unittest discover -s tests/shell -p 'test_lockscreen.py'`: 2 pruebas Python; incluye 9 casos QML por paleta, cero fallos, perfil y buses aislados.
- Las cuatro ejecuciones de captura: 3 casos cada una, cero fallos.
- `git diff --check`: limpio.

Las pruebas nuevas verifican selección/ciclo/menú del teclado, geometría ante cambios, estados D-Bus de luz nocturna, inhibición ajena, recuento de pantallas y contraste de texto >= 4.5:1 sobre superficies sólidas, selección y translucidez compuesta con fondos negros/blancos, incluido vidrio y errores del bloqueo. Se adaptan dos expectativas antiguas fijadas al oscuro. Se cualifican tres llamadas de un fixture de medios existente para que qmllint las resuelva.

## Pendiente para Claude, en entorno anidado

No se ha recargado ni modificado la sesión habitual. Validar teclado real y menú en cada pantalla; cambios externos de distribución; inhibición y reanudación de luz nocturna con otro cliente; KCM de pantallas; hotplug; desenfoque GPU con fondos claros/oscuros; carga del greeter real y cambio de paleta mientras está bloqueado. El fixture acredita presentación y contratos de interacción, no integración efectiva con esos servicios.

Ejecutar `tools/measure-resources.sh` antes de integrar (P-016); no se ejecutó porque requiere los pasos anidados reservados a Claude. Las adiciones son por señales, sin temporizadores de sondeo. Las decisiones técnicas y límites de esta entrega quedan aquí dentro del alcance; Claude puede incorporarlos al handoff y registro común.

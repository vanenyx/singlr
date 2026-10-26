# T258 — seleccionar y pegar desde Meta+V

26 oct 2026. Encargo explícito P-026; incremento de System/Command, sin declarar
completa la aceptación de Singlr 1.0.

## Resultado

Clic y Enter seleccionan el contenido, cierran el panel y envían el atajo de pegado
a la ventana original. Ctrl+Enter y la nueva acción «Copiar» solo copian. Se reutiliza
el HistoryModel de Klipper y sus formatos originales, también para imágenes.

ClipboardPasteBridge captura el destino antes del panel. Espera propiedad del
portapapeles restaurado, foco original, ninguna superficie del shell con foco y
modificadores físicos liberados. Cancela si otra app obtiene foco, el destino se
cierra o vence 1,5 s. No activa otra ventana ni envía Enter. Si falla tras seleccionar,
una notificación transitoria permite pegar manualmente. Si no hay capacidad o destino
al abrir, la selección conserva el comportamiento de copia y el pie lo indica.

## Integración

Qt 6.12.0, KWin/KWayland 6.8.1, KF6 6.31.0 locales. Dependencias KWayland,
GuiAddons >=6.29 y Service. [KSystemClipboard](https://api.kde.org/ksystemclipboard.html)
expone ownsClipboard desde 6.29; Klipper restaura entradas históricas de forma
asíncrona. El puente no lee ni guarda el texto o imagen.

Se usa la API pública de KWayland para plasma-window-management y
[fake-input](https://invent.kde.org/libraries/plasma-wayland-protocols/-/blob/master/src/protocols/fake-input.xml),
protocolo interno para implementar el escritorio, habilitado solo por Session.
Sin API D-Bus de inyección genérica ni cambio de permisos del equipo. El compositor
recibe códigos de teclado Ctrl+V; Ctrl+Shift+V cuando KService identifica la categoría
TerminalEmulator, como Warp/Konsole. Referencias oficiales:
[Warp](https://docs.warp.dev/getting-started/keyboard-shortcuts/),
[Konsole](https://docs.kde.org/trunk_kf6/en/konsole/konsole/commandreference.html).
Dos temporizadores solo durante una solicitud pendiente; sin polling de reposo.

## Verificación

- Compilación nativa y CMake/DESTDIR correctos; vidrio OFF en este build, sin
  atribuir validación al efecto. qmllint con build/qml antes de imports instalados.
- Native singlr-clipboard-paste-test: 4 resultados correctos; sin destino/capacidad
  no se envía teclado y cancelar es silencioso.
- Siete escenarios KWin privado: texto Unicode multilínea antiguo, entrada actual,
  imagen con dimensión/color verificados por receptor, terminal, solo copiar,
  destino cerrado y otra app con foco. Todos PASS; limpieza sin procesos restantes
  y hashes de configuración anfitriona iguales.
- La prueba terminal usa metadatos reales de Warp y un receptor TextEdit que exige
  Ctrl+Shift+V; no ejecuta Warp. El recorrido usa el panel/HistoryModel reales;
  la selección se invoca mediante adaptador exclusivo de pruebas. QML comprueba
  clic real, Enter, Ctrl+Enter en búsqueda y fila y acción «Copiar».
- Suites QML claro/oscuro: 241 shell + 9 Ajustes por modo, 0 fallos, 5 capturas
  opcionales omitidas. Packaging: 5 pruebas correctas. Preparación y diff
  correctos. Medida privada 93,94 MB PSS, CPU 0 % / 30 s, tres superficies; no es
  A/B ni acredita P-016 en sesión real.

[Evidencia filtrada](../../tests/shell/evidence/t258/README.md).

## Entrega y límites

No se recargó la sesión del creador. Actualizar paquete y entrar de nuevo en Singlr
para cargar el módulo nativo. Quedan la aceptación en uso cotidiano, Warp real,
otras apps, distribuciones de teclado y atajos personalizados. El envío del atajo
no acredita que una app arbitraria haya aceptado el contenido. Terminales embebidos
sin categoría TerminalEmulator o atajos personalizados pueden requerir pegado manual.
Wayland/KWin es el destino implementado; sin su protocolo se mantiene solo copia.

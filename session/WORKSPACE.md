# Singlr Workspace — T246

Implementación propuesta del sistema 03 sobre **KWin 6.8.1 / Qt 6.12.0**.
La composición visual queda pendiente de revisión del creador.

## Uso

| Acción | Entrada |
| --- | --- |
| Cambiar ventana | Alt+Tab; Alt+Shift+Tab retrocede; soltar Alt activa; Esc cancela |
| Navegar el cambiador | Flechas; clic activa una miniatura; Enter acepta (KWin) |
| Vista general | Meta+Tab; gesto de tres dedos arriba (P-015) |
| Cambiar escritorio | Clic en su número en la barra; Ctrl+Meta+←/→ (KWin) |
| Crear escritorio | + en la vista general; Ctrl++ dentro de la vista |
| Cambiar en vista general | Clic en miniatura de escritorio; Ctrl+1…9 |
| Mover ventana a escritorio | Arrastrar su miniatura al escritorio de destino |
| Quitar escritorio | Menú derecho o Supr; confirmar dentro del menú; nunca el último |
| Buscar | Escribir en la vista general abre Command con ese texto y en esa salida |
| Mitades | Meta+← / Meta+→, acciones estándar de KWin |
| Maximizar / minimizar | Meta+↑ / Meta+↓ (P-015) |
| Editor de mosaicos | Meta+T, editor estándar de KWin; Esc sale |
| Usar zonas del editor | Arrastrar una ventana por el título manteniendo Shift |
| Menú nativo de ventana | Alt+F3, o menú de la decoración; acciones y escritorios de KWin |

Los atajos de KWin personalizados del usuario siguen siendo suyos. Meta+T y
las mitades se documentan con su asignación estándar; no se duplican motores,
acciones, geometrías ni editores. El editor está presente en la instalación
6.8.1 (`/usr/share/kwin/builtin-effects/tileseditor.json`).
[Referencia oficial del editor Meta+T](https://blogs.kde.org/2026/02/21/this-week-in-plasma-6.6-is-here/).

## Integración

- `session/kwin/tabbox/singlr`: KPackage `KWin/WindowSwitcher`, mismo contrato
  `TabBoxSwitcher`/`WindowThumbnail.wId` que el `thumbnail_grid` instalado.
  KWin administra el modelo, MRU, Alt/Shift+Tab, aceptación y cancelación.
  Las flechas y el clic usan la misma selección de KWin; la vista es desplazable.
- `singlr_kwin.py`: `TabBox/LayoutName=singlr`, `ShowTabBox=true`, dentro del
  journal original de entrada/salida/recuperación. Admite el formato anterior
  sin claves TabBox y lo restaura antes de capturar las nuevas. Plasma recupera
  la elección anterior, incluido clave ausente o valor vacío.
- Indicador: `TaskManager.VirtualDesktopInfo` obtiene IDs, nombres y escritorio
  por pantalla. La activación usa `org.kde.KWin.VirtualDesktopManager` mediante
  el módulo D-Bus de Plasma. No son escritorios simulados ni temporizadores.
  Con uno solo se oculta; con muchos mantiene 72 px y desplazamiento interno.
- Overview conserva `Workspace`/`WindowFilterModel` y sus miniaturas reales por
  pantalla, actividad y escritorio. Se comparte `Singlr.Ui` con el shell:
  Inter, paleta KDE claro/oscuro, Phosphor, bordes, superficies y movimiento
  reducido. El fondo real sigue visible bajo el tinte; no se añade blur propio.
- `WorkspaceBridge` se exporta únicamente cuando `Session` lo habilita, en
  `/SinglrWorkspace` del servicio que ya posee el shell. El efecto pasa texto
  y nombre de salida después de liberar la captura de teclado. La desconexión
  de esa salida usa la pantalla del dock como destino de respaldo.
- CMake adapta solo las copias instaladas de los imports compartidos. No
  instala copias de tokens ni depende de rutas del checkout en producción.

Contratos oficiales: [cambiador](https://develop.kde.org/docs/plasma/windowswitcher/),
[Workspace y ventanas](https://develop.kde.org/docs/plasma/kwin/api/).
Contraste local: `/usr/share/kwin/tabbox/thumbnail_grid`,
`/usr/include/kwin/dbusinterface.h`, `taskmanager.qmltypes`,
`dbusplugin.qmltypes` y metadatos extraídos de `libkwin.so.6.8.1`.

## Verificación anidada para Claude

Fuera del sandbox, desde una terminal de Wayland, sin instalar ni recargar la
sesión del creador:

```bash
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_LIBDIR=lib
cmake --build build --parallel 2
tools/test-qml.sh
tools/test-qml.sh --light
python3 tests/shell/workspace-e2e.py --interactive
```

El procedimiento prepara paquetes en XDG temporal, reescribe sus imports al
checkout, inicia KWin con dos salidas, bus/config/state propios y duración
máxima de diez minutos. Aplica la misma transacción de sesión, abre tres
Dolphin, crea dos escritorios y mueve una ventana al segundo. Guarda escritorio,
vista general, log y snapshot. Enter termina y limpia solo esa sesión;
comprueba inventario de procesos y hashes de configuración anfitriona.
Sin `--interactive`, también llama al endpoint de búsqueda y captura Command.
Este modo no prueba la escritura física ni el gesto de arrastre.

Recorrido manual en las salidas anidadas (capturar con `tools/capture-session.sh`
y el `SINGLR_SESSION_FILE` privado anunciado):

1. Dos ventanas en el primer escritorio, una en el segundo. Comprobar títulos,
   iconos originales y miniaturas vivas en Alt+Tab. Mantener Alt; Tab/Shift+Tab,
   flechas, Enter, soltar Alt y Esc. Repetir con más ventanas que celdas visibles.
   Asegurar que el teclado se dirige al compositor anidado, no al anfitrión.
2. Meta+Tab sigue abriendo Overview. Crear un escritorio con +; cambiar con clic
   y con el indicador; arrastrar una ventana, volver y comprobar pertenencia.
   Eliminar desde el menú requiere confirmar; el último no se elimina.
3. Abrir una ventana en cada salida: cada vista debe incluir solo sus ventanas.
   Cambiar escritorio, repetir con escritorios independientes por pantalla si
   están habilitados. Escribir «2+2» desde cada salida: Command debe abrir allí
   con la consulta completa. Esc no debe abrir Command. Desconectar una salida.
4. Alt+F3 muestra operaciones nativas; Meta+←/→ coloca mitades; Meta+T abre el
   editor de KWin, Shift+arrastre usa sus zonas. Verificar recuperación del foco.
5. Repetir claro/oscuro, escala 1 y 1.5, animación reducida, compositor sin blur.
   Guardar capturas reales `alt-tab.png`, `overview.png`, `command.png` en
   `tests/shell/evidence/t246/nested/` y revisar avisos del log.
6. En un perfil XDG temporal, ejecutar apply/restore del helper, con una elección
   TabBox previa distinta: al restaurar debe recuperarla. El test Python ya
   comprueba ese ciclo real con KConfig, claves ausentes y journal anterior.
7. Medir `tools/measure-resources.sh --output /tmp/t246-resources-real` en idle y
   con paneles abiertos antes de integrar (P-016). Las miniaturas viven en KWin;
   medir también el compositor, no atribuir todo el coste al shell.

El harness anidado usa atajos globales desactivados para aislar al anfitrión.
Invoca Overview por el componente privado de KGlobalAccel; si la entrada física
no llega al KWin anidado, Claude debe usar su entorno virtual de entrada o una
sesión virtual dedicada, sin cambiar los atajos de la sesión anfitriona.

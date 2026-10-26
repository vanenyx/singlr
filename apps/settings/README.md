# Ajustes de Singlr

Ventana normal de 880×600, con apariencia compartida con el shell.

## Apariencia del sistema (T241)

KDE es la fuente de verdad. Appearance.qml importa el módulo nativo
Singlr.System, que recibe cambios de paleta de Qt y notificaciones KConfig.
Claro/Oscuro escribe AutomaticLookAndFeel=false y usa la herramienta de
colores de Plasma. Automático activa el autoswitcher de KDE con el horario de
knighttime; no hay un horario de Singlr. Los temas automáticos configurados por
el usuario se respetan. Sin alternativas se usan los dos paquetes Singlr que
solo declaran el esquema de color, conservando la decoración y demás ajustes.

El acento se persiste en las claves del KCM de KDE y se aplica con
plasma-apply-colorscheme. El indicador de selección muestra la preferencia;
la paleta del shell sigue el highlight efectivo de KDE, que puede ajustarse
para contraste. No existe la opción separada «Aplicar también a las apps».

La migración única de mode/accent desde singlr.conf mantiene el schema 1 de
T239, conserva fondo y claves desconocidas y deja los datos antiguos intactos
si falla. Los perfiles nuevos siguen KDE sin imponer valores al abrir la app.
Los procesos de aplicación son asíncronos y se serializan, con error visible.

## Fondo

QtCore.Settings mantiene Appearance/wallpaper en
StandardPaths.ConfigLocation + /singlr/singlr.conf. Los presets son
singlr:linear, singlr:glow, singlr:light y singlr:graphite; también se admiten
imágenes locales file:///. Se guarda antes de notificar por D-Bus al shell.
Wallpaper comparte la vista previa y el fondo entre app y shell y muestra el
predeterminado detrás de imágenes no disponibles.

## Selección nativa de archivos (T256)

El explorador de Singlr es Dolphin (P-024). La ventana para elegir el fondo es un
selector de archivos de KDE, no una instancia de Dolphin ni un explorador propio.
`QtQuick.Dialogs.FileDialog` conserva la API, los filtros y la persistencia; el
lanzador inicia `qml6 --apptype widget` para que plasma-integration proporcione
su helper QWidget/KFileWidget. Si no hay tema explícito, usa `QT_QPA_PLATFORMTHEME=kde`.
Una selección explícita del usuario del tema de plataforma se respeta.

Prueba nativa del diálogo real, selección de PNG con espacios/#/Unicode y cancelación:

```sh
cmake --build build --target singlr-file-dialog-test
QML_IMPORT_PATH="$PWD/build/qml" build/session/appearance/singlr-file-dialog-test
```

La prueba crea XDG temporales y desconecta ambos buses antes de QApplication.
No modifica el fondo ni abre diálogos sobre la sesión habitual. El listado
asíncrono KIO, montajes y red requieren una sesión KDE completa; la prueba
comprueba el helper nativo y el retorno de una imagen local existente.

## Desarrollo y comprobación

CMake compila e instala Singlr.System en el directorio QML estándar. Antes de
usar la app desde el checkout:

```sh
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_LIBDIR=lib
cmake --build build
SINGLR_DEV_ROOT="$PWD" apps/settings/singlr-settings
```

Para invocaciones directas de qml6/qmltestrunner añadir
QML_IMPORT_PATH=$PWD/build/qml. Las pruebas usan XDG temporal y bus inexistente;
no ejecutar los controles de prueba con la configuración del perfil real.

Resultados T241: 7 pruebas QML de ajustes pasan, 8 checks QtTest del adaptador
nativo pasan y el lint de los archivos modificados termina sin avisos. Las
pruebas cubren configuración KDE, selección del acento, persistencia del fondo,
recarga fallida, paleta efectiva y migración. El recorrido completo con portal,
autoswitcher y apps GTK requiere sesión anidada: está bloqueado por los sockets
del sandbox. [Inventario, causa de los SVG vacíos y evidencia](../../session/GTK.md).

Las capturas de captures/ corresponden a la revisión visual T228 anterior;
no acreditan el nuevo puente KDE ni la integración GTK de T241.

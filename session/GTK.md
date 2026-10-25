# T241 — Apariencia KDE y aplicaciones GTK/CSD

Solución técnica derivada de P-005/P-016/P-017. KDE es la fuente de verdad;
no se define una paleta nueva ni un horario propio. Sin commit ni cambios a la
sesión activa. Claude recoge las decisiones técnicas en docs/decisions.md al
integrar (fuera del alcance de escritura de este encargo).

## Integración final

`Singlr.System.KDEAppearance` es un módulo QML nativo pequeño, compartido por
la app de ajustes y Appearance.qml. Lee la paleta efectiva de QGuiApplication y
recibe ApplicationPaletteChange; lee AutomaticLookAndFeel mediante
KConfigWatcher. El shell sigue claro/oscuro y highlight de KDE, igual que la
paleta que utiliza el portal. No calcula la hora y no consulta archivos por
intervalos. Theme.qml se modifica únicamente para retirar su reloj y seguir
Appearance.dark. No se modifica lockscreen.

Claro y Oscuro desactivan `kdeglobals [KDE] AutomaticLookAndFeel` mediante
KConfig::Notify y ejecutan `plasma-apply-colorscheme BreezeLight|BreezeDark`.
Automático activa esa clave: **el kded lookandfeelautoswitcher de KDE 6.8.1**
resuelve el modo y sus transiciones con knighttime (horario del usuario / ciclo
solar), incluidos cambios del reloj e inactividad. La sesión solicita también
la unidad estándar plasma-knighttimed. No hay singlr-appearance, servicio,
path ni timer propios.

Si no hay alternativas configuradas, se guardan DefaultLightLookAndFeel y
DefaultDarkLookAndFeel con `dev.singlr.light` / `dev.singlr.dark`. Son paquetes
LookAndFeel estándar que contienen únicamente ColorScheme=BreezeLight/Dark:
el autoswitcher aplica los contenidos declarados, sin sustituir la decoración
Singlr, los iconos ni el fondo. Se conservan las alternativas que ya estén
configuradas en KDE. Si el usuario eligió temas globales más amplios en KDE,
se aplica su comportamiento completo, como en Plasma.

El acento guarda AccentColor, LastUsedCustomAccentColor y
accentColorFromWallpaper=false en [General], como el KCM de colores, y llama a
plasma-apply-colorscheme --accent-color. Es necesario guardar la preferencia:
la herramienta de 6.8.1 solo aplica el acento suministrado. El siguiente cambio
automático de esquema conserva así el acento. Tampoco se combinan esquema y
--accent-color en una llamada: en 6.8.1 la opción tiene prioridad y omite el
argumento posicional. La selección del control lee la preferencia KDE; los
tokens del shell leen el highlight efectivo, que KDE adapta para contraste.

Se elimina «Aplicar también a las apps de KDE» y el helper Python redundante.
El guardado del fondo sigue usando singlr.conf y avisa al shell por D-Bus.

## Migración y distribución

Al instanciar el módulo, un perfil con mode/accent antiguos se migra una sola
vez a KDE. Se mantiene el schema 1 de T239 y se añade el marcador separado
Config/kdeAppearanceMigrated. Se conservan fondo y claves desconocidas; los
esquemas futuros o inválidos no se tocan. Un QLockFile evita dos migraciones
simultáneas entre shell y ajustes. Solo después del éxito se retiran mode,
accent y applyToApps antiguos. Un fallo conserva las claves para reintentar.
Un perfil nuevo sigue KDE sin imponer preferencias al arrancar.

CMake instala el módulo en el directorio QML estándar y los dos LookAndFeel.
El paquete declara kde-gtk-config, breeze-gtk y xsettingsd explícitamente.
No se inicia otro daemon de XSettings ni se escribe CSS de GTK a mano.
Para desarrollo, compilar con CMake antes de lanzar la UI; los lanzadores de
ajustes y las herramientas de prueba anteponen build/qml. Una invocación directa
de qml6 o shell/session/qml-shell necesita QML_IMPORT_PATH=$PWD/build/qml.

## Inventario y mecanismos KDE

Verificado localmente: Plasma/kde-gtk-config/breeze-gtk/portal-kde 6.8.1,
KWin 6.8.1-2, Qt 6.12.0, GTK3 3.24.52, xsettingsd 1.0.4. GTK4/libadwaita,
gtk3-demo, gtk4-demo y Nautilus no están instalados. Disponibles:
/usr/lib/gtk3_preview, Chrome y Firefox. No se instalaron paquetes.

Singlr ya solicita plasma-kded6 y ambos portales; gtkconfig y
lookandfeelautoswitcher son kded autoload. No se pudo consultar loadedModules
del bus anfitrión: el sandbox deniega el acceso al socket. Los archivos GTK
existentes acreditan sincronización previa, no el estado actual del módulo.

KDE traduce el orden de kwinrc a gtk-decoration-layout de GTK3/GTK4,
org.gnome.desktop.wm.preferences/button-layout y XSettings. Sincroniza colores,
fuentes, cursores y preferencias a GTK mediante sus propios mecanismos.
GTK3 tiene Breeze y los módulos colorreload/window-decorations. No se fuerza
GTK_USE_PORTAL: su ausencia no impide Appearance en libadwaita y también
influye en la ruta de integración nativa de gtkconfig sobre Wayland.

XDG_CURRENT_DESKTOP=Singlr:KDE permite resolver kde-portals.conf instalado:
Settings lo implementa KDE. org.freedesktop.appearance es un namespace de
Settings, no un backend separado. El portal toma color-scheme y accent-color
de la paleta de KDE y notifica sus cambios; no necesita un portal Singlr.
La lectura y los cambios del portal sobre un bus real siguen pendientes.

## Causa demostrada de los botones GTK3 vacíos

**Limitación de búsqueda en kde-gtk-config 6.8.1**, no del SVG de Singlr:

- DecorationPainter::get() selecciona Aurorae por el prefijo
  `__aurorae__svg__` del tema. La diferencia aurorae / aurorae.v2 del identificador
  de biblioteca no interviene en esa selección; no se cambia el helper KWin.
- AuroraeDecorationPainter construye la ruta exclusivamente desde
  QStandardPaths::writableLocation(GenericDataLocation), más aurorae/themes.
  No busca GenericDataLocation con locate/locateAll ni recorre /usr/share.
- Singlr está correctamente empaquetado en /usr/share/aurorae/themes/Singlr.
  KWin sí lo encuentra; el generador GTK de KDE intenta el directorio de datos
  del usuario, falla al cargar el SVG y genera un documento sin geometría.

Fuentes exactas del tag v6.8.1:
[selector](https://github.com/KDE/kde-gtk-config/blob/v6.8.1/kded/kwin_bridge/decorationpainter.cpp)
(blob 469d295a343693b7c3f4cf72b24d0cd63c3d8810) y
[renderizador](https://github.com/KDE/kde-gtk-config/blob/v6.8.1/kded/kwin_bridge/auroraedecorationpainter.cpp)
(blob 4fafed1e8010439e45ed48a06a1eb8f39feff9e8).

La prueba tests/shell/gtk_csd.cpp reproduce esa ruta y el renderizado de Qt
sin ejecutar kded. Resultado para cuatro botones y cuatro estados:
`system/source=16/16 user-missing=0/16 temporary-user-copy=16/16`.
La copia de control existe exclusivamente en XDG_DATA_HOME temporal y se
elimina al terminar; no se instala ni se propone como solución de producto.
En el perfil existente se observaron 24 SVG GTK3 sin geometría y ningún SVG
GTK4. No se parchea KDE ni se duplica el tema en cada perfil. Queda pendiente
una corrección upstream para que GTK3 pueda reproducir estos botones desde
una instalación de sistema.

## Otros límites estándar

GTK4/libadwaita puede seguir el orden y la preferencia de color, pero no carga
los módulos GTK3 ni recibe formas de Aurorae por el portal. Conserva sus CSD.
Las aplicaciones pueden imponer un modo y adaptar/cuantizar el acento según
su versión. No se fuerza GTK_THEME ni CSS externo. Los colores fijos del tema
SVG Singlr tampoco se convierten automáticamente en variantes claras.

Chrome/Chromium ofrece tema GTK, pero sus CSD no garantizan usar las imágenes
generadas por gtkconfig. La opción «Usar barra de título del sistema y bordes»
entrega la decoración a KWin. Electron depende de la aplicación y no tiene un
ajuste KDE universal. No se modifican preferencias por aplicación.

## Evidencia y pendientes

- 8 checks nativos QtTest: lectura por eventos de paleta, escritura KDE,
  alternativas automáticas del usuario, migración única y reintento tras fallo.
- 4 pruebas Python: ejecutan los checks nativos, la herramienta real de Plasma
  con persistencia del acento entre esquemas, la reproducción de Aurorae y
  ambos paquetes LookAndFeel reales conservando la decoración.
- QML ajustes: 7 pasan. Suite QML shell: 128 pasan, usando como fixture una
  paleta KDE BreezeDark temporal, pues dos tests previos asumen colores oscuros.
- qmllint de los archivos modificados: sin avisos. CMake compila e instala en
  DESTDIR; se verifican biblioteca, plugin, rutas, permisos y temas globales.
- check_setup y regresiones de sesión/empaquetado ejecutadas; detalle final en
  tools/evidence/t241.txt.

Todas las pruebas usan XDG temporal y bus inexistente o privado. No se tocó la
sesión activa. El intento KWin anidado falla antes de arrancar el compositor:
D-Bus no puede crear su socket (`Operation not permitted`). Limpieza sin
procesos restantes y hashes KDE del anfitrión iguales antes/después. Por la
misma restricción no hay capturas GTK, prueba real de SettingsChanged ni medida
P-016 del escritorio; no se declara listo para integración sin esos checks.

Reproducción de los checks offline:

```sh
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_LIBDIR=lib
cmake --build build --target singlr-appearance-test singlr-systemplugin
python3 -m unittest discover -s tests/shell -p test_gtk_integration.py
tools/check-cmake.sh
```

Fuera del sandbox, completar en KWin anidado con XDG y bus privados: arrancar
kded/knighttimed/portales sin usar systemd del anfitrión, probar las apps
disponibles, leer Settings.Read para color-scheme/accent-color, observar
SettingChanged al cambiar KDE y capturar con tools/capture-session.sh. Para
autoswitch instalar los paquetes de datos en XDG_DATA_DIRS temporal. Medir con
tools/measure-resources.sh antes de integrar; las capturas offscreen de pruebas
no acreditan funcionamiento de apps GTK ni del portal.

Más fuentes v6.8.1:
[autoswitcher](https://github.com/KDE/plasma-workspace/blob/v6.8.1/kcms/lookandfeel/kded/lookandfeelautoswitcher.cpp),
[claves](https://github.com/KDE/plasma-workspace/blob/v6.8.1/kcms/lookandfeel/lookandfeelsettings.kcfg),
[aplicador de temas](https://github.com/KDE/plasma-workspace/blob/v6.8.1/libklookandfeel/klookandfeelmanager.cpp),
[herramienta de colores](https://github.com/KDE/plasma-workspace/blob/v6.8.1/kcms/colors/plasma-apply-colorscheme.cpp),
[preferencias de acento](https://github.com/KDE/plasma-workspace/blob/v6.8.1/kcms/colors/colorssettings.kcfg).

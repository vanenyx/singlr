# T256 — Dolphin y selector nativo de KDE

26 oct 2026. Encargo directo del creador: Dolphin como explorador del producto e
integración coherente, incluida la selección del fondo. P-024 es la decisión
explícita; la elección del helper nativo es una solución técnica derivada.

## Causa y corrección

Ajustes ya usaba QtQuick.Dialogs.FileDialog; no había un gestor de Singlr. El
lanzador ejecutaba qml6 con su QGuiApplication por defecto. El helper QWidget de
plasma-integration no estaba disponible, por lo que aparecía el fallback Qt Quick.

Se usa `qml6 --apptype widget` (QApplication) y tema `kde` si no hay uno explícito.
El diálogo utiliza el KFileWidget nativo de KDE; conserva filtro de imágenes,
selección y guardado. Dolphin es el explorador para carpetas y ubicaciones, y
FileManager1 sigue siendo la integración de «Mostrar en carpeta». No se modifica
Dolphin ni se crea un fork, otro selector o un protocolo de selección propio.

El MIME inode/directory del creador ya resuelve a org.kde.dolphin.desktop; no se
reescribe. Dolphin y plasma-integration quedan explícitos en PKGBUILD (la segunda
ya era dependencia transitiva de plasma-workspace en este equipo).

Versiones locales: Qt 6.12.0, plasma-integration 6.8.1, Dolphin 26.08.2. Contratos:
[qml --apptype](https://doc.qt.io/qt-6/qtqml-tooling-qml.html),
[FileDialog](https://doc.qt.io/qt-6/qml-qtquick-dialogs-filedialog.html),
y cabeceras locales KFileWidget de KF6/KIO.

## Evidencia

- Probe aislada sobre Main.qml real: QGuiApplication → KFileWidget=false;
  QApplication → KFileWidget=true. Misma configuración temporal por caso.
- Target `singlr-file-dialog-test`: cuatro resultados QtTest correctos. Carga
  Ajustes real, exige KFileWidget visible, selecciona un PNG local con espacios,
  # y acento mediante el widget nativo y comprueba la URL persistida; vuelve a
  abrir y cancelar conservando el fondo. XDG temporal y buses inexistentes.
- Cinco pruebas de packaging correctas: launcher de desarrollo/instalado, modo
  widget, tema KDE por defecto y respeto de tema explícito, rutas con espacios,
  argumentos y error de entrada ausente.
- CMake/DESTDIR correcto; plugin de vidrio omitido por configuración local OFF,
  no se atribuye validación del efecto a este check.
- Captura del widget nativo con una ruta sintética: [evidencia](../../tests/shell/evidence/t256/README.md).

## Alcance y límites

No se tocó el fondo ni se recargó la sesión. Los buses desconectados no permiten
acreditar listado asíncrono KIO, dispositivos ni red. La captura no certifica
renderizado Wayland. La integración de aplicaciones sandbox sigue correspondiendo
al portal KDE ya solicitado por la sesión; no se fuerza una UI sobre aplicaciones
de terceros que implementen su propio selector.

Para utilizar el nuevo lanzamiento desde el menú hay que actualizar el paquete
instalado. Desde el checkout se puede iniciar `apps/settings/singlr-settings`.

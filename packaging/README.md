# Empaquetado local de Singlr (T229)

Preparación técnica de Fase 1, sin publicación ni instalación en esta entrega.
El paquete instala una sesión separada; no habilita unidades ni cambia KDE.
Debe integrarse primero `apps/settings/Main.qml` del trabajo de Codex 1.
La licencia de distribución sigue pendiente; no publicar este paquete local.

Desde la raíz del checkout, crear un snapshot que incluya los cambios sin commit:

```bash
git ls-files -z --cached --others --exclude-standard -- \
    ':!:packaging/arch/*.tar*' ':!:packaging/arch/src/**' ':!:packaging/arch/pkg/**' | \
    tar --null -T - --transform='s,^,singlr-0.1.0/,' \
        -czf /tmp/singlr-0.1.0.tar.gz
cp /tmp/singlr-0.1.0.tar.gz packaging/arch/
cd packaging/arch
makepkg -si
```

`makepkg -si` compila e instala con pacman; ejecutarlo solo cuando se quiera
instalar en el equipo. Requiere las herramientas de `base-devel`; makepkg
resuelve las dependencias declaradas. No se ha ejecutado en esta entrega.
El snapshot usa `SKIP` por ser local: fijar SHA-256 antes de distribuirlo.
No mezclar este paquete con el instalador manual de metadatos `session/install.sh`.
Para desinstalar, `pacman -R singlr-desktop` desde otra sesión, con Singlr cerrado.

## Validación sin instalar

```bash
tools/check-cmake.sh
python3 -m unittest discover -s tests/shell -p test_packaging.py -v
bash -n packaging/arch/PKGBUILD
```

El check usa `build/`, prefijo `/usr`, libdir `lib` y un DESTDIR temporal;
verifica binarios, QML, fuentes, unidades, decoración, efecto y script antes de
eliminar el staging. Si CMake no existe, informa y termina con 0; ese resultado
no acredita compilación ni instalación. Si existe, cualquier fallo es un error.
`build.py` y `qml-shell` siguen siendo la vía de desarrollo sin CMake.

CMake configura las copias instaladas del supervisor, entrada de sesión,
servicio y lanzador con `${KDE_INSTALL_FULL_LIBDIR}/singlr`. El QML se instala
allí en `qml`, los ajustes en `apps/settings` y las fuentes en `third_party`.
Solo la copia generada de `Theme.qml` adapta la referencia relativa a las
fuentes; el QML del checkout permanece intacto. El lanzador usa el checkout
cuando está dentro de él, o `SINGLR_DEV_ROOT` explícito; instalado usa la ruta
configurada. No compila durante el login. Los prefijos con espacios no están
soportados por Exec de la entrada de sesión.

Targets contrastados con los Config/Targets.cmake locales: Qt 6.12.0,
KF6 6.31.0, LayerShellQt/Plasma 6.8.1. `libnm` se enlaza mediante pkg-config.
Directorios según [KDEInstallDirs6](https://api.kde.org/ecm/kde-module/KDEInstallDirs6.html).
Moc se gestiona con [AUTOMOC de Qt](https://doc.qt.io/qt-6/moc.html).
Dependencias Arch contrastadas con pacman local (propiedad de plugins QML) y
[plasma-workspace](https://archlinux.org/packages/extra/x86_64/plasma-workspace/),
[layer-shell-qt](https://archlinux.org/packages/extra/x86_64/layer-shell-qt/).
La ejecución real de la sesión y la recarga visual quedan para la prueba aislada
tras integrar QML; las pruebas nativas solo acreditan el despacho del puente.

## Evidencia de T229

- 5 pruebas de `test_packaging.py` correctas: lanzador con rutas de desarrollo e
  instalación, argumentos con espacios, app ausente, sintaxis bash, nombres,
  fuentes CMake, ausencia de CMake y despacho nativo de recarga.
- 7 pruebas existentes de `test_session_entry.py` correctas.
- `shell/session/build.sh`: compilación correcta; aviso preexistente por
  `LayerShellQt::Shell::useLayerShell()` obsoleto. Las siete unidades C++
  también pasan `g++ -fsyntax-only` por separado.
- `scripts/check_setup.py` y `git diff --check`: correctos.
- CMake, Ninja y ECM ausentes: no se configuró/compiló con CMake ni se
  ejecutó DESTDIR/makepkg. `tools/check-cmake.sh` informa la omisión con código 0.
- Sin prueba de login ni recarga visual; no se modificó la sesión KDE.

## Actualizaciones con pacman (repositorio local)

`tools/build-package.sh` construye desde `HEAD` con versión `0.1.0.r<commits>.g<hash>`
(convención VCS de Arch: cada build es más nueva) y la añade a `.local/repo` con `repo-add`.
Configuración única, decidida por el creador (requiere sudo):

```ini
# /etc/pacman.conf, al final
[singlr]
SigLevel = Optional TrustAll
Server = file:///home/sunw/Projects/singlr/.local/repo
```

Después Singlr se actualiza con el sistema: `sudo pacman -Syu`. El repositorio es local y
sin firma; publicarlo (remoto, firma, checksums fijos) sigue pendiente de autorización.

## Aceptación y soporte — T247

CMake instala también `/usr/bin/singlr-doctor` (Python, ya dependencia del paquete).
No incorpora hooks, servicios residentes ni escrituras en HOME al instalar.
`singlr-doctor --output informe-nuevo.json` prepara el informe filtrado para una
incidencia; no adjuntar journal crudo ni el inventario privado del usuario.

[Instalación limpia, inventario de HOME y retorno a Plasma](../tests/session/README.md#instalación-limpia--desinstalación--plasma):
procedimiento para un usuario que creará el creador, con verificación tras cerrar
Singlr, tras `pacman -R singlr-desktop` y tras entrar en Plasma. Restaurar cualquier
transacción KWin pendiente **antes de desinstalar**. La desinstalación es global:
no hacerla mientras otro usuario esté usando Singlr. Las preferencias explícitas
de apariencia KDE son compartidas y persistentes; no se promete revertirlas con
pacman. La [matriz](../docs/compatibility.md) distingue cobertura real y pendiente.

## Workspace (T246)

El paquete instala `KWin/WindowSwitcher` en `kwin/tabbox/singlr`, junto al
Overview existente. La sesión aplica el tema Alt+Tab mediante el journal de
`singlr_kwin.py` y restaura la elección de Plasma al salir, también tras fallos.
Las copias instaladas del QML de Workspace apuntan a los tokens `Singlr.Ui`
instalados, no al checkout. Guía de uso, organización nativa de ventanas y
procedimiento de dos pantallas/escritorios: [session/WORKSPACE.md](../session/WORKSPACE.md).

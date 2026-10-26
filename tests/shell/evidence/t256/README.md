# T256 — selector de archivos KDE

[Captura offscreen/software](kde-file-picker.png) del KFileWidget nativo abierto
por el FileDialog real de Ajustes. Ruta e imagen sintéticas. Se captura antes de
aceptar; el listado asíncrono KIO no se acredita con buses desconectados.

Regenerar en XDG temporal administrado por el propio test:

```bash
cmake --build build --target singlr-file-dialog-test
QML_IMPORT_PATH="$PWD/build/qml" \
SINGLR_PICKER_CAPTURE="$PWD/tests/shell/evidence/t256/kde-file-picker.png" \
build/session/appearance/singlr-file-dialog-test
```

Resultado: 4 pasadas, 0 fallos. Ver [causa, cambios y límites](../../../../docs/handoffs/T256-native-file-picker.md).

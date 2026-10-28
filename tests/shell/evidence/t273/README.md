# T273 — orden de copia

Resultados filtrados de tres perfiles KWin privados nuevos: texto, imagen y solo
copiar. UUID sintéticos comparados por el adaptador; no se guardan contenidos o
UUID del portapapeles real. Cada sesión terminó con remaining=[] y hashes host
iguales. El recorrido mantiene la prueba original T258 de pegado real.

Reproducir tras compilar:

```bash
cmake --build build --target singlr-systemplugin singlr-clipboard-history-test singlr-clipboard-target
build/session/appearance/singlr-clipboard-history-test
python3 tests/shell/clipboard-paste-e2e.py --output /tmp/t273-text-new
python3 tests/shell/clipboard-paste-e2e.py --case image --output /tmp/t273-image-new
python3 tests/shell/clipboard-paste-e2e.py --case copy-only --output /tmp/t273-copy-new
```

Nativo: 4 resultados, 0 fallos. QML por modo: 244 shell + 11 Ajustes correctos,
5 capturas opcionales omitidas. Packaging: 5 correctas; CMake/DESTDIR, qmllint,
check_setup y diff correctos. No se ejecutaron aquí Warp real, otros escritorios
ni una actualización en caliente de la sesión habitual.
[Contrato y límites](../../../../docs/handoffs/T273-clipboard-copy-order.md).

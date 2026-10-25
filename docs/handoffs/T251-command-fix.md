# T251 — Command: origen, relevancia y duplicados

Codex 1 · `day3/codex1-command-fix` · sin commit. No se tocaron materiales.

- Causa comprobada: los IDs de los plugins C++ instalados son
  `krunner_systemsettings`, `krunner_services` y `krunner_appstream`, no sus
  nombres abreviados. La restricción `systemsettings` de T250 no aislaba KCM.
  Fixture de metadatos **capturada del framework instalado**:
  `tests/shell/fixtures/runner-metadata-plasma-6.8.1.json` (opción `--metadata`
  del capturador). Baloo se identifica como `baloosearch`.
- `Singlr.Command.CommandSourceModel` deriva del modelo estándar KRunner que
  también usa Milou y añade el rol `runnerId` desde `QueryMatch.runner()->id()`.
  No interpreta prefijos de IDs de resultados: los IDs únicos de services/Baloo
  pueden carecer de prefijo. Conserva ejecución, acciones y roles de KDE.
- El agregado filtra el modelo dedicado por origen comprobado, unifica KCM en
  Configuración y deduplica por ID global entre consultas. Conserva el resultado
  de la consulta original si también llega por la consulta de sinónimos.
- Calculadora/conversiones primero; aplicaciones instaladas y configuración
  antes del resto; ofertas AppStream/Discover al final, sección independiente,
  máximo tres. Secciones contiguas según su mejor relevancia KDE; filas por
  relevancia, categoría y desempate estable. Sin clasificación por palabras.

## Verificación ejecutada

- `cmake -S . -B build -DSINGLR_BUILD_LIQUIDGLASS=OFF` y build: correctos.
  Se conserva el valor predeterminado del proyecto; no se editó el efecto.
- `tools/test-qml.sh`: **204 passed, 0 failed, 3 skipped** (shell) y
  **8 passed, 0 failed** (settings). Command aporta 16 resultados correctos,
  incluidos bluetooth, wifi, fondo, firefox y 2+2, más unitconverter;
  duplicados, llegada progresiva, cambio de relevancia, índices de ejecución
  y ofertas con texto engañoso. Las omisiones son pruebas de captura optativas.
- Repetición focalizada tras ajustar IDs/nombres de la fixture contra los KCM
  instalados: **16 passed, 0 failed**. `qmllint` con imports fuente/build: sin
  diagnósticos. `python3 scripts/check_setup.py` y `git diff --check`: correctos.
- Metadatos: Plasma/milou 6.8.1, KF6 Runner 6.31.0, Qt 6.12.0.

## Fixture de consultas reales pendiente por sandbox

`tools/capture-command-fixture.sh OUTPUT.json` compila un capturador C++,
consulta los modelos KRunner en un **bus privado**, perfil XDG temporal y bus
system deshabilitado, y guarda runner, ID, categoría, relevancias y demás roles.
Incluye las cinco búsquedas; wifi conserva la consulta original y consulta network
solo para KCM. Rechaza resultados incompletos por timeout. No ejecuta resultados.

Aquí `dbus-run-session` falla al crear su socket (`Operation not permitted`),
antes de consultar. Intentar consultar sin bus produjo un diálogo/fallo de KDE;
no se usa el bus cotidiano como alternativa. Evidencia en
`tests/shell/evidence/t251/private-bus.txt`.

`command-contract.json` es una **fixture de contrato, no captura de consultas**:
IDs/orígenes y categorías contrastados con el sistema, forma y escalas contrastadas
con las APIs/código oficial; relevancias representativas, sin afirmar que sean
mediciones de estas consultas. Incluye deliberadamente una oferta en el modelo
supuestamente dedicado para reproducir el fallo de T250. Fuentes en su provenance:
[QueryMatch](https://api.kde.org/krunner-querymatch.html),
[runner KCM](https://github.com/KDE/systemsettings/blob/master/runner/systemsettingsrunner.cpp),
[AppStream](https://github.com/KDE/plasma-workspace/blob/master/runners/appstream/appstreamrunner.cpp).

Claude puede generar la fixture nativa con el script fuera de la restricción de
sockets y repetir Command en su sesión anidada, comprobando Bluetooth primero,
Permisos una sola vez y tienda al final. El perfil vacío del capturador no tiene
índice Baloo personal: los casos de archivos se cubren en el contrato, no como
captura de resultados Baloo vivos. No se acredita aún esta validación anidada.
No se instaló ni recargó la sesión del creador.

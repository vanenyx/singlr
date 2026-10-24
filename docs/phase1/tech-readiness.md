# T102 — Preparación técnica (2026-10-24)

Encargo explícito: preparar ejecución/captura/medición aisladas; no elegir arquitectura final.
Herramientas y aislamiento: solución técnica derivada. Recomendación: propuesta por validar.

## Entorno e inventario ejecutado

Arch; Qt 6.12.0; Plasma/KWin 6.8.1; Kirigami/KWindowSystem 6.31.0; LayerShellQt 6.8.1.
Sesión heredada Wayland (`wayland-1`); eDP-1 2560×1600 / 1,25 según Claude, no reconsultada aquí.
PCI: NVIDIA RTX 4070 Max-Q/Mobile + AMD Radeon 610M; el sandbox no expone `/dev/dri`.
`python3 scripts/doctor.py`: qml6, qmllint y qsb disponibles; sin instalaciones.
`python3 tools/inventory-qml.py`: QML mínimo independiente por import, no inferencia por paquetes.

| Import/contrato | Resultado local |
|---|---|
| QtQuick.Effects, Shapes, Controls, Layouts | PASS los cuatro |
| QtQuick.ShaderEffect; [qsb](https://doc.qt.io/qt-6/qtshadertools-qsb.html) `--qt6` | Instancia PASS; shader compilado a seis variantes |
| Qt5Compat.GraphicalEffects; org.kde.kirigami | PASS ambos |
| org.kde.layershell | PASS import; protocolo/attached properties sin integración verificada |
| org.kde.plasma.core/components/extras/plasmoid/configuration/shell/plasma5support | PASS los siete |
| Otros módulos Plasma públicos descubiertos | PASS salvo welcome; detalle en evidencia |
| org.kde.plasma.welcome | FAIL: plugin estático, no cargable por qml6; plasma-welcome ya instalado |
| Quickshell; Quickshell.Wayland | FAIL: no instalados; paquete Arch [quickshell](https://archlinux.org/packages/extra/x86_64/quickshell/) |

Evidencia: [imports](../../tools/evidence/qml-imports.txt), [ejecuciones](../../tools/evidence/runtime-check.txt).
Imports no acreditan servicios: Plasmoid requiere host Plasma; welcome no bloquea Fase 1.
Qt Wayland proviene aquí de **qt6-base** (`pacman -Qo libqwayland.so`); no asumir paquete qt6-wayland.

## Ejecución, captura y medición

Contrato: [run-prototype.sh](../../tools/run-prototype.sh); instrucciones en [tools](../../tools/README.md).
Escena `prototypes/runtime-check/Main.qml`: 2048×1280, 90 figuras animadas y tres paneles,
con recortes vivos ShaderEffectSource → MultiEffect (blurMax 64); Espacio alterna blur.
`tools/check-qml.sh prototypes/runtime-check`: PASS (qmllint + carga/captura); host lint PASS.
`tools/run-prototype.sh prototypes/runtime-check/Main.qml --capture /tmp/singlr-runtime.png --size 2048x1280`: PASS.
PNG comprobado 2048×1280 e inspeccionado; backend **software**, sin RHI/GPU ni desenfoque real.
Qt documenta que [software omite ShaderEffect](https://doc.qt.io/qt-6/qtquick-visualcanvas-adaptations-software.html); ese PNG no prueba blur.
Dentro del sandbox, RHI OpenGL: FAIL. Fuera del sandbox (Claude), `--capture` con `QSG_RHI_BACKEND=opengl`: PASS en AMD Radeon 610M (Mesa 26.2.5) con desenfoque real visible.

| Modo, prueba de 11 s prevista | Muestras / media / p95 / máximo | Resultado |
|---|---|---|
| --window (Claude, fuera del sandbox) | 2238 / 5,7 ms / 12 ms / 392 ms | PASS; OpenGL en Radeon 610M; el máximo es un pico aislado al presentar la ventana |
| --nested (Claude, fuera del sandbox) | 1157 / 8,0 ms / 14 ms / 22 ms | PASS; KWin anidado 2048×1280, bus propio; sin procesos residuales al cerrar |

Contador: intervalos frameSwapped con Date.now(), 1 s de calentamiento, ~10 s útiles;
mide cadencia, no coste GPU. QSG_INFO + qt.rhi registran backend/adaptador al inicializarse.
Mediciones de cadencia en la pantalla de 240 Hz, no presupuestos aprobados. La GPU NVIDIA no se usó; queda pendiente comparar.
Comandos exactos para Claude **fuera del sandbox**, desde este checkout:
```bash
SINGLR_DURATION_MS=11000 tools/run-prototype.sh prototypes/runtime-check/Main.qml --window
SINGLR_DURATION_MS=11000 tools/run-prototype.sh prototypes/runtime-check/Main.qml --nested
QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl tools/run-prototype.sh prototypes/runtime-check/Main.qml --capture /tmp/runtime-rhi.png --size 2048x1280
```
Aislamiento: XDG config/datos/estado/caché temporales, runtime/socket y bus propios en nested;
KWin sin lockscreen, atajos globales ni KActivities; cierre de grupos propios y borrado temporal.
Tras intentos: 27 archivos de configuración k*/plasma* con hashes idénticos y cero procesos propios residuales.
No se verificó el ciclo exitoso de nested, sus ventanas residuales ni cierre por interacción: ejecutar arriba.
Pruebas negativas: QML inválido retorna 1; raíz Window captura PASS; check_setup.py PASS.

## Vías de escritorio real (evaluación, no aprobación)

| Vía | Ventaja | Coste/límite |
|---|---|---|
| Tema Plasma + plasmoids + efectos/scripts KWin | Reutiliza shell, ventanas y servicios | Tema no basta para toda UX; host Plasma obligatorio; scripts no sustituyen compositor |
| Shell QML + LayerShellQt sobre KWin | Superficies propias, capas/anclajes y zonas exclusivas | Construir integración de sesión/servicios; layer-shell no gestiona ventanas |
| Quickshell | PanelWindow/layer-shell y servicios QML existentes | Dependencia no aprobada/ausente; evaluar compatibilidad KWin y mantenimiento |

Contratos: [Plasma/KF6](https://develop.kde.org/docs/plasma/widget/porting_kf6/), [scripts KWin](https://develop.kde.org/docs/plasma/kwin/),
[LayerShellQt oficial](https://github.com/KDE/layer-shell-qt), [Quickshell layer-shell](https://quickshell.org/docs/v0.2.1/types/Quickshell.Wayland/WlrLayershell/).
Blur entre ventanas: efecto del compositor KWin + región mediante [KWindowEffects KF6](https://api.kde.org/kwindoweffects.html)
`enableBlurBehind(QWindow*, bool, QRegion)` / protocolo Wayland negociado; comprobar disponibilidad real.
[MultiEffect](https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html) procesa una textura de la escena; no lee ventanas ajenas.
KF6 abstrae el protocolo: no fijar org_kde_kwin_blur/ext-background-effect sin validar globals del KWin objetivo.
Propuesta Fase 1: app QML a pantalla completa dentro de KWin anidado, servicios simulados tras interfaces.
Migración: conservar componentes/modelos; sustituir adaptadores por servicios KDE y superficies por plasmoids
(o LayerShellQt si se justifica); ventanas/multitarea reales quedan en KWin, no en ventanas simuladas.
Riesgos pendientes: blur real/coste GPU, escala fraccionaria/multimonitor, foco/teclado y ciclo nested completo.

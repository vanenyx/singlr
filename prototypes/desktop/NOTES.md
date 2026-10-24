# T104 · Dirección propuesta, brief v2

Prototipo QML aislado; decisiones visuales pendientes de aprobación del creador.
Solo se escribe en `prototypes/desktop/`; A y B permanecen como referencia histórica.

- **Explícito:** Linear como base visible y operativa; macOS para profundidad/cristal; Raycast para comandos. Sin Liquid Glass.
- **Tema propuesto:** `Theme.qml` + `Theme.js`, generación CIELAB/LCH desde base, acento y contraste; neutros independientes del acento, cuatro niveles de fondo/texto y bordes alfa. Oscuro/claro.
- **Tipografía propuesta:** Inter variable local; `opsz=32` en títulos (display), `opsz=14` en UI; pesos 510/590, interfaz principal 12–13 px, metadatos 10–12 px.
- **Iconografía:** Phosphor a 16 px; marcas originales de Dolphin, Konsole y Firefox desde `/usr/share/icons/`. Tareas es una app simulada propia.
- **Linear:** navegación lateral más tenue, cabeceras compactas con acciones fijas, filas de 30–36 px, casi sin separadores; el contenido conserva la jerarquía.
- **macOS:** radio de ventana/panel 12 px, sombra amplia + contacto, foco mediante borde y selección; cristal selectivo en lanzador y controles.
- **Raycast:** búsqueda grande, secciones, título/subtítulo/accesorios, navegación cíclica, menú de acciones anclado sobre el pie y acción ↵.
- **Escritorio propuesto:** estado superior de 38 px y barra inferior de 48 px; fondo neutro casi negro, con variación de luminancia mínima; claro neutro.
- **Multitarea propuesta:** ventanas ordenadas por posición y miniaturas de espacios; clic devuelve foco a la ventana elegida.
- **Controles propuestos:** red/Bluetooth, audio/brillo, energía, No molestar, material Mate/Cristal y dos notificaciones, en filas compactas.
- **Solución técnica:** `ShaderEffectSource` toma la escena inferior con 64 px de margen; `MultiEffect` desenfoca/desatura, recorta y aplica máscara. `autoPaddingEnabled: false` en ambos efectos; backend leído con `glass.GraphicsInfo.api`.
- **Software:** material mate opaco de respaldo, aviso explícito en consola. Las capturas de este sandbox NO muestran desenfoque; no se imita con un filtro CPU.
- **Simulado:** archivos, terminal, tareas, ventanas, espacios, red, Bluetooth, volumen, brillo, batería y notificaciones. Nada consulta ni modifica servicios del sistema o KWin.
- **Interacción real local:** filtrar, ↑/↓, Ctrl+K, ↵, Esc; foco/minimizar/cerrar/maximizar ventanas y recuperarlas desde la barra; toggles y sliders. Fijar/copiar muestran confirmación simulada.
- **Accesibilidad:** nombres/roles accesibles, foco de teclado y búsqueda vacía. Los metadatos cuaternarios quedan deliberadamente tenues; lector de pantalla y escalado pendientes.

Ejecución desde la raíz (sesión gráfica con RHI):
`qml6 prototypes/desktop/Main.qml -- --state=desktop --mode=dark --capture=/tmp/singlr.png`
Estados: `desktop|search|actions|multitask|controls`; modos: `dark|light`; opcional `--material=mate`.
Sin `--capture`, permanece interactivo. 1–5 cambian estado; L alterna modo; Esc vuelve. Mientras se escribe, números/L son texto: Esc libera esos atajos. Ctrl+Espacio abre/cierra el lanzador.
En este sandbox: `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software` antes de `qml6`.

Verificaciones ejecutadas con Qt/QML/QtTest 6.12.0:
- `prototypes/desktop/capture.sh`: 6 PNG a 2048×1280, backend software detectado tras prueba RHI/opengl; cero errores QML. Se elimina la prueba temporal al salir.
- `/usr/lib/qt6/bin/qmllint -W 0 -I /usr/lib/qt6/qml -i prototypes/desktop/qmldir prototypes/desktop/*.qml`: código 0, sin avisos.
- `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input prototypes/desktop/tests -import /usr/lib/qt6/qml`: 7 pasan, 0 fallan; incluye flechas/acciones, filtrado/apertura, vacío/números, modos/atajos y comandos/aislamiento de acento.
- `bash -n prototypes/desktop/capture.sh`: código 0. `git status --ignored`: solo archivos de esta entrega, sin binarios de compilación, cachés ni temporales.

Revisión visual propia: estado inicial A inspeccionado; se entrega una dirección única por encargo.
Pasada 1, las seis vistas: corregidos controles fuera de cabecera, sombra excesiva en claro, selección inactiva y alto de secciones del lanzador.
Pasada 2, las seis vistas: acciones ancladas al pie, metadatos/barra más legibles, iconos inactivos neutros y texto/acento generados con el tema. Las seis capturas finales se volvieron a inspeccionar.
Evidencia final: `captures/{desktop,search,actions,multitask,controls}-dark.png` y `captures/desktop-light.png`.

Pendiente: aprobación de composición/tokens/densidad/materiales; comprobar desenfoque real, animación y coste en RHI/GPU; integración Plasma/KWin y servicios; empaquetar marcas con sus licencias. Sin validación en la sesión KDE activa.
Fuentes contrastadas: [Linear 2026](https://linear.app/now/behind-the-latest-design-refresh), [Linear 2024](https://linear.app/now/how-we-redesigned-the-linear-ui), [Qt MultiEffect](https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html), [GraphicsInfo](https://doc.qt.io/qt-6/qml-qtquick-graphicsinfo.html), [ejes tipográficos](https://doc.qt.io/qt-6/qml-qtquick-text.html#font.variableAxes-prop).

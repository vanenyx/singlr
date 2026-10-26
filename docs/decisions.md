# Registro de decisiones

La fuente de producto es [la recuperación original](../SINGLR_recuperacion_desde_mensajes_originales.md). No repetir aquí todo su contenido.

| ID | Clase | Estado | Decisión y procedencia |
| --- | --- | --- | --- |
| P-001 | Explícita del creador | Vigente | En esta etapa solo configurar proyecto, repo, skills, documentación y agentes. Solicitud de 2026-10-23. |
| T-001 | Técnica derivada | Aplicada | Instrucciones comunes en AGENTS.md; CLAUDE.md las importa. Evita definiciones contradictorias. |
| T-002 | Técnica derivada | Aplicada | Skills locales versionadas en .agents/skills y enlaces relativos desde .claude/skills. |
| T-003 | Técnica derivada | Sustituida como flujo habitual por P-003 | Checkouts aislados preparados inicialmente. Se conservan como opción para escritura paralela, con integración de ramas cuando se utilicen. |
| P-002 | Propuesta por validar | Pendiente | Licencia, visibilidad del remoto y decisiones futuras de diseño y arquitectura. |
| P-003 | Explícita del creador | Vigente | Actualizar las instrucciones al flujo presentado y aceptado en esta conversación: el creador encarga a Claude, Claude realiza sus tareas y coordina los dos roles Codex mediante el plugin; carpeta principal con escritura por turnos y worktrees opcionales. |
| T-004 | Técnica derivada | Sustituida por T-005 | Dos entornos respondieron mediante el script del plugin, sin selector de cuenta por encargo. |
| P-004 | Explícita del creador | Vigente | Modelo permanente de colaboración (2026-10-23): Claude Code con Opus 5.5 como arquitecto principal y orquestador. Codex 1 con `gpt-6.1-sol` en Medium para interfaz, Qt Quick/QML e interacciones. Codex 2 con `gpt-6.1-sol` en Medium para integración, herramientas, pruebas, rendimiento, errores y revisión independiente. High solo si se justifica. Encargos autocontenidos y sin review gates permanentes. Ver [workflow.md](workflow.md). |
| T-005 | Técnica derivada | Aplicada | `scripts/codex-route.sh` asigna Codex 1 → cuenta 1 y Codex 2 → cuenta 2 mediante `CODEX_HOME`, con estado y broker del plugin aislados por rol. Motivo: el plugin 1.0.6 no tiene selector de cuenta y comparte el broker por carpeta. La correspondencia se ajusta en `.local/codex-accounts.env`. |
| P-005 | Explícita del creador | Vigente | Dirección visual (2026-10-24): se descartan A y B. Base: filosofía, estilo y diseño de Linear en UI y UX. Sobre ella, identidades de macOS (glassmorphism, no Liquid Glass) y de Raycast (superficies de comando, listas, acciones, teclado). Fondos sobrios al estilo de Linear. Ver [brief v2](phase1/brief.md). |
| P-007 | Explícita del creador | Sustituida por P-019 | Liquid Glass queda descartado también como opción futura (2026-10-24). Sustituye a la preferencia de la visión original de mantenerlo opcional y ajustable. El material translúcido de Singlr es el glassmorphism. |
| P-006 | Explícita del creador | Vigente | Fase 1 iniciada (2026-10-24): dirección visual y prototipo integrado, en entorno aislado que no altera la sesión KDE. |
| P-008 | Explícita del creador | Modificada por P-009 | Dock con el modelo de macOS (2026-10-24): un icono por app. El clic trae la app al frente (todas sus ventanas, la última usada encima) y nunca minimiza. La ventana concreta se elige con el menú contextual o con Alt+` de KWin. Sin ciclo por clics ni rueda. |
| P-009 | Explícita del creador | Vigente | Dock (2026-10-24): un icono por app; el clic trae la app al frente con su ventana más reciente y nunca minimiza. Con la app ya activa, cada clic pasa a la siguiente ventana en orden estable y cíclico. El menú contextual sigue listando las ventanas. |
| P-010 | Explícita del creador | Vigente | Controles (deslizadores, interruptores, barras del OSD) en blanco neutro, no en el acento. Sin sonido al cambiar el volumen (AudioFeedback=false en plasmaparc, ajuste estándar de KDE). |
| P-011 | Explícita del creador | Vigente | Principio de experiencia (2026-10-24): simplicidad usable. Ninguna superficie cambia de tamaño ni de posición por datos en segundo plano, solo por acción directa del usuario. Paneles de alto fijo por página con desplazamiento interno; las filas nunca se despliegan; los detalles, contraseñas y confirmaciones se abren como página dentro del mismo panel; sin animaciones decorativas. Se aplica a todos los paneles del shell. |
| P-012 | Explícita del creador | Vigente | Acciones de elementos al estilo Linear (2026-10-24): clic derecho o «…» abre un menú contextual flotante superpuesto junto al cursor, con atajos, sin cambiar de vista ni mover contenido. Confirmaciones destructivas dentro del propio menú (segundo clic). Complementa P-011. Actualizado: la contraseña de red también se pide en una barra flotante compacta tipo comando sobre la fila (sin página), con iconos y el mínimo texto. |
| P-013 | Explícita del creador | Vigente | Conectar en el sitio (2026-10-24): clic en una red o dispositivo conecta si ya es conocido; si no, esa misma fila se convierte en el campo necesario (solo icono y entrada), Enter conecta y el error o el éxito se muestran en la misma fila. El clic derecho mantiene el menú flotante y su «Conectar» hace lo mismo. Se aplica de forma coherente a Wi-Fi, Bluetooth y donde corresponda. Sustituye la barra flotante de contraseña. |
| P-014 | Explícita del creador | Vigente | Mínimo entendible (2026-10-24): preferir iconos y símbolos a texto, una sola fila cuando baste y nada de elementos redundantes (por ejemplo, barras que repiten un porcentaje). Batería: icono, porcentaje y perfiles de energía como tres círculos en la misma fila (Ahorro azul, Equilibrado blanco, Rendimiento rojo; contorno = no seleccionado, relleno = seleccionado). Se aplica a todo el shell. |
| P-015 | Explícita del creador | Vigente | Gestos y atajos (2026-10-24). Panel táctil: 3 dedos arriba = multitarea (con progreso); 3 abajo = mostrar escritorio; 3 o 4 izq./der. = cambiar escritorio (KWin); pinza de 4 = todas las apps. Teclado: Meta = lanzador; Meta+Tab = multitarea; Alt+Tab = ventanas; Meta+D = escritorio; Meta+↑/↓ = maximizar/minimizar; Meta+←/→ = mitad de pantalla; Ctrl+Meta+←/→ = escritorios; Meta+1…9 = app N del dock; Meta+N = notificaciones; Meta+A = centro de control; Meta+L = bloquear. |
| P-016 | Explícita del creador | Vigente | Eficiencia como prioridad de producto (2026-10-25): uno de los motivos del creador para pasar de Windows a Linux es un menor consumo de recursos. Presupuesto inicial del shell: memoria propia (PSS) < 120 MB, CPU en reposo ≈ 0 (sin animaciones ni temporizadores continuos innecesarios), y los paneles cerrados no consumen GPU ni mantienen modelos cargados. Toda funcionalidad nueva se mide con `tools/measure-resources.sh` antes de integrarse. Medida de partida: ~208 MB PSS (25 oct). |
| P-017 | Explícita del creador | Vigente | Comportamientos estándar y sin parches (2026-10-25): donde existe una convención clara (sesión, ventanas, cierre), Singlr adopta el comportamiento estándar (macOS como referencia, que coincide con el valor por defecto de KDE) sin pedir decisión al creador, y los problemas se resuelven integrando el mecanismo correcto, no con reglas forzadas. Primera aplicación: gestión de sesión con ksmserver de KDE: al cerrar sesión las apps se cierran por el protocolo estándar (pueden pedir guardar) y al volver a entrar se reabre lo que estaba abierto al salir. |
| P-018 | Explícita del creador | Vigente | Definición de producto Singlr 1.0 (2026-10-25): [docs/singlr-1.0.md](singlr-1.0.md). Siete sistemas (Desktop, Command, Workspace, System, Appearance, Session, Platform), criterio de publicación y alcance fuera de la v1. Hay que terminarla. Licencia: el creador decidirá más adelante (P-002). |
| P-019 | Explícita del creador | Sustituida por P-021 | Liquid Glass vuelve como material opcional y configurable de la v1, junto al glassmorphism (2026-10-25). Sustituye a P-007. |
| P-020 | Explícita del creador | Vigente | Materiales planos (2026-10-25): vidrio y Liquid Glass sin bordes gruesos, volumen ni relieve; superficies planas y nítidas como Linear. Contorno, si existe, de 1 px tenue; sin líneas de brillo, biseles ni lóbulos especulares anchos. En Liquid Glass la refracción puede verse, pero sin aspecto de borde en relieve. |
| P-021 | Explícita del creador | Vigente | Se retira Liquid Glass (2026-10-25): tras probarlo, el creador decide quedarse solo con el vidrio (glassmorphism plano, P-020) y el sólido. Sustituye a P-019. |
| P-022 | Explícita del creador | Vigente | Dock configurable en Ajustes de Singlr (2026-10-25): modo **flotante** (como ahora, algo más abajo) o **fijo** de borde a borde (como la barra de Windows); **altura** ajustable en ambos, con iconos proporcionales a la altura; **ocultación automática** opcional. |
| P-023 | Explícita del creador | Vigente | Decoración de ventanas nativa de KDE (2026-10-25): se retira la decoración Aurorae Singlr; botones nativos a la derecha. Motivo: la personalizada añadía una barra sobre apps que no la necesitan, quitando espacio al contenido («ver más, más productividad»). |
| P-024 | Explícita del creador | Vigente | Dolphin es el explorador de archivos de Singlr (26 oct 2026), ratificado porque al creador le gusta y lo considera completo. Se prioriza su integración en todo el escritorio y no un gestor propio. Los selectores de abrir/guardar son integración nativa KDE, documentada como solución técnica T256; no se presenta Dolphin como API de selección. |
| P-025 | Explícita del creador | Vigente | Dock sin punto de aplicación abierta (26 oct 2026): se retira por limpieza visual. El creador también pide corregir el tamaño desigual de algunos logotipos. Se conservan las marcas originales; el ajuste técnico T257 se presenta con comparación visual, sin elevar su geometría a token general aprobado. |
| T-006 | Técnica derivada | Aplicada | Portapapeles (T238): el historial es el de KDE (Klipper, `org.kde.plasma.private.clipboard`) cargado en el shell; Meta+V abre el panel Singlr. Klipper registra su popup en el componente del shell; Singlr le quita Meta+V solo en ese componente, como haría Configuración del sistema. |
| T-007 | Técnica derivada | Aplicada | Recuperación del shell (T239): misma política que `plasma-plasmashell.service` (`Restart=on-failure`, 3 arranques/60 s); el target no depende del shell, como `plasma-core.target`. |
| T-008 | Técnica derivada | Aplicada | Pantalla de bloqueo (T240): paquete `Plasma/Shell` `org.singlr.desktop` con su `lockscreen`; la sesión Singlr exporta `PLASMA_DEFAULT_SHELL`, que kscreenlocker 6.8.1 usa si `plasmashellrc` no fija otro. Plasma conserva la suya. |
| T-009 | Técnica derivada | Vigente | Pantalla de inicio: el greeter de Plasma Login Manager 6.8.1 compila su QML y no admite temas; solo fondo. Un diseño propio requeriría otro gestor de inicio (decisión del creador). |
| T-010 | Técnica derivada | En curso | Apariencia (T241): KDE es la fuente única de claro/oscuro y acento (incluido el cambio automático de `lookandfeelautoswitcher`/knighttime); el shell la sigue y los ajustes de Singlr escriben la de KDE. |

| T-011 | Técnica derivada | Aplicada; aceptación real pendiente | T247: batería de sesión instalada y auditoría de reversión en usuario dedicado; `singlr-doctor` instalado, de solo lectura y sin mensajes libres del journal. El greeter propio emite un marcador constante de carga QML para verificar selección sin instrumentar autenticación. Las preferencias KDE explícitas se conservan; los ajustes transitorios KWin/atajos se deben restaurar. Ver [batería](../tests/session/README.md) y [matriz](compatibility.md). No cambia comportamiento estándar ni acredita pruebas reales todavía. |
| T-012 | Técnica derivada | Aplicada, validación anidada pendiente | Workspace (T246): Alt+Tab usa un KPackage `KWin/WindowSwitcher`; sus claves TabBox entran en la transacción de sesión existente. Indicador con VirtualDesktopInfo/VirtualDesktopManager y Overview con las APIs de efectos de KWin; materiales compartidos de `Singlr.Ui`. El puente de búsqueda se exporta en el servicio del shell existente, sin nuevo daemon. Organización mediante atajos/editor nativos de KWin. Ver [procedimiento y límites](../session/WORKSPACE.md). La propuesta visual no constituye aprobación del creador. |

| T-012 | Técnica derivada / propuesta visual | Implementación parcial; validación pendiente | T248: materiales persistidos con Singlr.System/KConfig, shader de borde posterior al blur nativo y activación/restauración mediante la transacción de sesión. ABI limitada a KWin 6.8.1. Intensidad 65 y aspecto del material son propuestas por validar. El blur estándar no expone radio por ventana; no se cambia el radio global de apps. Efecto compilado y factory cargada con cabeceras oficiales temporales; renderizado/GPU pendientes por restricción del bus privado. Ver [handoff](handoffs/T248-liquidglass.md) y [medición](testing/materials.md). |

| T-013 | Técnica derivada / propuesta visual | T249 implementada; validación visual pendiente | El tinte anterior transmitía solo 7 % / 3 % del fondo a intensidad 65 y anulaba el brillo. La curva nueva transmite 25,8 % a 65 y hasta 30 % a 100, con texto adaptado y AA calculado en SDR. Liquid amplía su borde óptico. Se conserva el alcance por ventana; diagnóstico de región/pases y captura QImage permiten comprobarlo en KWin. Sin nueva dependencia ni instalación en sesión activa. Valores visuales por validar con el creador. Ver [causa y procedimiento](handoffs/T249-liquidglass-fix.md). |

Para nuevas entradas: ID, clase, estado, motivo, evidencia/autor y consecuencias. Una decisión técnica no aprueba decisiones perceptibles de producto.

| T-250 | Técnica derivada / propuesta visual | Implementada; login y aceptación visual pendientes | T250: Command conserva el runner systemsettings estándar para KCM y añade las secciones existentes de Singlr en Configuración. La sesión inicia `plasma-ksplash.service`, conserva su límite KDE y anuncia hitos reales por `/KSplash`; presentación compartida en Singlr.Ui con anillo monocromo y reducción de movimiento. La geometría propuesta no constituye aprobación visual. Ver [contratos y verificación](testing/command-splash.md). |

| T-251 | Técnica derivada del encargo T251 | Implementada; comprobación anidada pendiente | Command expone el origen real mediante KRunner QueryMatch, usa el ID instalado `krunner_systemsettings`, deduplica por ID global y prioriza operaciones, aplicaciones instaladas y KCM sobre ofertas AppStream/Discover; estas quedan en sección final con máximo tres. No clasifica por el texto. Metadatos capturados y fixture de contrato diferenciada de consultas vivas. Ver [entrega y límites](handoffs/T251-command-fix.md). |

| T-252 | Técnica derivada / propuesta visual del encargo T252 | Implementada; revisión KWin y P-016 pendientes | Intensidad con transmisión nominal lineal hasta 85 %. Corrección de Claude: se retiran las placas opacas y contornos; la legibilidad depende de la adaptación suave de luminancia local del material en el compositor. Vidrio y Liquid comparten pase; Liquid añade lente normal a SDF, brillo por forma y dispersión periférica. Sin timers de render ni lectura GPU→CPU en producto. Parámetros y contorno requieren revisión visual del creador. Matriz EGL verificada; bus anidado bloqueado. Ver [corrección vigente y procedimiento](handoffs/T252-material-correction.md). |

## T253 — solución técnica derivada de P-020/P-021

Se conserva el ID técnico `singlr-liquidglass` y su grupo kwinrc para no romper los
journals existentes ni exigir migrar y revertir dos juegos de claves/binarios. Nombre
visible: Singlr Glass; función: difusión y adaptación de luminancia para Vidrio. La
preferencia antigua `material=liquid` se persiste como `glass` al cargar Appearance.
Corrección integrada por Claude: el radio se recupera de las filas de la región de
blur rasterizada por el shell (`blurregion.h`); no hay canal D-Bus ni adaptador privado
de Qt. La ABI privada del plugin de KWin sigue limitada a KWin 6.8.1. Detalle y límites en `kwin/effects/singlr-liquidglass/README.md`.

## T254 — solución técnica derivada de P-022

- Ajustes `[Dock]` en `singlr/singlr.conf`: `mode=floating|fixed`, `height=40|48|56|64|72`, `autoHide=true|false`. Valores iniciales: flotante, 48 px, sin ocultación. Se reutiliza el KConfigWatcher abierto por nombre relativo de Appearance; escrituras con `KConfig::Notify`. Sin reiniciar el shell.
- Flotante conserva radio 14 y baja el margen inferior de 10 a 4 px. Fijo tiene radio 0 y solo hilo superior; reserva `altura + margen` sin ocultación y 0 con ella. Iconos y espacios proporcionales con tamaños enteros.
- Activación por una superficie layer-shell de 2 px, a todo lo ancho del borde inferior de la pantalla principal, capa Overlay, sin teclado ni exclusión. Evita polling, desplazamientos del puntero y scripts de bordes globales; solo existe con autohide. El dock se desmapea al ocultarse. Espera de salida de 450 ms para cruzar el margen y los menús; transición inmediata, también con movimiento reducido. Preferencias y geometrías derivadas del encargo; revisión visual y del comportamiento nativo pendientes.
- La vista general comunica su visibilidad por el puente Workspace existente para mantener visible el dock también con Meta+Tab y gestos. Ver [entrega T254](handoffs/T254-dock-settings.md).

## T255 — solución técnica y continuidad, 26 oct 2026

Encargo explícito del creador: continuar directamente con Codex y mantener los MD;
subir primero los commits existentes a GitHub. `main` hasta `e844fdf` subido y verificado.
No cambia la licencia ni constituye una release.

El dock antes podía medir 1792 px en una salida lógica de 1280 px con 30 apps a
72 px. Se acota al ancho de salida y se incorpora viewport con recorte, flechas
solo al desbordar, rueda/touchpad y desplazamiento al recibir foco. Conserva las
aplicaciones, sus acciones, orden, modo/altura y espacio reservado. La presentación
de las flechas es una propuesta visual pendiente; no se eleva a token aprobado.
Qt 6.12.0 local; APIs públicas de
[Flickable](https://doc.qt.io/qt-6/qml-qtquick-flickable.html) y WheelHandler.
[Entrega y límites](handoffs/T255-audit-followup.md).

## T256 — selector nativo KDE y Dolphin (P-024)

Ajustes usaba `QtQuick.Dialogs.FileDialog`, pero `qml6` arranca por defecto con
QGuiApplication. El helper de KDE requiere QApplication/QtWidgets: se cambia el
lanzador a `qml6 --apptype widget`, con tema de plataforma `kde` si no hay uno
explícito. No se implementa otro explorador ni se intenta usar Dolphin como diálogo.
El selector nativo utiliza KFileWidget; Dolphin permanece como explorador y
proveedor FileManager1 para abrir ubicaciones. Dependencias de producto explícitas:
Dolphin y plasma-integration. No se cambian asociaciones MIME del usuario.
[Pruebas y entrega](handoffs/T256-native-file-picker.md).

## T257 — iconos del dock (P-025)

Se retira el punto de abierta y se centra verticalmente el icono en su celda.
El estado abierto se conserva en la descripción accesible. Para compensar márgenes
transparentes distintos se mide el alfa del QIcon original y se ajustan escala
uniforme y centro, solo en el dock. Kirigami sigue dibujando los logotipos;
`roundToIconSize=false`, muestra de 128 px y reducción al tamaño de pantalla.
Rectángulos de medida en caché acotada a 128 entradas, sin imágenes retenidas por
el helper, timers ni trabajo por frame. Caja de clic, orden y comportamiento intactos.
El ajuste es una solución técnica/propuesta de pulido visual, no rediseño de marcas.
[Comparación, pruebas y límites](handoffs/T257-dock-icons.md).


## P-026 — pegar desde el historial (explícita del creador, 26 oct 2026)

Seleccionar con clic una entrada del portapapeles debe copiarla y pegarla en la
aplicación desde la que se abrió Meta+V. Se conserva la posibilidad de solo copiar.

## T258 — solución técnica derivada de P-026

Enter equivale al clic; Ctrl+Enter y el menú «Copiar» solo seleccionan el contenido.
Se captura la ventana antes de abrir el panel y se espera a que Klipper restaure
los formatos y KWin devuelva el foco. Puente nativo Wayland del shell con APIs
públicas KWayland/KSystemClipboard; sin demonio ni almacén de historial adicional.
Ctrl+V para aplicaciones; Ctrl+Shift+V para servicios con categoría TerminalEmulator.
Si desaparece el destino o cambia el foco a otra app, no se envía el atajo.
Espera acotada a 1,5 s, sin temporizador activo en reposo. Ver
[verificación y límites](handoffs/T258-clipboard-paste.md).


## P-027 — peso del logo de la barra (explícita, 26 oct 2026)

El creador pide un anillo algo más grueso conservando su tamaño exterior. El
valor de trazo concreto es un ajuste visual para valorar, no un token global.
También pide acercar los tooltips de las aplicaciones al dock.

## T259 — logo, anclaje de tooltips y diagnóstico de esquina

Logo de barra: anillo vectorial con diámetro 11,375 px (contorno del glifo Phosphor
anterior a 14 px), trazo 1,5 px hacia dentro y color secundario existente. Solo
cambia esta instancia; no las fuentes, iconos ni otras representaciones de marca.

Tooltips y menú contextual del dock usan zona exclusiva -1 y margen inferior
altura + margen real del dock + 8 px. Con zona 0, KWin ya añadía la reserva del
dock al margen explícito, duplicando el desplazamiento. Conservan entrada/foco
previos y superficies independientes. Doce geometrías nativas verificadas.

La esquina superior izquierda activa por defecto Overview de KDE (Effect-overview,
BorderActivate=ElectricTopLeft en KWin 6.8). El usuario lo plantea como duda: se
recomienda evitar duplicidad con Singlr, pero **no se modifica la configuración**
ni se aprueba aún eliminar o reasignar la esquina. [Entrega](handoffs/T259-bar-dock-polish.md).


## P-028 — retirar la esquina duplicada (explícita, 26 oct 2026)

Tras el diagnóstico T259, el creador autoriza quitar la activación de Overview
nativo de KDE al llevar el cursor a la esquina superior izquierda durante Singlr.
Meta+Tab y la vista general propia permanecen como acceso de Singlr.

## T260 — preferencia de borde reversible

Se filtra ElectricTopLeft (7) de Effect-overview/BorderActivate al aplicar la
configuración de sesión. Si no existía clave, se escribe lista vacía para anular
el valor predeterminado de KWin 6.8. Se conservan otros bordes personalizados,
los gestos y el resto de efectos. El journal captura el valor original, incluida
su ausencia, y acepta los journals previos para actualizar y restaurar sin perder
preferencias. No se aplicó ni reconfiguró KWin en la sesión activa como prueba.
[Entrega y comprobación](handoffs/T260-overview-corner.md).

## P-029 — Claude orquesta y reparto por consumo (explícita, 26 oct 2026)

El creador restablece el equipo: el creador más Claude Code, que controla su trabajo
y el de Codex 1 y Codex 2 mediante el plugin. Sustituye el encargo del 25/26 oct de
trabajar solo con Codex. Al delegar, el consumo de tokens prevalece sobre la especialidad. Reparto vigente
(invertido el 26 oct por el uso restante de las cuentas): pesados a Codex 2, ligeros a Codex 1.

## P-030 — gestos de multitarea como en macOS (explícita, 26 oct 2026)

En la sesión Singlr no existe una segunda multitarea: se desactivan los efectos
KDE Overview y Window View (journal reversible). Tres o cuatro dedos hacia arriba
abren la multitarea de Singlr y hacia abajo la cierran. El desplazamiento natural
del touchpad no lo gestiona Singlr: el creador lo configura en Ajustes de KDE.
[Entrega T262](handoffs/T262-touchpad-gestures.md).

## T266 — inicio oficial de Plasma (explícita y solución derivada, 26 oct 2026)

El encargo del creador fija startplasma-wayland de Plasma 6.8.1 como propietario
del ciclo de sesión y retira el grafo/supervisor propios y el agente de secretos.
Solución técnica derivada: conservar la unidad canónica plasma-plasmashell.service
(Type=dbus y un único BusName), con drop-in ExecStart y selección del binario por
XDG_SESSION_DESKTOP. La transacción KWin se integra mediante una unidad oneshot
ordenada antes del compositor y detenida después. El agente de plasma-nm/kded
atiende los secretos. No es una aprobación visual ni certificación de login real.
[Diseño, fuentes y comprobaciones](handoffs/T266-startplasma.md).

## P-031 — Singularidad opcional (explícita y solución derivada, 26 oct 2026)

El creador encarga un fondo negro con un agujero negro construido con partículas
blancas dinámicas, profundidad, movimiento y reacción al cursor, tomando sus
cuatro imágenes y la técnica de partículas de remix.run como referencias.
Se elige desde Ajustes; no sustituye el fondo actual ni permanece trabajando
cuando se elige otro. El «OK. HAZLO» autoriza su implementación en este encargo.

Solución técnica derivada: lote de geometría nativa Qt Quick y shaders GPU,
órbitas procedurales, lente artística, hover local con paralaje amortiguado,
límite de 30 fps y tres densidades. Imagen propia estática para miniaturas,
reducir movimiento y backend software; carga diferida y observación de bloqueo,
suspensión y DPMS. La composición exacta queda pendiente de valoración visual
del creador; no es una simulación relativista ni una aprobación de consumo.
[Entrega y límites](handoffs/T267-singularity-wallpaper.md).

### P-031 — excepción local a reducir movimiento (explícita, 26 oct 2026)

Tras comprobar `AnimationDurationFactor=0`, el creador elige «Animar solo
Singularidad, manteniendo las demás animaciones desactivadas». Se añade
`wallpaperMotionOverride` (false por defecto) y el control «Permitir movimiento
solo en este fondo». La excepción se ha activado en su equipo por este encargo;
no modifica `kdeglobals`. Sin excepción, el fondo sigue respetando reducir
movimiento y muestra el motivo junto a sus controles, con Movimiento inactivo.

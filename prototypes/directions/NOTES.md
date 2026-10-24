# T103 · Direcciones propuestas, ninguna aprobada

## A — Estrato
Trabajo compacto, navegación inferior con nombres y orientación explícita por espacios.
Ventanas y barra mates; el cristal aparece en búsqueda y controles temporales.
- Base: grises RGB neutros; oliva solo en acento y selección.
- Escala: cuerpo 16, título 27, cabecera 46, fila 49 y navegación 38 px.
- Fondo propio: planos minerales angulares, grafito y luz oliva contenida.
- Multitarea: tres ventanas en fila, espacios debajo; chips de escritorio de 44 px.
- Compromiso: menor presencia de efectos, más densidad y consumo de altura por la barra.

## B — Margen
Navegación vertical persistente y una escala más abierta para el mismo contenido.
El cristal tiene más presencia en columna y estado; las ventanas de trabajo siguen mates.
- Base: los mismos grises neutros; arcilla solo en acento y selección.
- Escala: cuerpo 20, título 36, cabecera 64, fila 70 y navegación 52 px.
- Fondo propio: contornos continuos plateados con luz ámbar en el horizonte.
- Multitarea: foco grande, ventanas secundarias a la derecha y espacios en columna.
- Compromiso: más anchura para navegación y más superficies con desenfoque.

## Comparación y correcciones
- Ambas muestran la misma carpeta, selección y apps: Archivos, Terminal y Kate; Firefox en el lanzador.
- Todas las superficies base son acromáticas; la transmisión del cristal también se desatura.
- Búsqueda: menor opacidad, fondo realmente desenfocado, borde fino y lectura contrastada.
- Cristal clásico es el estado inicial de ambas; cada una añade controls-liquid-dark para comparar Liquid.
- Liquid aproxima transmisión más clara/nítida, luz especular y borde interior fino; no refracción física.
- Barras laterales alineadas a la izquierda; Terminal muestra comandos y resultados por encima de la ventana activa.
- Miniaturas rasterizadas antes de escalar; se eliminó la línea azul bajo los títulos observada en T101.
- Estado B ajustado a su contenido, sin reserva vacía y con borde fino; espacios A más grandes y legibles.
- Se quitaron los lemas del sistema; títulos informativos de carpeta, espacios y controles.
- Se revisaron como imágenes las doce capturas y se corrigió también la alineación de columnas.

## Ejecutar
- `bash prototypes/directions/capture.sh` genera y valida 12 PNG de 2048×1280, esperando las fuentes.
- `qml6 prototypes/directions/a/Main.qml -- --state=search --mode=dark --material=glass`
- Cambiar a b/Main.qml para Margen; `--capture=/ruta/imagen.png` captura y sale.
- Estados: desktop, search, multitask, controls. Modos: dark, light. Materiales: matte, glass, liquid.
- `--material=liquid` abre Liquid; mate/cristal lo desactivan. Slider de intensidad en controles.
- Atajos conservados: 1–4 cambian estado, L alterna modo, G recorre materiales, Escape vuelve al escritorio.
- A mantiene su barra mate; su selector de material afecta a las superficies temporales.
- Sin puente C++, compilación, binarios ni variables de entorno propias; argumentos leídos directamente en QML.

## Evidencia y límites
- Qt/QML 6.12.0. El script prueba RHI con QSG_RHI_BACKEND=opengl por defecto antes de capturar.
- Si RHI no inicializa, avisa y usa software con desenfoque CPU de los píxeles reales de detrás.
- RHI usa ShaderEffectSource + MultiEffect. CPU usa grabToImage y blur separable a 1/4 de resolución.
- La caché CPU se limpia al terminar capture.sh; no quedan .blur-*.png, temporales ni binarios.
- El revisor reportó RHI funcional en Radeon 610M fuera del sandbox; no se atribuye esa prueba a esta entrega.
- Dentro de este sandbox la GPU no inicializó; las 12 capturas entregadas usan CPU. Véase captures.log.
- Carga individual con qml6 offscreen comprobada sin errores ni avisos QML; no se tocó la sesión KDE.
- FontLoader y mapas Phosphor conservados; iconos originales de apps desde /usr/share/icons.
- Ventanas, búsqueda y servicios simulados; los sliders no modifican dispositivos reales.
- Pendientes: revisión GPU de este refinamiento, rendimiento, escalado y accesibilidad completa en KWin.
- El creador conserva la elección de dirección, densidad, disposición y material predeterminado.

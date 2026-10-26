# Estado de Singlr

Actualizado el **26 oct 2026**. Prototipo integrado e instalable de Fase 1.
**Singlr 1.0 todavía no cumple su criterio de completo**: ver
[definición](singlr-1.0.md) y [matriz de aceptación](compatibility.md).

## Coordinación vigente

Desde el 26 oct (P-029) Claude Code orquesta de nuevo el trabajo y delega en
Codex 1 (encargos de mayor consumo de tokens) y Codex 2 (encargos ligeros) con
[workflow.md](workflow.md). Un solo escritor a la vez en la carpeta principal.

El 26 oct, con autorización del creador y autenticación GitHub realizada por él,
se subió `main` hasta `e844fdf` a `https://github.com/vanenyx/singlr`.
La licencia y una release distribuible siguen pendientes; el push no declara v1 estable.

## Estado por sistema

| Sistema | Implementado | Pendiente de aceptación |
| --- | --- | --- |
| Desktop | Shell, barras, dock configurable y bandeja | Desbordamiento corregido y probado en QML (T255); aceptación visual, autohide/DND nativos y multimonitor |
| Command | KRunner, aplicaciones, archivos, calculadora, ajustes y acciones | Recorridos completos y aprobación UX |
| Workspace | Overview, Alt+Tab, escritorios y atajos | Topologías, foco y gestos en uso real |
| System | Controles, notificaciones, multimedia y menú de sesión | Dispositivos y recorridos reales de extremo a extremo |
| Appearance | Claro/oscuro, vidrio/sólido, preferencias KDE | Aprobación visual; matriz compositor/escalado; compatibilidad ABI KWin |
| Session | Login dedicado, ksmserver, bloqueo propio, recuperación | PAM real, suspensión, salidas, ráfagas y continuidad completa |
| Platform | CMake, paquete Arch, diagnóstico y herramientas de aceptación | Instalación limpia, actualización/reversión y otra configuración; licencia/documentación pública completa |

## Evidencia y límites

- Creador confirmó login real, teclado, cursor, cartera y ksmserver (T237).
- T247: startup, crash y daemon-reexec comprobados en sesión del creador con canal
  de desarrollo. No certifican el shell empaquetado ni la batería completa.
- Paquete instalado inventariado en auditoría: `0.1.0.r178.ge844fdf-1`.
- Canal de desarrollo activo: shell desde el checkout; no recargar como prueba rutinaria.
  Sesión, bloqueo, unidades y efectos instalados siguen dependiendo del paquete.
- Auditoría inicial: 93 pruebas Python shell y 6 de herramientas de sesión correctas;
  QML por modo: 221 shell + 9 ajustes, cuatro capturas opcionales omitidas.
  Compilación/DESTDIR correctos; plugin de vidrio construido aparte, 8 pruebas y
  72 comparaciones del shader ejecutadas. No equivalen a validación visual KWin.
- Muestra puntual de shell en uso: 167,75 MB PSS y 0,067 % CPU durante 30 s.
  Supera P-016 (<120 MB); no es comparación controlada ni prueba de regresión.
  El cumplimiento en sesión real sigue abierto.

T255: 231 comprobaciones QML del shell + 9 de Ajustes por modo (captura T255
activada, cuatro capturas ajenas opcionales omitidas); corrección del desbordamiento,
foco tras cambiar anchura y reordenación comprobados. Recorrido KWin privado de
cuatro paneles: 85,34 MB al inicio y 90,75 MB tras cerrar; no equivale a la sesión
instalada. Atlas reducido y liberación de metadatos QML ensayados sin mejora útil;
no se integran cambios experimentales de memoria.

Entrega y evidencia: [T255](handoffs/T255-audit-followup.md).

T256/P-024: Dolphin ratificado como explorador. Corregido el lanzador de Ajustes
para habilitar el selector nativo KDE al elegir una imagen; cuatro resultados de
la prueba nativa correctos, incluyendo selección y cancelación. Dependencias
Dolphin/plasma-integration explícitas. Requiere actualizar el paquete para que
el lanzador instalado incluya el cambio. [Entrega](handoffs/T256-native-file-picker.md).

T257/P-025: retirado el punto de aplicación abierta del dock, iconos centrados y
escala visible compensada a partir de sus márgenes transparentes. Marcas originales
conservadas; ajuste solo en dock, pendiente de valoración visual. QML: 239 shell +
9 Ajustes por modo, 0 fallos; 6 resultados nativos de métricas y 9 QML a escala 2
correctos. Medida aislada: 93,45 MB PSS y 0,033 % CPU; no acredita P-016 real.
Requiere actualizar paquete y relanzar shell/sesión por el nuevo tipo QML nativo.
[Entrega y comparación](handoffs/T257-dock-icons.md).

T258/P-026: clic o Enter en el historial pega en la ventana original; Ctrl+Enter
o «Copiar» conserva selección sin pegado. Texto, imagen, atajo de terminal,
solo copiar, destino cerrado, cambio de foco y entrada actual comprobados en KWin
privado. Requiere paquete actualizado y nueva sesión para cargar el puente nativo.
[Entrega, evidencia y límites](handoffs/T258-clipboard-paste.md).

El creador confirmó el funcionamiento de T258 el 26 oct.

T259/P-027: anillo de la barra algo más grueso con diámetro exterior conservado.
Tooltip del dock corregido de 62 a 8 px en la muestra de 40 px; separación nativa
8 px en doce combinaciones de modo/altura/autohide, también menú contextual.
QML 241 shell + 9 Ajustes por modo, 0 fallos. Capturas claro/oscuro revisadas;
grosor propuesto pendiente de valoración del creador. La esquina de KDE se
identificó; la autorización posterior y su corrección se registran en T260.
[Comparación y entrega](handoffs/T259-bar-dock-polish.md).

T260/P-028: retirada la esquina superior izquierda de Overview nativo de KDE en
la configuración de Singlr. Otros bordes personalizados se conservan; preferencia
original restaurada al salir. Migración de journals anteriores y KConfig real
verificados. El cambio entra al iniciar sesión con el paquete actualizado;
no se ha reconfigurado el compositor activo. [Entrega](handoffs/T260-overview-corner.md).

## Siguientes cierres necesarios

1. Aceptación visual y nativa del dock corregido: touchpad, DND, autohide y espacio reservado en distintas salidas.
2. Diagnóstico y reducción de memoria con comparación reproducible, sin eliminar funciones.
3. Batería real en usuario/equipo de prueba: autenticación, suspensión, monitores,
   instalación, actualización y regreso a Plasma. No ejecutarla sobre el trabajo del creador.
4. Aprobación visual del creador, primer uso, licencia y preparación de publicación.

Las propuestas de diseño no se consideran aprobadas por tener pruebas correctas.

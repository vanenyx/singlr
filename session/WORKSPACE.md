# Workspace desde P-032 — T272

KDE gestiona ventanas, escritorios virtuales, multitarea, Alt+Tab, gestos,
animaciones y esquinas. Singlr respeta las preferencias de Ajustes de KDE;
no aplica temas de cambiador, efectos de ventanas ni atajos propios de multitarea.

El botón de multitarea del dock permanece visible e invoca `Overview` de `kwin`
mediante `org.kde.kglobalaccel.Component.invokeShortcut` en `/component/kwin`.
No depende de la tecla que el usuario haya asignado. Si deshabilita el efecto en
KDE, KWin decide la disponibilidad de la acción. No se fuerza su carga.

Se retiran el sondeo del efecto y el puente exclusivo de búsqueda/estado de la
antigua vista. El dock ya no recibe un estado de multitarea abierta: conserva
el autoocultado habitual; el lanzador y el foco de teclado siguen reteniéndolo.
La búsqueda de la vista general nativa pertenece a KDE.

Los journals KWin antiguos siguen restaurando sus claves originales, incluso
vacías o ausentes, antes de crear un journal nuevo solo de material. Los backups
de atajos anteriores se restauran al arrancar; no se generan nuevos.

Atajos, fuentes, comprobaciones y límites: [T272](../docs/handoffs/T272-singlr-scope.md).

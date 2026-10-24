---
name: singlr-qt-plasma
description: Investigar o implementar integración de Singlr con Qt Quick/QML, Plasma 6 y KWin, comprobando versiones, APIs y ejecución aislada. Usar al trabajar en componentes nativos o su cadena técnica.
---

# Qt y Plasma para Singlr

Consulta la tarea, docs/architecture.md y la visión original antes de elegir componentes. Ejecuta `python3 scripts/doctor.py` para inventariar herramientas; no confundas ausencia en PATH con paquete ausente: Qt puede instalar ejecutables en `/usr/lib/qt6/bin`.

Verifica las APIs contra las versiones locales y documentación oficial de [Qt](https://doc.qt.io/), [Plasma](https://develop.kde.org/docs/plasma/) y [KWin](https://develop.kde.org/docs/plasma/kwin/). Registra versión y procedencia de contratos relevantes; no traslades ejemplos Plasma 5 sin comprobarlos.

Elige reutilizar capacidades existentes de KDE cuando cumplan el escenario. Justifica servicios o componentes nuevos y sus límites. Quickshell no está aprobado como dependencia. No impongas CMake, una shell propia o un proyecto web antes de que la tarea lo justifique.

Cuando exista QML, usa las herramientas disponibles y rutas de imports correspondientes al componente. Un qmllint sin imports correctos no acredita compatibilidad. Distingue lint, carga del componente, interacción e integración real.

Prueba en un visor compatible, sesión anidada o entorno aislado según corresponda. No reinicies plasmashell/KWin ni instales temas en la sesión cotidiana como comprobación rutinaria. Documenta cualquier instalación de prueba y su reversión.

Entrega cambios, versiones verificadas, comandos/resultados y límites. Si falta una dependencia, informa de la herramienta y el paquete contrastado con fuentes oficiales; instalarla requiere estar dentro del encargo vigente.

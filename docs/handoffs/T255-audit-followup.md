# T255 — continuidad tras auditoría

26 oct 2026. Encargo directo del creador: subir primero el estado existente a GitHub,
continuar correcciones y mantener los MD. Sin Claude ni delegación. Afecta a Desktop,
Appearance, Session/Platform y su evidencia; no declara Singlr 1.0 completa.

## Entrega

- Push inicial autorizado de `main` hasta `e844fdf`; remoto verificado.
- Dock acotado al ancho de salida (flotante con 8 px laterales), viewport con
  recorte y flechas solo al desbordar; rueda/touchpad y seguimiento de foco.
  Sin cambiar tamaño de iconos, altura, orden, modo ni reserva de espacio.
- Navegación por teclado revela las entradas fuera de vista y conserva el objetivo
  al reducir el ancho. Reordenación resuelve coordenadas en el viewport desplazado;
  las flechas no son destinos de reordenación. El arrastre no lo captura Flickable.
- README, estado, arquitectura, compatibilidad, recursos y coordinación actualizados.
  AGENTS refleja el encargo directo y el presupuesto P-016 ya aprobado.
- Registro T253 corregido: región de blur, sin canal D-Bus/API privada Qt.
- `check-cmake.sh` avisa explícitamente si el cache local omite el plugin de vidrio.

La composición, tipografía, colores y materiales se conservan. Las flechas de
exceso son una propuesta visual por validar, no una nueva decisión del creador.
[Capturas reproducibles](../../tests/shell/evidence/t255/README.md).
Qt 6.12.0 / KWin 6.8.1 locales, APIs públicas:
[Flickable](https://doc.qt.io/qt-6/qml-qtquick-flickable.html) y
[WheelHandler](https://doc.qt.io/qt-6/qml-qtquick-wheelhandler.html).

## Memoria: investigación y límite

Sesión privada con datos nuevos, fondo sólido, salida solicitada 2048×1280 / escala
1,25. Recorrido completo: 85,34 MB PSS al inicio, máximo observado entre fases
95,30 MB, 90,75 MB tras cerrar. CPU de reposo medida 0 %; tres superficies al final.
Limpieza `remaining=[]` y hashes del host iguales. No es el escritorio completo ni
reproduce los datos de la sesión instalada.

Dos enfoques sin mejora útil: atlas Qt de 1024×1024 (85,79 MB frente a 83,47 MB
con heurística por defecto) y trimComponentCache (91,00 MB tras cerrar frente a
90,75 MB base). Son ejecuciones individuales, no una serie controlada. El reajuste
del viewport también fue refinado entre las dos ejecuciones del recorrido.
Ambos experimentos se descartan; **no hay modificación final del runtime nativo
por rendimiento**. No se quitan funciones. Resultados filtrados y método en
[resources.md](../phase1/resources.md).

La muestra de sesión real de la auditoría (167,75 MB) sigue fuera de P-016.
Siguiente paso concreto: perfilar asignaciones en una sesión desechable con fondo,
escala y bandeja equivalentes; distinguir cachés, imágenes, historial y driver antes
de cambiar código. Heaptrack no está instalado; no se instalaron paquetes.

## Verificación

- QML con captura T255: **231 shell + 9 Ajustes por modo**, oscuro y claro; 0 fallos,
  4 capturas opcionales de otras tareas omitidas. Incluye 60 entradas a 40/72 px,
  ambos modos, flechas, rueda, foco, reducción de anchura y reordenación desplazada.
- qmllint con imports absolutos de shell/build: correcto para dock y nueva suite.
- Python shell: **93 correctas** en ejecución completa. Un fallo transitorio de
  compilación durante el experimento fue corregido y la suite completa repetida.
- Tras retirar el experimento: **7 pruebas nativas** de aplicaciones, robustez y
  acciones de sesión repetidas, correctas; CMake/DESTDIR final correcto.
- Herramientas de sesión: **6 correctas**.
- CMake/DESTDIR correcto; cache local con efecto OFF, ahora advertido expresamente.
  No se atribuye a ese build validación del plugin ni de su ABI.
- `real-session.py startup --allow-development`: **PASS**, solo lectura. Informe
  filtrado `singlr-doctor` generado. No certifica el shell empaquetado.
- Preparación, inventario y diff: correctos.

## Aceptación pendiente

No se bloqueó, suspendió, reinició ni recargó la sesión del creador. Las capturas
son offscreen/software; no acreditan blur, touchpad físico ni arrastre de archivos
nativo. La apertura/cierre de paneles sí se comprobó con KWin privado.

PAM, suspensión física, multimonitor, instalación limpia, segundo entorno y reversión
requieren usuario/equipo de prueba y observaciones humanas de
[tests/session](../../tests/session/README.md). Los procedimientos no se cuentan
como pruebas ejecutadas. El creador puede revisar las cuatro capturas del dock;
la aceptación visual y el cumplimiento de P-016 real siguen pendientes.

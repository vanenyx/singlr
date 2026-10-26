# T268 — Partículas de pantalla completa y perturbación local

Encargo explícito del creador, 26 oct 2026, tras aceptar el funcionamiento de
T267: partículas por todo el fondo que converjan hacia el agujero negro; cursor
que aparte solo las cercanas y les permita volver a su sitio, como agua.

## Resultado

- Campo de partículas distribuido hasta las esquinas de cada salida. Trayectorias
  procedurales en espiral hacia el horizonte; vidas escalonadas y reciclaje con
  entrada/salida atenuadas. El disco y los arcos conservan su forma central.
- Eliminado el paralaje: el puntero no traslada ni rota la cámara. Centro y
  silueta permanecen fijos. La oclusión se calcula tras la perturbación.
- Dieciséis impulsos locales guardan posición/velocidad del paso del cursor.
  El shader aplica repulsión y un pequeño remolino de soporte compacto; fuera
  de la zona de influencia la posición permanece exactamente igual.
- Los impulsos se amortiguan, con leve sobrepaso, y caducan en dos segundos.
  Un cursor quieto no genera impulsos nuevos; tampoco una posición inventada
  en el centro cuando el puntero no está sobre el escritorio.
- Se conserva el hover pasivo y local de Wayland, sin capturar clics ni seguir
  el ratón sobre otras aplicaciones. Reacción desactivada elimina las estelas.
- Lote único: 26 000 / 52 000 / 90 000 partículas. Solo 16 impulsos/uniformes
  se actualizan en CPU; las partículas siguen calculándose en GPU, máximo 30 fps.
  Los impulsos caducados omiten el trabajo de deformación en el shader.
- Fotograma estático actualizado con nuestro propio renderizado a 2560×1280.
  Se mantienen pausa/descarga, excepción local de reducir movimiento y opciones.

## Comprobaciones

Compilación nativa/QSB en `.local/build-singularity`, Qt 6.12.0 y KF6/Plasma
6.31.0/6.8.1. OpenGL real offscreen en Radeon 610M, Mesa 26.2.5.

- 4 resultados nativos + 3 QML normal + 3 QML con reducir movimiento y excepción
  local: 0 fallos. [Resumen](../../tests/shell/evidence/t268/verification.txt).
- Cobertura comprobada en una cuadrícula 6×4 de toda la salida a 1000×640.
- La imagen evoluciona también fuera del disco central.
- Comparación con el mismo tiempo orbital: la zona del cursor cambia y la mitad
  lejana queda idéntica píxel a píxel. Al caducar la estela o desactivar reacción
  se recupera exactamente la imagen base. Cursor quieto no renueva impulsos.
- Se conservaron pruebas de temporizador, bloqueo/sueño simulado, visibilidad,
  descarga, reacción local y excepción a reducir movimiento.
- qmllint con el módulo nuevo y `git diff --check`, sin avisos/errores.

Fotogramas nativos de la misma órbita:
[base](../../tests/shell/evidence/t268/flow-base.png),
[perturbación local](../../tests/shell/evidence/t268/flow-local-wake.png).
La revisión visual del creador queda pendiente; estas imágenes no la sustituyen.

### Recursos

[Muestra](../../tests/shell/evidence/t268/flow-resources.json), mismo método que
T267: proceso qmlscene aislado, 1920×1080, cuatro fases de 4 s y muestras de 2 s,
CPU como porcentaje de un núcleo, PSS de `/proc`:

| Escenario | CPU | PSS |
| --- | --- | --- |
| Sin efecto | 0 % | 26 970 KiB |
| Flujo equilibrado sin cursor | 1,0 % | 55 112 KiB |
| Flujo con cursor en movimiento | 1,5 % | 57 983 KiB |
| Tras descarga | 0 % | 50 679 KiB |

Qt/controlador conservan cachés tras destruir el lote. Son muestras breves,
no certificación de consumo total del shell. Los contadores GPU por proceso no
estuvieron disponibles (`null`); no se midieron GPU ni batería. Siguen pendientes
otra GPU, múltiples pantallas y aceptación de DPMS/suspensión física.

## Aplicación

Se actualizó el módulo del canal de desarrollo con reemplazo atómico,
preservando los inodos de bibliotecas cargadas en
`.local/singularity/dev-module-before-flow`, y se cargó reiniciando únicamente el
shell de Singlr. La unidad quedó activa y el registro confirmó «animación activa».
El SHA-256 de kdeglobals permanece idéntico. Las aplicaciones y las preferencias
globales de animación se conservan. El paquete instalado requiere la actualización habitual;
no se ejecuta pacman ni sudo en esta tarea.

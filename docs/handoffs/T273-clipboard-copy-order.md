# T273 — usar una entrada no cambia su orden

28 oct 2026. Encargo directo del creador, P-033. Mejora del portapapeles dentro
del alcance de superficies de Singlr (P-032); KDE mantiene los datos y el pegado.

## Resultado

Clic o Enter siguen pegando y Ctrl+Enter/«Copiar» siguen copiando sin pegar.
Ninguna de estas acciones mueve la entrada en la lista de Singlr. Las nuevas
copias y la copia explícita repetida desde otra aplicación aparecen arriba.
Búsqueda, imágenes, fijados, eliminación y vaciado se conservan.

## Solución y contrato KDE

DeclarativeHistoryModel 6.8.1 solo expone moveToTop para activar una entrada;
HistoryModel liga la fila cero al contenido actual y a la restauración asíncrona
de formatos. Reordenar otra vez el modelo nativo cambiaría el contenido pegado.

Se añade ClipboardHistoryModel, QSortFilterProxyModel con orden independiente por
UUID. select() activa Klipper dentro de una guarda; currentTextChanged de KDE
fuera de esa guarda representa copias y actualiza la prioridad. Lee el UUID del
modelo raíz, porque su proxy puede estar propagando todavía rowsMoved, y difiere
la actualización del orden hasta salir de esa notificación. Eliminar y vaciar
usan la misma guarda para no tratar sus notificaciones como una copia nueva.
Roles y mutaciones se siguen delegando a KDE, sin enlazar headers privados.

Metadatos en $XDG_STATE_HOME/singlr/clipboard-order.json, solo UUID en el orden
visible, lectura acotada a 1 MiB, escritura atómica con permisos del propietario.
Se podan UUID ausentes y no hay temporizadores de reposo, nuevo demonio ni
almacén de texto/imágenes. La búsqueda utiliza el proxy existente sobre esta vista.
La primera ejecución toma el orden actual como punto de partida: no reconstruye
el orden anterior a la instalación. Los movimientos internos de Klipper continúan;
la presentación estable es específica de Singlr. La actividad mientras Singlr
está detenido no se registra como una secuencia nueva independiente de KDE.

Fuentes contrastadas con Plasma 6.8.1 y Qt 6.12.0 locales:
[HistoryModel](https://github.com/KDE/plasma-workspace/blob/Plasma/6.8/klipper/historymodel.cpp),
[DeclarativeHistoryModel](https://github.com/KDE/plasma-workspace/blob/Plasma/6.8/klipper/declarative/declarativehistorymodel.cpp),
[QSortFilterProxyModel](https://doc.qt.io/qt-6/qsortfilterproxymodel.html).

## Verificación ejecutada

- singlr-clipboard-history-test: 4 resultados correctos. Cuatro entradas, usar
  la cuarta sin moverla, recopia de la primera nativa, inserción nueva, UUID
  inexistente, persistencia al recrear vista, eliminación de otra entrada y vaciado.
  Fixture con proxy y notificación antes de acabar el movimiento como en KDE.
- tools/test-qml.sh y --light: 244 shell + 11 Ajustes por modo, 0 fallos;
  5 capturas opcionales omitidas. Clic, teclado, copia y accesibilidad existentes.
- KWin privado con Klipper real: texto Unicode multilínea, imagen con dimensión
  y color verificados y solo copiar: todos PASS. Se compara la secuencia de UUID
  antes y después de seleccionar. Adaptador de prueba, sin capturar clipboard real.
- qmllint con build/qml antes de imports instalados: correcto. Compilación nativa
  y DESTDIR correctos, vidrio OFF; no valida el efecto. Packaging: 5 pruebas
  correctas. Preparación, inventario y diff correctos.
- Medida privada: 79,37 MB PSS, 61,03 MB anónimos, CPU 0,100 %, 35 hilos,
  3 superficies. Sin comparación A/B ni acreditación en sesión real. El coste
  añadido es una lista de UUID; no retiene miniaturas ni cargas MIME propias.
- Limpieza de las sesiones privadas sin procesos y hashes anfitriones iguales.

[Evidencia filtrada](../../tests/shell/evidence/t273/README.md).

## Entrega

No se reinició el shell del creador ni se tocó su historial/configuración KDE.
Actualizar paquete y entrar de nuevo en Singlr para cargar el tipo QML nativo;
QML nuevo con un módulo instalado antiguo no basta. Pendiente comprobar el uso
cotidiano del creador; no se redefine la aceptación global de Singlr 1.0.

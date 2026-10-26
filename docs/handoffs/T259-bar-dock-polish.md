# T259 — logo de barra y tooltips del dock

26 oct 2026. Ajuste acotado de Desktop/Appearance, diagnóstico de Workspace.
P-027 explícita; medidas concretas derivadas, pendientes de valoración visual.

## Resultado y criterio visual

El logo conserva su diámetro exterior: el contorno real del círculo Phosphor a
14 px mide 11,375 px, contrastado con QRawFont/pathForGlyph local. Se dibuja como
anillo de ese diámetro y trazo 1,5 px, sin relleno ni expansión hacia fuera.
Color Theme.secondary, caja de clic 24×22 y acceso al menú conservados. El mayor
peso mejora presencia sin añadir acento, brillo o nuevos materiales. Solo afecta
a la barra superior. Tipografía, composición, paleta y el resto de iconos intactos.

[Comparación nativa](../../tests/shell/evidence/t259/comparison.png): antes/después
en oscuro, detalle ampliado sin suavizado y muestras de claro. El anillo nuevo
mantiene lectura monocromática y el tooltip queda asociado al dock visualmente.
No se presenta el valor de trazo como aprobado todavía.

## Causa del tooltip

La superficie independiente usaba exclusionZone=0, que solicita evitar las reservas
de otros paneles. Además sumaba altura del dock + 18 al margen inferior. En KWin
se añadía la reserva del propio dock: a 40 px flotante había 62 px de hueco.
Se usa exclusionZone=-1 para coordenadas desde el borde de pantalla, y margen
altura + bottomMargin + 8. El menú contextual tenía la misma causa y comparte
el ajuste. El tooltip sigue sin aceptar teclado ni entrada del puntero, y no se
amplía la ventana del dock. Sin timer ni dependencia nuevos en producto.

Contrato contrastado con LayerShellQt 6.8.1 instalado y
[protocolo wlr-layer-shell](https://github.com/swaywm/wlr-protocols/blob/master/unstable/wlr-layer-shell-unstable-v1.xml),
set_exclusive_zone y set_margin. Medición geométrica desde KWin, no deducción
basada solo en propiedades QML.

## Esquina superior izquierda — diagnóstico, sin cambio

La barra abre Menú Singlr por clic, no por acercar el cursor. No hay un manejador
de esquina en TopBar. El kwinrc del creador no sobrescribe BorderActivate para
Overview; la [configuración oficial de KWin 6.8](https://github.com/KDE/kwin/blob/Plasma/6.8/src/plugins/overview/overviewconfig.kcfg)
activa ElectricTopLeft por defecto. Esto explica una vista distinta de Meta+Tab
de Singlr y su aviso de borde coloreado. No se simuló el puntero en su sesión.

Se recomienda retirar esa duplicidad en Singlr; no se cambió kwinrc, el journal
ni los efectos del creador, ya que lo formuló como consulta. Si autoriza quitarla,
el cambio debe ser reversible y específico de Singlr, conservando la preferencia
original al regresar a Plasma.

## Comprobación

- Qt 6.12.0, KWin/LayerShellQt 6.8.1; APIs y protocolo contrastados.
- tools/test-qml.sh y --light: 241 shell + 9 Ajustes por modo, 0 fallos;
  5 capturas opcionales ajenas omitidas. Incluye clic en logo abre/cierra menú,
  teclado, tooltips y ajustes del dock existentes.
- KWin privado: modos flotante/fijo, alturas 40/48/72 y autohide activo/inactivo:
  doce distancias reales de tooltip de 8 px. Menú contextual en ambos modos y
  ambas reservas: cuatro distancias reales de 8 px.
- Capturas de pantalla nativas en oscuro/claro, 2560×1600 físicos sobre salida
  lógica 2048×1280. Comparación y rasterización del logo inspeccionadas.
- El adaptador de prueba invoca el tooltip tras asentar el layout y configura
  geometrías en su perfil privado; no simula movimiento de ratón físico. Los
  tests QML anteriores cubren retardo/selección/ocultación del tooltip.
- qmllint con build/qml antes del módulo instalado: correcto. Preparación,
  inventario y diff correctos. Sin reejecutar pruebas nativas ajenas o medir
  recursos como si se hubiera añadido una función nueva.
- Cada sesión privada finalizó sin procesos y con hashes anfitriones iguales.

## Entrega y pendientes

Código, MD y evidencia sincronizados en GitHub; paquete local para instalar.
No se recargó la sesión activa. Tras actualizar, el siguiente inicio de Singlr
carga los ajustes. Pendientes: valoración del grosor, comprobación cotidiana del
tooltip y decisión de retirar/reasignar la esquina. No declara completados los
siete sistemas ni P-016 en sesión real.

Actualización posterior: el creador autorizó retirar la esquina; implementado en
[T260](T260-overview-corner.md), con restauración de preferencias.

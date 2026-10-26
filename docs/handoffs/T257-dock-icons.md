# T257 — dock sin puntos e iconos equilibrados

26 oct 2026. Encargo directo: retirar el punto de abierta y corregir logotipos que
se ven menores. P-025 explícita; geometría de compensación propuesta técnica.

## Resultado

- Se retira el punto y se centra el icono en la altura del dock. Estado abierto
  conservado en Accessible.description; navegación, acciones, DND y celdas intactos.
- Causa medida con QIcon a 128 px: Dolphin 116×104, Konsole 108×108, Firefox
  118×122, Warp/Chrome 128×128 y Codex 110×110 de contenido no transparente.
  Una caja igual no implica un dibujo igual.
- `DockIconMetrics` mide todos los píxeles alfa >0, incluidas sombras tenues;
  centra el contorno y mantiene proporción. Soporta QIcon de TasksModel, nombres
  de tema y rutas locales. No reescribe imágenes ni usa factores por aplicación.
- `DockAppIcon` conserva Kirigami como renderer, sin redondear a tamaños estándar.
  Fuente fija de 128 px y escala descendente para evitar elegir un bitmap menor y
  ampliarlo. Respiro lógico de 1 px y techo 1,5× ante padding excesivo.
- Caché acotada a 128 rectángulos, no imágenes; sin temporizadores ni animación nueva.
  El resto de AppIcon en el shell no cambia.

## Revisión visual

[Cuatro comparaciones](../../tests/shell/evidence/t257/README.md): claro/oscuro y
alturas 48/72. Cada una muestra anterior, caja uniforme sin compensación y ajuste
de tamaño visible. Se revisaron oscuro 48 y claro 72; la variante de compensación
equilibra mejor las marcas conservando colores, proporciones y material del dock.
No se afirma igualdad perceptual de masa ni aprobación final del creador.

## Verificación

- Qt 6.12.0, KF6/Kirigami 6.31.0 locales. API oficial:
  [Icon](https://api.kde.org/qml-org-kde-kirigami-primitives-icon.html),
  [QIcon](https://doc.qt.io/qt-6/qicon.html). Sin APIs privadas nuevas.
- `singlr-dock-icon-test`: 6 resultados correctos, 0 fallos. Alfa tenue, padding
  asimétrico, imagen vacía, URL con espacios/#/Unicode, cambio de icono y forma
  rectangular preservada; no se deforma un icono no cuadrado.
- `tools/test-qml.sh` y `--light`: 239 shell + 9 Ajustes por modo, 0 fallos; 5
  capturas opcionales omitidas. Tamaños 27/32/37/43/48, centro y límites visibles,
  sustitución/fallback y descripción accesible. Interacciones anteriores conservadas.
- Suite DockIcons con QT_SCALE_FACTOR=2: 9 resultados correctos. Offscreen/software,
  no certifica renderizado nativo a escalas fraccionales.
- qmllint `--bare` con build/qml, shell/qml y Qt en ese orden: correcto. El módulo
  instalado anterior no conoce el tipo nuevo; no usarlo para lint del checkout.
- CMake/DESTDIR correcto; efecto OFF advertido, no atribuir validación del efecto.
- Medida de recursos aislada: 93,45 MB PSS / 0,033 % CPU, tres superficies, limpieza
  correcta y configuración anfitriona igual. No es A/B ni cumplimiento en sesión real.
- Preparación, inventario y diff correctos.

## Entrega y límites

No se ha recargado ni alterado la sesión. Actualizar paquete y relanzar shell/sesión
para cargar el tipo nativo nuevo; no basta con mezclar QML nuevo y módulo instalado
antiguo. Propuesta visual para revisión; radio, materiales, paleta y tipografía no
se redefinen. Fuentes con poca resolución o padding extremo pueden seguir teniendo
diferencias; no se inventa detalle ni se promete igualdad entre todas las formas.

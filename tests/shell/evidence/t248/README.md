# T248 — evidencia ejecutada

- [Comprobaciones](verification.txt): compilación con KWin 6.8.1, factory del plugin,
  configuración/alcance, QML claro/oscuro, Python, staging y bloqueo de sesión anidada.
- [Ajustes oscuro](settings-dark.png) y [claro](settings-light.png): 880×600, offscreen con
  software rendering y perfiles temporales. Selector, intensidad e interruptor visibles,
  sin solapamiento y con tamaño fijo. Son propuestas visuales, no aprobación del creador.
- Estado previo de Ajustes: `apps/settings/captures/appearance-dark.png` (sin Material).
  Se conserva la jerarquía y tipografía; se añaden filas compactas, sin repetir el valor
  numérico de la intensidad ni desplegar contenido al cambiar de material.
- Accesibilidad: nombres de selector/slider/toggle y fallback opaco comprobados por QML;
  lectura visual en ambos modos. Interacción nativa de compositor pendiente.

No hay capturas reales de Liquid Glass ni medidas de GPU/frame time: el bus privado no
puede crear su socket en este sandbox. La carga QPluginLoader demuestra biblioteca/factory,
no el render del efecto. Cabeceras oficiales temporales usadas para compilar, no instaladas.

[Procedimiento de laptop y seis capturas](../../../../docs/testing/materials.md).

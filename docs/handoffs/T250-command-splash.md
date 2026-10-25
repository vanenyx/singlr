# T250 — Command: configuraciones y KSplash

Codex 1, rama `day3/codex1-command-splash`, sin commit.

- Configuraciones reales mediante el runner estándar systemsettings, mezcladas
  con resultados generales y las secciones existentes de Singlr; categoría única,
  sinónimos ES/EN, iconos KCM/Phosphor, Enter y Ctrl+K.
- KSplash estándar con paquetes dark/light y presentación compartida Singlr.Ui:
  anillo monocromo, progreso por etapas, transición breve y movimiento reducido.
  Integración con unidad KDE y señales estándar; no altera la sesión activa.
- Material continúa enlazando a Apariencia, donde existe hoy. Coordinar el
  argumento de la nueva página al integrar Codex 2. Sus materiales no se tocaron.

Procedimiento, fuentes, límites y contratos en
[command-splash.md](../testing/command-splash.md). Evidencia y resultados en
[README](../../tests/shell/evidence/t250/README.md).

La geometría del splash es propuesta visual por validar; el mecanismo de sesión
es solución técnica derivada de P-017. No se acredita login systemd real ni consumo
por la restricción de sockets D-Bus del sandbox. Sin instalación ni recarga.

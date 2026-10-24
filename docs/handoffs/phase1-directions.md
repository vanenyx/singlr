# Fase 1 — Direcciones visuales y preparación técnica

- **T101/T103 (Codex 1, cuenta 1, `phase1/codex1-directions`):** direcciones A «Estrato» y B «Margen» en `prototypes/directions/`, con 12 capturas y la lámina `captures/comparacion-A-B.png`. Claude corrigió en `common/Glass.qml` la detección de GPU (`GraphicsInfo` sin calificar) y el `autoPaddingEnabled` de MultiEffect, que impedían el desenfoque con RHI, y regeneró las capturas con OpenGL en la Radeon 610M.
- **T102 (Codex 2, cuenta 2, `phase1/codex2-qt-readiness`):** `tools/run-prototype.sh` (ventana, KWin anidado, captura), `tools/check-qml.sh`, inventario y viabilidad en `docs/phase1/tech-readiness.md`. Mediciones en ventana y anidado ejecutadas por Claude fuera del sandbox.
- **Límite del sandbox de Codex:** sin `/dev/dri` ni Wayland. Codex no puede validar efectos GPU ni ventanas, así que Claude ejecuta esas verificaciones.
- **Pendiente:** elección de dirección por el creador. Defectos conocidos: Liquid Glass deja ver con poco desenfoque los controles de las ventanas de detrás; la lista de Archivos de B queda justa sobre el pie.

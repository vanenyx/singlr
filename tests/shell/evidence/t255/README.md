# T255 — dock y auditoría de continuidad

26 oct 2026. Encargo directo del creador. Las capturas son **offscreen/software**,
1280×300 lógicos, 30 entradas representativas a 72 px; el icono de terminal repetido
es una fixture, no un cambio del catálogo ni de las marcas de aplicaciones.

| Modo | Oscuro | Claro |
| --- | --- | --- |
| Flotante | [Captura](dark-floating.png) | [Captura](light-floating.png) |
| Fijo | [Captura](dark-fixed.png) | [Captura](light-fixed.png) |

Reproducir:

```bash
SINGLR_CAPTURE_T255=1 tools/test-qml.sh
SINGLR_CAPTURE_T255=1 tools/test-qml.sh --light
```

El test de captura solo se ejecuta al pedirlo. `tst_DockOverflow.qml` verifica también
60 entradas, alturas 40/72, ambos modos, flechas, rueda, visibilidad del foco,
reducción de anchura, eliminación de entradas y coordenadas de reordenación después
de desplazar. Se conserva el arrastre de aplicación; Flickable no captura ese gesto.
El desplazamiento es inmediato y no añade animaciones ni temporizadores continuos.

La propuesta conserva tipografía, colores, materiales, altura y tamaño de iconos.
Las flechas aparecen únicamente al desbordar; la superficie flotante deja 8 px
laterales como máximo de anchura, y la fija sigue ocupando el ancho completo.
No constituye aprobación visual del creador. Touchpad físico y DND de archivos en
Wayland siguen pendientes; una prueba de rueda sintética no acredita esos recorridos.

Resultados finales y medición: [handoff T255](../../../../docs/handoffs/T255-audit-followup.md).

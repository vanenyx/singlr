# Fase 1 — Brief v2 de dirección visual

Encargo del creador (2026-10-24), tras descartar las direcciones A y B (prefería A): el escritorio sigue la filosofía de UI/UX de Linear y replica su estilo y diseño. Sobre esa base se aplican identidades de macOS (glassmorphism, no Liquid Glass) y de Raycast. Ver P-005 en [decisions.md](../decisions.md). Las cifras de este brief son referencias de partida, no tokens aprobados.

## Influencias

- **Linear (fundamental):** organización de áreas, proporciones, jerarquía, contraste, densidad, tipografía, componentes, detalles, navegación y UX.
- **macOS:** acabados, capas y elevación, ventanas, movimiento, interacción entre aplicaciones, consistencia y glassmorphism en superficies flotantes.
- **Raycast:** superficies de comando flotantes, listas compactas, filas de resultados con accesorios, panel de acciones (⌘K), vista de detalle, barra inferior de acciones, navegación completa por teclado y latencia percibida baja. Su vidrio es selectivo; no se replica su IA ni su catálogo.
- **Singlr:** síntesis propia, geometría moderada, Phosphor para símbolos del sistema y logotipos originales para aplicaciones.

## Principios de Linear que se aplican

Del artículo [Behind the latest design refresh](https://linear.app/now/behind-the-latest-design-refresh), de [How we redesigned the Linear UI](https://linear.app/now/how-we-redesigned-the-linear-ui) y de las [10 reglas de Karri Saarinen](https://www.figma.com/es-la/blog/karri-saarinens-10-rules-for-crafting-products-that-stand-out/):

- No competir por atención no ganada: el contenido de trabajo domina y la navegación y la orientación quedan unos tonos más tenues.
- La estructura se crea con espaciado y contraste sutil, no con líneas. Pocos separadores, de contraste suave.
- Neutros ligeramente cálidos y poco saturados pero nítidos; nada azulado ni turbio. Tema generado a partir de base, acento y contraste, en un espacio perceptual (LCH).
- Inter Display para títulos e Inter para el resto. Iconos pequeños y escasos, texto inactivo atenuado, pestañas y controles compactos.
- Acciones de cabecera en un lugar fijo. Densidad alta sin agobio.
- Calidad por encima del alcance: menos superficies, todas pulidas.

## Referencia tomada de los tokens públicos de linear.app (modo oscuro)

| Uso | Valor de referencia |
| --- | --- |
| Fondos por nivel | `#08090a` → `#0f1011` → `#141516` → `#191a1b`; panel `#0f1011` |
| Bordes | `#ffffff14` (primario), `#ffffff0d` (translúcido), `#23252a` sólido |
| Texto | primario `#f7f8f8`, secundario `#d0d6e0`, terciario `#8a8f98`, cuaternario `#62666d` |
| Acento | índigo `#5e6ad2` / `#7170ff`; selección como mezcla del acento con transparencia |
| Tipografía | 12–13 px en interfaz y 15 px en texto normal; títulos de 20, 24 y 36 px; pesos 400, 510, 590 y 680 |
| Radios | 4, 6 y 8 px en controles; 12 px en paneles y ventanas |
| Sombras | baja `0 2px 4px #0000001a`, media `0 4px 24px #0003`, alta `0 7px 32px #00000059` |

El modo claro usa la misma lógica (fondo `#fff`/`#f8f8f8`, texto `#282a30`). Se pueden ajustar levemente hacia el calor que describe el refresh, sin enturbiar.

## Fondo de pantalla

El fondo no es protagonista ni una exhibición. Debe ser sobrio, como los fondos de Linear: casi negro neutro con, como mucho, una luz difusa muy tenue que permita percibir el cristal. En modo claro, neutro claro. Sin formas geométricas, ondas ni colores dominantes.

## Estados que se muestran

Escritorio principal, búsqueda/lanzador al estilo Raycast (con panel de acciones abierto en una variante), multitarea y controles del sistema. Modo oscuro en todos y escritorio en claro, a 2048×1280 lógicos. Ventanas de apps simuladas con datos verosímiles y logotipos originales.

## Criterios de evaluación

1. ¿Se lee como un escritorio hecho con el lenguaje de Linear, no como un tema genérico ni una copia de macOS?
2. Jerarquía: trabajo primero; navegación y estado atenuados.
3. Precisión: alineación, ritmo, escala tipográfica, peso de iconos y contraste.
4. Glassmorphism selectivo y legible; nada de Liquid Glass.
5. Lanzador con la eficiencia de Raycast: teclado, filas compactas y acciones.
6. Viable sobre Plasma 6 y KWin.

# Singlr 1.0 — definición de producto

> Documento de referencia permanente, aportado por el creador el 25 oct 2026 (P-018). Todo trabajo
> se evalúa contra esta definición. Las notas marcadas **[Registro]** señalan dónde el texto toca
> decisiones ya tomadas en [decisions.md](decisions.md); no cambian el texto del creador.

Una experiencia de escritorio completa, original y abierta para Linux.

Singlr es una alternativa a la experiencia de escritorio de KDE Plasma: usa su infraestructura
tecnológica, pero ofrece una interfaz, una organización y una forma de interactuar claramente propias.

No es una distribución Linux, un paquete de temas ni una suite de aplicaciones. **Singlr es el entorno
en el que trabajas**: un producto que se instala porque se quiere un escritorio extraordinariamente
cuidado, rápido, coherente y agradable de utilizar, no porque se necesiten diez herramientas adicionales.

**Decisión de partida:** Singlr 1.0 debe ser un producto completo dentro de un alcance bien definido,
no una implementación superficial de todo lo que alguna vez imaginamos. Así podrá ampliarse durante
años sin que la primera versión se sienta incompleta.

## 1. La experiencia

Encender el equipo, elegir Singlr al iniciar sesión y entrar a un espacio de trabajo distinto al de
Plasma convencional.

- **Un escritorio sereno y organizado.** Superficie limpia, navegación reconocible, jerarquía visual
  cuidada. Lo necesario está disponible al momento; lo secundario aparece cuando se necesita, sin
  competir con el contenido.
- **Interacciones naturales y rápidas.** Teclado, ratón y touchpad igual de satisfactorios. Tareas
  frecuentes en pocos pasos; resultados previsibles; foco, ventanas, menús y transiciones con una
  lógica común.
- **Una interfaz con personalidad.** La precisión y composición de Linear, la sofisticación espacial de
  macOS y la calidad de las superficies interactivas de Raycast alimentan un lenguaje visual nuevo,
  reconocible por sus propias proporciones, materiales, tipografía, componentes y comportamiento.
- **Personalización integrada.** Tema, transparencias, organización del escritorio o reducir
  animaciones forman parte del producto, sin editar archivos dispersos.

**Principio de diseño de cada pantalla:** la interfaz debe hacer evidente lo importante, facilitar la
acción siguiente y mantener la continuidad del trabajo. Primero la experiencia completa; después los
componentes que necesita.

## 2. Los siete sistemas de Singlr 1.0

| Sistema | Qué incluye en la v1 |
| --- | --- |
| 01. Singlr Desktop | Superficie del escritorio, fondo, paneles, navegación de aplicaciones, dock o equivalente, indicadores, bandeja y menús |
| 02. Singlr Command | Búsqueda de aplicaciones, archivos y configuraciones, acciones rápidas, calculadora y operaciones contextuales |
| 03. Singlr Workspace | Cambio de ventanas, multitarea, vista general, organización, escritorios virtuales, foco y atajos |
| 04. Singlr System | Centro de control, conectividad, audio, energía, notificaciones, controles multimedia y menú de sesión |
| 05. Singlr Appearance | Sistema visual, decoración de ventanas, materiales, efectos, modos claro y oscuro, preferencias y personalización |
| 06. Singlr Session | Inicio, bloqueo seguro, suspensión, recuperación ante fallos, multimonitor y funcionamiento de una sesión real |
| 07. Singlr Platform | Instalador, empaquetado, actualizaciones, configuración persistente, compatibilidad, documentación y herramientas de diagnóstico |

Son sistemas del producto, no siete programas. El usuario instala una experiencia unificada; quien
contribuye encuentra módulos separados.

**Archivos y capturas:** Singlr 1.0 no desarrolla gestor de archivos ni app de capturas propios. Se
especializa en la experiencia de escritorio y la relación entre sus herramientas. Encontrar archivos,
abrir ubicaciones, ejecutar acciones y capturar la pantalla se resuelve con integraciones bien
diseñadas (Dolphin, Spectacle). Una experiencia de archivos propia sería una ampliación futura solo si
demuestra merecerlo.

## 3. Cómo se ve

- **Composición:** estructura precisa, áreas de navegación bien delimitadas, controles compactos,
  márgenes consistentes, equilibrio entre espacio libre e información. Fuerte influencia de Linear.
- **Superficies y materiales:** superficies sólidas elegantes para el contenido principal; materiales
  translúcidos y profundidad para elementos flotantes, menús y capas temporales. Los materiales son
  capacidades configurables, no tratamientos indiscriminados. Vidrio plano y sólido son
  los materiales del sistema; Liquid Glass se probó y se retiró (P-021). Siempre planos (P-020).
- **Tipografía, color e iconografía:** escala tipográfica ajustada; paleta neutral con acentos
  controlados; Phosphor Icons como base. Símbolos propios (p. ej. controles de ventana inspirados en
  la singularidad) como exploraciones de identidad, sujetas a pruebas de reconocimiento y legibilidad.
- **Movimiento e interacción:** transiciones coordinadas, respuesta inmediata, animaciones cortas y
  relaciones espaciales comprensibles; el movimiento explica qué cambió.

Una captura del escritorio debe reconocerse como Singlr, y esa identidad debe estar en toda la
interfaz, no solo en el fondo, los colores o el logotipo.

## 4. Experiencias centrales

- **Encontrar y actuar:** Singlr Command encuentra aplicación, archivo, configuración o acción y la
  ejecuta, con acciones relacionadas sin navegar menús.
- **Trabajar con varias aplicaciones:** abrir, cambiar de contexto, organizar y volver. Dock,
  indicadores, escritorios y vista general con estados consistentes.
- **Controlar el sistema:** volumen, dispositivos, conectividad, energía y preferencias en una misma
  interfaz que refleja el estado real.
- **Interrumpir y continuar:** bloquear, suspender, desbloquear y retomar con seguridad. Una caída del
  shell nunca deja sin forma de recuperar el escritorio.

No todo pasa por el centro de comandos: excelente con atajos y con ratón.

## 5. Arquitectura

```
Singlr Desktop Experience   Shell · Command · Workspace · System · Appearance
Singlr Runtime + Design     Qt Quick / QML · componentes · preferencias · servicios
Integración KDE             KRunner · KWin · NetworkManager · PipeWire · D-Bus · portales
Base                        Linux + Wayland + KWin
```

KWin sigue siendo compositor y motor de ventanas; Singlr desarrolla su shell y componentes de
experiencia, usando los mecanismos de extensión de KDE (decoraciones, scripts, efectos, sesiones).
Implica mantener compatibilidad con las versiones soportadas de Plasma y KWin.

Soporte oficial v1: **Arch Linux + KDE Plasma 6 + Wayland**; más compatibilidad con pruebas reales y
contribuciones. Se reutilizan mecanismos seguros y probados (p. ej. KScreenLocker con PAM para el
bloqueo), nunca autenticación propia.

## 6. Criterio de «Singlr 1.0 completo»

| Criterio | Exigencia |
| --- | --- |
| Instalación | Instalable desde un paquete documentado y seleccionable como sesión |
| Funcionamiento | Trabajo cotidiano con apps Linux reales, sin otro shell en ejecución |
| Experiencia | Superficies principales con UI/UX coherentes; claro y oscuro comprobados |
| Integración | Ventanas, búsqueda, controles, notificaciones y preferencias de extremo a extremo |
| Confiabilidad | Inicio, bloqueo, suspensión, recuperación, cierre y multimonitor superan pruebas reales |
| Calidad | Revisiones visuales, accesibilidad básica, pruebas de interacción y mediciones de rendimiento |
| Mantenimiento | Actualizar, desinstalar y volver a Plasma sin comprometer la configuración del usuario |
| Código abierto | Código, licencia, instrucciones de compilación, pruebas, guía de contribución e incidencias públicos |

No basta con la laptop del creador: instalación limpia, al menos otra configuración representativa,
matriz de compatibilidad y procedimiento de recuperación probado. Distribución v1: paquete de Arch y
repositorio de código. Licencia libre compatible con las dependencias; **GPL-3.0-or-later** como
candidata tras revisar las licencias de los componentes. **[Registro]** P-002 (licencia y
publicación): el creador decidirá más adelante; sin licencia no se publica.

## 7. Punto de partida

No se empieza de cero. Prioridad: primero convertir el código actual en una experiencia fiable,
instalable y utilizable de principio a fin; después elevar sistemáticamente la calidad visual y de
interacción hasta este estándar. Ambas pueden avanzar en paralelo, pero **no hay v1 estable mientras
la sesión no esté comprobada**. El consumo debe seguir midiéndose sobre el escritorio completo, no
solo sobre el proceso del shell.

## 8. Por qué Singlr

Un tema cambia la apariencia; un lanzador mejora una forma de acceder. Singlr transforma cómo se
presenta, se organiza y se usa el entorno completo: organización, búsqueda, controles, ventanas,
materiales y transiciones con identidad y criterios comunes. La diferencia debe percibirse al usarlo.

## 9. Fuera de la v1

Ecosistema de extensiones de terceros, gestor de archivos original, herramientas especializadas de
capturas, sincronización entre dispositivos o un compositor propio: estudiables después, nunca
compromisos automáticos. Todo lo que sí forma parte de la experiencia principal debe funcionar
correctamente antes de publicar la versión estable.

## Definición final

**Singlr 1.0:** una experiencia de escritorio alternativa, abierta, refinada y altamente productiva
para Linux, construida sobre KWin y las tecnologías de KDE. Navegar, trabajar con aplicaciones,
controlar el sistema y organizar el espacio de trabajo se sienten inmediatos, naturales y
visualmente coherentes. Una interpretación original de lo mejor de Linear, macOS y Raycast, con
identidad propia, alto rendimiento y capacidad de personalización. Un producto completo, instalable,
mantenible y abierto a contribuciones. Se define por la calidad de la experiencia completa, no por
el número de widgets, aplicaciones o funciones.

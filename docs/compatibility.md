# Compatibilidad — matriz inicial Session/Platform

Actualizada 26-10-2026, T255 (conserva evidencia T247). Soporte objetivo v1: Arch Linux + Plasma 6 + Wayland.
**Ninguna fila equivale a certificación v1.** «Inventariado» solo indica presencia;
«componente»/«anidado» no prueban login, hardware, seguridad ni retorno a Plasma.

| Entorno / evidencia | GPU / render | Escalado / monitores | Versiones | Resultado y límite |
| --- | --- | --- | --- | --- |
| Equipo del creador; confirmación en `docs/status.md` / T237 | GPU usada no registrada | Topología y escala no registradas | Base local Plasma 6.8.1, KWin 6.8.1, Qt 6.12.0; versión exacta del paquete de esa confirmación no fijada | Creador confirmó login real, teclado, cursor, cartera y uso de ksmserver. No es ejecución de la batería T247. |
| Inventario T247 del host, sin controlar su sesión | PCI vendor/device AMD `1002:164e` y NVIDIA `10de:2860`; selección de GPU/driver sin verificar | Sin consultar topología activa | plasma-workspace 6.8.1-1, kwin 6.8.1-2, qt6-base 6.12.0-3, qt6-declarative 6.12.0-2, systemd 262.1-1, libkscreen/kscreenlocker 6.8.1-1 | Versiones por `pacman -Q`, IDs por sysfs. Inventario; no atribuir resultados de render a esas GPU. |
| Componentes T240, repetidos en T247 (`test_lockscreen.py`) | Qt offscreen/software | Layout con salida pequeña; capturas previas 1280×900; claro/oscuro | Qt 6.12.0 / KF6 instalado, KPackage Plasma/Shell API 2 | KPackage propio y fallback de archivos KDE correctos; dos series de 9 resultados QtTest correctos. El greeter nativo `--testing` T247 también emitió el marcador de QML propio sin fallback con payload DESTDIR y buses privados no disponibles. No acredita PAM, greeter bloqueado real ni escalado fraccional. |
| KWin anidado + ksmserver, validación Claude T237 | Backend no registrado | Topología/escala no registradas | Véase handoff T237 | Guardado/restauración de Dolphin y sesión vacía, sin plasmashell/KRunner. No prueba instalación limpia ni guardado interactivo Kate. |
| T247 CMake + instalación DESTDIR | No render | No aplica | Toolchain local: CMake 4.4.4, Qt 6.12.0 | Compilación/payload correctos, incluye singlr-doctor. No instala sobre el host. |
| Usuario nuevo + batería T247 + regreso a Plasma | **Pendiente** | **Pendiente** | Fijar versión exacta del paquete antes de ejecutar | Procedimiento y scripts en [tests/session](../tests/session/README.md). No ejecutados aquí. |

## Diagnóstico T255

El 26 oct `real-session.py startup --allow-development` pasó en la sesión instalada,
sin acciones de mutación. Shell, KWin y ksmserver estaban activos. Se generó informe
filtrado con `singlr-doctor`. No se recargó el shell ni se probó el paquete fuera del
canal dev. Dock: pruebas QML/capturas aisladas de muchas aplicaciones; pendiente
valoración visual y touchpad/DND físico. Recursos: recorrido KWin privado y cifras
en [resources.md](phase1/resources.md); no certifican el presupuesto en sesión real.

## Cobertura todavía necesaria

| Configuración/recorrido | Evidencia que falta |
| --- | --- |
| Segunda configuración representativa | Otro equipo o VM Wayland con GPU/backend distinto; instalación limpia, uso y reversión completos. Registrar si es virtual, sin presentarlo como hardware físico. |
| AMD integrada, Intel integrada, NVIDIA propietaria/Mesa según equipo | Driver/kernel y GPU **realmente usada**, login, estabilidad, bloqueo, hotplug, recuperación; repetir con GPUs híbridas si procede. IDs PCI presentes no validan render. |
| 100 %, 125 %, 150 %, 200 %; escalas mixtas | Barra/dock, ajustes, Command, greeter, foco y ausencia de duplicados tras desconectar/reconectar. Registrar resolución, refresco, escala por salida sin EDID ni números de serie. |
| 1 monitor, 2 monitores, externo primario, portátil con tapa | Mover ventanas entre salidas, retirar/devolver salida, suspensión física y DPMS, desbloqueo en ambas, docks USB-C si existen. Cero salidas sigue pendiente; prueba T247 retira una conservando otra. |
| Ciclo de vida real completo | Inicio, bloqueo/desbloqueo con PAM, shell <3 s visual, ráfagas, reexec, guardar/cancelar logout, restauración de apps, instalación durante sesión. |
| Desinstalación y actualización | Usuario nuevo, auditoría antes/después de `pacman -R`, login Plasma sin pérdida de ajustes transitorios; actualización desde paquete anterior con datos existentes. Preferencias de apariencia compartidas se conservan según inventario; comprobar/reseleccionar alternativas automáticas `dev.singlr.*` antes de eliminar los paquetes LookAndFeel. |
| Presupuesto P-016 | Medición de shell y escritorio completo. T247 intentó `tools/measure-resources.sh`: sin muestra por fallo del bus privado; limpieza confirmó hashes del host iguales. No se acredita PSS <120 MB ni GPU liberada. Doctor no añade servicio residente. |
| Otras versiones de Plasma/KWin/Qt | Solo la base local está contrastada. No declarar soporte por mínimos de CMake ni extender a Plasma 5, X11 u otra distribución sin pruebas. |

Para cada ejecución registrar fecha, revisión/versión de Singlr, canal de desarrollo
activo/inactivo, versiones de componentes, GPU/driver/kernel, backend, resolución/
escala/salidas, escenario, resultado automático **y** observación manual, fallos y
limpieza. Adjuntar el JSON filtrado de `singlr-doctor` y resultados de pruebas;
el inventario de HOME es privado y se revisa localmente. No publicar capturas con
nombres, notificaciones ni documentos personales.

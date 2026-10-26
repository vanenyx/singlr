# Arquitectura implementada

Actualizada el 26 oct 2026. Fase 1: prototipo integrado; arquitectura actual,
no certificación de Singlr 1.0. [Definición de producto](singlr-1.0.md).

| Capa | Implementación |
| --- | --- |
| Shell | `shell/qml/`: Qt Quick, módulos Singlr.Ui/Shell, superficies layer-shell por pantalla, dock principal y paneles diferidos |
| Runtime | `shell/session/src/`: lanzador C++, atajos, servicios del sistema, agente NetworkManager/KWallet, bandeja SNI, fondo y regiones de blur |
| Command | `shell/command/`: modelo de resultados KRunner; UI/acciones en el shell |
| Appearance | `session/appearance/`: módulo QML nativo Singlr.System, KConfig/KConfigWatcher y puente Workspace; KDE es fuente de modo y acento |
| Workspace | Efecto QML Overview, script de gestos y paquete KWin WindowSwitcher; KWin conserva la gestión de ventanas |
| Vidrio | Plugin C++ `kwin/effects/singlr-liquidglass/`: difusión y luminancia, sin Liquid Glass; requiere ABI KWin 6.8.1 exacta |
| Session | `session/startsinglr-wayland`, target/unidades systemd, KWin y ksmserver de KDE; bloqueo KScreenLocker/PAM con paquete Plasma/Shell propio |
| Platform | CMake/ECM, paquete Arch local, diagnóstico y batería de aceptación/reversión |

## Datos y recuperación

- Preferencias propias: `singlr/singlr.conf` en XDG_CONFIG_HOME. Esquema versionado;
  no se degrada una configuración futura. Dock fijado/orden conserva su archivo previo.
- Claro/oscuro y acento siguen KDE; los cambios explícitos de apariencia son compartidos
  y persistentes. La desinstalación no promete deshacer preferencias elegidas por el usuario.
- Ajustes KWin y atajos temporales usan journals persistentes con restauración.
  Se retira la decoración Aurorae propia (P-023); se respeta la decoración KDE elegida.
- El shell se recupera con `Restart=on-failure`, tres arranques en 60 s; el agotamiento
  no debe terminar KWin, ksmserver ni las aplicaciones.
- Canal de desarrollo del creador: shell/QML desde el checkout. Sesión, unidades,
  bloqueo y módulos de KWin instalados requieren actualizar el paquete.

## Compatibilidad y pruebas

Base inventariada: Arch, Plasma/KWin 6.8.1, Qt 6.12.0 y KF6 6.31.0.
CMake construye binarios y módulos; `tools/check-cmake.sh` valida un DESTDIR temporal.
Comprobar `SINGLR_BUILD_LIQUIDGLASS`: con OFF, ese check no acredita el plugin de vidrio.
Las pruebas QML usan datos y buses aislados. Sesiones anidadas no equivalen a login,
PAM, suspensión física o reversión de una instalación real.

Límites y matriz: [compatibility.md](compatibility.md).
Presupuesto y método: [phase1/resources.md](phase1/resources.md).
Quickshell no es una dependencia; Node/web no sustituyen el escritorio nativo.

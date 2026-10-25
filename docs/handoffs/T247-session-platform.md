# T247 — Session y Platform: batería y diagnóstico

Codex 2, 25-10-2026. Worktree `codex-2`, rama
`day3/codex2-session-platform`. Sin commit, instalación ni cambios a la sesión activa.
Solución técnica derivada de sistemas 06/07, §6 de Singlr 1.0 y P-016/P-017.

## Entrega

- `tests/session/real-session.py`: batería para sesión instalada. Inicio, bloqueo
  con marcador positivo del QML propio y rechazo de fallback, retirada/retorno de
  salida, SIGKILL/recuperación D-Bus <3 s, ráfagas con política efectiva, reexec y
  dos fases de continuidad de pacman/logout. Exige acción explícita para interrumpir
  la sesión y rechaza canal de desarrollo salvo diagnóstico solicitado.
- `tests/session/home-audit.py`: baseline privado y comparación tras Singlr,
  desinstalación y regreso a Plasma. KWin/atajos transitorios restaurados,
  preferencias persistentes inventariadas, detección de referencias de apariencia
  `dev.singlr.*` tras quitar el paquete. No recorre HOME ni carteras; alcance
  permitido documentado. Los cambios de apps/KDE requieren revisión local.
- `tests/session/package-probe/PKGBUILD`: fixture desechable sin hooks/servicios.
- `tools/singlr-doctor`: informe JSON filtrado instalado en `/usr/bin` por CMake;
  versiones, sesión, unidades, canal dev, eventos recientes clasificados sin
  mensajes libres. Archivo nuevo 0600, datos inaccesibles marcados desconocidos.
- `LockScreenUi.qml`: **dos líneas de observabilidad**, marcador constante en
  Component.onCompleted. Sin cambios de autenticación, fallback, apariencia ni
  comportamiento de bloqueo. No se tocó `singlr_kwin.py` ni paquetes KWin.
- README de batería, enlaces de Session/Packaging, `docs/compatibility.md` y
  registro técnico T-011. Matriz inicial distingue evidencia heredada, inventario,
  pruebas de componentes y sesiones reales pendientes.

## Verificación ejecutada

- `python3 -m unittest discover -s tests/session -v`: **6 correctas**, XDG temporal
  y dobles de frontera, sin controlar la sesión activa.
- `test_packaging.py`: **5 correctas**; `test_session_entry.py`: **17 correctas**.
- `test_lockscreen.py`: **2 correctas**, KPackage y dos series de **9 resultados
  QtTest** (claro/oscuro), offscreen/software.
- Greeter nativo `--testing --shell org.singlr.desktop`, payload DESTDIR, XDG
  temporal, buses inexistentes, offscreen/software: **marcador propio presente,
  sin fallback**. No se envió contraseña ni se bloqueó la pantalla. PAM/login
  quedan sin acreditar. Log local `/tmp/t247-greeter.log` (no adjuntar crudo).
- `tools/check-cmake.sh`: compilación y DESTDIR correctos, verificador exige
  `singlr-doctor` y modo ejecutable. Staging eliminado. Log de última ejecución
  `/tmp/t247-cmake-final.log`.
- Fixture construido con `makepkg --nodeps --noconfirm` en `/tmp/t247-pkg.*`:
  paquete creado correctamente; **no instalado**. Log `/tmp/t247-probe-build.log`.
- `python3 scripts/check_setup.py`, sintaxis del PKGBUILD, py_compile y
  `git diff --check`: correctos. `scripts/doctor.py`: inventario realizado.
- `tools/singlr-doctor --output /tmp/t247-doctor.json`: informe generado; versiones
  disponibles, bus de usuario/journal inaccesibles en sandbox, no declara salud.
- `real-session.py startup --evidence /tmp/t247-real-startup.json`: **FAIL por
  acceso a systemctl/bus bloqueado**; ninguna acción de mutación ejecutada.
- P-016: intento `tools/measure-resources.sh --output /tmp/t247-resources`: **sin
  muestra**, exit 127 del escenario por fallo del bus privado (`Operation not
  permitted`); limpieza `remaining=[]`, hashes host `equal=True`. No se afirma
  cumplimiento de presupuesto. Doctor es una herramienta puntual sin daemon;
  marcador de greeter se emite una vez por instancia, sin temporizador nuevo.

## Qué sigue

Claude puede ejecutar checks de infraestructura ya y, fuera del sandbox dentro
del usuario de prueba autorizado, inicio, pérdida de salida, caídas/ráfagas y
reexec. Creador: crear usuario/equipo o VM de prueba, instalar paquete actualizado,
introducir contraseña exclusivamente en greeter, validar login/logout/guardado,
transacciones administrativas de pacman y regreso a Plasma. No desinstalar sobre
el equipo mientras otro usuario esté usando Singlr.

El script mide readiness D-Bus; primer frame/recuperación visual requiere observar.
Retirar una salida conserva otra: suspensión física/DPMS/cero salidas siguen
pendientes. El logout en dos fases verifica nueva sesión; guardado/cancelación y
reapertura de documentos requieren observación explícita. No se declara Session/
Platform completos con estas herramientas.

Límite de reversión detectado/documentado: las preferencias de apariencia KDE
son compartidas; si el usuario activó alternativas `dev.singlr.light/dark`, debe
seleccionar alternativas instaladas antes de quitar sus LookAndFeel. El auditor
falla si siguen referenciadas tras desinstalar. No se añade un hook privilegiado
que reescriba preferencias de todos los usuarios.

## Ejecución real en la sesión del creador (25 oct, Claude, con su autorización)

Sesión Singlr instalada, canal de desarrollo activo (`--allow-development`: no acredita el shell empaquetado).
- `startup`: PASS (solo lectura).
- `crash`: PASS — recuperación D-Bus en 0,39 s (SIGKILL al shell; KWin/ksmserver/target intactos).
- `reexec`: PASS — `systemctl --user daemon-reexec` sin perder la sesión (el fallo que antes cerraba la sesión al instalar).
- `singlr-doctor`: informe generado.
Pendientes: `lock` (requiere al creador), `outputs` (requiere 2 salidas), `burst` (verificado solo en anidado),
cierre/restauración e instalación durante sesión con el fixture, instalación limpia en usuario dedicado.

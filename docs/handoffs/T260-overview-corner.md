# T260 — retirar la esquina duplicada de KDE

26 oct 2026. Autorización explícita P-028, posterior a la consulta T259.
Ajuste de Workspace/Session; no cambia la presentación ni declara Singlr completo.

## Cambio

singlr_kwin elimina únicamente ElectricTopLeft (7) de la lista BorderActivate de
Overview nativo. Si falta la clave se escribe lista vacía: borrar la clave volvería
a habilitar el valor predeterminado, que es esa esquina. Otros bordes explícitos
se conservan y la vista general propia de Singlr sigue accesible con Meta+Tab.
No se deshabilita el efecto completo ni se modifican atajos o gestos.

El journal existente añade la clave al nuevo snapshot y restaura su valor exacto
al salir, también si estaba ausente o vacía. Los journals anteriores siguen
siendo válidos: se restauran primero y luego se captura la clave nueva. Errores,
reintentos e idempotencia conservan el mecanismo transaccional previo.

KWin 6.8.1 local; ElectricTopLeft=7 en /usr/include/kwin/effect/globals.h y
[configuración oficial de Overview 6.8](https://github.com/KDE/kwin/blob/Plasma/6.8/src/plugins/overview/overviewconfig.kcfg).
Se reutilizan KConfig y el arranque de sesión, sin nuevos procesos o dependencias.

## Evidencia

Tests temporales de recuperación, lista ausente/vacía, esquina sola, otras esquinas,
valor deshabilitado y journal anterior a T260. El test real con kreadconfig6 y
kwriteconfig6 verifica clave ausente → vacía → ausente, y 1,7,3 → 1,3 → 1,7,3;
no opera sobre el kwinrc anfitrión. Además, comprobación C++ temporal con
KConfigGroup::readEntry<QList<int>>: ausencia devuelve el predeterminado [7],
valor vacío devuelve [] y 1,3 conserva [1,3], tres comprobaciones correctas.

- test_kwin.py: 17 pruebas correctas, incluidos KConfig CLI y recuperación.
- Suite Python shell completa: 95 pruebas correctas (111,3 s).
- Herramientas de sesión: 6 pruebas correctas.
- check_setup.py y git diff --check: correctos.

No hay cambio QML: no se repiten capturas ni la suite QML completa del shell.
La batería Python ejecuta incidentalmente 9 resultados de bloqueo QML correctos. La prueba de
movimiento físico del cursor en la sesión instalada queda para la comprobación
del creador después de actualizar. No se recargó KWin ni se aplicaron preferencias
a la sesión activa para verificar el cambio.

## Activación

Instalar el paquete nuevo y entrar de nuevo en Singlr. El arranque aplica la
preferencia antes de iniciar KWin; al salir restaura Plasma. No hace falta editar
kwinrc manualmente. Código y documentación sincronizados en GitHub.

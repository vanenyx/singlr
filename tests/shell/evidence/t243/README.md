# T243 — Desktop actions in application menus

Technical solution derived from T243, applying P-009/P-012/P-014/P-017.

- Local versions: Plasma 6.8.1, KService/KIO 6.31.0, Qt 6.12.0.
- `System::applicationActions()` uses the existing `desktopService()` resolution
  and `KService::actions()`. KDE resolves locale-specific `Name` entries, order,
  action identity and optional icon. Hidden, separator and incomplete actions are
  excluded. QML receives metadata, never executable command lines.
- `System::launchApplicationAction()` resolves the action again by its identity
  and starts `KIO::ApplicationLauncherJob(const KServiceAction &, QObject *)`.
  KIO handles command expansion, launch context and job lifetime. Completion/errors
  are exposed through `applicationActionFinished`; errors are also logged.
- Standard API documented at https://api.kde.org/kio-applicationlauncherjob.html;
  local headers `/usr/include/KF6/KService/kserviceaction.h` and
  `/usr/include/KF6/KIOGui/kio/applicationlauncherjob.h` confirm these contracts.
  This directly fits the already resolved KService; no Plasma-private jump-list
  API, Exec parsing or new desktop-file parser is needed.
- Shared `ApplicationActions.js` maps the same actions into dock and launcher.
  In the dock, windows precede the app section; pin/quit follow separate dividers.
  In the launcher, native desktop actions replace runner app actions to avoid
  duplicated entries; non-app runner actions retain their original indexes.
- Desktop Entry has no semantic identifier for “new window”. The fallback checks
  common normalized IDs (`new-window`, `NewWindow`, `new-empty-window`,
  `window-new`, `open-new-window`) independently of translated names. Unknown,
  nonstandard IDs cannot be classified reliably. Generic new-window additionally
  requires `IsNewInstanceable`; unavailable menu operations are omitted.
- CMake, incremental build and native test link commands now link KIOGui and
  CoreAddons as needed. Arch declares `kservice` and `kio` directly.

Verification performed in this worktree:

- `cmake -S . -B build && cmake --build build -j2`: passed.
- `SINGLR_BUILD_DIR=/tmp/singlr-t243-build shell/session/build.sh`: passed.
- `python3 -m unittest discover -s tests/shell -p test_application_actions.py`:
  passed for en/es/fr. Real KIO launches `/usr/bin/touch` into a temporary
  directory; main Exec is `/usr/bin/false`, so the marker verifies the action
  Exec was selected. Also verifies order, icons, hidden/incomplete action
  filtering and rejected identities. Temporary XDG profile, offscreen platform,
  disconnected session/system buses; no real application or KDE session changed.
- `bash tools/test-qml.sh`: 155 shell + 7 settings cases passed, zero failures.
  Dock tests use a TasksModel double and an action-service double; launcher tests
  cover both applications and search results, keyboard dispatch and icons.
- Existing native regression suites: `test_session_actions.py` (1 passed,
  1 skipped: private bus unavailable), `test_tray.py` (3 passed, 1 skipped:
  private bus unavailable), `test_build.py` (1 passed, incremental dependencies,
  locking and failed-build cache preservation). An initial incremental test ran
  while build.py formatting changed and counted an extra rebuild; rerunning on
  the stable final files passed.
- `python3 scripts/check_setup.py` and `git diff --check`: passed.

A private dbus-daemon initially could not bind a socket in the sandbox. The native
launch test instead uses disconnected buses; KIO's process launch succeeds in that
configuration. Interactive activation of real Chrome/Firefox windows and review
in the installed session remain for integration; the active shell was not reloaded.

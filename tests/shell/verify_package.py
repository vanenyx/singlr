#!/usr/bin/env python3
"""Verify the complete /usr Arch staging payload without running a session."""
from pathlib import Path
import sys


def verify(stage):
    root = Path(stage)
    required = [
        'usr/lib/singlr/singlr-shell', 'usr/lib/singlr/startsinglr-wayland',
        'usr/lib/singlr/singlr_kwin.py', 'usr/lib/singlr/singlr-kwin',
        'usr/lib/qt6/qml/Singlr/System/qmldir',
        'usr/lib/qt6/qml/Singlr/System/libsinglr-system.so',
        'usr/lib/qt6/qml/Singlr/System/libsinglr-systemplugin.so',
        'usr/share/plasma/look-and-feel/dev.singlr.light/contents/defaults',
        'usr/share/plasma/look-and-feel/dev.singlr.dark/contents/defaults',
        'usr/lib/systemd/user/singlr-kwin-recover.service',
        'usr/lib/systemd/user/plasma-kwin_wayland.service.d/50-singlr-recovery.conf',
        'usr/lib/singlr/qml/Shell.qml', 'usr/lib/singlr/qml/Singlr/Ui/qmldir',
        'usr/lib/singlr/apps/settings/Main.qml', 'usr/bin/singlr-settings',
        'usr/share/applications/singlr-settings.desktop',
        'usr/share/wayland-sessions/singlr.desktop',
        'usr/lib/systemd/user/singlr-shell.service',
        'usr/lib/systemd/user/singlr-shell-failed.service',
        'usr/lib/systemd/user/singlr-workspace.target',
        'usr/share/aurorae/themes/Singlr/Singlrrc',
        'usr/share/kwin/effects/singlr-overview/metadata.json',
        'usr/share/kwin/effects/singlr-overview/contents/ui/main.qml',
        'usr/share/kwin/scripts/singlr-gestures/metadata.json',
        'usr/share/kwin/scripts/singlr-gestures/contents/ui/main.qml',
        'usr/share/plasma/shells/org.singlr.desktop/metadata.json',
        'usr/share/plasma/shells/org.singlr.desktop/contents/lockscreen/LockScreen.qml',
        'usr/share/plasma/shells/org.singlr.desktop/contents/lockscreen/LockScreenUi.qml',
        'usr/share/plasma/shells/org.singlr.desktop/contents/lockscreen/MainBlock.qml',
        'usr/share/plasma/shells/org.singlr.desktop/contents/lockscreen/config.xml',
        'usr/share/plasma/shells/org.singlr.desktop/contents/fonts/InterVariable.ttf',
        'usr/share/plasma/shells/org.singlr.desktop/contents/fonts/Phosphor.ttf',
    ]
    for relative in required:
        assert (root / relative).is_file(), f'Missing payload: {relative}'
    for relative in required[:2] + ['usr/bin/singlr-settings', 'usr/lib/singlr/singlr-kwin']:
        assert (root / relative).stat().st_mode & 0o111, f'Not executable: {relative}'
    import re
    theme = root / 'usr/lib/singlr/qml/Singlr/Ui/Theme.qml'
    for font in re.findall(r'source:\s*"([^"]+\.ttf)"', theme.read_text()):
        assert (theme.parent / font).is_file(), f'Missing font: {font}'
    lockscreen = root / 'usr/share/plasma/shells/org.singlr.desktop/contents/lockscreen'
    for font in re.findall(r'source:\s*"([^"]+\.ttf)"', (lockscreen / 'Theme.qml').read_text()):
        assert (lockscreen / font).is_file(), f'Missing greeter font: {font}'
    for relative in ('usr/share/wayland-sessions/singlr.desktop',
                     'usr/lib/systemd/user/singlr-shell.service'):
        text = (root / relative).read_text()
        assert '/usr/lib/singlr/startsinglr-wayland' in text
    print('PASS staged payload, executable modes, fonts and session paths')


if __name__ == '__main__':
    verify(sys.argv[1])

#!/usr/bin/env python3
"""T261: remove every backend output, then map the real dock onto a new one.

Requires the test-only KWin plugin built with:
  cmake -S tests/shell/output-control -B build/output-control
  cmake --build build/output-control
Usage: python3 tests/shell/dock-resume-e2e.py --output /tmp/t261-before
Run again after rebuilding singlr-shell. Logs survive failures. Never uses the
host bus, display, profile or installed shell. This is not physical suspend.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]


def run_inside(folder, binary):
    env = os.environ.copy()
    env.pop('DISPLAY', None)
    env.pop('WAYLAND_DISPLAY', None)
    env.pop('WAYLAND_SOCKET', None)
    env.update(QT_FORCE_STDERR_LOGGING='1', QT_QPA_PLATFORM='wayland',
               DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent',
               XDG_CURRENT_DESKTOP='KDE', XDG_SESSION_TYPE='wayland',
               QML_IMPORT_PATH=str(ROOT / 'build/qml'),
               SINGLR_TEST_OUTPUT_CONTROL='1')
    with tempfile.TemporaryDirectory(prefix='singlr-resume-') as temp:
        base = Path(temp)
        env.update(XDG_RUNTIME_DIR=temp, XDG_CONFIG_HOME=str(base / 'config'),
                   XDG_DATA_HOME=str(base / 'data'), XDG_CACHE_HOME=str(base / 'cache'),
                   XDG_STATE_HOME=str(base / 'state'))
        plugin = ROOT / 'build/output-control/plugins'
        env['QT_PLUGIN_PATH'] = str(plugin)
        kwin_log = folder / 'kwin.log'
        with kwin_log.open('w') as log:
            kwin = subprocess.Popen(['kwin_wayland', '--virtual', '--output-count', '2',
                                     '--width', '1280', '--height', '800', '--socket', 'resume-test',
                                     '--no-lockscreen', '--no-global-shortcuts', '--no-kactivities'],
                                    env=env, stdout=log, stderr=subprocess.STDOUT)
            env['WAYLAND_DISPLAY'] = 'resume-test'
            def dbus(path, method, *args, service='org.kde.KWin'):
                return subprocess.check_output(['qdbus6', service, path, method, *args],
                                               env=env, text=True, stderr=subprocess.PIPE, timeout=5).strip()
            def wait_for(predicate, label):
                deadline = time.monotonic() + 12
                while time.monotonic() < deadline:
                    if kwin.poll() is not None:
                        raise RuntimeError('Private KWin exited; see kwin.log')
                    try:
                        value = predicate()
                        if value: return value
                    except subprocess.CalledProcessError:
                        pass
                    time.sleep(.1)
                raise AssertionError('Timeout: ' + label)
            try:
                wait_for(lambda: dbus('/SinglrTestOutputs', 'org.singlr.TestOutputs.count') == '2', 'test plugin ready')
                def snapshot():
                    marker = 'RESUME_' + uuid.uuid4().hex
                    script = base / 'snapshot.js'
                    script.write_text('print(' + json.dumps(marker) + ''' + JSON.stringify({
                        outputs: workspace.screens.map(o => o.name),
                        windows: workspace.windowList().filter(w => w.resourceClass == "singlr-shell").map(w => ({
                            output: w.output ? w.output.name : null, hidden: w.hidden,
                            x: w.frameGeometry.x, y: w.frameGeometry.y,
                            width: w.frameGeometry.width, height: w.frameGeometry.height
                        }))}));''')
                    number = dbus('/Scripting', 'org.kde.kwin.Scripting.loadScript', str(script), marker)
                    try:
                        dbus('/Scripting/Script' + number, 'run')
                        def read():
                            for line in kwin_log.read_text(errors='replace').splitlines():
                                if marker in line: return json.loads(line.split(marker, 1)[1])
                        return wait_for(read, 'KWin snapshot')
                    finally:
                        dbus('/Scripting', 'org.kde.kwin.Scripting.unloadScript', marker)
                results = []
                for fixed in (False, True):
                    for autohide in (False, True):
                        name = ('fixed' if fixed else 'floating') + ('-autohide' if autohide else '-visible')
                        shell_log = folder / (name + '.log')
                        with shell_log.open('w') as log:
                            command = [str(binary), str(ROOT / 'shell/qml'), str(ROOT / 'tests/shell/DockResumeProbe.qml')]
                            if fixed: command.append('--fixed')
                            if autohide: command.append('--autohide')
                            shell = subprocess.Popen(command, env={**env, 'WAYLAND_DEBUG': '1'}, stdout=log, stderr=subprocess.STDOUT)
                            try:
                                def call(method):
                                    return dbus('/PlasmaShell', 'org.kde.PlasmaShell.' + method, service='org.kde.plasmashell')
                                wait_for(lambda: dbus('/PlasmaShell', 'org.freedesktop.DBus.Introspectable.Introspect', service='org.kde.plasmashell'), 'shell bridge')
                                call('toggleLauncher')
                                def check(mapped, output=None):
                                    state = snapshot()
                                    docks = [w for w in state['windows'] if w['height'] == 48 and not w['hidden']]
                                    edges = [w for w in state['windows'] if w['height'] == 2 and not w['hidden']]
                                    if len(docks) != int(mapped) or len(edges) != int(autohide): return False
                                    for window in docks + edges:
                                        if output and window['output'] != output: return False
                                    if docks:
                                        dock = docks[0]
                                        if (dock['width'] == 1280) != fixed: return False
                                        if dock['y'] + dock['height'] != (800 if fixed else 796): return False
                                    return state
                                wait_for(lambda: check(True), 'initial dock: ' + name)
                                # Closed while shown: shown remains true, exposing the original bug
                                # even with autohide enabled (keyboard hold is legitimate state).
                                for cycle in range(2):
                                    call('toggleLauncher')
                                    if cycle and autohide:
                                        call('singlrShowApplications')
                                        wait_for(lambda: check(False), 'dock auto-hidden before loss')
                                    dbus('/SinglrTestOutputs', 'org.singlr.TestOutputs.removeAll')
                                    assert dbus('/SinglrTestOutputs', 'org.singlr.TestOutputs.count') == '0'
                                    # Give Qt time to receive wl_output removal and create its placeholder.
                                    time.sleep(.6)
                                    target = 'Virtual-T261-' + name + '-' + str(cycle)
                                    assert dbus('/SinglrTestOutputs', 'org.singlr.TestOutputs.add', target.removeprefix('Virtual-')) == 'true'
                                    state = wait_for(lambda: check(not (cycle and autohide), target), 'restored surface: ' + name)
                                    assert state['outputs'] == [target], state
                                    if autohide:
                                        call('singlrShowApplications')
                                        wait_for(lambda: check(False, target), 'auto-hide after resume')
                                        call('toggleClipboard')
                                        wait_for(lambda: check(True, target), 'reveal after resume')
                                        wait_for(lambda: check(False, target), 'hide again after resume')
                                    results.append(dict(scenario=name, cycle=cycle, state=state))
                                assert shell.poll() is None, 'shell exited'
                                assert 'TypeError' not in shell_log.read_text(errors='replace'), shell_log
                                print('PASS', name, flush=True)
                            finally:
                                shell.terminate()
                                shell.wait(timeout=10)
                (folder / 'results.json').write_text(json.dumps(results, indent=2))
            finally:
                kwin.terminate()
                kwin.wait(timeout=10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--binary', type=Path, default=ROOT / 'build/shell/session/singlr-shell')
    parser.add_argument('--inside', action='store_true', help=argparse.SUPPRESS)
    args = parser.parse_args()
    folder = args.output.resolve()
    if args.inside:
        run_inside(folder, args.binary.resolve())
    else:
        folder.mkdir(parents=True, exist_ok=False)
        # Always create a new bus; never accept a descriptor of the active session.
        with (folder / 'driver.log').open('w') as log:
            result = subprocess.run(['dbus-run-session', '--', sys.executable, __file__,
                                     '--inside', '--output', str(folder), '--binary', str(args.binary.resolve())],
                                    stdout=log, stderr=subprocess.STDOUT)
        print((folder / 'driver.log').read_text())
        sys.exit(result.returncode)


if __name__ == '__main__':
    main()

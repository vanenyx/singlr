#!/usr/bin/env python3
"""Read the real AT-SPI tree of a marked private Singlr session via D-Bus.

No pyatspi dependency; requires python-dbus. Does not enable accessibility on the
host, invoke actions, or connect to the host's session bus. Start the private
runner with QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 before taking a snapshot.
"""
import argparse
import json
from pathlib import Path
import runpy
import sys

ROOT = Path(__file__).resolve().parents[1]
resources = runpy.run_path(str(ROOT / 'tools/measure-resources.py'))
ACCESSIBLE = 'org.a11y.atspi.Accessible'
PROPERTIES = 'org.freedesktop.DBus.Properties'


def collect_tree(bus, reference, visited=None):
    import dbus
    visited = set() if visited is None else visited
    service, path = map(str, reference)
    key = service, path
    if key in visited or path == '/org/a11y/atspi/null':
        return None
    if len(visited) >= 10000:
        raise RuntimeError('Árbol AT-SPI excede 10000 nodos')
    visited.add(key)
    obj = bus.get_object(service, path, introspect=False)
    api = dbus.Interface(obj, ACCESSIBLE)
    props = dbus.Interface(obj, PROPERTIES).GetAll(ACCESSIBLE, timeout=5)
    node = dict(service=service, path=path, name=str(props.get('Name', '')),
                description=str(props.get('Description', '')), role=str(api.GetRoleName(timeout=5)),
                states=[int(n) for n in api.GetState(timeout=5)], children=[])
    node['interfaces'] = [str(name) for name in api.GetInterfaces(timeout=5)]
    if 'org.a11y.atspi.Action' in node['interfaces']:
        node['actions'] = [list(map(str, action)) for action in dbus.Interface(obj, 'org.a11y.atspi.Action').GetActions(timeout=5)]
    for child in api.GetChildren(timeout=5):
        value = collect_tree(bus, child, visited)
        if value is not None:
            node['children'].append(value)
    return node


def names(node):
    yield node['name']
    for child in node['children']:
        yield from names(child)


def snapshot(descriptor):
    import dbus
    env = json.loads(descriptor.read_text())['env']
    sid = env['SINGLR_SESSION_ID']
    if not sid.startswith('singlr-session-'):
        raise ValueError('Solo se admite session.json del runner privado')
    pids = resources['find_clients'](sid, 'singlr-shell')
    if len(pids) != 1:
        raise RuntimeError(f'Se esperaba un shell privado marcado; encontrados {pids}')
    session = dbus.bus.BusConnection(env['DBUS_SESSION_BUS_ADDRESS'])
    address = str(dbus.Interface(session.get_object('org.a11y.Bus', '/org/a11y/bus'),
                                 'org.a11y.Bus').GetAddress(timeout=5))
    bus = dbus.bus.BusConnection(address)
    daemon = dbus.Interface(bus.get_object('org.freedesktop.DBus', '/org/freedesktop/DBus'),
                            'org.freedesktop.DBus')
    registry = dbus.Interface(bus.get_object('org.a11y.atspi.Registry', '/org/a11y/atspi/accessible/root'), ACCESSIBLE)
    trees = []
    for reference in registry.GetChildren(timeout=5):
        pid = int(daemon.GetConnectionUnixProcessID(str(reference[0]), timeout=5))
        if pid == pids[0]:
            trees.append(collect_tree(bus, reference))
    if not trees:
        raise RuntimeError('Shell ausente del registro AT-SPI; arrancar con QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1')
    return dict(session_id=sid, pid=pids[0], trees=trees)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session-file', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--expect', action='append', default=[], help='Nombre accesible requerido, repetible')
    args = parser.parse_args()
    report = dict(status='FAIL', errors=[])
    try:
        report.update(snapshot(args.session_file))
        found = {name for tree in report['trees'] for name in names(tree)}
        missing = set(args.expect) - found
        if missing:
            raise RuntimeError('Faltan nombres accesibles: ' + ', '.join(sorted(missing)))
        report['status'] = 'PASS'
    except Exception as error:
        report['errors'].append(f'{type(error).__name__}: {error}')
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print(report['status'], *report['errors'])
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())

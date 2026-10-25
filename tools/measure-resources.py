#!/usr/bin/env python3
"""Measure marked private shell sessions, or explicit existing user session PIDs (Linux)."""
import argparse
import hashlib
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import runpy
import signal
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
runtime = runpy.run_path(str(HERE / 'session-runtime.py'))
# Reuse the same private-bus KWin scripting contract and environment as e2e.
e2e = runpy.run_path(str(ROOT / 'tests/shell/e2e.py'))
PSS_LIMIT = 120_000_000  # MB decimal, strict < per P-016 / T230
CPU_LIMIT = 0.5


def parse_stat(text):
    """Fields after the FINAL ')' allow spaces and ')' in Linux comm."""
    fields = text.rsplit(')', 1)[1].split()
    return dict(state=fields[0], ticks=int(fields[11]) + int(fields[12]),
                threads=int(fields[17]), starttime=int(fields[19]))


def parse_rollup(text):
    result = {}
    for line in text.splitlines():
        key, sep, value = line.partition(':')
        if sep and key in ('Rss', 'Pss', 'Pss_Anon', 'Pss_File', 'Pss_Shmem'):
            amount, unit = value.split()
            if unit != 'kB' or int(amount) < 0:
                raise ValueError('smaps_rollup: unidad/valor inválido')
            result[key] = int(amount) * 1024
    if not {'Rss', 'Pss'} <= result.keys():
        raise ValueError('smaps_rollup incompleto: requiere Rss y Pss')
    return result


def parse_schedstat(text):
    fields = text.split()
    if len(fields) != 3 or any(int(f) < 0 for f in fields):
        raise ValueError('schedstat inválido')
    return dict(runtime_ns=int(fields[0]), wait_ns=int(fields[1]), timeslices=int(fields[2]))


def matches_environment(data, session_id):
    return f'SINGLR_SESSION_ID={session_id}'.encode() in data.split(b'\0')


def find_clients(session_id, name, proc=Path('/proc')):
    found = []
    for directory in proc.iterdir():
        if not directory.name.isdigit():
            continue
        try:
            if (matches_environment((directory / 'environ').read_bytes(), session_id)
                    and (directory / 'comm').read_text().strip() == name
                    and parse_stat((directory / 'stat').read_text())['state'] != 'Z'):
                found.append(int(directory.name))
        except (OSError, ValueError, IndexError):
            pass  # Process exit/other user's process; target absence fails at caller.
    return sorted(found)


def snapshot(pid, session_id):
    base = Path('/proc') / str(pid)
    if session_id is not None and not matches_environment((base / 'environ').read_bytes(), session_id):
        raise RuntimeError(f'PID {pid} ya no pertenece a esta sesión')
    before = parse_stat((base / 'stat').read_text())
    memory = parse_rollup((base / 'smaps_rollup').read_text())
    schedule = {}
    try:
        for task in (base / 'task').iterdir():
            schedule[task.name] = parse_schedstat((task / 'schedstat').read_text())
    except (OSError, ValueError):
        schedule = None
    after = parse_stat((base / 'stat').read_text())
    if before['starttime'] != after['starttime'] or after['state'] == 'Z':
        raise RuntimeError(f'Proceso {pid} terminó o cambió de identidad')
    return dict(pid=pid, **after, memory=memory, schedule=schedule, sampled_at=time.monotonic())


def cpu_percent(before, after, seconds, hz):
    if before['starttime'] != after['starttime'] or after['ticks'] < before['ticks']:
        raise RuntimeError('PID reutilizado o contador CPU regresivo')
    if seconds <= 0 or hz <= 0:
        raise ValueError('Intervalo y CLK_TCK deben ser positivos')
    return (after['ticks'] - before['ticks']) / hz / seconds * 100


def idle_wait(seconds, process):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if process is not None and process.poll() is not None:
            raise RuntimeError('Sesión terminada durante la medida')
        time.sleep(min(0.2, max(0, deadline - time.monotonic())))


def call(env, method):
    result = subprocess.run(['qdbus6', 'org.kde.plasmashell', '/PlasmaShell',
                             'org.kde.PlasmaShell.' + method], env=env,
                            capture_output=True, text=True, timeout=5)
    if result.returncode:
        raise RuntimeError(f'{method}: {result.stderr.strip()}')


def windows(env, folder, log, pids):
    return [w for w in e2e['kwin_snapshot'](env, folder, log) if w['pid'] in pids]


def visible_count(items):
    return sum(not w['hidden'] and w['width'] > 0 and w['height'] > 0 for w in items)


def measure(pids, phase, process, env, folder, log):
    # Scripting happens before/after, never within the CPU sample.
    owned = windows(env, folder, log, pids) if env.get('SINGLR_SESSION_ID') else []
    before = {pid: snapshot(pid, env.get('SINGLR_SESSION_ID')) for pid in pids}
    idle_wait(30, process)
    after = {pid: snapshot(pid, env.get('SINGLR_SESSION_ID')) for pid in pids}
    rows = []
    for pid in pids:
        a, b = before[pid], after[pid]
        elapsed = b['sampled_at'] - a['sampled_at']
        cpu = cpu_percent(a, b, elapsed, os.sysconf('SC_CLK_TCK'))
        timeslices = None
        if a['schedule'] is not None and b['schedule'] is not None and a['schedule'].keys() == b['schedule'].keys():
            deltas = [b['schedule'][tid]['timeslices'] - a['schedule'][tid]['timeslices'] for tid in a['schedule']]
            if all(d >= 0 for d in deltas):
                timeslices = sum(deltas)
        rows.append(dict(phase=phase, pid=pid, name=Path(f'/proc/{pid}/comm').read_text().strip(),
                         pss_bytes=b['memory']['Pss'], pss_anon_bytes=b['memory'].get('Pss_Anon'),
                         pss_file_bytes=b['memory'].get('Pss_File'), pss_shmem_bytes=b['memory'].get('Pss_Shmem'),
                         rss_bytes=b['memory']['Rss'], threads=b['threads'], cpu_percent=cpu,
                         interval_seconds=elapsed, scheduler_timeslices=timeslices, wakeups=None,
                         windows=[w for w in owned if w['pid'] == pid] if env.get('SINGLR_SESSION_ID') else None,
                         window_count=sum(w['pid'] == pid for w in owned) if env.get('SINGLR_SESSION_ID') else None,
                         budget=budget_result(Path(f'/proc/{pid}/comm').read_text().strip(), phase, b['memory']['Pss'], cpu)))
    return rows


def budget_result(name, phase, pss, cpu):
    # P-016 caps the shell, not arbitrary auxiliary processes. CPU while a panel
    # is in use is recorded without applying the idle-only threshold.
    shell = name in ('singlr-shell', 'plasmashell', 'krunner')
    idle = phase in ('idle', 'after-close', 'idle-late-krunner')
    return 'FAIL' if (shell and pss >= PSS_LIMIT) or (idle and cpu >= CPU_LIMIT) else 'PASS'


def validate_selected_pids(pids):
    allowed = {'singlr-shell', 'plasmashell', 'krunner', 'ksmserver', 'kscreenlocker_g'}
    if len(set(pids)) != len(pids):
        raise ValueError('PID repetido: no sumar un proceso dos veces')
    for pid in pids:
        base = Path('/proc') / str(pid)
        if base.stat().st_uid != os.getuid() or (base / 'comm').read_text().strip() not in allowed:
            raise ValueError(f'PID {pid}: se requiere un proceso de shell/sesión del usuario actual')


def run_session(kind, args, folder):
    folder.mkdir()
    log_path = folder / 'session.log'
    process = None
    sid = None
    rows = []
    try:
        with log_path.open('w') as log:
            env = os.environ.copy()
            # Reproducible primary measure; opt in explicitly for profile overhead.
            env['SINGLR_PROFILE'] = '1' if args.profile else '0'
            if args.wallpaper:
                env['SINGLR_TEST_WALLPAPER'] = str(args.wallpaper)
            env.pop('SINGLR_DURATION_MS', None)
            process = subprocess.Popen([str(HERE / 'run-singlr.sh'), '--client', kind, '--size', args.size],
                                       env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            def descriptor_path():
                for line in log_path.read_text().splitlines():
                    if line.startswith('SINGLR_SESSION_FILE='):
                        path = Path(line.split('=', 1)[1])
                        if path.exists():
                            return path
            descriptor = e2e['wait_for'](descriptor_path, process, 60)
            data = json.loads(descriptor.read_text())
            sid = data['env']['SINGLR_SESSION_ID']
            env = e2e['session_environment'](data)
            name = 'singlr-shell' if kind == 'singlr' else 'plasmashell'
            pids = e2e['wait_for'](lambda: find_clients(sid, name), process, 30)
            if len(pids) != 1:
                raise RuntimeError(f'Se esperaba un {name}, encontrados {pids}')
            idle_wait(20, process)
            # krunner is measured only if Plasma activated it in this private session.
            pids += find_clients(sid, 'krunner') if kind == 'plasma' else []
            pids += find_clients(sid, 'ksmserver')
            pids += find_clients(sid, 'kscreenlocker_g')
            (folder / 'session-components.json').write_text(json.dumps({
                'ksmserver_pids': find_clients(sid, 'ksmserver'),
                'lockscreen_pids': find_clients(sid, 'kscreenlocker_g'),
                'note': 'Ausencia en este bus privado no mide el coste de la sesión instalada. Klipper y Singlr.System forman parte del PSS del shell.'}, indent=2))
            rows += measure(pids, 'idle', process, env, folder, log_path)
            (folder / 'samples.json').write_text(json.dumps(rows, indent=2))
            if kind == 'plasma':
                late = sorted(set(find_clients(sid, 'krunner')) - set(pids))
                if late:
                    idle_wait(20, process)
                    rows += measure(late, 'idle-late-krunner', process, env, folder, log_path)
                    (folder / 'samples.json').write_text(json.dumps(rows, indent=2))
            if args.scenario == 'open-panels' and kind == 'singlr':
                baseline = visible_count(windows(env, folder, log_path, pids))
                for method in ('toggleLauncher', 'toggleControlCenter', 'toggleNotifications', 'toggleClipboard'):
                    call(env, method)
                    idle_wait(2, process)
                    opened = windows(env, folder, log_path, pids)
                    (folder / f'{method}-open.json').write_text(json.dumps(opened, indent=2))
                    if visible_count(opened) <= baseline:
                        raise RuntimeError(f'{method}: panel no visible en KWin')
                    rows += measure(pids, 'open-' + method, process, env, folder, log_path)
                    (folder / 'samples.json').write_text(json.dumps(rows, indent=2))
                    call(env, method)
                    idle_wait(2, process)
                    closed = windows(env, folder, log_path, pids)
                    if visible_count(closed) != baseline:
                        raise RuntimeError(f'{method}: panel no cerrado en KWin')
                idle_wait(20, process)
                rows += measure(pids, 'after-close', process, env, folder, log_path)
                initial = {row['pid']: row['pss_bytes'] for row in rows if row['phase'] == 'idle'}
                for row in rows:
                    if row['phase'] == 'after-close':
                        row['pss_delta_bytes'] = row['pss_bytes'] - initial[row['pid']]
                (folder / 'samples.json').write_text(json.dumps(rows, indent=2))
            if args.profile and kind == 'singlr':
                call(env, 'singlrProfile')
    finally:
        if process:
            if process.poll() is None:
                process.send_signal(signal.SIGTERM)
                try:
                    process.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    runtime['stop'](process)
                    raise RuntimeError('Timeout de limpieza: revisar session.log')
            if process.returncode not in (0, 130):
                raise RuntimeError(f'Sesión falló (exit={process.returncode}); {log_path}')
            residual = runtime['marked_processes'](sid) if sid else set()
            if residual or 'equal=True' not in log_path.read_text():
                raise RuntimeError(f'Limpieza/configuración host no verificada: {sorted(residual)}; {log_path}')
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--existing-pid', type=int, action='append', default=[], help='Muestra de solo lectura de PID explícitos del usuario (repetible); no inicia ni controla sesiones')
    parser.add_argument('--phase', choices=('idle', 'open-panels', 'after-close'), default='idle', help='Etiqueta para --existing-pid; preparar los paneles manualmente antes')
    parser.add_argument('--compare-plasma', action='store_true')
    parser.add_argument('--scenario', choices=('idle', 'open-panels'), default='idle')
    parser.add_argument('--profile', action='store_true', help='SINGLR_PROFILE=1; añade coste diagnóstico')
    parser.add_argument('--size', default='2048x1280')
    parser.add_argument('--wallpaper', type=Path, help='imagen local para la configuración privada de Singlr')
    parser.add_argument('--output', type=Path, default=Path('/tmp') / datetime.now().strftime('singlr-resources-%Y%m%d-%H%M%S'))
    args = parser.parse_args()
    if args.existing_pid and (args.compare_plasma or args.scenario != 'idle' or args.profile):
        parser.error('--existing-pid no inicia escenarios ni compara sesiones automáticamente')
    if args.wallpaper:
        args.wallpaper = args.wallpaper.resolve()
        if not args.wallpaper.is_file():
            parser.error('--wallpaper debe ser una imagen local existente')
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error('--output debe ser nuevo o vacío')
    output.mkdir(parents=True, exist_ok=True)
    report = dict(schema=1, timestamp=datetime.now(timezone.utc).isoformat(),
                  environment=dict(kernel=platform.release(), machine=platform.machine(),
                                   cpu=platform.processor(), size=args.size, profile=args.profile,
                                   locale={k: v for k, v in os.environ.items() if k.startswith('LC_') or k in ('LANG', 'LANGUAGE')},
                                   clk_tck=os.sysconf('SC_CLK_TCK')),
                  scenario=args.phase if args.existing_pid else args.scenario, budget=dict(pss_bytes_lt=PSS_LIMIT, cpu_percent_lt=CPU_LIMIT),
                  notes=['CPU: 100% = un núcleo lógico; 30 s de muestra. Sesiones nuevas: 20 s de reposo; existing-pid: preparar reposo manualmente.',
                         'schedstat timeslices NO son despertares; wakeups=null (no expuesto).',
                         'KWin enumera superficies mapeadas; ventanas Qt ocultas: log --profile.',
                         'Plasma limpio; krunner solo si se activa. open-panels se aplica a Singlr.',
                         'PSS excluye KWin y memoria GPU no mapeada; ksmserver se mide por separado si existe.',
                         'Klipper y Singlr.System están incluidos en el proceso del shell, sin PSS independiente.',
                         'existing-pid: selección explícita, 30 s de muestra, sin control de paneles ni snapshot KWin.'],
                  results=[], errors=[])
    if args.wallpaper:
        report['environment']['wallpaper'] = dict(path=str(args.wallpaper),
            sha256=hashlib.sha256(args.wallpaper.read_bytes()).hexdigest())
    try:
        for command in (['kwin_wayland', '--version'], ['plasmashell', '--version'], ['pkg-config', '--modversion', 'Qt6Quick']):
            result = subprocess.run(command, capture_output=True, text=True, timeout=10)
            report['environment'][command[0]] = (result.stdout + result.stderr).strip()
        report['environment']['cpuinfo'] = Path('/proc/cpuinfo').read_text().split('\n\n', 1)[0]
        if args.existing_pid:
            validate_selected_pids(args.existing_pid)
            report['results'] += measure(args.existing_pid, args.phase, None, {}, output, None)
        else:
            build = subprocess.run([str(ROOT / 'shell/session/build.sh')], capture_output=True, text=True)
            (output / 'build.log').write_text(build.stdout + build.stderr)
            if build.returncode:
                raise RuntimeError('Compilación fallida: ver build.log')
            for kind in ('singlr', 'plasma') if args.compare_plasma else ('singlr',):
                print(f'Midiendo {kind}: escenario={args.scenario}…', file=sys.stderr, flush=True)
                report['results'] += run_session(kind, args, output / kind)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        report['errors'].append(str(error) or type(error).__name__)
    report['status'] = 'PASS' if report['results'] and not report['errors'] and all(r['budget'] == 'PASS' for r in report['results']) else 'FAIL'
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    table = ['Proceso | Fase | PSS MB | anon MB | file MB | RSS MB | Hilos | CPU % | Ventanas | Turnos | Presupuesto',
             '--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---']
    def mb(value):
        return 'N/D' if value is None else f'{value / 1_000_000:.2f}'
    for r in report['results']:
        table.append(f"{r['name']} | {r['phase']} | {mb(r['pss_bytes'])} | {mb(r['pss_anon_bytes'])} | {mb(r['pss_file_bytes'])} | {mb(r['rss_bytes'])} | {r['threads']} | {r['cpu_percent']:.3f} | {r['window_count'] if r['window_count'] is not None else 'N/D'} | {r['scheduler_timeslices']} | {r['budget']}")
    table += ['', report['status'], *report['errors']]
    (output / 'results.md').write_text('\n'.join(table) + '\n')
    print('\n'.join(table))
    print(f'JSON: {output / "results.json"}')
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())

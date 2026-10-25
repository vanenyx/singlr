"""T214: kded agent takeover/restore with fake commands; never touches the host."""
import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
loader = importlib.machinery.SourceFileLoader('singlr_live', str(ROOT / 'tools/singlr-live.py'))
spec = importlib.util.spec_from_loader(loader.name, loader)
live = importlib.util.module_from_spec(spec)
loader.exec_module(live)


class LiveSecretsTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix='singlr-live-test-')
        self.addCleanup(tmp.cleanup)
        self.state = Path(tmp.name)
        for name, value in {'STATE': self.state, 'PLASMA_MARK': self.state / 'plasma-stopped',
                            'NETWORK_MARK': self.state / 'networkmanagement-unloaded',
                            'PIDFILE': self.state / 'supervisor.pid'}.items():
            patcher = patch.object(live, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_exact_module_command(self):
        with patch.object(live.subprocess, 'run') as run:
            live.network_module('unload')
            run.assert_called_once_with(['qdbus6', 'org.kde.kded6', '/kded',
                                         'org.kde.kded6.unloadModule', 'networkmanagement'],
                                        capture_output=True, text=True)

    def test_restore_and_failed_restore_keeps_retry_marker(self):
        live.NETWORK_MARK.touch()
        with patch.object(live, 'network_module', return_value=subprocess.CompletedProcess([], 0, 'false\n', '')):
            live.restore_plasma()
            self.assertTrue(live.NETWORK_MARK.exists())
        with patch.object(live, 'network_module', return_value=subprocess.CompletedProcess([], 0, 'true\n', '')) as module:
            live.restore_plasma()
            module.assert_called_once_with('load')
            self.assertFalse(live.NETWORK_MARK.exists())

    def test_missing_qdbus_does_not_prevent_plasma_restore(self):
        live.NETWORK_MARK.touch()
        live.PLASMA_MARK.touch()
        with patch.object(live, 'network_module', side_effect=FileNotFoundError), patch.object(live, 'plasma') as plasma:
            live.restore_plasma()
            self.assertEqual([call.args for call in plasma.call_args_list], [('reset-failed',), ('start',)])
            self.assertTrue(live.NETWORK_MARK.exists())
            self.assertFalse(live.PLASMA_MARK.exists())

    def test_start_takeover_and_stop_restore(self):
        commands = []

        def run(args, **_):
            commands.append(args)
            return subprocess.CompletedProcess(args, 0, 'true\n' if args[0] == 'qdbus6' else 'active\n', '')

        with patch.object(live, 'running', return_value=None), \
             patch.dict(live.os.environ, {'WAYLAND_DISPLAY': 'test-only'}), \
             patch.object(live.subprocess, 'run', side_effect=run), \
             patch.object(live.os, 'fork', return_value=123), patch.object(live.time, 'sleep'), \
             patch('sys.argv', ['singlr-live.py', 'start']):
            self.assertEqual(live.main(), 0)
            self.assertEqual(commands[0], ['qdbus6', 'org.kde.kded6', '/kded',
                                           'org.kde.kded6.unloadModule', 'networkmanagement'])
            self.assertTrue(live.NETWORK_MARK.exists())
            self.assertTrue(live.PLASMA_MARK.exists())
            with patch('sys.argv', ['singlr-live.py', 'stop']):
                self.assertEqual(live.main(), 0)
            self.assertFalse(live.NETWORK_MARK.exists())
            self.assertFalse(live.PLASMA_MARK.exists())
            self.assertIn(['qdbus6', 'org.kde.kded6', '/kded', 'org.kde.kded6.loadModule', 'networkmanagement'], commands)

    def test_keep_plasma_does_not_unload(self):
        with patch.object(live, 'running', return_value=None), \
             patch.dict(live.os.environ, {'WAYLAND_DISPLAY': 'test-only'}), \
             patch.object(live.os, 'fork', return_value=123), patch.object(live.time, 'sleep'), \
             patch.object(live.subprocess, 'run', side_effect=AssertionError('unexpected command')), \
             patch('sys.argv', ['singlr-live.py', 'start', '--keep-plasma']):
            self.assertEqual(live.main(), 0)
            self.assertFalse(live.NETWORK_MARK.exists())

    def test_fork_failure_restores_modules(self):
        with patch.object(live, 'running', return_value=None), \
             patch.dict(live.os.environ, {'WAYLAND_DISPLAY': 'test-only'}), \
             patch.object(live, 'network_module', return_value=subprocess.CompletedProcess([], 0, 'true\n', '')) as module, \
             patch.object(live, 'plasma', return_value=subprocess.CompletedProcess([], 0, 'active\n', '')), \
             patch.object(live.subprocess, 'run'), patch.object(live.os, 'fork', side_effect=OSError('fixture')), \
             patch('sys.argv', ['singlr-live.py', 'start']):
            with self.assertRaises(OSError):
                live.main()
            self.assertEqual([call.args for call in module.call_args_list], [('unload',), ('load',)])
            self.assertFalse(live.NETWORK_MARK.exists())
            self.assertFalse(live.PLASMA_MARK.exists())

    def test_supervisor_error_stops_agent_before_restoring_kde(self):
        live.PIDFILE.write_text('123')
        events = []
        shell = Mock()
        shell.poll.return_value = None
        shell.terminate.side_effect = lambda: events.append('terminate')
        shell.wait.side_effect = [subprocess.TimeoutExpired('fixture', 3), None]
        shell.kill.side_effect = lambda: events.append('kill')
        with patch.object(live.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '/tmp/fake-shell\n', '')), \
             patch.object(live.subprocess, 'Popen', return_value=shell), \
             patch.object(live, 'LOG', self.state / 'shell.log'), \
             patch.object(live.signal, 'signal'), patch.object(live.time, 'sleep'), \
             patch.object(live, 'snapshot', side_effect=[{}, RuntimeError('fixture')]), \
             patch.object(live, 'restore_plasma', side_effect=lambda: events.append('restore')):
            with self.assertRaises(RuntimeError):
                live.supervise(True)
            self.assertEqual(events, ['terminate', 'kill', 'restore'])
            self.assertFalse(live.PIDFILE.exists())


if __name__ == '__main__':
    unittest.main()

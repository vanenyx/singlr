"""Recovery fallback uses the headless launcher and retains failed backups."""
import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
loader = importlib.machinery.SourceFileLoader('live_shortcuts', str(ROOT / 'tools/singlr-live.py'))
spec = importlib.util.spec_from_loader(loader.name, loader)
live = importlib.util.module_from_spec(spec)
loader.exec_module(live)


class LiveShortcutsTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix='singlr-live-shortcuts-')
        self.addCleanup(tmp.cleanup)
        self.state = Path(tmp.name)
        patcher = patch.object(live, 'STATE', self.state)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.backup = self.state / 'shortcuts-backup.json'

    def test_no_backup_needs_no_command(self):
        with patch.object(live.subprocess, 'run') as run:
            self.assertTrue(live.restore_shortcuts())
            run.assert_not_called()

    def test_restores_with_headless_mode(self):
        self.backup.write_text('{}')
        commands = []

        def run(command, **kwargs):
            commands.append(command)
            if '--restore-shortcuts' in command:
                self.backup.unlink()
                return subprocess.CompletedProcess(command, 0, '', '')
            return subprocess.CompletedProcess(command, 0, '/tmp/fake-launcher\n', '')

        with patch.object(live.subprocess, 'run', side_effect=run):
            self.assertTrue(live.restore_shortcuts())
        self.assertEqual(commands[-1], ['/tmp/fake-launcher', '--restore-shortcuts'])
        self.assertFalse(self.backup.exists())

    def test_failed_restore_keeps_backup_for_retry(self):
        self.backup.write_text('{}')
        for error in (False, True):
            with self.subTest(build_error=error):
                with patch.object(live.subprocess, 'run', side_effect=(
                        FileNotFoundError('fixture') if error else [
                            subprocess.CompletedProcess([], 0, '/tmp/fake-launcher\n', ''),
                            subprocess.CompletedProcess([], 1, '', 'unavailable')])):
                    self.assertFalse(live.restore_shortcuts())
                    self.assertTrue(self.backup.exists())


if __name__ == '__main__':
    unittest.main()

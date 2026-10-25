"""Infrastructure checks; these never claim a real login/session was tested."""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]

def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module

doctor = load('doctor', ROOT / 'tools/singlr-doctor')
audit = load('audit', ROOT / 'tests/session/home-audit.py')
real = load('real', ROOT / 'tests/session/real-session.py')


class Tools(unittest.TestCase):
    def test_report_does_not_echo_free_text(self):
        secret = '/home/alice/private-document SSID=private token=secret'
        def fake(*args):
            if args[0] == 'journalctl':
                return 0, json.dumps({'MESSAGE': secret + ' QML TypeError', 'PRIORITY': '4',
                                      '__REALTIME_TIMESTAMP': '123', '_HOSTNAME': secret})
            return 0, secret
        with patch.object(doctor, 'command', fake):
            data = doctor.report()
        self.assertNotIn(secret, json.dumps(data))
        self.assertEqual(data['recent_errors']['counts'], {'qml': 1})
        self.assertIsNone(data['versions']['kwin'])

    def test_unavailable_is_not_healthy(self):
        with patch.object(doctor, 'command', return_value=(127, '')):
            data = doctor.report()
        self.assertFalse(data['units']['singlr-shell.service']['available'])
        self.assertFalse(data['recent_errors']['available'])

    def test_audit_detects_restoration_failure(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {'XDG_CONFIG_HOME': tmp, 'XDG_STATE_HOME': tmp, 'XDG_RUNTIME_DIR': tmp}):
            p = Path(tmp) / 'kwinrc'
            p.write_text('[Plugins]\nscaleEnabled=false\n')
            before = audit.snapshot()
            p.write_text('[Plugins]\nscaleEnabled=true\n')
            after = audit.snapshot()
            self.assertFalse(audit.compare(before, after)['restoration_pass'])
            p.write_text('[Plugins]\nscaleEnabled=false\n')
            self.assertTrue(audit.compare(before, audit.snapshot())['restoration_pass'])
            self.assertNotIn('scaleEnabled=false', json.dumps(before))

    def test_refuses_foreign_session_before_any_action(self):
        with patch.dict(os.environ, {'XDG_CURRENT_DESKTOP': 'KDE'}), patch.object(real, 'run') as command:
            with self.assertRaises(RuntimeError):
                real.startup()
            command.assert_not_called()

    def test_private_evidence_never_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'report.json'
            real.save(p, {'result': 'FAIL'})
            self.assertEqual(p.stat().st_mode & 0o777, 0o600)
            with self.assertRaises(FileExistsError):
                real.save(p, {})

    def test_output_restore_preserves_geometry_and_mode(self):
        output = {'id': 2, 'currentModeId': '42', 'pos': {'x': 1920, 'y': 0},
                  'scale': 1.25, 'rotation': 2}
        args = real.restore_outputs([output])
        self.assertIn('output.2.position.1920,0', args)
        self.assertIn('output.2.scale.1.25', args)
        self.assertIn('output.2.mode.42', args)
        self.assertIn('output.2.rotation.left', args)
        with self.assertRaises(KeyError):
            real.restore_outputs([{'id': 2}])

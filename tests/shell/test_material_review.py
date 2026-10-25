"""The review helper must reject host profiles before invoking any desktop tool."""
import json
import os
from pathlib import Path
import runpy
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
environment = runpy.run_path(str(ROOT / 'tools/material-review.py'))['environment']


class ReviewEnvironmentTests(unittest.TestCase):
    def test_only_private_marked_profiles(self):
        with tempfile.TemporaryDirectory(prefix='singlr-session-review-') as temp:
            base = Path(temp)
            env = {'SINGLR_SESSION_ID': base.name, 'DBUS_SESSION_BUS_ADDRESS': 'unix:path=' + temp + '/bus'}
            for key in ('XDG_CONFIG_HOME', 'XDG_STATE_HOME', 'XDG_RUNTIME_DIR'):
                env[key] = str(base / key)
            descriptor = base / 'session.json'
            data = dict(kind='singlr-nested-v1', pid=os.getpid(), env=env)
            descriptor.write_text(json.dumps(data)); descriptor.chmod(0o600)
            self.assertEqual(environment(descriptor)['XDG_CONFIG_HOME'], env['XDG_CONFIG_HOME'])
            env['XDG_CONFIG_HOME'] = str(Path.home() / '.config')
            descriptor.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, 'perfil desechable'):
                environment(descriptor)
            descriptor.chmod(0o644)
            with self.assertRaisesRegex(ValueError, 'Descriptor privado'):
                environment(descriptor)


if __name__ == '__main__':
    unittest.main()

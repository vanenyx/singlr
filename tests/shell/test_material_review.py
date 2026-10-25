"""The review helper must reject host profiles before invoking any desktop tool."""
import json
import os
from pathlib import Path
import runpy
import tempfile
import unittest
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[2]
review = runpy.run_path(str(ROOT / 'tools/material-review.py'))
environment = review['environment']


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

    def test_crop_uses_content_region_not_fullscreen_launcher(self):
        diagnostic = {'windows': [
            dict(eligible=True, visible=True, region=[0, 0, 2048, 28], position=[0, 0]),
            dict(eligible=True, visible=True, region=[0, 0, 200, 48], position=[924, 1222]),
            dict(eligible=True, visible=True, region=[664, 286, 720, 490], position=[0, 0]),
            dict(eligible=False, visible=True, region=[0, 0, 340, 560], position=[1692, 36])
        ]}
        self.assertEqual(review['panel_edge'](diagnostic, 'launcher'), [652, 274, 256, 96])
        self.assertEqual(review['panel_edge'](diagnostic, 'dock'), [912, 1210, 200, 48])
        with self.assertRaisesRegex(RuntimeError, 'No hay región'):
            review['panel_edge'](diagnostic, 'control-center')

    def test_clipboard_opens_its_endpoint_and_uses_its_own_region(self):
        from unittest.mock import patch
        calls = []
        with patch('time.sleep'):
            review['open_surface'](lambda *args: calls.append(args), 'clipboard')
        self.assertTrue(calls[-1][-1].endswith('.toggleClipboard'))
        diagnostic = {'windows': [
            dict(eligible=True, visible=True, region=[664,286,720,490], position=[0,0]),
            dict(eligible=True, visible=True, region=[0,0,760,542], position=[640,300])
        ]}
        self.assertEqual(review['panel_edge'](diagnostic, 'clipboard'), [628,288,256,96])

    def test_crop_maps_logical_geometry_to_spectacle_pixels(self):
        diagnostic = dict(screenCount=1, virtualGeometry=[0, 0, 2048, 1280])
        source = ROOT / 'tests/shell/evidence/t248/nested/cc-liquid.png'
        self.assertEqual(review['pixel_edge']([652, 274, 256, 96], diagnostic, source), [815, 342, 320, 121])
        diagnostic['screenCount'] = 2
        with self.assertRaisesRegex(RuntimeError, 'una salida'):
            review['pixel_edge']([652, 274, 256, 96], diagnostic, source)

    @unittest.skipUnless((ROOT / 'build/singlr-material-image').is_file(), 'Build Qt crop helper first')
    def test_qimage_crop_zoom_and_bounds(self):
        source = ROOT / 'tests/shell/evidence/t248/nested/cc-liquid.png'
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'crop.png'
            command = [str(ROOT / 'build/singlr-material-image'), str(source), str(output)]
            subprocess.run([*command, '1680', '24', '20', '10', '4'], check=True)
            self.assertEqual(struct.unpack('>II', output.read_bytes()[16:24]), (80, 40))
            output.unlink()
            failed = subprocess.run([*command, '99999', '0', '20', '10', '4'], capture_output=True)
            self.assertNotEqual(failed.returncode, 0)
            self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()

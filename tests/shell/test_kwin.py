"""KWin transaction recovery, entirely in temporary state/config directories."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('kwin_test_module', ROOT / 'session/singlr_kwin.py')
kwin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kwin)


class KWinTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        patcher = patch.dict(os.environ, {'XDG_CONFIG_HOME': str(Path(tmp.name) / 'config')})
        patcher.start(); self.addCleanup(patcher.stop)
        self.backup = Path(tmp.name) / 'state/kwinrc-backup.json'
        self.values = {(g, k): 'previous' for g, k, _ in kwin.KWIN_SETTINGS}
        self.values[('Effect-singlrliquidglass', 'Enabled')] = ''
        self.values.pop(('Plugins', 'singlr-liquidglassEnabled'))
        self.original = self.values.copy()
        self.writes = []
        for name, function in [('read', lambda g, k: self.values.get((g, k))), ('write', self.write)]:
            patcher = patch.object(kwin, name, side_effect=function)
            patcher.start()
            self.addCleanup(patcher.stop)

    def write(self, group, key, value):
        self.writes.append((group, key, value))
        if value is None:
            self.values.pop((group, key), None)
        else:
            self.values[group, key] = value

    def test_journal_from_before_native_decoration_restores_the_original_decoration(self):
        # P-023: Singlr no longer applies its Aurorae theme, but a journal written while it
        # did must still put the user's original decoration back.
        legacy = [[g, k, self.values.get((g, k))] for g, k, _ in kwin.KWIN_SETTINGS]
        legacy += [['org.kde.kdecoration2', 'library', 'org.kde.breeze'], ['org.kde.kdecoration2', 'theme', 'Breeze']]
        self.backup.parent.mkdir(parents=True, exist_ok=True)
        self.backup.write_text(__import__("json").dumps(legacy))
        self.backup.chmod(0o600)
        self.values[('org.kde.kdecoration2', 'library')] = 'org.kde.kwin.aurorae'
        self.assertTrue(kwin.restore(self.backup))
        self.assertEqual(self.values[('org.kde.kdecoration2', 'library')], 'org.kde.breeze')
        self.assertEqual(self.values[('org.kde.kdecoration2', 'theme')], 'Breeze')

    def test_backup_precedes_first_write_and_roundtrip_preserves_absent_and_empty(self):
        def write(group, key, value):
            self.assertTrue(self.backup.exists())
            self.assertEqual(self.backup.stat().st_mode & 0o777, 0o600)
            self.write(group, key, value)
        with patch.object(kwin, 'write', side_effect=write):
            self.assertTrue(kwin.apply(self.backup))
        self.assertEqual(self.values, {(g, k): v for g, k, v in kwin.KWIN_SETTINGS})
        self.assertTrue(kwin.restore(self.backup))
        self.assertEqual(self.values, self.original)
        self.assertFalse(self.backup.exists())

    def test_material_preferences_are_session_only_and_recoverable(self):
        config = Path(os.environ['XDG_CONFIG_HOME']) / 'singlr/singlr.conf'
        config.parent.mkdir(parents=True)
        config.write_text('[Appearance]\nmaterial=liquid\nintensity=81\n')
        kwin.apply(self.backup)
        self.assertEqual(self.values[('Effect-singlrliquidglass', 'Enabled')], 'true')
        self.assertEqual(self.values[('Effect-singlrliquidglass', 'Intensity')], '81')
        kwin.restore(self.backup)
        self.assertEqual(self.values, self.original)

        config.write_text('[Appearance]\nmaterial=liquid\nintensity=81\n[Accessibility]\nreduceTransparency=true\n')
        kwin.apply(self.backup)
        self.assertEqual(self.values[('Effect-singlrliquidglass', 'Enabled')], 'false')
        kwin.restore(self.backup)
        self.assertEqual(self.values, self.original)

    def test_all_accepted_legacy_versions_restore_exactly_before_new_material_snapshot(self):
        previous = kwin.MATERIAL_KEYS | kwin.WORKSPACE_KEYS
        legacy = {pair for pair in previous if pair[0] != 'TabBox'}
        for base in (previous, legacy, previous - kwin.MATERIAL_KEYS, legacy - kwin.MATERIAL_KEYS):
            for edges in (set(), kwin.OVERVIEW_EDGE_KEYS):
                for gestures in (set(), kwin.GESTURE_KEYS):
                    for decoration in (set(), kwin.DECORATION_KEYS):
                        keys = (base - edges - gestures) | decoration
                        for recover in (False, True):
                            with self.subTest(keys=keys, recover=recover):
                                originals = [[g, k, (None, '', 'custom')[i % 3]]
                                             for i, (g, k) in enumerate(sorted(keys))]
                                self.values = {(g, k): 'singlr-applied' for g, k in keys}
                                expected = {(g, k): v for g, k, v in originals if v is not None}
                                self.backup.parent.mkdir(exist_ok=True)
                                self.backup.write_text(json.dumps(originals))
                                self.writes.clear()
                                if recover:
                                    kwin.apply(self.backup, recover_pending=True)
                                    self.assertEqual(self.writes[:len(originals)], [tuple(row) for row in originals])
                                    journal = json.loads(self.backup.read_text())
                                    self.assertEqual({(g, k) for g, k, _ in journal}, kwin.MATERIAL_KEYS)
                                    for g, k, v in journal:
                                        self.assertEqual(v, expected.get((g, k)))
                                    kwin.restore(self.backup)
                                else:
                                    kwin.restore(self.backup)
                                self.assertEqual(self.values, expected)
                                self.assertFalse(self.backup.exists())

    def test_new_journal_only_material_leaves_workspace_preferences_untouched(self):
        for i, pair in enumerate(sorted(kwin.RETIRED_KEYS)):
            if i % 3:
                self.values[pair] = '' if i % 3 == 1 else 'custom'
        before = self.values.copy()
        kwin.apply(self.backup)
        self.assertEqual({(g, k) for g, k, _ in json.loads(self.backup.read_text())}, kwin.MATERIAL_KEYS)
        self.assertTrue(all((g, k) in kwin.MATERIAL_KEYS for g, k, _ in self.writes))
        kwin.restore(self.backup)
        self.assertEqual(self.values, before)

    def test_reload_retires_extensions_and_leaves_kde_effects_to_reconfigure(self):
        for applying in (True, False):
            with patch.object(kwin.subprocess, 'run') as run:
                kwin.reload_kwin(applying=applying)
            calls = [call.args[0][2:] for call in run.call_args_list]
            self.assertIn(['/KWin', 'reconfigure'], calls)
            self.assertFalse(any(c[-1] in ('overview', 'windowview') for c in calls))
            if applying:
                self.assertIn(['/Effects', 'org.kde.kwin.Effects.unloadEffect', kwin.RETIRED_EFFECT], calls)
                self.assertIn(['/Scripting', 'org.kde.kwin.Scripting.unloadScript', kwin.RETIRED_SCRIPT], calls)

    def test_desktop_layout_is_not_changed(self):
        self.values[('Desktops', 'Rows')] = '2'
        kwin.apply(self.backup)
        self.assertEqual(self.values[('Desktops', 'Rows')], '2')
        kwin.restore(self.backup)
        self.assertEqual(self.values[('Desktops', 'Rows')], '2')
        self.assertFalse(any((g, k) == ('Desktops', 'Rows') for g, k, _ in self.writes))

    def test_malformed_material_preferences_do_not_prevent_login(self):
        config = Path(os.environ['XDG_CONFIG_HOME']) / 'singlr/singlr.conf'
        config.parent.mkdir(parents=True)
        config.write_text('invalid preference file')
        self.assertTrue(kwin.apply(self.backup))
        self.assertEqual(self.values[('Effect-singlrliquidglass', 'Enabled')], 'true')
        self.assertEqual(self.values[('Effect-singlrliquidglass', 'Intensity')], '65')
        kwin.restore(self.backup)
        self.assertEqual(self.values, self.original)
        self.assertEqual(config.read_text(), 'invalid preference file')

    def test_existing_glass_journal_keeps_legacy_keys_reversible(self):
        self.values[('Effect-singlrliquidglass', 'Enabled')] = 'false'
        self.values[('Effect-singlrliquidglass', 'Intensity')] = '81'
        original = self.values.copy()
        self.backup.parent.mkdir()
        self.backup.write_text(json.dumps([[g, k, self.values.get((g, k))]
                                          for g, k, _ in kwin.KWIN_SETTINGS]))
        self.assertTrue(kwin.apply(self.backup, recover_pending=True))
        self.assertEqual(self.values[('Effect-singlrliquidglass', 'Enabled')], 'true')
        self.assertTrue(kwin.restore(self.backup))
        self.assertEqual(self.values, original)

    def test_apply_and_restore_are_idempotent(self):
        kwin.apply(self.backup)
        snapshot = self.backup.read_bytes()
        writes = self.writes.copy()
        self.assertFalse(kwin.apply(self.backup))
        self.assertEqual(self.backup.read_bytes(), snapshot)
        self.assertEqual(self.writes, writes)
        kwin.restore(self.backup)
        writes = self.writes.copy()
        self.assertFalse(kwin.restore(self.backup))
        self.assertEqual(self.writes, writes)

    def test_pending_restore_before_new_snapshot_after_partial_apply(self):
        kwin.apply(self.backup)
        # Model a crash partway through applying: some keys still have old values.
        self.values[('Effect-singlrliquidglass', 'Intensity')] = self.original[('Effect-singlrliquidglass', 'Intensity')]
        kwin.apply(self.backup, recover_pending=True)
        journal = {(g, k): v for g, k, v in json.loads(self.backup.read_text())}
        self.assertEqual(journal, {(g, k): self.original.get((g, k)) for g, k, _ in kwin.KWIN_SETTINGS})
        kwin.restore(self.backup)
        self.assertEqual(self.values, self.original)

    def test_failed_restore_retains_original_journal_then_retry_succeeds(self):
        kwin.apply(self.backup)
        snapshot = self.backup.read_bytes()
        with patch.object(kwin, 'write', side_effect=OSError('read-only')):
            with self.assertRaises(OSError):
                kwin.apply(self.backup, recover_pending=True)
        self.assertEqual(snapshot, self.backup.read_bytes())
        kwin.restore(self.backup)
        self.assertEqual(self.values, self.original)

    def test_failed_apply_rolls_back(self):
        def write(group, key, value):
            if (group, key, value) == kwin.KWIN_SETTINGS[1]:
                raise OSError('write failed')
            self.write(group, key, value)
        with patch.object(kwin, 'write', side_effect=write):
            with self.assertRaises(OSError):
                kwin.apply(self.backup)
        self.assertEqual(self.values, self.original)
        self.assertFalse(self.backup.exists())

    def test_invalid_journal_is_preserved_without_writes(self):
        self.backup.parent.mkdir()
        for content in ('{broken', '[["foreign", "key", "value"]]'):
            self.backup.write_text(content)
            with self.assertRaises(ValueError):
                kwin.apply(self.backup, recover_pending=True)
            self.assertEqual(self.backup.read_text(), content)
            self.assertEqual(self.writes, [])

    def test_duplicate_journal_is_rejected(self):
        self.backup.parent.mkdir()
        entry = list(kwin.KWIN_SETTINGS[0])
        self.backup.write_text(json.dumps([entry, entry]))
        with self.assertRaises(ValueError):
            kwin.restore(self.backup)
        self.assertEqual(self.writes, [])

    def test_backup_failure_does_not_modify_config(self):
        with patch.object(kwin, 'save', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                kwin.apply(self.backup)
        self.assertEqual(self.writes, [])


@unittest.skipUnless(shutil.which('kreadconfig6') and shutil.which('kwriteconfig6'), 'requires KConfig tools')
class KConfigTests(unittest.TestCase):
    def test_real_cli_roundtrip_and_offline_recovery(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {'XDG_CONFIG_HOME': str(Path(tmp) / 'config'),
                   'XDG_CONFIG_DIRS': str(Path(tmp) / 'defaults'),
                   'XDG_STATE_HOME': str(Path(tmp) / 'state')}
            with patch.dict(os.environ, env):
                kwin.write('org.kde.kdecoration2', 'theme', '')
                kwin.write('Plugins', 'scaleEnabled', 'false')
                self.assertEqual(kwin.read('org.kde.kdecoration2', 'theme'), '')
                self.assertTrue(kwin.apply())
                for effect in ('overviewEnabled', 'windowviewEnabled'):
                    self.assertIsNone(kwin.read('Plugins', effect))
                self.assertIsNone(kwin.read('Effect-overview', 'BorderActivate'))
                # New process models recovery after the original process disappeared.
                subprocess.run([str(ROOT / 'session/singlr-kwin'), '--restore', '--offline'],
                               check=True, env=os.environ | {'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent'})
                self.assertEqual(kwin.read('Plugins', 'scaleEnabled'), 'false')
                self.assertEqual(kwin.read('org.kde.kdecoration2', 'theme'), '')
                self.assertFalse(kwin.backup_path().exists())
                for effect in ('overviewEnabled', 'windowviewEnabled'):
                    self.assertIsNone(kwin.read('Plugins', effect))
                self.assertIsNone(kwin.read('Effect-overview', 'BorderActivate'))
                kwin.write('Effect-overview', 'BorderActivate', '1,7,3')
                kwin.apply()
                self.assertEqual(kwin.read('Effect-overview', 'BorderActivate'), '1,7,3')
                kwin.restore()
                self.assertEqual(kwin.read('Effect-overview', 'BorderActivate'), '1,7,3')


if __name__ == '__main__':
    unittest.main()

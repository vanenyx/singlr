"""Synthetic /proc tests; these do not measure shell performance."""
from pathlib import Path
import runpy
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
m = runpy.run_path(str(ROOT / 'tools/measure-resources.py'))


def stat_text(comm='singlr-shell', start=12345):
    fields = ['0'] * 50
    fields[0] = 'S'
    fields[11], fields[12] = '101', '23'
    fields[13], fields[14] = '9999', '9999'  # children must not enter process CPU
    fields[17], fields[19] = '8', str(start)
    return f'42 ({comm}) ' + ' '.join(fields)


class ProcTests(unittest.TestCase):
    def test_stat_spaces_and_parentheses(self):
        value = m['parse_stat'](stat_text('a ) b ( c)'))
        self.assertEqual(value, dict(state='S', ticks=124, threads=8, starttime=12345))

    def test_truncated_stat_fails(self):
        with self.assertRaises((IndexError, ValueError)):
            m['parse_stat']('42 (shell) S 1')

    def test_rollup_bytes_and_optional_breakdown(self):
        value = m['parse_rollup']('1000-2000 ---p [rollup]\nRss: 4096 kB\nPss: 2048 kB\nPss_Anon: 1024 kB\nPss_File: 1000 kB\nPss_Shmem: 24 kB\nSwapPss: 10 kB\n')
        self.assertEqual(value, dict(Rss=4194304, Pss=2097152, Pss_Anon=1048576, Pss_File=1024000, Pss_Shmem=24576))
        self.assertNotIn('Pss_Anon', m['parse_rollup']('Rss: 1 kB\nPss: 1 kB\n'))

    def test_rollup_missing_invalid_units_and_negative(self):
        for text in ('Rss: 1 kB', 'Rss: 1 MB\nPss: 1 kB', 'Rss: -1 kB\nPss: 1 kB'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                m['parse_rollup'](text)

    def test_schedstat_timeslices_not_wakeups(self):
        self.assertEqual(m['parse_schedstat']('120000 20000 42\n'),
                         dict(runtime_ns=120000, wait_ns=20000, timeslices=42))
        self.assertEqual(m['parse_schedstat']('0 0 0')['timeslices'], 0)
        for text in ('1 2', '1 2 3 4', '1 -1 2', 'a b c'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                m['parse_schedstat'](text)

    def test_cpu_one_core_and_pid_reuse(self):
        before = dict(ticks=100, starttime=5)
        after = dict(ticks=115, starttime=5)
        self.assertAlmostEqual(m['cpu_percent'](before, after, 30, 100), 0.5)
        self.assertEqual(m['cpu_percent'](before, dict(ticks=3100, starttime=5), 30, 100), 100)
        for value in (dict(ticks=115, starttime=6), dict(ticks=99, starttime=5)):
            with self.assertRaises(RuntimeError):
                m['cpu_percent'](before, value, 30, 100)

    def test_budget_distinguishes_open_cpu_and_auxiliary_pss(self):
        budget = m['budget_result']
        self.assertEqual(budget('singlr-shell', 'idle', 119_999_999, 0.49), 'PASS')
        self.assertEqual(budget('singlr-shell', 'idle', 120_000_000, 0), 'FAIL')
        self.assertEqual(budget('singlr-shell', 'idle', 80_000_000, 0.5), 'FAIL')
        self.assertEqual(budget('singlr-shell', 'open-toggleLauncher', 80_000_000, 2), 'PASS')
        self.assertEqual(budget('ksmserver', 'idle', 121_000_000, 0), 'PASS')
        self.assertEqual(budget('ksmserver', 'idle', 20_000_000, 0.5), 'FAIL')

    def test_explicit_pid_does_not_accept_unrelated_process(self):
        import os
        with self.assertRaises(ValueError):
            m['validate_selected_pids']([os.getpid()])
        with self.assertRaises(ValueError):
            m['validate_selected_pids']([os.getpid(), os.getpid()])

    def test_exact_environment_and_comm_and_zombies(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            for pid, sid, name, state in ((1, 'target', 'singlr-shell', 'S'),
                    (2, 'target-other', 'singlr-shell', 'S'), (3, 'target', 'kwin_wayland', 'S'),
                    (4, 'target', 'singlr-shell', 'Z'), (5, 'target', 'singlr-shell', 'S')):
                path = base / str(pid)
                path.mkdir()
                (path / 'environ').write_bytes(f'OTHER=x\0SINGLR_SESSION_ID={sid}\0'.encode())
                (path / 'comm').write_text(name + '\n')
                (path / 'stat').write_text(stat_text().replace(') S ', f') {state} '))
            (base / '5/environ').unlink()  # race or permission error
            self.assertEqual(m['find_clients']('target', 'singlr-shell', base), [1])
        self.assertFalse(m['matches_environment'](b'X=SINGLR_SESSION_ID=target\0', 'target'))


if __name__ == '__main__':
    unittest.main()

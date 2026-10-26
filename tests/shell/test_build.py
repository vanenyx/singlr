"""Exercise the real native compiler cache in a disposable build directory."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('g++') and shutil.which('pkg-config'), 'requires g++ and pkg-config')
class BuildTests(unittest.TestCase):
    def test_incremental_dependencies_flags_lock_and_failure(self):
        with tempfile.TemporaryDirectory(prefix='singlr-build-test-') as directory:
            base = Path(directory)
            header = base / 'dependency.h'
            header.write_text('// first version\n')
            counter = base / 'calls'
            wrapper = base / 'compiler'
            wrapper.write_text('#!/usr/bin/env python3\nimport os,sys\n'
                               'from pathlib import Path\n'
                               'with Path(os.environ["BUILD_CALLS"]).open("a") as f: f.write("compile\\n")\n'
                               'os.execvp("g++", ["g++", *sys.argv[1:]])\n')
            wrapper.chmod(0o755)
            env = os.environ | {'CXX': str(wrapper), 'SINGLR_BUILD_DIR': str(base / 'build'),
                                'BUILD_CALLS': str(counter), 'CXXFLAGS': '-include ' + str(header)}
            command = [str(ROOT / 'shell/session/build.sh')]
            def build(environment=env):
                result = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), str(base / 'build/singlr-shell'))
                return result
            # Two initial callers must serialize and share one compilation.
            first = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            second = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            for proc in (first, second):
                stdout, stderr = proc.communicate(timeout=30)
                self.assertEqual(proc.returncode, 0, stderr)
            self.assertEqual(len(counter.read_text().splitlines()), 1)
            binary = base / 'build/singlr-shell'
            mtime = binary.stat().st_mtime_ns
            build()
            self.assertEqual(binary.stat().st_mtime_ns, mtime)
            self.assertEqual(len(counter.read_text().splitlines()), 1)
            header.write_text('// updated header; must invalidate dependencies\n')
            build()
            self.assertEqual(len(counter.read_text().splitlines()), 2)
            env['CXXFLAGS'] += ' -DT204_CACHE_CHECK=1'
            build()
            self.assertEqual(len(counter.read_text().splitlines()), 3)
            state = json.loads((base / 'build/state.json').read_text())
            self.assertIn(str(header), state['deps'])
            self.assertTrue(any('/qt6/' in dep for dep in state['deps']))
            for source in ('main.cpp',
                           'tray.cpp', 'tray.h', 'trayformat.cpp', 'trayformat.h', 'system.cpp', 'system.h'):
                self.assertIn(str(ROOT / 'shell/session/src' / source), state['deps'])
            self.assertFalse(any('/.compile-' in dep for dep in state['deps']))
            mtime = binary.stat().st_mtime_ns
            failure = subprocess.run(command, env=env | {'CXXFLAGS': '-include no_such_t204_header.h'},
                                     capture_output=True, text=True, timeout=30)
            self.assertNotEqual(failure.returncode, 0)
            self.assertIn('SINGLR_BUILD_ERROR', failure.stderr)
            self.assertIn('cabeceras Qt6 y LayerShellQt/Shell', failure.stderr)
            self.assertEqual(failure.stdout, '')
            self.assertEqual(binary.stat().st_mtime_ns, mtime)
            # A failed compile must leave the last valid cache usable.
            build()
            self.assertEqual(len(counter.read_text().splitlines()), 4)


if __name__ == '__main__':
    unittest.main()

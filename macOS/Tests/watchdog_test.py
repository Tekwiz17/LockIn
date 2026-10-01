"""Run the actual embedded shell watchdog with simulated macOS commands/clock.

This tests deadline/relaunch/quoting behavior, not launchd or AppKit integration.
"""
from pathlib import Path
import json, os, re, subprocess, tempfile, unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'MacApp/NuclearWatchdog.swift').read_text()
SCRIPT = re.search(r'static let scriptSource = #"""\n(.*?)\n    """#', SOURCE, re.S).group(1)
SCRIPT = '\n'.join(line[4:] if line.startswith('    ') else line for line in SCRIPT.splitlines()) + '\n'


class WatchdogTests(unittest.TestCase):
    def run_watchdog(self, deadline='104', alive=False, pid='1234', app_exists=True):
        with tempfile.TemporaryDirectory(prefix='lockin-watchdog-') as temp:
            folder = Path(temp)
            # These characters must remain data throughout shell argument handling.
            app = folder / 'LockIn space $(touch INJECTED).app'
            if app_exists: app.mkdir()
            plist = folder / 'agent.plist'; plist.write_text('test')
            pidfile = folder / 'app.pid'; pidfile.write_text(pid)
            (folder / 'clock').write_text('100')
            (folder / 'running').write_text('yes' if alive else 'no')
            executable = folder / 'command'
            executable.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root=Path(os.environ['LOCKIN_TEST_ROOT'])
action=sys.argv[1]; args=sys.argv[2:]
if action=='date': print((root/'clock').read_text())
elif action=='sleep':
    (root/'clock').write_text(str(int((root/'clock').read_text())+2))
elif action=='kill': sys.exit(0 if (root/'running').read_text()=='yes' else 1)
elif action=='ps': print(os.environ['LOCKIN_TEST_APP']+'/Contents/MacOS/LockIn')
elif action=='open':
    with (root/'opens').open('a') as file: file.write(json.dumps(args)+'\\n')
    (root/'running').write_text('yes'); (root/'app.pid').write_text('5678')
''')
            executable.chmod(0o700)
            script = SCRIPT
            for name in ['date', 'sleep', 'kill', 'ps']:
                script = script.replace('/bin/' + name, f'"{executable}" {name}')
            script = script.replace('/usr/bin/open', f'"{executable}" open')
            file = folder / 'watchdog.sh'; file.write_text(script)
            subprocess.run(['/bin/sh', '-n', str(file)], check=True)
            env = {**os.environ, 'LOCKIN_TEST_ROOT': str(folder), 'LOCKIN_TEST_APP': str(app)}
            result = subprocess.run(['/bin/sh', str(file), deadline, str(app), str(plist), str(pidfile)],
                                    env=env, cwd=folder, capture_output=True, timeout=5)
            opens = [json.loads(line) for line in (folder / 'opens').read_text().splitlines()] if (folder / 'opens').exists() else []
            return result, opens, plist.exists(), (folder / 'INJECTED').exists(), str(app)

    def test_alive_app_does_not_relaunch_and_agent_file_expires(self):
        result, opens, exists, _, _ = self.run_watchdog(alive=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(opens, [])
        self.assertFalse(exists)

    def test_closed_app_relaunches_once_with_literal_path(self):
        result, opens, exists, injected, app = self.run_watchdog()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(opens, [['-g', app, '--args', '--nuclear-background']])
        self.assertFalse(exists)
        self.assertFalse(injected)

    def test_expired_deadline_never_relaunches(self):
        result, opens, exists, _, _ = self.run_watchdog(deadline='99')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(opens, [])
        self.assertFalse(exists)

    def test_invalid_deadline_does_not_launch(self):
        result, opens, _, _, _ = self.run_watchdog(deadline='bad')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(opens, [])

    def test_corrupt_pid_recovers_without_shell_injection(self):
        result, opens, _, injected, _ = self.run_watchdog(pid='$(touch INJECTED)')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(opens), 1)
        self.assertFalse(injected)

    def test_missing_app_does_not_spin_launches(self):
        result, opens, exists, _, _ = self.run_watchdog(app_exists=False)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(opens, [])
        self.assertFalse(exists)


if __name__ == '__main__': unittest.main(verbosity=2)

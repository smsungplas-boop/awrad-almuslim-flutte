#!/usr/bin/env python3
"""Exercise CI SDK setup control flow without downloading Android packages."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().with_name('setup_android_ci.sh')
MOCK = '''#!/usr/bin/env python3
import json, os, pathlib, sys
root = pathlib.Path(os.environ['ANDROID_HOME'])
with (root / 'calls.jsonl').open('a') as f:
    f.write(json.dumps(sys.argv[1:]) + '\\n')
if '--licenses' in sys.argv:
    answers = sys.stdin.read()
    if answers and not all(v == 'y' for v in answers.splitlines()):
        sys.exit(9)
    if os.environ.get('MOCK_MODE') == 'unaccepted':
        print('7 of 8 SDK package licenses not accepted.')
    else:
        print('All SDK package licenses accepted.')
elif os.environ.get('MOCK_MODE') == 'install-failure':
    sys.exit(17)
else:
    for p in ['platform-tools', 'platforms/android-35', 'build-tools/35.0.0', 'ndk/26.3.11579264']:
        d = root / p
        d.mkdir(parents=True, exist_ok=True)
        (d / 'source.properties').touch()
'''


class AndroidSetupTests(unittest.TestCase):
    def run_setup(self, mode='success'):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sdk = root / 'sdk'
            sdk.mkdir()
            manager = root / 'sdkmanager'
            manager.write_text(MOCK)
            manager.chmod(0o755)
            env = os.environ.copy()
            env.update(ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk),
                       PATH=f'{root}{os.pathsep}{env["PATH"]}', MOCK_MODE=mode)
            result = subprocess.run(['bash', str(SCRIPT)], env=env,
                                    capture_output=True, text=True, timeout=15)
            calls = [json.loads(line) for line in (sdk / 'calls.jsonl').read_text().splitlines()]
            return result, calls

    def test_only_required_packages_and_license_verification(self):
        result, calls = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum('--licenses' in c for c in calls), 3)
        packages = [c[1:] for c in calls if '--licenses' not in c]
        self.assertEqual(packages, [['platform-tools', 'platforms;android-35',
                                    'build-tools;35.0.0', 'ndk;26.3.11579264']])

    def test_zero_exit_with_unaccepted_licenses_still_fails(self):
        result, calls = self.run_setup('unaccepted')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('licenses remain unaccepted', result.stderr)
        self.assertTrue(all('--licenses' in c for c in calls))

    def test_install_failure_is_not_hidden(self):
        result, _ = self.run_setup('install-failure')
        self.assertEqual(result.returncode, 17)


if __name__ == '__main__':
    unittest.main()

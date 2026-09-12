"""Offline updater regression tests; all files and injected tools are temporary."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'dictup.sh'
OLD = '기본:舊\n\n###DKST\n내단어:사용자값\n'
NEW = '기본:新\n\n###DKST\n원격:제외할값\n'


class DictionaryUpdaterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.target = self.root / 'data' / 'hanja.txt'
        self.target.parent.mkdir()
        self.target.write_text(OLD)
        self.remote = self.root / 'remote.txt'
        self.remote.write_text(NEW)
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'],
                        DKST_DICTIONARY_PATH=str(self.target), MOCK_REMOTE=str(self.remote))
        self.tool('curl', '''while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then shift; /bin/cat "$MOCK_REMOTE" > "$1"; exit 0; fi
  shift
done
exit 1
''')

    def tool(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/bash\n' + body)
        path.chmod(0o755)

    def run_update(self):
        return subprocess.run(['/bin/bash', str(SCRIPT)], env=self.env,
                              text=True, capture_output=True)

    def assert_failure_preserves_dictionary(self):
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('Dictionary update successful!', result.stdout)
        self.assertEqual(self.target.read_text(), OLD)
        self.assertEqual(list(self.target.parent.glob('.hanja.*')), [])

    def test_success_preserves_user_entries_and_replaces_file(self):
        old_inode = self.target.stat().st_ino
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('기본:新', self.target.read_text())
        self.assertIn('내단어:사용자값', self.target.read_text())
        self.assertNotIn('원격:', self.target.read_text())
        self.assertNotEqual(old_inode, self.target.stat().st_ino)
        self.assertEqual(list(self.target.parent.glob('.hanja.*')), [])

    def test_download_failure(self):
        self.tool('curl', 'exit 22\n')
        self.assert_failure_preserves_dictionary()

    def test_empty_download(self):
        self.remote.write_text('')
        self.assert_failure_preserves_dictionary()

    def test_partial_copy_failure(self):
        self.tool('cp', 'printf "partial" > "$2"\nexit 1\n')
        self.assert_failure_preserves_dictionary()

    def test_rename_failure(self):
        self.tool('mv', 'case "$1" in *.tmp) exec /bin/mv "$@" ;; esac\nexit 1\n')
        self.assert_failure_preserves_dictionary()

    def test_destination_parent_is_file(self):
        blocker = self.root / 'blocker'
        blocker.write_text('unchanged')
        self.env['DKST_DICTIONARY_PATH'] = str(blocker / 'hanja.txt')
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Dictionary update successful!', result.stdout)
        self.assertEqual(blocker.read_text(), 'unchanged')

    def test_destination_is_directory(self):
        self.env['DKST_DICTIONARY_PATH'] = str(self.target.parent)
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Dictionary update successful!', result.stdout)
        self.assertEqual(self.target.read_text(), OLD)

    def test_new_install_without_remote_separator(self):
        self.target.unlink()
        self.remote.write_text('기본:新\n')
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([line for line in self.target.read_text().splitlines() if line],
                         ['기본:新', '###DKST'])


if __name__ == '__main__':
    unittest.main()

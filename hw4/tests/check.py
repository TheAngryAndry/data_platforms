"""Check deployment wiring without SSH or changes to the local system."""
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tarfile
import tempfile
from unittest.mock import patch

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as directory:
    tmp = Path(directory)
    # An isolated copy must work without hw1, hw2 or hw3 alongside it.
    hw4 = tmp / 'hw4'
    shutil.copytree(root, hw4)
    ssh = tmp / 'ssh'
    ssh.write_text('''#!/bin/bash
set -eu
command=${!#}
echo "$command" >> "$CHECK_DIR/calls"
if [[ $command == *'tar -xzf'* ]]; then
  cat > "$CHECK_DIR/upload.tar.gz"
fi
if [[ -n ${FAIL_STAGE:-} && $command == *"$FAIL_STAGE"* ]]; then exit 42; fi
''')
    ssh.chmod(0o755)
    env = dict(os.environ, PATH=f'{tmp}:{os.environ["PATH"]}', CHECK_DIR=str(tmp))
    for script in ('deploy.sh', 'deploy-spark.sh'):
        (tmp / 'calls').write_text('')
        subprocess.run(['bash', str(hw4 / 'scripts' / script)], env=env, check=True)
        calls = (tmp / 'calls').read_text().splitlines()
        assert all('hw4' in call and 'hw3' not in call for call in calls), calls
        if script == 'deploy.sh':
            assert len(calls) == 5, calls
            for call, stage in zip(calls[1:], ('deploy-hdfs-edge.sh', 'deploy-yarn-edge.sh',
                                              'deploy-hive-edge.sh', 'install-spark.sh')):
                assert stage in call, calls
        else:
            assert len(calls) == 2, calls
        assert 'run-spark.sh' in calls[-1], calls
        with tarfile.open(tmp / 'upload.tar.gz') as archive:
            names = set(archive.getnames())
        required = {str(p.relative_to(root)) for p in root.rglob('*') if p.is_file()
                    and p.parts[-2] != 'tests' and p.name != 'verification.txt'}
        assert required <= names, required - names
    (tmp / 'calls').write_text('')
    result = subprocess.run(['bash', str(hw4 / 'scripts/deploy.sh')],
                            env=dict(env, FAIL_STAGE='deploy-yarn-edge.sh'))
    assert result.returncode == 42
    assert len((tmp / 'calls').read_text().splitlines()) == 3

    # Hive can be active in systemd before its JDBC endpoint accepts queries.
    for command in ('sudo', 'ssh', 'sleep'):
        (tmp / command).write_text('#!/bin/bash\nexit 0\n')
        (tmp / command).chmod(0o755)
    (tmp / 'timeout').write_text('''#!/bin/bash
echo attempt >> "$CHECK_DIR/attempts"
[[ ${NEVER_READY:-} != 1 && $(wc -l < "$CHECK_DIR/attempts") -ge 2 ]]
''')
    (tmp / 'timeout').chmod(0o755)
    (hw4 / 'scripts/load-data.sh').write_text('touch "$CHECK_DIR/loaded"\n')
    subprocess.run(['bash', str(hw4 / 'scripts/deploy-hive-edge.sh')], env=env, check=True)
    assert (tmp / 'loaded').exists()
    assert len((tmp / 'attempts').read_text().splitlines()) == 2
    (tmp / 'loaded').unlink()
    (tmp / 'attempts').write_text('')
    result = subprocess.run(['bash', str(hw4 / 'scripts/deploy-hive-edge.sh')],
                            env=dict(env, NEVER_READY='1'), capture_output=True, text=True)
    assert result.returncode == 1 and 'did not become ready' in result.stderr
    assert not (tmp / 'loaded').exists()
    assert len((tmp / 'attempts').read_text().splitlines()) == 30

    hosts = tmp / 'hosts'
    hosts.write_text('127.0.0.1 localhost\n127.0.1.1 team-01-nn.hse.c.mws team-01-nn other\n'
                     '192.0.2.1 unrelated\n10.1.0.11 team-01-nn\n')
    with patch('pathlib.Path', return_value=hosts):
        runpy.run_path(str(root / 'scripts/configure-hosts.py'))
        first = hosts.read_text()
        runpy.run_path(str(root / 'scripts/configure-hosts.py'))
    assert hosts.read_text() == first
    assert '127.0.0.1 localhost\n' in first and '127.0.1.1\tother\n' in first
    assert '192.0.2.1 unrelated\n' in first
    entries = [line.split() for line in first.splitlines()]
    for name in ('team-01-nn', 'team-01-nn.hse.c.mws'):
        assert [row[0] for row in entries if name in row[1:]] == ['10.1.0.11']
print('PASS: standalone archives, deploy order, stop on failure, Hive readiness, hosts aliases and idempotence.')

#!/usr/bin/env python3
from pathlib import Path

# Hadoop RPC resolves the bind address back to a hostname. The VM image maps
# its own hostname to 127.0.1.1; all cluster aliases must resolve to the LAN.
nodes = {
    'team-01-en': '10.1.0.10',
    'team-01-nn': '10.1.0.11',
    'team-01-00': '10.1.0.12',
    'team-01-01': '10.1.0.13',
}
aliases = {alias for host in nodes for alias in (host, host + '.hse.c.mws')}
path = Path('/etc/hosts')
lines = []
for line in path.read_text().splitlines():
    fields = line.split('#', 1)[0].split()
    if len(fields) > 1 and aliases.intersection(fields[1:]):
        remaining = [name for name in fields[1:] if name not in aliases]
        if remaining:
            lines.append(fields[0] + '\t' + ' '.join(remaining))
    else:
        lines.append(line)
for host, address in nodes.items():
    lines.append(f'{address}\t{host} {host}.hse.c.mws')
path.write_text('\n'.join(lines) + '\n')

#!/usr/bin/env python3
"""Read-only telemetry, started only while the control centre is open."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


def cpu_sample():
    fields = list(map(int, Path('/proc/stat').read_text().splitlines()[0].split()[1:9]))
    return sum(fields), fields[3] + fields[4]


def cpu_percent(previous, current):
    total = current[0] - previous[0]
    idle = current[1] - previous[1]
    return round(max(0, min(100, (total - idle) * 100 / total))) if total > 0 else 0


def disk(label, path):
    if path != '/' and not os.path.ismount(path):
        return {'label': label, 'path': path, 'mounted': False}
    usage = shutil.disk_usage(path)
    return {'label': label, 'path': path, 'mounted': True,
            'used': usage.used, 'total': usage.total}


def snapshot(previous):
    current = cpu_sample()
    memory = {line.split(':')[0]: int(line.split()[1]) * 1024
              for line in Path('/proc/meminfo').read_text().splitlines()}
    result = {'cpu': cpu_percent(previous, current),
              'ramUsed': memory['MemTotal'] - memory['MemAvailable'],
              'ramTotal': memory['MemTotal'],
              'uptime': int(float(Path('/proc/uptime').read_text().split()[0])),
              'disks': [disk('System', '/')], 'gpu': None}
    if shutil.which('nvidia-smi'):
        try:
            values = subprocess.check_output(
                ['nvidia-smi', '--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu',
                 '--format=csv,noheader,nounits'], text=True, timeout=2, stderr=subprocess.DEVNULL)
            load, used, total, temperature = map(int, values.splitlines()[0].split(','))
            result['gpu'] = {'load': load, 'used': used, 'total': total, 'temperature': temperature}
        except (OSError, subprocess.SubprocessError, ValueError, IndexError):
            pass
    return result, current


if __name__ == '__main__':
    if '--check' in sys.argv:
        assert cpu_percent((100, 60), (200, 80)) == 80
        assert cpu_percent((100, 60), (100, 60)) == 0
        assert not disk('missing', '/this-mount-does-not-exist')['mounted']
        print('CPU deltas and missing disk handling: OK')
    else:
        previous = cpu_sample()
        time.sleep(0.2)
        while True:
            data, previous = snapshot(previous)
            print(json.dumps(data), flush=True)
            if '--once' in sys.argv:
                break
            time.sleep(2)

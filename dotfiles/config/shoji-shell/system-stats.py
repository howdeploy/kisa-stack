#!/usr/bin/env python3
"""Shared read-only telemetry for the control centre and desktop widgets."""
import json
import atexit
import ctypes
import os
from pathlib import Path
import select
import shutil
import subprocess
import sys
import time

import psutil


class GpuProcessSample(ctypes.Structure):
    _fields_ = [('pid', ctypes.c_uint), ('timestamp', ctypes.c_ulonglong),
                ('sm', ctypes.c_uint), ('memory', ctypes.c_uint),
                ('encoder', ctypes.c_uint), ('decoder', ctypes.c_uint)]


class GpuProcesses:
    def __init__(self):
        self.query = None
        self.cursor = 0
        self.primed = False
        self.device = ctypes.c_void_p()
        try:
            self.library = ctypes.CDLL('libnvidia-ml.so.1')
            init = self.library.nvmlInit_v2
            init.argtypes = []
            init.restype = ctypes.c_int
            handle = self.library.nvmlDeviceGetHandleByIndex_v2
            handle.argtypes = [ctypes.c_uint, ctypes.POINTER(ctypes.c_void_p)]
            handle.restype = ctypes.c_int
            query = self.library.nvmlDeviceGetProcessUtilization
            query.argtypes = [ctypes.c_void_p, ctypes.POINTER(GpuProcessSample),
                             ctypes.POINTER(ctypes.c_uint), ctypes.c_ulonglong]
            query.restype = ctypes.c_int
            shutdown = self.library.nvmlShutdown
            shutdown.argtypes = []
            shutdown.restype = ctypes.c_int
            if init() == 0:
                atexit.register(shutdown)
                # Match the first GPU already used by the shared system metrics.
                if handle(0, ctypes.byref(self.device)) == 0:
                    self.query = query
        except (OSError, AttributeError):
            pass

    def reset(self):
        self.cursor = 0
        self.primed = False

    def sample(self):
        if self.query is None:
            return None
        count = ctypes.c_uint()
        status = self.query(self.device, None, ctypes.byref(count), self.cursor)
        if status == 3:  # NVML_ERROR_NOT_SUPPORTED
            self.query = None
        if status not in (0, 7) or not 0 < count.value <= 8192:
            return None
        for _attempt in range(2):
            buffer = (GpuProcessSample * count.value)()
            status = self.query(self.device, buffer, ctypes.byref(count), self.cursor)
            if status != 7:  # The required buffer can grow between the two reads.
                break
            if not 0 < count.value <= 8192:
                return None
        if status != 0 or count.value > len(buffer):
            return None
        values = {}
        for sample in buffer[:count.value]:
            self.cursor = max(self.cursor, sample.timestamp)
            values.setdefault(sample.pid, []).append(sample.sm)
        if not self.primed:
            # Discard driver history captured before this widget was enabled.
            self.primed = True
            return None
        if not values:
            return None
        return {pid: sum(samples) / len(samples) if all(value <= 100 for value in samples) else None
                for pid, samples in values.items()}


class ProcessSampler:
    def __init__(self):
        self.previous = {}
        self.total = None
        self.hz = os.sysconf('SC_CLK_TCK')
        self.gpu = None
        self.scores = {}

    def reset(self):
        self.previous = {}
        self.total = None
        self.scores = {}
        if self.gpu is not None:
            self.gpu.reset()

    def sample(self, total, memory_total):
        records = {}
        attrs = ['pid', 'ppid', 'name', 'create_time', 'cpu_times', 'memory_info']
        for process in psutil.process_iter(attrs=attrs, ad_value=None):
            info = process.info
            if info['cpu_times'] is not None and info['memory_info'] is not None and info['create_time'] is not None:
                records[info['pid']] = info
        games = {}
        runtime = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
        for path in Path(runtime).glob('shoji-shell/game-fps/game-*/session.json'):
            try:
                game = json.loads(path.read_text())
                pid = int(game['pid'])
                stat = Path(f'/proc/{pid}/stat').read_text()
                if pid in records and stat[stat.rfind(')') + 2:].split()[19] == game['identity']:
                    games[pid] = str(game['appId'])
            except (OSError, ValueError, KeyError, TypeError, IndexError):
                continue

        agents = {'codex': ('Codex', 'session-codex'), 'claude': ('Claude', 'provider-claude'),
                  'kimi': ('Kimi', 'session-kimi'), 'opencode': ('OpenCode', 'applications'),
                  'hermes': ('Hermes', 'message-circle'), 'ollama': ('Ollama', 'home-gpu'),
                  'llama-server': ('llama-server', 'home-gpu')}
        applications = {'brave': 'Brave', 'chrome': 'Chrome', 'chromium': 'Chromium',
                        'firefox': 'Firefox', 'steam': 'Steam', 'steamwebhelper': 'Steam',
                        'quickshell': 'Quickshell', 'shoji_wm': 'ShojiWM', 'ghostty': 'Ghostty',
                        'telegram': 'Telegram', 'obs': 'OBS', 'discord': 'Discord'}

        def group_for(info):
            cursor = info['pid']
            seen = set()
            agent = None
            application = None
            while cursor in records and cursor not in seen:
                seen.add(cursor)
                if cursor in games:
                    app_id = games[cursor]
                    return f'game:{app_id}', 'Игра Steam', 'image', app_id
                name = (records[cursor]['name'] or '').lower()
                if agent is None:
                    for prefix, (label, icon) in agents.items():
                        if name == prefix or name.startswith(prefix + '-'):
                            agent = (prefix, label, icon, '')
                            break
                if application is None and name in applications:
                    label = applications[name]
                    application = (label.lower(), label, 'applications', '')
                cursor = records[cursor]['ppid']
            return agent or application or (info['name'], info['name'], 'applications', '')

        if self.gpu is None:
            self.gpu = GpuProcesses()
        gpu = self.gpu.sample()
        elapsed = total - self.total if self.total is not None else 0
        samples = {}
        groups = {}
        for info in records.values():
            identity = (info['pid'], info['create_time'])
            used = info['cpu_times'].user + info['cpu_times'].system
            samples[identity] = used
            delta = max(0, used - self.previous[identity]) if identity in self.previous else 0
            key, label, icon, app_id = group_for(info)
            group = groups.setdefault(key, {'key': key, 'name': label or str(info['pid']),
                                           'icon': icon, 'appId': app_id, 'cpu': 0,
                                           'gpu': 0 if gpu is not None else None, 'rss': 0, 'count': 0})
            group['cpu'] += delta * self.hz * 100 / elapsed if elapsed > 0 else 0
            if gpu is not None:
                value = gpu.get(info['pid'], 0)
                if value is None:
                    group['gpu'] = None
                elif group['gpu'] is not None:
                    group['gpu'] += value
            group['rss'] += info['memory_info'].rss
            group['count'] += 1
        self.previous, self.total = samples, total
        rows = [group for group in groups.values() if group['rss'] > 0 or group['cpu'] > 0 or (group['gpu'] or 0) > 0]
        scores = {}
        for group in rows:
            group['cpu'] = round(min(100, group['cpu']), 1) if elapsed > 0 else None
            if group['gpu'] is not None:
                group['gpu'] = round(min(100, group['gpu']), 1)
            available = [value for value in (group['cpu'], group['gpu'],
                         min(100, group['rss'] * 100 / memory_total) if memory_total > 0 else None)
                         if value is not None]
            average = sum(available) / len(available) if available else 0
            # Smooth ranking only; the CPU/GPU columns still show the current sample.
            group['score'] = average * 0.35 + self.scores.get(group['key'], average) * 0.65
            scores[group['key']] = group['score']
        self.scores = scores
        return {'ranked': sorted(rows, key=lambda row: (row['score'], row['rss']), reverse=True)[:6]}


def cpu_sample():
    fields = list(map(int, Path('/proc/stat').read_text().splitlines()[0].split()[1:9]))
    return sum(fields), fields[3] + fields[4]


def cpu_percent(previous, current):
    total = current[0] - previous[0]
    idle = current[1] - previous[1]
    return round(max(0, min(100, (total - idle) * 100 / total))) if total > 0 else 0


def cpu_temperature(hwmon=Path('/sys/class/hwmon')):
    for device in hwmon.glob('hwmon*'):
        try:
            if (device / 'name').read_text().strip() == 'k10temp':
                return int((device / 'temp1_input').read_text()) / 1000
        except (OSError, ValueError):
            continue
    return None


def disk(label, path):
    if path != '/' and not os.path.ismount(path):
        return {'label': label, 'path': path, 'mounted': False}
    usage = shutil.disk_usage(path)
    return {'label': label, 'path': path, 'mounted': True,
            'used': usage.used, 'total': usage.total}


def snapshot(previous, processes=None):
    current = cpu_sample()
    memory = {line.split(':')[0]: int(line.split()[1]) * 1024
              for line in Path('/proc/meminfo').read_text().splitlines()}
    result = {'cpu': cpu_percent(previous, current),
              'cpuTemperature': cpu_temperature(),
              'ramUsed': memory['MemTotal'] - memory['MemAvailable'],
              'ramTotal': memory['MemTotal'],
              'uptime': int(float(Path('/proc/uptime').read_text().split()[0])),
              'disks': [disk('System', '/')], 'gpu': None}
    if processes is not None:
        result['processes'] = processes.sample(current[0], memory['MemTotal'])
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
        from tempfile import TemporaryDirectory
        with TemporaryDirectory() as directory:
            hwmon = Path(directory)
            assert cpu_temperature(hwmon) is None
            device = hwmon / 'hwmon7'
            device.mkdir()
            (device / 'name').write_text('nvme\n')
            (device / 'temp1_input').write_text('33750\n')
            assert cpu_temperature(hwmon) is None
            (device / 'name').write_text('k10temp\n')
            assert cpu_temperature(hwmon) == 33.75
            (device / 'temp1_input').write_text('unavailable\n')
            assert cpu_temperature(hwmon) is None
        print('CPU deltas, temperature and missing disk handling: OK')
    else:
        previous = cpu_sample()
        processes = ProcessSampler()
        include_processes = '--processes' in sys.argv
        stdin_open = True
        pending = b''
        first = True
        time.sleep(0.2)
        while True:
            if stdin_open and select.select([sys.stdin], [], [], 0)[0]:
                chunk = os.read(sys.stdin.fileno(), 4096)
                stdin_open = bool(chunk)
                pending += chunk
                while b'\n' in pending:
                    line, pending = pending.split(b'\n', 1)
                    try:
                        request = json.loads(line)
                        if isinstance(request, dict) and isinstance(request.get('processes'), bool):
                            include_processes = request['processes']
                    except (ValueError, UnicodeDecodeError):
                        pass
            if not include_processes:
                processes.reset()
            data, previous = snapshot(previous, processes if include_processes else None)
            if first:
                data['telemetryReady'] = True
                first = False
            print(json.dumps(data), flush=True)
            if '--once' in sys.argv:
                break
            time.sleep(2)

#!/usr/bin/env python3
"""DDC/CI brightness for a named output. Writes only on an explicit UI action."""
import json
import math
import re
import subprocess
import sys


def run(*args):
    return subprocess.check_output(['ddcutil', *args], text=True, timeout=12,
                                   stderr=subprocess.DEVNULL)


def bus_for(connector, detection):
    for block in detection.split('\n\n'):
        bus = re.search(r'I2C bus:\s+/dev/i2c-(\d+)', block)
        drm = re.search(r'DRM connector:\s+(\S+)', block)
        if bus and drm and drm[1].endswith('-' + connector):
            return bus[1]
    raise ValueError('Монитор не найден через DDC/CI')


def brightness(output):
    match = re.search(r'^VCP 10 C (\d+) (\d+)$', output.strip(), re.MULTILINE)
    if not match or int(match[2]) <= 0:
        raise ValueError('Монитор не сообщает яркость')
    return int(match[1]), int(match[2])


def raw_level(percent, maximum):
    if not math.isfinite(percent) or not 0 <= percent <= 100:
        raise ValueError('Яркость должна быть от 0 до 100%')
    return round(percent * maximum / 100)


def main():
    mode, connector, *rest = sys.argv[1:]
    if mode not in ('get', 'set') or not re.fullmatch(r'[A-Za-z0-9-]+', connector):
        raise ValueError('Некорректный запрос яркости')
    bus = bus_for(connector, run('detect', '--brief'))
    current, maximum = brightness(run('--bus', bus, 'getvcp', '10', '--terse'))
    if mode == 'set':
        level = raw_level(float(rest[0]), maximum)
        run('--bus', bus, 'setvcp', '10', str(level))
        current, maximum = brightness(run('--bus', bus, 'getvcp', '10', '--terse'))
    return {'available': True, 'value': round(current * 100 / maximum), 'error': ''}


if __name__ == '__main__':
    if '--check' in sys.argv:
        assert brightness('VCP 10 C 75 150\n') == (75, 150)
        assert raw_level(50, 150) == 75
        assert bus_for('DP-1', 'Display 1\n I2C bus: /dev/i2c-4\n DRM connector: card1-DP-1\n') == '4'
        try:
            raw_level(float('nan'), 100)
        except ValueError:
            pass
        else:
            raise AssertionError('Non-finite brightness accepted')
        print('DDC parsing and range checks passed.')
    else:
        try:
            result = main()
        except (OSError, ValueError, IndexError, subprocess.SubprocessError) as error:
            result = {'available': False, 'value': 0, 'error': str(error) if isinstance(error, ValueError) else 'Нет доступа к DDC/CI'}
        print(json.dumps(result, ensure_ascii=False))

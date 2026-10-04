#!/usr/bin/env python3
"""Steam catalogue and a shell-owned Wallpaper Engine process. NDJSON over stdio."""
import fcntl
import json
import math
import os
from pathlib import Path
import re
import selectors
import signal
import socket
import subprocess
import sys
import time


def steam_libraries():
    home = Path.home()
    roots = [home / suffix for suffix in (
        '.local/share/Steam', '.steam/steam',
        '.var/app/com.valvesoftware.Steam/.local/share/Steam',
        'snap/steam/common/.local/share/Steam')]
    for root in list(roots):
        try:
            vdf = (root / 'steamapps/libraryfolders.vdf').read_text()
            for path in re.findall(r'"path"\s*"((?:\\.|[^"\\])*)"', vdf):
                roots.append(Path(path.replace('\\\\', '\\').replace('\\"', '"')))
        except OSError:
            pass
    return list(dict.fromkeys(root.resolve() for root in roots if root.is_dir()))


def catalogue():
    items = []
    assets = ''
    seen = set()
    for library in steam_libraries():
        base = library / 'steamapps/common/wallpaper_engine/assets'
        if not assets and base.is_dir():
            assets = str(base)
        workshop = library / 'steamapps/workshop/content/431960'
        if not workshop.is_dir():
            continue
        for folder in workshop.iterdir():
            if not folder.is_dir() or folder.resolve() in seen:
                continue
            seen.add(folder.resolve())
            try:
                project = json.loads((folder / 'project.json').read_text())
                kind = str(project.get('type', '')).lower()
                if kind not in ('scene', 'video', 'web'):
                    continue
                preview = (folder / str(project.get('preview', 'preview.jpg'))).resolve()
                image = preview.as_uri() if preview.is_relative_to(folder.resolve()) and preview.is_file() else ''
                if kind == 'video':
                    video = (folder / str(project.get('file', ''))).resolve()
                    if video.is_relative_to(folder.resolve()) and video.is_file():
                        image = video.as_uri()
                items.append(dict(path=str(folder.resolve()), title=str(project.get('title') or folder.name),
                                  preview=image, kind=kind, id=folder.name))
            except (OSError, ValueError, TypeError, AttributeError):
                continue
    return sorted(items, key=lambda item: item['title'].casefold()), assets


def compositor(method='wallpaper.outputs', params=None):
    path = Path(os.environ['XDG_RUNTIME_DIR']) / ('shojiwm-' + os.environ['WAYLAND_DISPLAY'] + '.sock')
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(2)
        connection.connect(str(path))
        connection.sendall((json.dumps(dict(id=1, method=method, params=params)) + '\n').encode())
        with connection.makefile('rb') as stream:
            for line in stream:
                reply = json.loads(line)
                if reply.get('id') == 1:
                    if 'error' in reply:
                        raise ValueError('Перезагрузи конфиг ShojiWM: Super+Shift+R')
                    return reply['result']
    raise OSError('ShojiWM не ответил')


def stop(process):
    if process is None:
        return
    # Only our own process group; never kill other Wallpaper Engine instances.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()


def retire(process, retiring):
    # Reap old renderers without blocking wave updates on decoder shutdown.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    retiring[process] = time.monotonic() + 3


def reap(retiring):
    for process, deadline in list(retiring.items()):
        if process.poll() is not None:
            del retiring[process]
        elif time.monotonic() >= deadline:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass


def ready_on_outputs(state, before, outputs):
    mapped = {layer['outputName'] for layer in state['layers']
              if layer['id'] not in before and layer['position']['width'] > 0
              and layer['position']['height'] > 0}
    return bool(outputs) and set(outputs).issubset(mapped)


def emit(event, **values):
    print(json.dumps(dict(event=event, **values), ensure_ascii=False), flush=True)


def crop_environment(selection):
    crop = selection.get('crop', dict(x=0.5, y=0, zoom=1))
    if not isinstance(crop, dict):
        raise ValueError('Некорректная область кадра')
    environment = os.environ.copy()
    for key, variable, low, high in (
        ('x', 'SHOJI_WALLPAPER_CROP_X', 0, 1),
        ('y', 'SHOJI_WALLPAPER_CROP_Y', 0, 1),
        ('zoom', 'SHOJI_WALLPAPER_ZOOM', 1, 3),
    ):
        value = crop.get(key)
        if type(value) not in (int, float) or not math.isfinite(value) or not low <= value <= high:
            raise ValueError('Некорректные настройки кадра')
        environment[variable] = str(value)
    return environment


def render_layers(selection, outputs, items, assets):
    if selection is None:
        return []
    if not isinstance(selection, dict):
        raise ValueError('Некорректный выбор обоев')
    layers = selection.get('layers', [dict(selection, outputs=outputs, visibleOutputs=outputs)])
    if not isinstance(layers, list) or len(layers) > len(outputs):
        raise ValueError('Некорректный набор экранов')
    result, occupied = [], set()
    for layer in layers:
        if not isinstance(layer, dict) or layer.get('mode') not in ('span', 'single'):
            raise ValueError('Неизвестный режим обоев')
        screens, visible = layer.get('outputs'), layer.get('visibleOutputs')
        if (not isinstance(screens, list) or not screens or not all(isinstance(s, str) for s in screens)
                or not set(screens).issubset(outputs) or len(set(screens)) != len(screens)
                or not isinstance(visible, list) or not visible or not all(isinstance(s, str) for s in visible)
                or not set(visible).issubset(screens) or occupied.intersection(visible)
                or (layer['mode'] == 'single' and len(screens) != 1)):
            raise ValueError('Некорректный набор экранов')
        occupied.update(visible)
        if layer.get('path') not in {item['path'] for item in items}:
            raise ValueError('Обои больше не найдены в библиотеке Steam')
        if not assets:
            raise ValueError('Не найдена папка assets установленного Wallpaper Engine')
        crop_environment(layer)
        result.append(layer)
    return result


def renderer_key(layer):
    # Visibility may shrink while an existing panoramic renderer keeps playing.
    return json.dumps({k: layer.get(k) for k in ('mode', 'outputs', 'path', 'crop')}, sort_keys=True)


def launch(layer, assets, logs):
    screens = layer['outputs']
    command = ['linux-wallpaperengine', '--layer', 'background', '--fps', '30',
               '--silent', '--disable-mouse', '--assets-dir', assets]
    command += (['--screen-span', ','.join(screens)] if len(screens) > 1 else ['--screen-root', screens[0]])
    command += ['--bg', layer['path'], '--scaling', 'fill', '--clamp', 'border']
    with (logs / 'live-wallpaper.log').open('a') as log:
        print(time.strftime('\n%Y-%m-%d %H:%M:%S'), 'Starting:', ' '.join(command), file=log, flush=True)
        # A stuck decoder may ignore TERM; it must not outlive its supervisor.
        return subprocess.Popen(['setpriv', '--pdeathsig', 'KILL', '--', *command], stdin=subprocess.DEVNULL,
            stdout=log, stderr=log, start_new_session=True,
            env=dict(crop_environment(layer), SDL_AUDIODRIVER='dummy'))


def serve():
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    lock = (runtime / 'shoji-live-wallpaper.lock').open('w')
    lock_deadline = time.monotonic() + 10
    while True:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except BlockingIOError:
            if time.monotonic() >= lock_deadline:
                raise RuntimeError('Управление обоями уже запущено другой оболочкой')
            # Quickshell creates the new generation before retiring the old one.
            time.sleep(0.1)
    logs = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state') / 'shoji-shell'
    logs.mkdir(parents=True, exist_ok=True)
    current, candidates = {}, {}
    retiring = {}
    pending = None
    before = set()
    deadline = 0
    prepare_timeout = 45
    ready = False
    queue = []
    waiting = None
    items, assets = catalogue()
    emit('catalogue', items=items, assets=bool(assets), nativeWave=compositor().get('wallpaperWaveVersion', 0) >= 2)
    selector = selectors.DefaultSelector()
    selector.register(sys.stdin, selectors.EVENT_READ)
    # Read raw chunks: TextIO buffering can hide a second NDJSON command from select().
    buffer = b''
    def terminate(_signum, _frame):
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    try:
        while True:
            for _, _ in selector.select(0.1):
                chunk = os.read(sys.stdin.fileno(), 65536)
                if not chunk:
                    return
                buffer += chunk
                if len(buffer) > 1048576:
                    raise ValueError('Слишком большая команда')
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    try:
                        request = json.loads(line)
                        if not isinstance(request, dict):
                            raise ValueError('Ожидалась JSON-команда')
                        action = request.get('action')
                        if action == 'wave':
                            compositor('wallpaper.wave', request.get('state'))
                            if request.get('acknowledge'):
                                emit('frozen')
                        elif action == 'scan':
                            items, assets = catalogue()
                            emit('catalogue', items=items, assets=bool(assets), nativeWave=compositor().get('wallpaperWaveVersion', 0) >= 2)
                        elif action == 'prepare':
                            if pending is not None:
                                raise ValueError('Смена обоев уже выполняется')
                            selection = request.get('selection')
                            state = compositor()
                            outputs = [output['name'] for output in state['outputs']]
                            if not outputs:
                                raise ValueError('Нет подключённых мониторов')
                            before = {layer['id'] for layer in state['layers']}
                            layers = render_layers(selection, outputs, items, assets)
                            pending = {renderer_key(layer): layer for layer in layers}
                            queue = [key for key in pending if key not in current or current[key].poll() is not None]
                            if queue:
                                waiting = queue.pop(0)
                                candidates[waiting] = launch(pending[waiting], assets, logs)
                            prepare_timeout = 120 if request.get('restore') is True else 45
                            deadline = time.monotonic() + prepare_timeout
                            ready = not candidates
                            if ready:
                                emit('ready')
                        elif action == 'commit':
                            if pending is None or not ready:
                                raise ValueError('Новые обои ещё не готовы')
                            for key in list(current):
                                if key not in pending:
                                    retire(current.pop(key), retiring)
                            current.update(candidates)
                            candidates = {}
                            pending = None
                            ready = False
                            emit('committed', active=bool(current))
                        elif action == 'cancel':
                            for process in candidates.values(): retire(process, retiring)
                            candidates = {}
                            pending = None
                            ready = False
                            emit('cancelled', active=bool(current))
                        else:
                            raise ValueError('Неизвестная команда')
                    except (OSError, ValueError, TypeError, KeyError) as error:
                        for process in candidates.values(): retire(process, retiring)
                        candidates = {}
                        pending = None
                        ready = False
                        emit('error', message=str(error), active=bool(current))
            if candidates:
                failure = ''
                if any(process.poll() is not None for process in candidates.values()):
                    failure = 'Движок не смог открыть сцену. Лог: ~/.local/state/shoji-shell/live-wallpaper.log'
                elif not ready:
                    try:
                        state = compositor()
                        outputs = pending[waiting]['outputs']
                        if ready_on_outputs(state, before, outputs):
                            # Shoji layer geometry comes from RendererSurfaceState.view():
                            # nonzero dimensions mean a buffer was committed, not merely configured.
                            # Map retained panoramas before individual replacements;
                            # asynchronous decoder startup must not reverse their stack.
                            if queue:
                                before = {layer['id'] for layer in state['layers']}
                                waiting = queue.pop(0)
                                candidates[waiting] = launch(pending[waiting], assets, logs)
                                deadline = time.monotonic() + prepare_timeout
                            else:
                                ready = True
                                emit('ready')
                    except (OSError, ValueError, KeyError):
                        pass
                    if not ready and time.monotonic() >= deadline:
                        failure = f'Обои не подготовили кадр на всех мониторах за {prepare_timeout} секунд'
                if failure:
                    for process in candidates.values(): retire(process, retiring)
                    candidates = {}
                    pending = None
                    ready = False
                    emit('error', message=failure, active=bool(current))
            if any(process.poll() is not None for process in current.values()):
                for process in current.values(): retire(process, retiring)
                current = {}
                emit('stopped', message='Движок завершился. Серый фон до восстановления видеообоев.')
            reap(retiring)
    finally:
        for process in [*candidates.values(), *current.values(), *retiring]: stop(process)
        try:
            compositor('wallpaper.wave', dict(active=False))
        except (OSError, ValueError):
            pass
        selector.close()
        lock.close()


if __name__ == '__main__':
    try:
        serve()
    except (OSError, ValueError, RuntimeError, KeyError) as error:
        emit('error', message=str(error), active=False)
        sys.exit(1)

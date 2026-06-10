#!/usr/bin/env python3
"""
Обработка VTT файла и создание таймкодов.
Выделяет 18 ключевых моментов из транскрипции.
"""
import re
import sys

def process_vtt(vtt_file_path):
    """Обрабатывает VTT файл и возвращает 18 таймкодов."""
    
    # Читаем VTT файл
    with open(vtt_file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Парсим временные метки и текст
    # Формат: HH:MM:SS.ms или MM:SS.ms
    pattern = r'([\d:]+\.\d{3}) --> [\d:]+\.\d{3}\n(.+?)(?=\n\n|\Z)'
    matches = re.findall(pattern, content, re.DOTALL)
    
    # Собираем текст по 5-минутным сегментам для анализа
    segments = {}
    for timestamp, text in matches:
        parts = timestamp.split(':')
        
        # Парсим время в зависимости от формата
        if len(parts) == 3:  # HH:MM:SS.ms
            hours = int(parts[0])
            minutes = int(parts[1])
            seconds = int(parts[2].split('.')[0])
        else:  # MM:SS.ms
            hours = 0
            minutes = int(parts[0])
            seconds = int(parts[1].split('.')[0])
        
        total_seconds = hours * 3600 + minutes * 60 + seconds
        
        # Группируем по 5 минут (300 секунд)
        interval = (total_seconds // 300) * 300
        
        if interval not in segments:
            segments[interval] = []
        segments[interval].append(text.strip())
    
    # Находим общую длительность
    total_duration = max(segments.keys())
    
    # Вычисляем интервал для 18 точек
    # Стараемся равномерно распределить по длительности
    if len(segments) <= 18:
        # Если сегментов меньше или равно 18, берем все
        selected_times = sorted(segments.keys())
    else:
        # Выбираем каждый N-ый сегмент чтобы получить примерно 18
        step = len(segments) / 18
        selected_times = []
        for i in range(18):
            idx = int(i * step)
            selected_times.append(sorted(segments.keys())[idx])
    
    # Формируем результат
    result = []
    for time_sec in selected_times:
        hours = time_sec // 3600
        mins = (time_sec % 3600) // 60
        secs = time_sec % 60
        
        # Получаем текст сегмента (первые 500 символов для краткости)
        text = ' '.join(segments[time_sec])[:500]
        
        result.append({
            'time': f'{hours:02d}:{mins:02d}:{secs:02d}',
            'text': text
        })
    
    return result

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: process_vtt.py <path_to_vtt_file>")
        sys.exit(1)
    
    vtt_path = sys.argv[1]
    segments = process_vtt(vtt_path)
    
    for seg in segments:
        print(f"{seg['time']} - {seg['text'][:100]}...")

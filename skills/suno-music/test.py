#!/usr/bin/env python3
"""
Тест EvoLink Suno API
"""
import os
import requests
import time
import json

# Загрузка API key из .env
def load_api_key():
    env_file = os.path.join(os.path.dirname(__file__), '.env')
    with open(env_file) as f:
        for line in f:
            if line.startswith('EVOLINK_API_KEY='):
                return line.strip().split('=', 1)[1]
    raise ValueError("API key not found in .env")

API_KEY = load_api_key()
BASE_URL = "https://api.evolink.ai/v1"
HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

def create_music_task(prompt, model="suno-v5"):
    """Создать задачу генерации музыки"""
    url = f"{BASE_URL}/audios/generations"
    payload = {
        "model": model,
        "prompt": prompt
    }
    
    print(f"🎵 Создаю задачу генерации...")
    print(f"Промпт: {prompt}")
    
    response = requests.post(url, headers=HEADERS, json=payload)
    
    if response.status_code != 200:
        print(f"❌ Ошибка: {response.status_code}")
        print(response.text)
        return None
    
    task = response.json()
    print(f"✅ Задача создана: {task['id']}")
    print(f"Примерное время: {task.get('task_info', {}).get('estimated_time', '?')} сек")
    
    return task

def get_task_status(task_id):
    """Получить статус задачи"""
    url = f"{BASE_URL}/tasks/{task_id}"
    response = requests.get(url, headers=HEADERS)
    
    if response.status_code != 200:
        print(f"❌ Ошибка получения статуса: {response.status_code}")
        return None
    
    return response.json()

def wait_for_completion(task_id, timeout=300):
    """Ждать завершения задачи"""
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        task = get_task_status(task_id)
        
        if not task:
            return None
        
        status = task['status']
        progress = task.get('progress', 0)
        
        print(f"⏳ Статус: {status} | Прогресс: {progress}%")
        
        if status == "completed":
            print("✅ Генерация завершена!")
            return task
        elif status == "failed":
            print(f"❌ Задача провалилась: {task.get('error')}")
            return None
        
        time.sleep(5)
    
    print("⏱️ Timeout!")
    return None

def main():
    # Тестовый промпт
    prompt = "Upbeat electronic music, 120 BPM, energetic synth, perfect for coding"
    
    # Создать задачу
    task = create_music_task(prompt)
    
    if not task:
        return
    
    # Ждать завершения
    result = wait_for_completion(task['id'])
    
    if result and result.get('results'):
        audio_url = result['results'][0]
        print(f"\n🎵 Трек готов!")
        print(f"URL: {audio_url}")
    else:
        print("\n❌ Не удалось сгенерировать трек")

if __name__ == "__main__":
    main()

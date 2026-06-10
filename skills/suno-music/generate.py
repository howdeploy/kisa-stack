#!/usr/bin/env python3
"""
Suno Music Generation через EvoLink API
"""
import os
import sys
import requests
import time
import json

# API настройки
def load_api_key():
    env_file = os.path.join(os.path.dirname(__file__), '.env')
    with open(env_file) as f:
        for line in f:
            if line.startswith('EVOLINK_API_KEY='):
                return line.strip().split('=', 1)[1]
    raise ValueError("API key not found")

API_KEY = load_api_key()
BASE_URL = "https://api.evolink.ai/v1"
HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

def create_music(prompt, lyrics=None, model="suno-v5"):
    """Создать музыку"""
    url = f"{BASE_URL}/audios/generations"
    
    payload = {
        "model": model,
        "prompt": prompt
    }
    
    if lyrics:
        payload["custom"] = True
        payload["lyrics"] = lyrics
    
    # Создать задачу
    response = requests.post(url, headers=HEADERS, json=payload)
    
    if response.status_code != 200:
        return {"error": f"API error: {response.status_code}", "details": response.text}
    
    task = response.json()
    task_id = task['id']
    
    # Ждать завершения
    timeout = 360  # 6 минут (на случай очереди)
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        status_response = requests.get(f"{BASE_URL}/tasks/{task_id}", headers=HEADERS)
        
        if status_response.status_code != 200:
            return {"error": "Failed to get task status"}
        
        task_data = status_response.json()
        status = task_data['status']
        
        if status == "completed":
            # Получить URL трека
            if task_data.get('results'):
                return {"success": True, "url": task_data['results'][0]}
            else:
                return {"error": "No results in completed task"}
        
        elif status == "failed":
            return {"error": f"Generation failed: {task_data.get('error')}"}
        
        time.sleep(5)
    
    return {"error": "Timeout"}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: generate.py <prompt> [lyrics]")
        sys.exit(1)
    
    prompt = sys.argv[1]
    lyrics = sys.argv[2] if len(sys.argv) > 2 else None
    
    result = create_music(prompt, lyrics)
    print(json.dumps(result, ensure_ascii=False))

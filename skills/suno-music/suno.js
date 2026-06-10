#!/usr/bin/env node
/**
 * Suno Music Generation Skill
 * Триггеры: "создай трек", "музыку", "сгенерируй песню", "suno"
 */

const { execSync } = require('child_process');
const path = require('path');

// Триггеры
const triggers = [
  /создай.*трек/i,
  /сделай.*музык/i,
  /сгенериру.*песн/i,
  /музык.*под.*настроение/i,
  /хочу.*послушать.*музык/i,
  /давай.*сделаем.*трек/i,
  /suno/i
];

// Проверка на триггер
function shouldHandle(message) {
  return triggers.some(pattern => pattern.test(message));
}

// Генерация промпта из описания пользователя
function generatePrompt(userMessage) {
  // Ключевые слова для жанров
  const keywords = {
    lofi: /lo-?fi|лоу-?фай|спокойн|расслаб|медитат|вечер/i,
    electronic: /электрон|синт|house|techno|edm/i,
    slavic: /славян|хор|фольк|этник/i,
    calm: /спокойн|тих|умиротвор|мягк/i,
    melancholic: /меланхол|груст|грузн/i,
    energetic: /энергич|бодр|танцев|активн/i,
    ambient: /эмбиент|атмосфер|космич/i
  };
  
  let prompt = [];
  let bpm = 100; // default
  
  // Определяем жанр
  if (keywords.lofi.test(userMessage)) {
    prompt.push('lo-fi');
    bpm = 75;
  }
  
  if (keywords.electronic.test(userMessage)) {
    prompt.push('electronic');
  }
  
  if (keywords.slavic.test(userMessage)) {
    prompt.push('Slavic folk');
    prompt.push('choir vocals');
  }
  
  if (keywords.ambient.test(userMessage)) {
    prompt.push('ambient');
    prompt.push('atmospheric');
  }
  
  // Определяем настроение
  if (keywords.calm.test(userMessage)) {
    prompt.push('calm and peaceful');
    prompt.push('soft pads');
    bpm = Math.min(bpm, 80);
  }
  
  if (keywords.melancholic.test(userMessage)) {
    prompt.push('melancholic');
    prompt.push('emotional');
  }
  
  if (keywords.energetic.test(userMessage)) {
    prompt.push('energetic');
    prompt.push('upbeat');
    bpm = Math.max(bpm, 120);
  }
  
  // Если ничего не определили - дефолт
  if (prompt.length === 0) {
    prompt.push('electronic music');
  }
  
  // Добавляем BPM
  prompt.push(`${bpm} BPM`);
  
  // Общие параметры для качества
  prompt.push('high quality');
  prompt.push('professional production');
  
  return prompt.join(', ');
}

// Основная функция
async function handleMusicRequest(message) {
  const scriptPath = path.join(__dirname, 'generate.py');
  const prompt = generatePrompt(message);
  
  console.log(`Generated prompt: ${prompt}`);
  
  // Запуск генерации
  const result = execSync(
    `python3 "${scriptPath}" "${prompt}"`,
    { encoding: 'utf-8', maxBuffer: 10 * 1024 * 1024 }
  );
  
  const response = JSON.parse(result);
  
  if (response.success) {
    return {
      success: true,
      url: response.url,
      prompt: prompt
    };
  } else {
    return {
      success: false,
      error: response.error
    };
  }
}

// CLI интерфейс
if (require.main === module) {
  const message = process.argv[2];
  
  if (!message) {
    console.error('Usage: suno.js <message>');
    process.exit(1);
  }
  
  if (!shouldHandle(message)) {
    console.log('Message does not match triggers');
    process.exit(0);
  }
  
  handleMusicRequest(message)
    .then(result => {
      console.log(JSON.stringify(result));
    })
    .catch(err => {
      console.error(JSON.stringify({ success: false, error: err.message }));
      process.exit(1);
    });
}

module.exports = { shouldHandle, handleMusicRequest, generatePrompt };

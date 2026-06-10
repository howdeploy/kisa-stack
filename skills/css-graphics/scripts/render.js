#!/usr/bin/env node

const path = require('path');
const fs = require('fs');

// --- CLI argument parsing ---

function parseArgs(argv) {
  const args = {
    input: null,
    output: null,
    width: 1920,
    height: 1080,
    scale: 2,
    transparent: false,
    quality: 90,
    wait: 1000,
  };

  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    switch (arg) {
      case '--input':
        args.input = argv[++i];
        break;
      case '--output':
        args.output = argv[++i];
        break;
      case '--width':
        args.width = parseInt(argv[++i], 10);
        break;
      case '--height':
        args.height = parseInt(argv[++i], 10);
        break;
      case '--scale':
        args.scale = parseFloat(argv[++i]);
        break;
      case '--transparent':
        args.transparent = true;
        break;
      case '--quality':
        args.quality = parseInt(argv[++i], 10);
        break;
      case '--wait':
        args.wait = parseInt(argv[++i], 10);
        break;
      default:
        console.error(`Unknown argument: ${arg}`);
        process.exit(1);
    }
  }

  if (!args.input || !args.output) {
    console.error('Usage: render.js --input <file.html> --output <file.png> [options]');
    console.error('Options:');
    console.error('  --width <px>       Viewport width (default: 1920)');
    console.error('  --height <px>      Viewport height (default: 1080)');
    console.error('  --scale <factor>   Device scale factor (default: 2)');
    console.error('  --transparent      Transparent background (PNG only)');
    console.error('  --quality <1-100>  JPEG quality (default: 90)');
    console.error('  --wait <ms>        Extra wait after load (default: 1000)');
    process.exit(1);
  }

  return args;
}

// --- Main ---

async function main() {
  const args = parseArgs(process.argv);

  // Resolve input path
  const inputPath = path.resolve(args.input);
  if (!fs.existsSync(inputPath)) {
    console.error(`Input file not found: ${inputPath}`);
    process.exit(1);
  }

  // Resolve output path and determine format
  const outputPath = path.resolve(args.output);
  const ext = path.extname(outputPath).toLowerCase();
  const isJpeg = ext === '.jpg' || ext === '.jpeg';
  const format = isJpeg ? 'jpeg' : 'png';

  // Launch Puppeteer
  const puppeteer = require('puppeteer');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
    ],
  });

  try {
    const page = await browser.newPage();

    await page.setViewport({
      width: args.width,
      height: args.height,
      deviceScaleFactor: args.scale,
    });

    // Load HTML file
    const fileUrl = `file://${inputPath}`;
    await page.goto(fileUrl, { waitUntil: 'networkidle0', timeout: 30000 });

    // Wait for fonts to load
    await page.evaluate(() => document.fonts.ready);

    // Extra configurable wait (for fonts, transitions, etc.)
    if (args.wait > 0) {
      await new Promise((resolve) => setTimeout(resolve, args.wait));
    }

    // Screenshot options
    const screenshotOptions = {
      path: outputPath,
      type: format,
      clip: {
        x: 0,
        y: 0,
        width: args.width,
        height: args.height,
      },
      omitBackground: args.transparent && format === 'png',
    };

    if (isJpeg) {
      screenshotOptions.quality = args.quality;
    }

    await page.screenshot(screenshotOptions);

    // Report results
    const stats = fs.statSync(outputPath);
    const sizeKB = (stats.size / 1024).toFixed(1);
    const finalWidth = args.width * args.scale;
    const finalHeight = args.height * args.scale;

    console.log(`Saved: ${outputPath}`);
    console.log(`Size: ${sizeKB} KB`);
    console.log(`Dimensions: ${finalWidth}x${finalHeight}px (viewport ${args.width}x${args.height} @${args.scale}x)`);
    console.log(`Format: ${format.toUpperCase()}`);
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error('Render failed:', err.message);
  process.exit(1);
});

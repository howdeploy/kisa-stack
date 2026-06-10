#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== CSS Graphics — Setup ==="

# Check Node.js version
if ! command -v node &> /dev/null; then
  echo "ERROR: Node.js not found. Install Node.js >= 18."
  exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
  echo "ERROR: Node.js >= 18 required, found v$(node -v)"
  exit 1
fi
echo "Node.js $(node -v) — OK"

# Init package.json if missing
cd "$SCRIPTS_DIR"
if [ ! -f package.json ]; then
  echo "Initializing package.json..."
  npm init -y --silent > /dev/null 2>&1
fi

# Install Puppeteer
echo "Installing Puppeteer (this downloads Chromium, ~200MB)..."
npm install puppeteer --silent

# Self-test
echo "Running self-test..."
node -e "require('puppeteer'); console.log('Puppeteer loaded — OK')"

echo ""
echo "=== Setup complete ==="
echo "Usage: node $SCRIPTS_DIR/render.js --input file.html --output file.png"

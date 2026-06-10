# CSS/SVG Techniques for Graphics Generation

Quick reference for creating graphics with pure CSS and inline SVG.

## Gradients

```css
/* Linear — direction + color stops */
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);

/* Radial — shape + position */
background: radial-gradient(circle at 30% 40%, #ff6b6b, #4ecdc4 70%, transparent 71%);

/* Conic — pie charts, color wheels */
background: conic-gradient(from 45deg, #f06, #9f6, #06f, #f06);

/* Multiple backgrounds — layer effects */
background:
  radial-gradient(circle at 20% 30%, rgba(255,255,255,0.1) 0%, transparent 50%),
  radial-gradient(circle at 80% 70%, rgba(99,102,241,0.3) 0%, transparent 40%),
  linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
```

## Shapes with clip-path

```css
/* Circle */
clip-path: circle(50% at center);

/* Triangle */
clip-path: polygon(50% 0%, 0% 100%, 100% 100%);

/* Hexagon */
clip-path: polygon(25% 0%, 75% 0%, 100% 50%, 75% 100%, 25% 100%, 0% 50%);

/* Star */
clip-path: polygon(50% 0%, 61% 35%, 98% 35%, 68% 57%, 79% 91%, 50% 70%, 21% 91%, 32% 57%, 2% 35%, 39% 35%);
```

## Depth and Shadows

```css
/* Stacked shadows for depth */
box-shadow:
  0 1px 2px rgba(0,0,0,0.1),
  0 4px 8px rgba(0,0,0,0.1),
  0 16px 32px rgba(0,0,0,0.15);

/* Glow effect */
box-shadow: 0 0 20px rgba(99,102,241,0.5), 0 0 60px rgba(99,102,241,0.2);

/* Glass morphism */
background: rgba(255,255,255,0.1);
backdrop-filter: blur(12px);
border: 1px solid rgba(255,255,255,0.15);
```

## Textures and Patterns

```css
/* Dots */
background: radial-gradient(circle, #333 1px, transparent 1px);
background-size: 20px 20px;

/* Grid lines */
background:
  linear-gradient(rgba(255,255,255,0.05) 1px, transparent 1px),
  linear-gradient(90deg, rgba(255,255,255,0.05) 1px, transparent 1px);
background-size: 40px 40px;

/* Diagonal stripes */
background: repeating-linear-gradient(
  45deg, transparent, transparent 10px,
  rgba(255,255,255,0.03) 10px, rgba(255,255,255,0.03) 20px
);
```

## Typography Effects

```css
/* Gradient text */
background: linear-gradient(135deg, #667eea, #764ba2);
-webkit-background-clip: text;
-webkit-text-fill-color: transparent;

/* Neon glow */
text-shadow: 0 0 7px #fff, 0 0 10px #fff, 0 0 21px #fff, 0 0 42px #0fa, 0 0 82px #0fa;
```

## SVG Quick Reference

```svg
<!-- Gradient fill -->
<defs>
  <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
    <stop offset="0%" stop-color="#667eea" />
    <stop offset="100%" stop-color="#764ba2" />
  </linearGradient>
</defs>

<!-- Arrow markers -->
<defs>
  <marker id="arrow" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
    <polygon points="0 0, 10 3.5, 0 7" fill="#818cf8" />
  </marker>
</defs>

<!-- Centered text -->
<text x="50%" y="50%" dominant-baseline="central" text-anchor="middle"
      font-family="Inter, system-ui" font-size="48" font-weight="700" fill="url(#grad1)">
  Hello
</text>

<!-- Filters: blur, noise, glow -->
<filter id="glow">
  <feGaussianBlur stdDeviation="4" result="blur" />
  <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
</filter>
```

## Common Color Palettes

### Catppuccin Mocha
Base: `#1e1e2e` | Surface: `#313244` | Blue: `#89b4fa` | Mauve: `#cba6f7` | Pink: `#f5c2e7` | Green: `#a6e3a1`

### Dark Theme
Background: `#0f172a` | Indigo: `#818cf8` | Blue: `#38bdf8` | Purple: `#c084fc` | Emerald: `#34d399`

## Google Fonts

```html
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;900&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;600;700&display=swap" rel="stylesheet">
```

Always add fallback: `font-family: 'Inter', system-ui, sans-serif;`

.pragma library

function clamp(x, y, zoom) {
    return { x: Math.max(0, Math.min(1, x)), y: Math.max(0, Math.min(1, y)),
        zoom: Math.max(1, Math.min(3, zoom)) };
}

function resize(edge, rect, dx, dy, initialZoom) {
    const left = edge.includes("l"), right = edge.includes("r");
    const top = edge.includes("t"), bottom = edge.includes("b");
    const sx = 1 + (left ? -dx : dx) / rect.w;
    const sy = 1 + (top ? -dy : dy) / rect.h;
    let scale = left || right ? top || bottom ? Math.max(sx, sy) : sx : sy;
    const ax = left ? rect.x + rect.w : right ? rect.x : rect.x + rect.w / 2;
    const ay = top ? rect.y + rect.h : bottom ? rect.y : rect.y + rect.h / 2;
    const maxW = left ? ax : right ? 1 - ax : Math.min(ax, 1 - ax) * 2;
    const maxH = top ? ay : bottom ? 1 - ay : Math.min(ay, 1 - ay) * 2;
    scale = Math.max(initialZoom / 3, Math.min(initialZoom, maxW / rect.w, maxH / rect.h, scale));
    const w = rect.w * scale, h = rect.h * scale;
    const x = left ? ax - w : right ? ax : ax - w / 2;
    const y = top ? ay - h : bottom ? ay : ay - h / 2;
    return clamp(w < 0.999999 ? x / (1 - w) : 0.5, h < 0.999999 ? y / (1 - h) : 0.5, initialZoom / scale);
}

type Point = [number, number];
export type FlowPoint = [number, number, number];

// Each branch goes from the upstream nose around the rectangle to the wake.
export function flowPaths(rect: [number, number, number, number], velocity: Point): FlowPoint[][] {
  const speed = Math.hypot(...velocity);
  const forward: Point = speed > 0 ? [velocity[0] / speed, velocity[1] / speed] : [1, 0];
  const side: Point = [-forward[1], forward[0]];
  const center: Point = [rect[0] + rect[2] / 2, rect[1] + rect[3] / 2];
  const half: Point = [rect[2] / 2 + 24, rect[3] / 2 + 24];
  const reach = Math.abs(forward[0]) * half[0] + Math.abs(forward[1]) * half[1];
  const points: Point[] = [[-reach - 160, 0], [reach + 64, 0]];
  for (const x of [-half[0], half[0]]) {
    for (const y of [-half[1], half[1]]) {
      points.push([x * forward[0] + y * forward[1], x * side[0] + y * side[1]]);
    }
  }
  points.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  const cross = (a: Point, b: Point, c: Point) =>
    (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);

  return [1, -1].map(sign => {
    const hull: Point[] = [];
    for (const point of points) {
      while (hull.length > 1 && sign * cross(hull.at(-2)!, hull.at(-1)!, point) <= 0) hull.pop();
      hull.push(point);
    }
    hull.reverse();
    const path: FlowPoint[] = [];
    const append = (point: Point) => {
      const x = center[0] + forward[0] * point[0] + side[0] * point[1];
      const y = center[1] + forward[1] * point[0] + side[1] * point[1];
      const last = path.at(-1);
      path.push([x, y, last ? last[2] + Math.hypot(x - last[0], y - last[1]) : 0]);
    };
    append(hull[0]);
    for (let i = 1; i < hull.length - 1; i++) {
      const p = hull[i], before = hull[i - 1], after = hull[i + 1];
      const incoming = Math.hypot(before[0] - p[0], before[1] - p[1]);
      const outgoing = Math.hypot(after[0] - p[0], after[1] - p[1]);
      // The 24 px clearance exceeds this corner cut, keeping the path outside.
      const trim = Math.min(24, incoming / 3, outgoing / 3);
      const a: Point = [p[0] + (before[0] - p[0]) * trim / incoming,
        p[1] + (before[1] - p[1]) * trim / incoming];
      const b: Point = [p[0] + (after[0] - p[0]) * trim / outgoing,
        p[1] + (after[1] - p[1]) * trim / outgoing];
      append(a);
      // ponytail: four chords per rounded corner; increase if faceting is visible.
      for (let step = 1; step <= 4; step++) {
        const t = step / 4, u = 1 - t;
        append([u * u * a[0] + 2 * u * t * p[0] + t * t * b[0],
          u * u * a[1] + 2 * u * t * p[1] + t * t * b[1]]);
      }
    }
    append(hull.at(-1)!);
    // Six hull candidates need at most 22 samples; fixed size for GLSL ES 1.00.
    while (path.length < 24) path.push(path.at(-1)!);
    return path;
  });
}

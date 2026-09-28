export type FlowRect = [number, number, number, number];
export const FLOW_SETTLE_SECONDS = 0.5;
export const FLOW_SAMPLES = 8;
export interface FlowMotion {
  from: FlowRect;
  to: FlowRect;
  started: number;
  duration: number;
  easing: (progress: number) => number;
  stopped?: number;
}

export function sampleFlowMotion(motion: FlowMotion, time: number): FlowRect {
  const elapsed = (Math.min(time, motion.stopped ?? Infinity) - motion.started) / motion.duration;
  const progress = motion.easing(Math.max(0, Math.min(1, elapsed)));
  return motion.from.map((from, i) => from + (motion.to[i] - from) * progress) as FlowRect;
}

// Window rect at each sample, not the swept box. A negative age means the
// window has not reached that point yet, so the shader must draw nothing there.
export function flowHistory(motion: FlowMotion, time: number) {
  const rects: FlowRect[] = [], deltas: FlowRect[] = [], ages: number[] = [];
  const limit = motion.stopped ?? motion.started + motion.duration;
  for (let i = 0; i < FLOW_SAMPLES; i++) {
    const begin = motion.started + motion.duration * i / FLOW_SAMPLES;
    const finish = motion.started + motion.duration * (i + 1) / FLOW_SAMPLES;
    if (begin >= time || begin >= limit) {
      rects.push([0, 0, 0, 0]);
      deltas.push([0, 0, 0, 0]);
      ages.push(-1);
      continue;
    }
    const shown = Math.min(finish, time, limit);
    const age = time - shown;
    if (age >= FLOW_SETTLE_SECONDS) {
      rects.push([0, 0, 0, 0]);
      deltas.push([0, 0, 0, 0]);
      ages.push(FLOW_SETTLE_SECONDS);
      continue;
    }
    const a = sampleFlowMotion(motion, begin);
    const b = sampleFlowMotion(motion, shown);
    const acx = a[0] + a[2] * 0.5, acy = a[1] + a[3] * 0.5;
    const bcx = b[0] + b[2] * 0.5, bcy = b[1] + b[3] * 0.5;
    rects.push(b);
    deltas.push([bcx - acx, bcy - acy, b[2] - a[2], b[3] - a[3]]);
    ages.push(age);
  }
  return { rects, deltas, ages };
}

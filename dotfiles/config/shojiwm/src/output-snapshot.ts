import { COMPOSITOR } from "shoji_wm";
import type { OutputInfo } from "shoji_wm/types";

let cached: Record<string, OutputInfo> | undefined;
COMPOSITOR.event.onOutputChange(() => { cached = undefined; });

/** Config-internal read-only snapshot; SDK clones only once per output change. */
export function outputSnapshot(): Readonly<Record<string, OutputInfo>> {
  return cached ??= COMPOSITOR.output.current;
}

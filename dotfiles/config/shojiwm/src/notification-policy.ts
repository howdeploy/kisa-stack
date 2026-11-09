import { COMPOSITOR, signal } from "shoji_wm";
import { type IpcServer, wakeRust } from "shoji_wm/ipc";

type Policy = { version: 1; quiet: boolean; allowedApplications: string[] };
const KEY = "shoji.notification-policy.v1";
const appKey = (value: string) => value.trim().toLowerCase().replace(/\.desktop$/, "");

function parse(raw: unknown): Policy {
  const policy = raw as Partial<Policy> | null;
  if (!policy || typeof policy.quiet !== "boolean" || !Array.isArray(policy.allowedApplications)
      || policy.allowedApplications.length > 1024
      || !policy.allowedApplications.every(id => typeof id === "string" && id.length <= 256 && !/[\x00-\x1f]/.test(id)))
    throw new Error("Invalid notification policy");
  return { version: 1, quiet: policy.quiet, allowedApplications: [...new Set(policy.allowedApplications.map(appKey))] };
}

export function registerNotificationPolicy(ipc: IpcServer): (appId: string | undefined | null) => boolean {
  const policy = signal<Policy>({ version: 1, quiet: true, allowedApplications: [] });
  ipc.handle("notifications.getPolicy", () => policy());
  ipc.handle("notifications.setPolicy", raw => {
    const next = parse(raw);
    policy.set(next);
    wakeRust();
    return next;
  });
  COMPOSITOR.onDisable(event => { if (event.isReloading) event.persist(KEY, policy()); });
  COMPOSITOR.onEnable(event => {
    if (!event.isReloading) return;
    const previous = event.restore<Policy>(KEY);
    if (previous) {
      try { policy.set(parse(previous)); }
      catch (error) { console.warn("Notification policy restore rejected", String(error)); }
    }
  });
  return appId => !policy().quiet || policy().allowedApplications.includes(appKey(appId || ""));
}

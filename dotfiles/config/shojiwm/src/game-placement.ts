const PORTPROTON_GAMES = new Set<string>();

export function gameMonitorForApp(
  appId: string | undefined,
  outputs: readonly { name: string; position: { x: number } }[],
): string | undefined {
  const id = (appId ?? "").toLowerCase();
  // shortcut: no game category in the window API; add non-Steam game IDs here as needed.
  const isGame = /^steam_app_\d+$/.test(id)
    || id === "com.mojang.minecraft" || id === "openmw" || id === "org.openmw.openmw"
    || PORTPROTON_GAMES.has(id.replace(/(?:-win64-shipping)?\.exe$/, ""));
  if (!isGame) return undefined;
  return [...outputs].sort((a, b) => a.position.x - b.position.x)[0]?.name;
}

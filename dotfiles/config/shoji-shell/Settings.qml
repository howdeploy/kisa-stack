pragma Singleton
import Quickshell

Singleton {
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    readonly property string wallpaperDirectory: Quickshell.env("SHOJI_WALLPAPERS") || Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string primaryOutput: Quickshell.env("SHOJI_PRIMARY_OUTPUT") || ""
    function enabled(id) {
        if (["github", "vast", "limits", "sessions", "hermes", "weather"].includes(id))
            return Quickshell.env("SHOJI_ENABLE_" + id.toUpperCase()) === "1";
        return true;
    }
}

pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtCore
import QtQuick
import qs.Services

Singleton {
    id: root

    readonly property var log: Log.scoped("Paths")

    readonly property url home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
    readonly property url pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
    readonly property url xdgCache: StandardPaths.standardLocations(StandardPaths.GenericCacheLocation)[0]

    readonly property url data: `${StandardPaths.standardLocations(StandardPaths.GenericDataLocation)[0]}/DankMaterialShell`
    readonly property url state: `${StandardPaths.standardLocations(StandardPaths.GenericStateLocation)[0]}/DankMaterialShell`
    readonly property url cache: `${StandardPaths.standardLocations(StandardPaths.GenericCacheLocation)[0]}/DankMaterialShell`
    readonly property url config: `${StandardPaths.standardLocations(StandardPaths.GenericConfigLocation)[0]}/DankMaterialShell`

    readonly property url imagecache: `${cache}/imagecache`

    property var _steamIconCache: ({})
    property var _steamIconPending: ({})
    property var _steamIconMisses: ({})
    property int steamIconRevision: 0
    property bool _steamBumpPending: false

    Component.onCompleted: mkdir(imagecache)

    function stringify(path: url): string {
        const raw = path.toString();
        try {
            return decodeURIComponent(raw);
        } catch (e) {
            log.warn("failed to decode path:", raw, e);
            return raw;
        }
    }

    function expandTilde(path: string): string {
        if (!path.startsWith("~"))
            return path;
        return strip(root.home) + path.substring(1);
    }

    function shortenHome(path: string): string {
        return path.replace(strip(root.home), "~");
    }

    function strip(path: url): string {
        return stringify(path).replace("file://", "");
    }

    function toFileUrl(path: string): string {
        return path.startsWith("file://") ? path : "file://" + path;
    }

    function isFileIconSource(source: string): bool {
        if (!source)
            return false;
        return source.startsWith("file:") || source.startsWith("qrc:") || source.startsWith("/");
    }

    function mkdir(path: url): void {
        Quickshell.execDetached(["mkdir", "-p", strip(path)]);
    }

    function copy(from: url, to: url): void {
        Quickshell.execDetached(["cp", strip(from), strip(to)]);
    }

    function steamAppNumericId(appId: string): string {
        const m = (appId || "").match(/^(?:steam_app_|steam_icon_)(\d+)$/);
        return m ? m[1] : "";
    }

    function isSteamApp(appId: string): bool {
        return steamAppNumericId(appId) !== "";
    }

    function _bumpSteamIcons() {
        if (_steamBumpPending)
            return;
        _steamBumpPending = true;
        Qt.callLater(() => {
            _steamBumpPending = false;
            steamIconRevision++;
        });
    }

    function _findSteamIcon(id) {
        const home = strip(root.home);
        const script = "id='" + id + "'\n" +
            "home='" + home + "'\n" +
            "for root in \"$home/.local/share/Steam\" \"$home/.steam/steam\" \"$home/.steam/root\" \"$home/.var/app/com.valvesoftware.Steam/data/Steam\"; do\n" +
            "  [ -d \"$root\" ] || continue\n" +
            "  for f in \"$root/appcache/librarycache/${id}_icon.jpg\" \"$root/appcache/librarycache/${id}_icon.png\"; do\n" +
            "    [ -f \"$f\" ] && echo \"$f\" && exit 0\n" +
            "  done\n" +
            "  lib=\"$root/appcache/librarycache/$id\"\n" +
            "  [ -d \"$lib\" ] || continue\n" +
            "  for f in \"$lib\"/*; do\n" +
            "    [ -f \"$f\" ] || continue\n" +
            "    base=$(basename \"$f\")\n" +
            "    case \"$base\" in\n" +
            "      header.jpg|header.jpeg|header.png|logo.png|logo.jpg|logo.jpeg|library_*) continue ;;\n" +
            "    esac\n" +
            "    case \"$base\" in\n" +
            "      *.jpg|*.jpeg|*.png) echo \"$f\"; exit 0 ;;\n" +
            "    esac\n" +
            "  done\n" +
            "done\n";
        Proc.runCommand("steamIcon:" + id, ["sh", "-c", script], (out, code) => {
            const path = ((out || "").trim().split("\n").filter(s => s)[0]) || "";
            delete root._steamIconPending[id];
            if (path) {
                root._steamIconCache[id] = root.toFileUrl(path);
                root._bumpSteamIcons();
            } else {
                root._steamIconMisses[id] = Date.now();
            }
        }, 0);
    }

    function getSteamGameIcon(appId: string): string {
        const _dep = steamIconRevision;
        const id = steamAppNumericId(appId);
        if (!id)
            return "";

        const themed = (typeof IconThemeService !== "undefined") ? IconThemeService.resolve("steam_icon_" + id) : "";
        if (themed)
            return themed;

        if (root._steamIconCache[id])
            return root._steamIconCache[id];
        if (root._steamIconPending[id])
            return "";
        const lastMiss = root._steamIconMisses[id];
        if (lastMiss && (Date.now() - lastMiss < 30000))
            return "";
        root._steamIconPending[id] = true;
        Qt.callLater(() => root._findSteamIcon(id));
        return "";
    }

    function moddedAppId(appId: string): string {
        const subs = SettingsData.appIdSubstitutions || [];
        for (let i = 0; i < subs.length; i++) {
            const sub = subs[i];
            if (sub.type === "exact" && appId === sub.pattern) {
                return sub.replacement;
            } else if (sub.type === "contains" && appId.includes(sub.pattern)) {
                return sub.replacement;
            } else if (sub.type === "regex") {
                const match = appId.match(new RegExp(sub.pattern));
                if (match) {
                    return sub.replacement.replace(/\$(\d+)/g, (_, n) => match[n] || "");
                }
            }
        }
        const steamMatch = appId.match(/^steam_app_(\d+)$/);
        if (steamMatch)
            return `steam_icon_${steamMatch[1]}`;
        return appId;
    }

    function themedIconPath(name: string): string {
        if (!name)
            return "";
        const themed = (typeof IconThemeService !== "undefined") ? IconThemeService.resolve(name) : "";
        if (themed)
            return themed;
        return Quickshell.iconPath(name, true);
    }

    function resolveIconPath(iconName: string): string {
        const _dep = steamIconRevision;
        if (!iconName)
            return "";
        const steam = getSteamGameIcon(iconName);
        if (steam)
            return steam;
        const moddedId = moddedAppId(iconName);
        if (moddedId !== iconName) {
            if (moddedId.startsWith("~") || moddedId.startsWith("/"))
                return toFileUrl(expandTilde(moddedId));
            if (moddedId.startsWith("file://"))
                return moddedId;
            return themedIconPath(moddedId);
        }
        return themedIconPath(iconName) || DesktopService.resolveIconPath(iconName);
    }

    function resolveIconUrl(iconName: string): string {
        if (!iconName)
            return "";
        const moddedId = moddedAppId(iconName);
        const target = (moddedId !== iconName) ? moddedId : iconName;
        if (target.startsWith("~") || target.startsWith("/"))
            return toFileUrl(expandTilde(target));
        if (target.startsWith("file://"))
            return target;
        const themed = (typeof IconThemeService !== "undefined") ? IconThemeService.resolve(target) : "";
        if (themed)
            return themed;
        return "image://icon/" + target;
    }

    function getAppIcon(appId: string, desktopEntry: var): string {
        const _dep = steamIconRevision;
        if (appId === "org.quickshell" || appId === "com.danklinux.dms") {
            return Qt.resolvedUrl("../assets/danklogo.svg");
        }

        const steam = getSteamGameIcon(appId);
        if (steam)
            return steam;

        const moddedId = moddedAppId(appId);
        if (moddedId !== appId)
            return resolveIconPath(appId);

        if (desktopEntry && desktopEntry.icon) {
            return themedIconPath(desktopEntry.icon);
        }

        const icon = themedIconPath(appId);
        if (icon && icon !== "")
            return icon;

        return DesktopService.resolveIconPath(appId);
    }

    function getAppName(appId: string, desktopEntry: var): string {
        if (appId === "org.quickshell" || appId === "com.danklinux.dms") {
            return "dms";
        }

        return desktopEntry && desktopEntry.name ? desktopEntry.name : appId;
    }
}

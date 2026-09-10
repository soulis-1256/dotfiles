import QtQuick

QtObject {
    // Shared Start pin-drag policy. Source of truth is Windows 10 Start.
    // Layout (tile size, packing, displacement) stays per-theme.
    // Both win10Start and win11Start instantiate this.

    readonly property real slowEnter: 300
    readonly property real slowLeave: 480
    readonly property int slowHoldMs: 80
    readonly property real folderSpeedMin: 360
    readonly property real folderHitRatio: 0.34
    readonly property int folderHitMin: 18
    readonly property int stickyPad: 10

    function folderHitLimit(w, h) {
        return Math.max(folderHitMin, Math.min(w, h) * folderHitRatio);
    }

    function sampleMotion(s, globalX, globalY) {
        const now = Date.now();
        let lastX = s.lastX || 0;
        let lastY = s.lastY || 0;
        let lastMs = s.lastMs || 0;
        let speed = s.speed || 0;
        let slowSince = s.slowSinceMs || 0;
        let live = !!s.live;

        const dt = now - lastMs;
        if (dt <= 0) {
            return {
                "lastX": globalX,
                "lastY": globalY,
                "lastMs": lastMs,
                "speed": speed,
                "slowSinceMs": slowSince,
                "live": live
            };
        }

        const dist = Math.hypot(globalX - lastX, globalY - lastY);
        const inst = (dist / dt) * 1000;
        if (dt > 120)
            speed = inst;
        else {
            const alpha = Math.min(1, dt / 40);
            speed = speed * (1 - alpha) + inst * alpha;
        }

        if (speed <= slowEnter) {
            if (slowSince <= 0)
                slowSince = now;
            if ((now - slowSince) >= slowHoldMs)
                live = true;
        } else {
            slowSince = 0;
            if (speed >= slowLeave)
                live = false;
        }

        return {
            "lastX": globalX,
            "lastY": globalY,
            "lastMs": now,
            "speed": speed,
            "slowSinceMs": slowSince,
            "live": live
        };
    }

    function resolveDrop(s) {
        const hit = s.centerHit || null;
        const result = {
            "dropType": "reorder",
            "live": !!s.live,
            "stickyId": "",
            "badge": s.fromFolder ? "Move out of folder" : "",
            "folderId": "",
            "tileId": "",
            "index": -1
        };

        // Folders cannot create folders. The fast-pass live=false path exists
        // so an app can aim at a center without shuffling. A folder drag is
        // always reorder, so keep live on or the source slot becomes a hole.
        if (s.draggedIsFolder) {
            result.live = true;
            return result;
        }

        const holdingSticky = !!(hit && s.stickyId && hit.tileId === s.stickyId);
        const fastEnough = (s.speed >= folderSpeedMin) || holdingSticky;
        if (hit && fastEnough) {
            result.stickyId = hit.tileId;
            result.index = (typeof hit.tileIndex === "number") ? hit.tileIndex : -1;
            if (hit.type === "folder") {
                result.dropType = "add-to-folder";
                result.folderId = hit.folderId;
                result.tileId = hit.folderId;
                result.badge = "Add to folder";
            } else {
                result.dropType = "create-folder";
                result.tileId = hit.tileId;
                result.badge = "Drop to create folder";
            }
        }

        // Over empty space: live immediately. Over apps/folders: don't
        // displace while passing through fast — slow-hold from sampleMotion
        // is what turns reorder on.
        if (!s.hasTileUnder && !hit)
            result.live = true;
        else if (s.hasTileUnder || hit) {
            if (s.speed > slowEnter)
                result.live = false;
        }

        return result;
    }
}

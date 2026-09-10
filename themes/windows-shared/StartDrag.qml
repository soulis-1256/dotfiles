import QtQuick

QtObject {
    // Pointer-speed sampling for Start pin drag. Drop targeting lives in PinGrid.js.

    readonly property real slowEnter: 300
    readonly property real slowLeave: 480
    readonly property int slowHoldMs: 80
    readonly property real folderSpeedMin: 360
    readonly property real folderHitRatio: 0.34
    readonly property int folderHitMin: 18
    readonly property int stickyPad: 10

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
}

import QtQuick

Item {
    id: root

    property int code: 0
    property bool isDay: true
    property real size: 24
    property color color: "#f2f2f2"
    property bool animated: true

    implicitWidth: size
    implicitHeight: size

    readonly property real u: size / 24
    readonly property real dpr: {
        const win = Window.window;
        if (win && win.screen)
            return win.screen.devicePixelRatio;
        return Screen.devicePixelRatio;
    }
    readonly property string kind: classify(code, isDay)
    readonly property bool motion: animated && visible && opacity > 0.01

    readonly property bool showSun: kind === "clear-day" || kind === "partly-day"
    readonly property bool showMoon: kind === "clear-night" || kind === "partly-night"
    readonly property bool sunLarge: kind === "clear-day"
    readonly property bool moonLarge: kind === "clear-night"
    readonly property bool showFrontCloud: kind !== "clear-day" && kind !== "clear-night" && kind !== "fog"
    readonly property bool showRearCloud: kind === "cloudy" || kind === "rain" || kind === "light-rain" || kind === "heavy-rain" || snow
    readonly property bool showFog: kind === "fog"
    readonly property bool showBolt: kind === "thunder" || kind === "thunder-hail"
    readonly property bool snow: kind === "light-snow" || kind === "snow" || kind === "heavy-snow"
    readonly property bool hail: kind === "thunder-hail"

    readonly property int dropCount: {
        switch (kind) {
        case "drizzle":
            return 2;
        case "light-rain":
            return 3;
        case "rain":
            return 5;
        case "heavy-rain":
            return 6;
        case "light-snow":
            return 3;
        case "snow":
            return 4;
        case "heavy-snow":
            return 6;
        case "thunder":
        case "thunder-hail":
            return 2;
        default:
            return 0;
        }
    }

    readonly property int fallMs: {
        switch (kind) {
        case "drizzle":
            return 1400;
        case "light-rain":
            return 1150;
        case "rain":
            return 950;
        case "heavy-rain":
            return 720;
        case "light-snow":
            return 2600;
        case "snow":
            return 2200;
        case "heavy-snow":
            return 1600;
        case "thunder":
        case "thunder-hail":
            return 1200;
        default:
            return 1000;
        }
    }

    function classify(cCode, day) {
        const c = Number(cCode);
        if (c === 0 || c === 1)
            return day ? "clear-day" : "clear-night";
        if (c === 2)
            return day ? "partly-day" : "partly-night";
        if (c === 45 || c === 48)
            return "fog";
        if (c === 51 || c === 53 || c === 55 || c === 56 || c === 57)
            return "drizzle";
        if (c === 61 || c === 66 || c === 80)
            return "light-rain";
        if (c === 63 || c === 81)
            return "rain";
        if (c === 65 || c === 67 || c === 82)
            return "heavy-rain";
        if (c === 71 || c === 77 || c === 85)
            return "light-snow";
        if (c === 73)
            return "snow";
        if (c === 75 || c === 86)
            return "heavy-snow";
        if (c === 95)
            return "thunder";
        if (c === 96 || c === 99)
            return "thunder-hail";
        return "cloudy";
    }

    property real phaseOffset: 0
    property real floatPhase: 0
    property real fogPhase: 0
    property real boltFlash: 0.85

    readonly property real floatOffset: motion ? Math.sin(floatPhase + phaseOffset) * (0.25 * u) : 0

    NumberAnimation on floatPhase {
        from: 0
        to: Math.PI * 2
        duration: 4200
        loops: Animation.Infinite
        running: root.motion
    }

    NumberAnimation on fogPhase {
        from: 0
        to: Math.PI * 2
        duration: 4800
        loops: Animation.Infinite
        running: root.motion && root.showFog
    }

    SequentialAnimation {
        running: root.motion && root.showBolt
        loops: Animation.Infinite

        PauseAnimation {
            duration: 3800
        }
        NumberAnimation {
            target: root
            property: "boltFlash"
            to: 1.0
            duration: 60
        }
        PauseAnimation {
            duration: 50
        }
        NumberAnimation {
            target: root
            property: "boltFlash"
            to: 0.55
            duration: 50
        }
        NumberAnimation {
            target: root
            property: "boltFlash"
            to: 1.0
            duration: 70
        }
        NumberAnimation {
            target: root
            property: "boltFlash"
            to: 0.85
            duration: 250
        }
    }

    // =========================================================================
    // 1. SUN SPHERE (Windows 11 Warm Golden-Orange Diagonal Sphere)
    // =========================================================================
    Canvas {
        id: sunCanvas
        visible: root.showSun
        width: (root.sunLarge ? 18.5 : 17.5) * root.u
        height: width
        x: (root.sunLarge ? 2.75 : 1.2) * root.u
        y: ((root.sunLarge ? 2.75 : 1.4) * root.u) + root.floatOffset
        renderStrategy: Canvas.Cooperative
        antialiasing: true

        property real paintScale: root.dpr
        canvasSize: Qt.size(Math.max(1, Math.ceil(width * paintScale)), Math.max(1, Math.ceil(height * paintScale)))

        onPaintScaleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.setTransform(paintScale, 0, 0, paintScale, 0, 0);
            ctx.clearRect(0, 0, width, height);

            const cx = width / 2;
            const cy = height / 2;
            const r = width / 2;

            const grad = ctx.createLinearGradient(cx - r * 0.7, cy - r * 0.7, cx + r * 0.7, cy + r * 0.7);
            grad.addColorStop(0.0, "#ffcf00");
            grad.addColorStop(0.5, "#ff9d00");
            grad.addColorStop(1.0, "#ff6a00");

            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.arc(cx, cy, r - 0.5, 0, Math.PI * 2);
            ctx.fill();
        }
    }

    // =========================================================================
    // 2. MOON CRESCENT (Windows 11 Mathematically Exact Golden 3D Crescent)
    // =========================================================================
    Canvas {
        id: moonCanvas
        visible: root.showMoon
        width: (root.moonLarge ? 17.5 : 16.5) * root.u
        height: width
        x: (root.moonLarge ? 3.25 : 1.5) * root.u
        y: ((root.moonLarge ? 3.25 : 1.5) * root.u) + root.floatOffset
        renderStrategy: Canvas.Cooperative
        antialiasing: true

        property real paintScale: root.dpr
        canvasSize: Qt.size(Math.max(1, Math.ceil(width * paintScale)), Math.max(1, Math.ceil(height * paintScale)))

        onPaintScaleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.setTransform(paintScale, 0, 0, paintScale, 0, 0);
            ctx.clearRect(0, 0, width, height);

            const cx = width / 2;
            const cy = height / 2;
            const r = width / 2;

            const ox = -0.436 * r;
            const oy = -0.182 * r;
            const inR = 0.873 * r;

            const grad = ctx.createLinearGradient(cx - r * 0.5, cy - r * 0.6, cx + r * 0.7, cy + r * 0.7);
            grad.addColorStop(0.0, "#fffde7");
            grad.addColorStop(0.3, "#fff176");
            grad.addColorStop(0.7, "#ffb300");
            grad.addColorStop(1.0, "#ff8f00");

            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.arc(cx, cy, r - 0.5, -0.537 * Math.PI, 0.788 * Math.PI, false);
            ctx.arc(cx + ox, cy + oy, inR, 0.631 * Math.PI, -0.380 * Math.PI, true);
            ctx.closePath();
            ctx.fill();
        }
    }

    // =========================================================================
    // 3. REAR CLOUD (Atmospheric Sky Blue / Moody Rain Layer)
    // =========================================================================
    Canvas {
        id: rearCloudCanvas
        visible: root.showRearCloud
        width: 14.5 * root.u
        height: 10.2 * root.u
        x: 8.2 * root.u
        y: (root.dropCount > 0 ? 2.6 : 4.0) * root.u + root.floatOffset * 0.5
        renderStrategy: Canvas.Cooperative
        antialiasing: true

        property real paintScale: root.dpr
        canvasSize: Qt.size(Math.max(1, Math.ceil(width * paintScale)), Math.max(1, Math.ceil(height * paintScale)))

        onPaintScaleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.setTransform(paintScale, 0, 0, paintScale, 0, 0);
            ctx.clearRect(0, 0, width, height);

            const w = width;
            const h = height;

            const isRain = root.kind === "rain" || root.kind === "light-rain" || root.kind === "heavy-rain" || root.kind === "drizzle";
            const rearGrad = ctx.createLinearGradient(0, 0, 0, h);
            if (isRain) {
                rearGrad.addColorStop(0.0, "#94a3b8");
                rearGrad.addColorStop(1.0, "#475569");
            } else {
                rearGrad.addColorStop(0.0, "#c8e2fb");
                rearGrad.addColorStop(1.0, "#82baf6");
            }
            ctx.fillStyle = rearGrad;

            const rPill = h * 0.24;
            const pillY = h - rPill * 2;

            ctx.beginPath();
            ctx.arc(w - rPill, pillY + rPill, rPill, -Math.PI * 0.5, Math.PI * 0.5, false);
            ctx.arc(rPill, pillY + rPill, rPill, Math.PI * 0.5, Math.PI * 1.5, false);
            ctx.closePath();
            ctx.fill();

            ctx.beginPath();
            ctx.arc(w * 0.28, h * 0.54, h * 0.38, 0, Math.PI * 2);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(w * 0.54, h * 0.42, h * 0.46, 0, Math.PI * 2);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(w * 0.76, h * 0.60, h * 0.34, 0, Math.PI * 2);
            ctx.fill();
        }
    }

    // =========================================================================
    // 4. FRONT CLOUD (Pure White / Moody Silver-Slate Rain Cloud)
    // =========================================================================
    Canvas {
        id: frontCloudCanvas
        visible: root.showFrontCloud
        width: (root.showBolt ? 19.6 : (root.kind.indexOf("partly") === 0 ? 15.2 : 16.2)) * root.u
        height: (root.showBolt ? 12.0 : 11.2) * root.u
        x: (root.showBolt ? 2.2 : (root.kind.indexOf("partly") === 0 ? 8.0 : 3.4)) * root.u
        y: (root.showBolt ? 2.2 : (root.kind.indexOf("partly") === 0 ? 9.6 : (root.dropCount > 0 ? 3.6 : 6.6))) * root.u + root.floatOffset
        renderStrategy: Canvas.Cooperative
        antialiasing: true

        property real paintScale: root.dpr
        canvasSize: Qt.size(Math.max(1, Math.ceil(width * paintScale)), Math.max(1, Math.ceil(height * paintScale)))

        onPaintScaleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.setTransform(paintScale, 0, 0, paintScale, 0, 0);
            ctx.clearRect(0, 0, width, height);

            const w = width;
            const h = height;

            const isThunder = root.kind === "thunder" || root.kind === "thunder-hail";
            const isRain = root.kind === "rain" || root.kind === "light-rain" || root.kind === "heavy-rain" || root.kind === "drizzle";
            const frontGrad = ctx.createLinearGradient(0, 0, 0, h);
            if (isThunder) {
                frontGrad.addColorStop(0.0, "#eef1f6");
                frontGrad.addColorStop(0.5, "#cbd5e1");
                frontGrad.addColorStop(1.0, "#94a3b8");
            } else if (isRain) {
                frontGrad.addColorStop(0.0, "#e2e8f0");
                frontGrad.addColorStop(0.5, "#94a3b8");
                frontGrad.addColorStop(1.0, "#64748b");
            } else {
                frontGrad.addColorStop(0.0, "#ffffff");
                frontGrad.addColorStop(0.6, "#f8fafc");
                frontGrad.addColorStop(1.0, "#e2e8f0");
            }
            ctx.fillStyle = frontGrad;

            const rPill = h * 0.24;
            const pillY = h - rPill * 2;

            ctx.beginPath();
            ctx.arc(w - rPill, pillY + rPill, rPill, -Math.PI * 0.5, Math.PI * 0.5, false);
            ctx.arc(rPill, pillY + rPill, rPill, Math.PI * 0.5, Math.PI * 1.5, false);
            ctx.closePath();
            ctx.fill();

            ctx.beginPath();
            ctx.arc(w * 0.28, h * 0.54, h * 0.38, 0, Math.PI * 2);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(w * 0.54, h * 0.42, h * 0.46, 0, Math.PI * 2);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(w * 0.76, h * 0.60, h * 0.34, 0, Math.PI * 2);
            ctx.fill();
        }
    }

    // =========================================================================
    // 5. LIGHTNING BOLT (Windows 11 Centered Vibrant Golden-Orange Bolt)
    // =========================================================================
    Canvas {
        id: boltCanvas
        visible: root.showBolt
        opacity: root.boltFlash
        width: 6.8 * root.u
        height: 11.2 * root.u
        x: (24 - 6.8) / 2 * root.u
        y: 9.0 * root.u
        renderStrategy: Canvas.Cooperative
        antialiasing: true

        property real paintScale: root.dpr
        canvasSize: Qt.size(Math.max(1, Math.ceil(width * paintScale)), Math.max(1, Math.ceil(height * paintScale)))

        onPaintScaleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.setTransform(paintScale, 0, 0, paintScale, 0, 0);
            ctx.clearRect(0, 0, width, height);

            const grad = ctx.createLinearGradient(0, 0, width, height);
            grad.addColorStop(0.0, "#ffb300");
            grad.addColorStop(1.0, "#f57c00");
            ctx.fillStyle = grad;

            ctx.beginPath();
            ctx.moveTo(width * 0.45, 0);
            ctx.lineTo(width * 0.05, height * 0.52);
            ctx.lineTo(width * 0.48, height * 0.52);
            ctx.lineTo(width * 0.30, height);
            ctx.lineTo(width * 0.95, height * 0.44);
            ctx.lineTo(width * 0.58, height * 0.44);
            ctx.closePath();
            ctx.fill();
        }
    }

    // =========================================================================
    // 6. PRECIPITATION (Cyan Capsule Rain Pills / Snowballs)
    // =========================================================================
    Repeater {
        model: root.dropCount

        Item {
            id: dropItem
            required property int index

            property real animProg: 0
            readonly property bool isSnowflake: root.snow || (root.hail && index % 2 === 1)
            readonly property bool isStorm: root.showBolt

            // Signature 24-degree slant matching Windows 11 (/ orientation)
            readonly property real angleRad: 24 * Math.PI / 180
            readonly property real sinA: Math.sin(angleRad)
            readonly property real cosA: Math.cos(angleRad)

            // Flanked slots for storm (Windows 11 teardrops flanking the bolt)
            readonly property var stormSlotX: [5.6, 15.4]
            readonly property var stormSlotY: [15.6, 14.8]

            // Staggered slots for rain (Windows 11 staggered 2-row layout)
            readonly property var slotX: [6.8, 10.6, 14.4, 8.6, 12.4, 16.2]
            readonly property var slotY: [15.0, 15.0, 15.0, 17.6, 17.6, 17.6]

            readonly property real baseX: (isStorm ? stormSlotX[index % 2] : slotX[index % slotX.length]) * root.u
            readonly property real baseY: (isStorm ? stormSlotY[index % 2] : slotY[index % slotY.length]) * root.u
            readonly property real fallDist: (isStorm ? 1.8 : (dropItem.isSnowflake ? 3.6 : 2.8)) * root.u

            readonly property real progress: root.motion ? animProg : (0.2 + (index * 0.16) % 0.65)
            readonly property real sway: isSnowflake ? Math.sin(progress * Math.PI * 2 + index) * 1.4 * root.u : 0

            // Slide smoothly down-and-to-the-left along the 24-degree slant vector
            x: ((baseX + sway) - (progress * fallDist * sinA))
            y: baseY + (progress * fallDist * cosA)
            width: isStorm ? (3.4 * root.u) : (isSnowflake ? 2.4 * root.u : 1.8 * root.u)
            height: isStorm ? (3.4 * root.u) : (isSnowflake ? 2.4 * root.u : (root.kind === "heavy-rain" ? 5.2 : 4.4) * root.u)

            opacity: root.motion ? (0.3 + 0.7 * Math.sin(progress * Math.PI)) : 0.95

            // Storm: authentic Windows 11 teardrop flanking the bolt
            Canvas {
                id: stormTeardropCanvas
                visible: dropItem.isStorm
                anchors.fill: parent
                renderStrategy: Canvas.Cooperative
                antialiasing: true

                property real paintScale: root.dpr
                canvasSize: Qt.size(Math.max(1, Math.ceil(width * paintScale)), Math.max(1, Math.ceil(height * paintScale)))

                onPaintScaleChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.setTransform(paintScale, 0, 0, paintScale, 0, 0);
                    ctx.clearRect(0, 0, width, height);
                    const w = width;
                    const h = height;
                    ctx.fillStyle = "#00c2ff";
                    ctx.beginPath();
                    ctx.moveTo(w * 0.96, h * 0.04);
                    ctx.bezierCurveTo(w * 0.30, h * 0.25, 0, h * 0.50, w * 0.15, h * 0.85);
                    ctx.bezierCurveTo(w * 0.25, h * 1.0, w * 0.55, h * 0.98, w * 0.75, h * 0.80);
                    ctx.bezierCurveTo(w * 0.92, h * 0.62, w * 0.92, h * 0.30, w * 0.96, h * 0.04);
                    ctx.closePath();
                    ctx.fill();
                }
            }

            // Normal Rain / Snow / Hail
            Rectangle {
                visible: !dropItem.isStorm
                anchors.centerIn: parent
                width: dropItem.isSnowflake ? (2.4 * root.u) : Math.max(1.8, 1.8 * root.u)
                height: dropItem.isSnowflake ? (2.4 * root.u) : Math.max(3.8, (root.kind === "heavy-rain" ? 5.2 : 4.4) * root.u)
                radius: width / 2
                color: dropItem.isSnowflake ? "#ffffff" : "#00c2ff"
                rotation: dropItem.isSnowflake ? 0 : 24
                antialiasing: true
            }

            SequentialAnimation {
                running: root.motion

                PauseAnimation {
                    duration: (dropItem.index * 0.25) * root.fallMs
                }
                SequentialAnimation {
                    loops: Animation.Infinite
                    NumberAnimation {
                        target: dropItem
                        property: "animProg"
                        from: 0
                        to: 1
                        duration: root.fallMs
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }

    // =========================================================================
    // 7. FOG MIST BANDS
    // =========================================================================
    Repeater {
        model: root.showFog ? 3 : 0

        Rectangle {
            required property int index
            readonly property var bandW: [13.0, 18.0, 12.0]
            readonly property var bandY: [8.4, 12.4, 16.4]
            readonly property var bandA: [0.75, 1.0, 0.8]

            height: Math.max(2.4, 2.6 * root.u)
            radius: height / 2
            width: bandW[index] * root.u
            x: ((24 - bandW[index]) / 2) * root.u + (root.motion ? Math.sin(root.fogPhase + index * 1.4) * (1.6 * root.u) : 0)
            y: bandY[index] * root.u
            color: "#cbd5e1"
            opacity: bandA[index]
            antialiasing: true
        }
    }
}

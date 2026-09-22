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
    readonly property bool showCloud: kind !== "clear-day" && kind !== "clear-night" && kind !== "fog"
    readonly property bool showFog: kind === "fog"
    readonly property bool showBolt: kind === "thunder" || kind === "thunder-hail"
    readonly property bool snow: kind === "light-snow" || kind === "snow" || kind === "heavy-snow"
    readonly property bool hail: kind === "thunder-hail"
    readonly property bool precip: dropCount > 0
    readonly property int dropCount: {
        switch (kind) {
        case "drizzle":
            return 2;
        case "light-rain":
            return 3;
        case "rain":
            return 4;
        case "heavy-rain":
            return 5;
        case "light-snow":
            return 3;
        case "snow":
            return 4;
        case "heavy-snow":
            return 6;
        case "thunder":
            return 3;
        case "thunder-hail":
            return 4;
        default:
            return 0;
        }
    }
    readonly property int fallMs: {
        switch (kind) {
        case "drizzle":
            return 1500;
        case "light-rain":
            return 1000;
        case "rain":
            return 760;
        case "heavy-rain":
            return 500;
        case "light-snow":
            return 2500;
        case "snow":
            return 2000;
        case "heavy-snow":
            return 1500;
        case "thunder":
            return 800;
        case "thunder-hail":
            return 900;
        default:
            return 900;
        }
    }
    readonly property real cloudS: (kind === "partly-day" || kind === "partly-night") ? 0.84 : (precip ? 0.92 : 1)
    readonly property real cloudX: ((kind.indexOf("partly") === 0) ? 8.6 : (precip ? 3.4 : 3)) * u
    readonly property real cloudY: ((kind.indexOf("partly") === 0) ? 9.2 : (precip ? 0.8 : 6.5)) * u
    readonly property real sunCx: (sunLarge ? 12 : 8.3) * u
    readonly property real sunCy: (sunLarge ? 12 : 7.4) * u
    readonly property real discR: (sunLarge ? 3.55 : 2.7) * u
    readonly property real rayOrbit: (sunLarge ? 6.45 : 5.15) * u
    readonly property real rayLen: (sunLarge ? 3.2 : 2.3) * u
    readonly property real rayThick: Math.max(1, (sunLarge ? 1.45 : 1.15) * u)
    readonly property real glowR: (sunLarge ? 4.7 : 3.5) * u
    readonly property real moonBox: (moonLarge ? 14.5 : 10.5) * u
    readonly property real moonX: (moonLarge ? 4.75 : 1.1) * u
    readonly property real moonY: (moonLarge ? 4.75 : 1.15) * u
    readonly property real boltX: 8.3 * u
    readonly property real boltY: 11.2 * u

    property real glowPhase: 0
    property real driftPhase: 0
    property real fogPhase: 0
    property real boltFlash: 0

    readonly property real glowWave: 0.5 + 0.5 * Math.sin(glowPhase)
    readonly property real glowOpacity: {
        if (!showSun)
            return 0;
        if (!motion)
            return sunLarge ? 0.26 : 0.18;
        return sunLarge ? (0.10 + 0.32 * glowWave) : (0.08 + 0.18 * glowWave);
    }
    readonly property real rayOpacity: showSun ? (motion ? (0.62 + 0.38 * glowWave) : 1) : 0
    readonly property real moonOpacity: {
        if (!showMoon)
            return 0;
        if (!motion)
            return 1;
        return 0.8 + 0.2 * glowWave;
    }
    readonly property real driftAmp: {
        if (!showCloud)
            return 0;
        if (kind.indexOf("partly") === 0)
            return 1.3 * u;
        if (precip)
            return 0.35 * u;
        return 0.65 * u;
    }
    readonly property real drift: motion ? Math.sin(driftPhase) * driftAmp : 0
    readonly property real boltOpacity: {
        if (!showBolt)
            return 0;
        return motion ? Math.max(0.42, boltFlash) : 1;
    }

    function classify(code, day) {
        const c = Number(code);
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

    function slotX(index) {
        const table = showBolt ? [3.1, 6.0, 16.8, 19.5, 9.0, 13.6] : [3.5, 6.5, 9.6, 12.6, 15.7, 18.6];
        return table[index % table.length] * u;
    }

    function restProgress(index) {
        const table = [0.22, 0.5, 0.76, 0.36, 0.62, 0.88];
        return table[index % table.length];
    }

    clip: true

    NumberAnimation on glowPhase {
        from: 0
        to: Math.PI * 2
        duration: root.showSun && root.sunLarge ? 2800 : 4600
        loops: Animation.Infinite
        running: root.motion && (root.showSun || root.showMoon)
        easing.type: Easing.Linear
    }

    NumberAnimation on driftPhase {
        from: 0
        to: Math.PI * 2
        duration: 5600
        loops: Animation.Infinite
        running: root.motion && root.showCloud
        easing.type: Easing.Linear
    }

    NumberAnimation on fogPhase {
        from: 0
        to: Math.PI * 2
        duration: 7000
        loops: Animation.Infinite
        running: root.motion && root.showFog
        easing.type: Easing.Linear
    }

    SequentialAnimation {
        running: root.motion && root.showBolt
        loops: Animation.Infinite

        PauseAnimation {
            duration: 1900
        }
        NumberAnimation {
            target: root
            property: "boltFlash"
            to: 1
            duration: 35
        }
        PauseAnimation {
            duration: 55
        }
        NumberAnimation {
            target: root
            property: "boltFlash"
            to: 0.12
            duration: 30
        }
        NumberAnimation {
            target: root
            property: "boltFlash"
            to: 1
            duration: 30
        }
        NumberAnimation {
            target: root
            property: "boltFlash"
            to: 0
            duration: 180
        }
    }

    Canvas {
        id: moon
        visible: root.showMoon
        opacity: root.moonOpacity
        x: root.moonX
        y: root.moonY
        width: root.moonBox
        height: root.moonBox
        antialiasing: true
        renderStrategy: Canvas.Cooperative
        property color glyphColor: root.color
        property real paintScale: root.dpr
        canvasSize: Qt.size(Math.max(1, Math.ceil(width * paintScale)), Math.max(1, Math.ceil(height * paintScale)))
        onGlyphColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaintScaleChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.setTransform(paintScale, 0, 0, paintScale, 0, 0);
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = glyphColor;
            const cx = width * 0.42;
            const cy = height * 0.50;
            const r = width * 0.38;
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0.55 * Math.PI, 1.45 * Math.PI, false);
            ctx.arc(cx + r * 0.47, cy - r * 0.06, r * 0.88, 1.35 * Math.PI, 0.65 * Math.PI, true);
            ctx.closePath();
            ctx.fill();
        }
    }

    Rectangle {
        visible: root.showSun
        width: root.glowR * 2
        height: width
        radius: width / 2
        x: root.sunCx - width / 2
        y: root.sunCy - height / 2
        color: root.color
        opacity: root.glowOpacity
        antialiasing: true
    }

    Repeater {
        model: root.showSun ? 8 : 0

        Rectangle {
            required property int index
            property real ang: index * Math.PI / 4
            width: root.rayLen
            height: root.rayThick
            radius: height / 2
            x: root.sunCx + Math.cos(ang) * root.rayOrbit - width / 2
            y: root.sunCy + Math.sin(ang) * root.rayOrbit - height / 2
            rotation: index * 45
            color: root.color
            opacity: root.rayOpacity
            antialiasing: true
        }
    }

    Rectangle {
        visible: root.showSun
        width: root.discR * 2
        height: width
        radius: width / 2
        x: root.sunCx - width / 2
        y: root.sunCy - height / 2
        color: root.color
        antialiasing: true
    }

    Canvas {
        id: cloud
        visible: root.showCloud
        x: root.cloudX + root.drift
        y: root.cloudY
        width: 18 * root.u * root.cloudS
        height: 11 * root.u * root.cloudS
        antialiasing: true
        renderStrategy: Canvas.Cooperative
        property color glyphColor: root.color
        property real paintScale: root.dpr
        canvasSize: Qt.size(Math.max(1, Math.ceil(width * paintScale)), Math.max(1, Math.ceil(height * paintScale)))
        onGlyphColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaintScaleChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.setTransform(paintScale, 0, 0, paintScale, 0, 0);
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = glyphColor;
            const w = width;
            const h = height;
            ctx.beginPath();
            ctx.ellipse(w * 0.04, h * 0.40, w * 0.40, h * 0.58);
            ctx.fill();
            ctx.beginPath();
            ctx.ellipse(w * 0.28, h * 0.02, w * 0.48, h * 0.82);
            ctx.fill();
            ctx.beginPath();
            ctx.ellipse(w * 0.58, h * 0.30, w * 0.38, h * 0.62);
            ctx.fill();
            ctx.beginPath();
            ctx.roundRect(w * 0.08, h * 0.52, w * 0.84, h * 0.46, h * 0.23);
            ctx.fill();
        }
    }

    Repeater {
        model: root.dropCount

        Item {
            id: bit
            required property int index
            property real animProgress: 0
            readonly property bool flake: root.snow || (root.hail && index % 2 === 0)
            readonly property real progress: root.motion ? animProgress : root.restProgress(index)
            readonly property real sway: flake ? Math.sin(progress * Math.PI * 2 + index) * 1.2 * root.u : 0
            readonly property real bitW: Math.max(1.15, (flake ? 2.7 : (root.kind === "heavy-rain" ? 1.55 : 1.25)) * root.u)
            readonly property real bitH: Math.max(bitW, (flake ? 2.7 : (root.kind === "drizzle" ? 3.1 : root.kind === "heavy-rain" ? 5.1 : 4.0)) * root.u)
            x: root.slotX(index) + sway
            y: 11.2 * root.u + progress * 9.6 * root.u
            width: bitW
            height: bitH
            opacity: {
                const fadeIn = progress / 0.08;
                const fadeOut = (1 - progress) / 0.12;
                return Math.max(0, Math.min(1, fadeIn, fadeOut));
            }

            Rectangle {
                anchors.fill: parent
                radius: bit.flake ? width / 2 : width / 2
                color: root.color
                rotation: bit.flake ? 0 : 12
                antialiasing: true
            }

            SequentialAnimation {
                running: root.motion

                PauseAnimation {
                    duration: bit.index * Math.round(root.fallMs / Math.max(2, root.dropCount))
                }
                SequentialAnimation {
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: bit
                        property: "animProgress"
                        from: 0
                        to: 1
                        duration: root.fallMs
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }

    Canvas {
        id: bolt
        visible: root.showBolt
        opacity: root.boltOpacity
        x: root.boltX
        y: root.boltY
        width: 7.6 * root.u
        height: 9.6 * root.u
        antialiasing: true
        renderStrategy: Canvas.Cooperative
        property color glyphColor: root.color
        property real paintScale: root.dpr
        canvasSize: Qt.size(Math.max(1, Math.ceil(width * paintScale)), Math.max(1, Math.ceil(height * paintScale)))
        onGlyphColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaintScaleChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.setTransform(paintScale, 0, 0, paintScale, 0, 0);
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = glyphColor;
            const w = width;
            const h = height;
            ctx.beginPath();
            ctx.moveTo(w * 0.55, 0);
            ctx.lineTo(w * 0.08, h * 0.54);
            ctx.lineTo(w * 0.42, h * 0.54);
            ctx.lineTo(w * 0.16, h);
            ctx.lineTo(w * 0.98, h * 0.38);
            ctx.lineTo(w * 0.56, h * 0.38);
            ctx.closePath();
            ctx.fill();
        }
    }

    Repeater {
        model: root.showFog ? 3 : 0

        Rectangle {
            required property int index
            readonly property var bandW: [11.5, 16, 9.5]
            readonly property var bandX: [6.2, 3.2, 8.2]
            readonly property var bandY: [6.2, 11, 15.6]
            readonly property var bandA: [0.4, 0.78, 0.5]
            height: Math.max(1.2, 1.7 * root.u)
            radius: height / 2
            width: bandW[index] * root.u
            x: bandX[index] * root.u + (root.motion ? Math.sin(root.fogPhase + index * 1.3) * 2.1 * root.u : 0)
            y: bandY[index] * root.u
            color: root.color
            opacity: bandA[index]
            antialiasing: true
        }
    }
}

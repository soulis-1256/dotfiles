import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool isExpanded: false
    property bool isDragging: false
    property string draggedWindowAddr: ""
    property string activeZone: ""
    property string activeZoneName: ""
    property string lastActiveZone: ""
    property string activeScreenName: ""
    property int lastDragGx: 0
    property int lastDragGy: 0
    property int dragStartMouseX: -1
    property int dragStartMouseY: -1
    property bool restoredThisDrag: false

    readonly property color winBg: Theme.popupLayerColor(Theme.surfaceContainer)
    readonly property color winText: Theme.surfaceText
    readonly property color winMuted: Theme.surfaceVariantText
    readonly property color winAccent: Theme.primary
    readonly property color winBorder: Theme.outlineVariant

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (!event) return;
            if (event.name === "dragstart") {
                root.draggedWindowAddr = event.data || "";
                root.isDragging = true;
                root.isExpanded = false;
                root.lastActiveZone = "";
                root.activeScreenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
                root.dragStartMouseX = -1;
                root.dragStartMouseY = -1;
                root.restoredThisDrag = false;
            } else if (event.name === "dragstop") {
                var targetZone = root.activeZone !== "" ? root.activeZone : root.lastActiveZone;
                if (targetZone !== "") {
                    root.triggerSnap(targetZone);
                } else {
                    var droppedAddr = root.draggedWindowAddr;
                    var dropX = root.lastDragGx;
                    var dropY = root.lastDragGy;
                    if (droppedAddr && droppedAddr !== "") {
                        root.restoreWindowPreSnapSize(droppedAddr, dropX, dropY);
                    }
                    root.forceCollapse();
                    root.isDragging = false;
                    root.draggedWindowAddr = "";
                    root.activeScreenName = "";
                    root.lastActiveZone = "";
                }
            } else if (event.name === "dragpos") {
                if (!root.isDragging) return;
                root.handleDragPos(event.data);
            }
        }
    }

    function detectFlyoutBox(relX, relY) {
        if (relY < 12 || relY > 72) return "";

        // Card 1: 50 / 50
        if (relX >= 16 && relX <= 112) {
            if (relX <= 62) return "half-left";
            if (relX >= 66) return "half-right";
            return "";
        }

        // Card 2: 67 / 33
        if (relX >= 120 && relX <= 216) {
            if (relX <= 180) return "left-two-thirds";
            if (relX >= 183) return "right-one-third";
            return "";
        }

        // Card 3: 3 Columns
        if (relX >= 224 && relX <= 320) {
            if (relX <= 253) return "col-1";
            if (relX >= 256 && relX <= 286) return "col-2";
            if (relX >= 289) return "col-3";
            return "";
        }

        // Card 4: 4 Quadrants
        if (relX >= 328 && relX <= 424) {
            var isLeft = relX <= 373;
            var isRight = relX >= 376;
            if (!isLeft && !isRight) return "";

            if (relY >= 14 && relY <= 40) {
                return isLeft ? "top-left" : "top-right";
            }
            if (relY >= 44 && relY <= 70) {
                return isLeft ? "bottom-left" : "bottom-right";
            }
            return "";
        }

        return "";
    }

    function handleDragPos(data) {
        if (!data || data === "") return;
        var parts = data.split(",");
        if (parts.length < 2) return;
        var gx = parseInt(parts[0]);
        var gy = parseInt(parts[1]);
        root.lastDragGx = gx;
        root.lastDragGy = gy;

        if (root.dragStartMouseX < 0) {
            root.dragStartMouseX = gx;
            root.dragStartMouseY = gy;
        }

        // Mid-drag unsnap: if snapped window dragged away (> 20px), restore immediately
        if (!root.restoredThisDrag && root.draggedWindowAddr !== "") {
            var dist = Math.hypot(gx - root.dragStartMouseX, gy - root.dragStartMouseY);
            if (dist > 20) {
                root.restoreWindowPreSnapSize(root.draggedWindowAddr, gx, gy);
                root.restoredThisDrag = true;
            }
        }

        for (var i = 0; i < Quickshell.screens.length; i++) {
            var s = Quickshell.screens[i];
            if (gx >= s.x && gx < s.x + s.width && gy >= s.y && gy < s.y + s.height) {
                if (root.activeScreenName !== s.name) {
                    root.activeScreenName = s.name;
                    root.activeZone = "";
                    root.activeZoneName = "";
                    root.lastActiveZone = "";
                }

                var localX = gx - s.x;
                var localY = gy - s.y;
                var centerX = s.width / 2;

                // 1. If flyout is currently expanded:
                if (root.isExpanded) {
                    var cardLeft = centerX - 220;
                    var cardRight = centerX + 220;
                    var cardTop = 8;
                    var cardBottom = 130;

                    if (localX < cardLeft - 15 || localX > cardRight + 15 || localY < cardTop - 4 || localY > cardBottom + 15) {
                        root.forceCollapse();
                    } else {
                        collapseTimer.stop();
                        var detected = root.detectFlyoutBox(localX - cardLeft, localY - cardTop);
                        if (detected !== "") {
                            root.setZone(detected);
                        } else {
                            root.activeZone = "";
                            root.activeZoneName = "";
                            root.lastActiveZone = "";
                        }
                        return;
                    }
                }

                // 2. If flyout is collapsed:
                // A. Check explicit hover on the collapsed pill handle (centered, top: 8, h: 22, w: 200)
                if (localY >= 8 && localY <= 32 && Math.abs(localX - centerX) <= 100) {
                    root.expand();
                    return;
                }

                // B. Edge & Corner Snapping (Windows 11):
                // Top screen edge (above the flyout: localY <= 7) -> Maximize
                if (localY <= 7) {
                    root.setZone("maximize");
                    return;
                }

                // Left screen edge (localX <= 20)
                if (localX <= 20) {
                    if (localY <= 150) {
                        root.setZone("top-left");
                    } else if (localY >= s.height - 150) {
                        root.setZone("bottom-left");
                    } else {
                        root.setZone("half-left");
                    }
                    return;
                }

                // Right screen edge (localX >= s.width - 20)
                if (localX >= s.width - 20) {
                    if (localY <= 150) {
                        root.setZone("top-right");
                    } else if (localY >= s.height - 150) {
                        root.setZone("bottom-right");
                    } else {
                        root.setZone("half-right");
                    }
                    return;
                }

                // Otherwise, outside all snap triggers:
                if (root.activeZone !== "") {
                    root.activeZone = "";
                    root.activeZoneName = "";
                    root.lastActiveZone = "";
                }
                break;
            }
        }
    }

    function toggle() {
        if (root.isExpanded) {
            root.forceCollapse();
        } else {
            root.expand();
        }
    }

    function expand() {
        collapseTimer.stop();
        root.isExpanded = true;
    }

    function collapse() {
        collapseTimer.restart();
    }

    function forceCollapse() {
        collapseTimer.stop();
        root.isExpanded = false;
        root.activeZone = "";
        root.activeZoneName = "";
    }

    function setZone(zone) {
        root.activeZone = zone;
        if (zone && zone !== "") root.lastActiveZone = zone;
        switch (zone) {
        case "half-left": root.activeZoneName = "Left 50%"; break;
        case "half-right": root.activeZoneName = "Right 50%"; break;
        case "left-two-thirds": root.activeZoneName = "Left 67%"; break;
        case "right-one-third": root.activeZoneName = "Right 33%"; break;
        case "col-1": root.activeZoneName = "Column 1 (33%)"; break;
        case "col-2": root.activeZoneName = "Center 33%"; break;
        case "col-3": root.activeZoneName = "Column 3 (33%)"; break;
        case "top-left": root.activeZoneName = "Top-Left 25%"; break;
        case "top-right": root.activeZoneName = "Top-Right 25%"; break;
        case "bottom-left": root.activeZoneName = "Bottom-Left 25%"; break;
        case "bottom-right": root.activeZoneName = "Bottom-Right 25%"; break;
        case "maximize": root.activeZoneName = "Maximize Work Area"; break;
        case "center": root.activeZoneName = "Center Float"; break;
        case "tile": root.activeZoneName = "Re-Tile"; break;
        default: root.activeZoneName = ""; break;
        }
    }

    Timer {
        id: snapTimer
        interval: 35
        repeat: false
        property string targetZone: ""
        property string targetAddr: ""
        property string targetScreenName: ""

        onTriggered: {
            var zone = targetZone;
            var addr = targetAddr;
            var screenName = targetScreenName;
            if (!zone || zone === "") return;

            // Find screen geometry
            var targetScreen = null;
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === screenName) {
                    targetScreen = Quickshell.screens[i];
                    break;
                }
            }
            if (!targetScreen) {
                for (var j = 0; j < Quickshell.screens.length; j++) {
                    if (Quickshell.screens[j].name === Hyprland.focusedMonitor?.name) {
                        targetScreen = Quickshell.screens[j];
                        break;
                    }
                }
            }
            if (!targetScreen && Quickshell.screens.length > 0) {
                targetScreen = Quickshell.screens[0];
            }

            // 1. Focus the dragged window
            if (addr && addr !== "") {
                Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + addr + "\" })");
            }

            // 2. Always ensure fullscreen is unset so the bottom bar remains visible
            Hyprland.dispatch("hl.dsp.window.fullscreen({ action = \"unset\" })");

            // 4. Position and size to exact snap layout bounds
            if (targetScreen) {
                var bounds = root.getZoneBounds(zone, targetScreen.width, targetScreen.height);
                var globalX = targetScreen.x + bounds.x;
                var globalY = targetScreen.y + bounds.y;

                if (addr && addr !== "") {
                    var luaEnsureFloat = "(function() " +
                        "local w = hl.get_window(\"address:" + addr + "\"); " +
                        "if w then " +
                            "_G.win11_snap_cache = _G.win11_snap_cache or {}; " +
                            "if not _G.win11_snap_cache[\"" + addr + "\"] then " +
                                "_G.win11_snap_cache[\"" + addr + "\"] = { w = w.size.x, h = w.size.y }; " +
                            "end; " +
                            "hl.dispatch(hl.dsp.focus({ window = \"address:" + addr + "\" })); " +
                            "if not w.floating then " +
                                "hl.dispatch(hl.dsp.window.float({ action = \"set\" })); " +
                            "end; " +
                        "end; " +
                        "return hl.dsp.no_op() " +
                    "end)()";
                    Hyprland.dispatch(luaEnsureFloat);
                }
                Hyprland.dispatch("hl.dsp.window.resize({ x = " + bounds.width + ", y = " + bounds.height + " })");
                Hyprland.dispatch("hl.dsp.window.move({ x = " + globalX + ", y = " + globalY + " })");
            }
        }
    }

    function restoreWindowPreSnapSize(addr, posX, posY) {
        if (!addr || addr === "") return;
        var luaRestore = "(function() " +
            "if _G.win11_snap_cache and _G.win11_snap_cache[\"" + addr + "\"] then " +
                "local s = _G.win11_snap_cache[\"" + addr + "\"]; " +
                "_G.win11_snap_cache[\"" + addr + "\"] = nil; " +
                "local newX = math.max(10, " + posX + " - math.floor(s.w / 2)); " +
                "local newY = math.max(10, " + posY + " - 20); " +
                "hl.dispatch(hl.dsp.focus({ window = \"address:" + addr + "\" })); " +
                "hl.dispatch(hl.dsp.window.resize({ x = s.w, y = s.h })); " +
                "hl.dispatch(hl.dsp.window.move({ x = newX, y = newY })); " +
            "end; " +
            "return hl.dsp.no_op() " +
        "end)()";
        Hyprland.dispatch(luaRestore);
    }

    function triggerSnap(zone) {
        if (!zone || zone === "") return;
        var addr = root.draggedWindowAddr;
        var sName = root.activeScreenName;
        root.forceCollapse();
        root.isDragging = false;
        root.draggedWindowAddr = "";
        root.activeScreenName = "";
        root.lastActiveZone = "";

        snapTimer.targetZone = zone;
        snapTimer.targetAddr = addr;
        snapTimer.targetScreenName = sName;
        snapTimer.restart();
    }

    function getZoneBounds(zone, screenWidth, screenHeight) {
        var barH = 52;
        var usableH = screenHeight - barH;
        var gap = 8;
        var w = screenWidth;
        var h = usableH;
        var halfW = Math.round(w / 2);
        var halfH = Math.round(h / 2);
        var twoThirdsW = Math.round(w * 0.67);
        var oneThirdW = Math.round(w / 3);

        switch (zone) {
        case "half-left":
        case "left":
            return { x: gap, y: gap, width: halfW - (gap * 1.5), height: h - (gap * 2) };
        case "half-right":
        case "right":
            return { x: halfW + (gap * 0.5), y: gap, width: halfW - (gap * 1.5), height: h - (gap * 2) };
        case "left-two-thirds":
            return { x: gap, y: gap, width: twoThirdsW - (gap * 1.5), height: h - (gap * 2) };
        case "right-one-third":
            return { x: twoThirdsW + (gap * 0.5), y: gap, width: (w - twoThirdsW) - (gap * 1.5), height: h - (gap * 2) };
        case "col-1":
            return { x: gap, y: gap, width: oneThirdW - (gap * 1.5), height: h - (gap * 2) };
        case "col-2":
            return { x: oneThirdW + (gap * 0.5), y: gap, width: oneThirdW - gap, height: h - (gap * 2) };
        case "col-3":
            return { x: (oneThirdW * 2) + (gap * 0.5), y: gap, width: (w - (oneThirdW * 2)) - (gap * 1.5), height: h - (gap * 2) };
        case "top-left":
            return { x: gap, y: gap, width: halfW - (gap * 1.5), height: halfH - (gap * 1.5) };
        case "top-right":
            return { x: halfW + (gap * 0.5), y: gap, width: halfW - (gap * 1.5), height: halfH - (gap * 1.5) };
        case "bottom-left":
            return { x: gap, y: halfH + (gap * 0.5), width: halfW - (gap * 1.5), height: halfH - (gap * 1.5) };
        case "bottom-right":
            return { x: halfW + (gap * 0.5), y: halfH + (gap * 0.5), width: halfW - (gap * 1.5), height: halfH - (gap * 1.5) };
        case "maximize":
            return { x: gap, y: gap, width: w - (gap * 2), height: h - (gap * 2) };
        default:
            return { x: 0, y: 0, width: 0, height: 0 };
        }
    }

    Timer {
        id: collapseTimer
        interval: 350
        repeat: false
        onTriggered: {
            root.forceCollapse();
        }
    }

    // 1. Fullscreen Snap Ghost / Preview Overlay
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: previewWin
            required property var modelData

            screen: modelData
            visible: root.isDragging && root.activeZone !== "" && root.activeScreenName === modelData.name
            mask: Region {}

            WlrLayershell.namespace: "dms:win11-snap-preview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            readonly property var bounds: root.getZoneBounds(root.activeZone, modelData.width, modelData.height)

            Rectangle {
                id: ghostRect
                x: previewWin.bounds.x
                y: previewWin.bounds.y
                width: previewWin.bounds.width
                height: previewWin.bounds.height
                radius: 12
                color: Qt.rgba(root.winAccent.r, root.winAccent.g, root.winAccent.b, 0.18)
                border.color: root.winAccent
                border.width: 2

                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                opacity: root.activeZone !== "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                Rectangle {
                    anchors.centerIn: parent
                    width: zoneBadgeText.implicitWidth + 28
                    height: 38
                    radius: 19
                    color: Theme.popupLayerColor(Theme.surfaceContainer)
                    border.color: root.winAccent
                    border.width: 1

                    StyledText {
                        id: zoneBadgeText
                        anchors.centerIn: parent
                        text: root.activeZoneName
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: root.winAccent
                    }
                }
            }
        }
    }

    // 2. Centered Top Snap Bar
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: snapWin
            required property var modelData

            screen: modelData
            visible: root.isDragging && root.activeScreenName === modelData.name

            WlrLayershell.namespace: "dms:win11-snap-bar"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            color: "transparent"

            anchors {
                top: true
                left: true
            }

            margins {
                left: Math.round((modelData.width - snapWin.width) / 2)
                top: 8
            }

            width: 480
            implicitHeight: root.isExpanded ? 120 : 20
            height: implicitHeight

            Item {
                id: barContainer
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: parent.height

                // Visual pill / card
                Rectangle {
                    id: cardBg
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.isExpanded ? 440 : 200
                    height: root.isExpanded ? 114 : 14
                    radius: root.isExpanded ? 10 : 7
                    color: root.isExpanded ? root.winBg : Qt.rgba(root.winAccent.r, root.winAccent.g, root.winAccent.b, 0.95)
                    border.color: root.winAccent
                    border.width: 1

                    Behavior on width {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on radius {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    // Hover area strictly bounded to the pill/card
                    MouseArea {
                        id: cardHoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton

                        onContainsMouseChanged: {
                            if (containsMouse) {
                                collapseTimer.stop();
                                root.expand();
                            } else {
                                root.collapse();
                            }
                        }
                    }

                    // Collapsed grip pill
                    Rectangle {
                        anchors.centerIn: parent
                        width: 44
                        height: 3
                        radius: 1.5
                        color: "#ffffff"
                        visible: !root.isExpanded
                    }

                    // Expanded Snap Layouts View
                    Item {
                        id: expandedContent
                        z: 2
                        anchors.fill: parent
                        anchors.margins: 10
                        visible: root.isExpanded
                        opacity: root.isExpanded ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                        }

                        Column {
                            anchors.fill: parent
                            spacing: 6

                            // 4 Layout Cards
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8

                                // Card 1: 50 / 50 Split
                                LayoutCard {
                                    width: 96
                                    height: 60

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 3

                                        ZoneTile {
                                            width: (parent.width - 3) / 2
                                            height: parent.height
                                            zone: "half-left"
                                        }

                                        ZoneTile {
                                            width: (parent.width - 3) / 2
                                            height: parent.height
                                            zone: "half-right"
                                        }
                                    }
                                }

                                // Card 2: 67 / 33 Priority Split
                                LayoutCard {
                                    width: 96
                                    height: 60

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 3

                                        ZoneTile {
                                            width: Math.round((parent.width - 3) * 0.65)
                                            height: parent.height
                                            zone: "left-two-thirds"
                                        }

                                        ZoneTile {
                                            width: parent.width - 3 - Math.round((parent.width - 3) * 0.65)
                                            height: parent.height
                                            zone: "right-one-third"
                                        }
                                    }
                                }

                                // Card 3: 3 Columns
                                LayoutCard {
                                    width: 96
                                    height: 60

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 3

                                        ZoneTile {
                                            width: (parent.width - 6) / 3
                                            height: parent.height
                                            zone: "col-1"
                                        }

                                        ZoneTile {
                                            width: (parent.width - 6) / 3
                                            height: parent.height
                                            zone: "col-2"
                                        }

                                        ZoneTile {
                                            width: (parent.width - 6) / 3
                                            height: parent.height
                                            zone: "col-3"
                                        }
                                    }
                                }

                                // Card 4: 4 Quadrants
                                LayoutCard {
                                    width: 96
                                    height: 60

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 3

                                        Row {
                                            width: parent.width
                                            height: (parent.height - 3) / 2
                                            spacing: 3

                                            ZoneTile {
                                                width: (parent.width - 3) / 2
                                                height: parent.height
                                                zone: "top-left"
                                            }

                                            ZoneTile {
                                                width: (parent.width - 3) / 2
                                                height: parent.height
                                                zone: "top-right"
                                            }
                                        }

                                        Row {
                                            width: parent.width
                                            height: (parent.height - 3) / 2
                                            spacing: 3

                                            ZoneTile {
                                                width: (parent.width - 3) / 2
                                                height: parent.height
                                                zone: "bottom-left"
                                            }

                                            ZoneTile {
                                                width: (parent.width - 3) / 2
                                                height: parent.height
                                                zone: "bottom-right"
                                            }
                                        }
                                    }
                                }
                            }

                            // Dynamic Hint Text
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.activeZoneName !== "" ? root.activeZoneName : "Hover a zone to preview, drop to snap"
                                font.pixelSize: 11
                                font.weight: root.activeZoneName !== "" ? Font.DemiBold : Font.Normal
                                color: root.activeZoneName !== "" ? root.winAccent : root.winMuted
                            }
                        }
                    }
                }
            }

            // Card Component
            component LayoutCard: Rectangle {
                radius: 6
                color: Qt.rgba(root.winText.r, root.winText.g, root.winText.b, 0.05)
                border.color: Qt.rgba(root.winText.r, root.winText.g, root.winText.b, 0.14)
                border.width: 1
                clip: true
            }

            // Zone Tile Component
            component ZoneTile: Rectangle {
                id: tile
                property string zone: ""
                readonly property bool isTargeted: (root.activeZone === tile.zone) || tileMouse.containsMouse

                radius: 3
                color: isTargeted ? root.winAccent : Qt.rgba(root.winText.r, root.winText.g, root.winText.b, 0.12)
                border.color: isTargeted ? root.winAccent : Qt.rgba(root.winText.r, root.winText.g, root.winText.b, 0.20)
                border.width: 1

                Behavior on color {
                    ColorAnimation { duration: 100; easing.type: Easing.OutQuad }
                }

                MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton

                    onContainsMouseChanged: {
                        if (containsMouse) {
                            collapseTimer.stop();
                            root.setZone(tile.zone);
                        } else {
                            if (root.activeZone === tile.zone) {
                                root.activeZone = "";
                                root.activeZoneName = "";
                                root.lastActiveZone = "";
                            }
                        }
                    }

                    onPositionChanged: {
                        if (containsMouse && root.activeZone !== tile.zone) {
                            collapseTimer.stop();
                            root.setZone(tile.zone);
                        }
                    }
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    WindowBlur {
        targetWindow: root
        blurX: card.x
        blurY: card.y
        blurWidth: root.visible ? card.width : 0
        blurHeight: root.visible ? card.height : 0
        blurRadius: Theme.cornerRadius
    }

    WlrLayershell.namespace: "dms:workspace-app-preview"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property var windows: []
    property string appTitle: ""
    property string appIcon: ""
    property bool isVertical: false
    property string edge: "bottom"
    property point anchorPos: Qt.point(0, 0)
    property bool hovered: previewHover.hovered

    readonly property real thumbMaxW: 520
    readonly property real thumbMaxH: 300
    readonly property real thumbGap: Theme.spacingM

    function showAt(x, y, vertical, barEdge, windowList, title, icon, targetScreen) {
        if (targetScreen)
            root.screen = targetScreen;

        anchorPos = Qt.point(x, y);
        isVertical = vertical ?? false;
        edge = barEdge ?? "bottom";
        windows = windowList || [];
        appTitle = title || "";
        appIcon = icon || "";
        visible = windows.length > 0;
    }

    function close() {
        visible = false;
        windows = [];
    }

    function thumbSizeFor(win) {
        const ipc = win?.hypr?.lastIpcObject || win?.toplevel?.lastIpcObject || null;
        const size = ipc?.size;
        let w = (size && size[0]) ? size[0] : 1280;
        let h = (size && size[1]) ? size[1] : 800;
        if (w <= 0)
            w = 1280;
        if (h <= 0)
            h = 800;
        const scale = Math.min(root.thumbMaxW / w, root.thumbMaxH / h);
        return Qt.size(Math.max(320, Math.round(w * scale)), Math.max(180, Math.round(h * scale)));
    }

    function captureSourceFor(win) {
        if (!win)
            return null;
        const t = win.toplevel || win.wayland || win.hypr;
        if (!t)
            return null;
        return t.wayland || t;
    }

    function focusWindow(win) {
        const address = win?.address || win?.hypr?.address || "";
        if (CompositorService.isHyprland && address) {
            HyprlandService.focusWindow(address);
        } else if (win?.toplevel?.activate) {
            win.toplevel.activate();
        }
        root.close();
    }

    screen: null
    visible: false
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Only the card takes input. A full-screen overlay would steal hover
    // from the workspace icon and flicker the preview on/off.
    mask: Region {
        item: card
    }

    Connections {
        target: PopoutManager
        function onPopoutOpening() {
            root.close();
        }
    }

    Rectangle {
        id: card
        width: thumbsRow.implicitWidth + Theme.spacingM * 2
        height: thumbsRow.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.floatingSurface
        border.color: BlurService.borderColor
        border.width: BlurService.borderWidth
        visible: root.visible && root.windows.length > 0
        opacity: visible ? 1 : 0

        x: {
            if (root.isVertical) {
                if (root.edge === "left")
                    return Math.min(root.width - width - 10, root.anchorPos.x);
                return Math.max(10, root.anchorPos.x - width);
            }
            const left = 10;
            const right = root.width - width - 10;
            return Math.max(left, Math.min(right, root.anchorPos.x - width / 2));
        }
        y: {
            if (root.isVertical) {
                const top = 10;
                const bottom = root.height - height - 10;
                return Math.max(top, Math.min(bottom, root.anchorPos.y - height / 2));
            }
            if (root.edge === "top")
                return Math.min(root.height - height - 10, root.anchorPos.y);
            return Math.max(10, root.anchorPos.y - height);
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        HoverHandler {
            id: previewHover
            blocking: false
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        }

        Row {
            id: thumbsRow
            anchors.centerIn: parent
            spacing: root.thumbGap

            Repeater {
                model: root.windows

                Rectangle {
                    id: thumbCard
                    required property var modelData
                    required property int index

                    readonly property var thumbSize: root.thumbSizeFor(modelData)
                    readonly property var captureSource: root.captureSourceFor(modelData)
                    readonly property string winTitle: modelData.windowTitle || modelData.toplevel?.title || root.appTitle || ""

                    width: thumbSize.width
                    height: thumbSize.height + titleLabel.height + Theme.spacingXS
                    radius: Theme.cornerRadius
                    color: thumbClick.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : "transparent"
                    border.width: 1
                    border.color: thumbClick.containsMouse ? Theme.primary : Theme.withAlpha(Theme.outline, 0.35)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: Theme.spacingXS

                        ClippingRectangle {
                            id: clipper
                            width: parent.width
                            height: thumbCard.thumbSize.height - 8
                            radius: Theme.cornerRadius - 2
                            color: Theme.surfaceContainerHigh

                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: root.visible ? thumbCard.captureSource : null
                                live: root.visible
                                visible: thumbCard.captureSource
                            }

                            IconImage {
                                anchors.centerIn: parent
                                width: Math.min(48, parent.width * 0.35)
                                height: width
                                source: root.appIcon
                                visible: !thumbCard.captureSource && root.appIcon !== ""
                            }
                        }

                        StyledText {
                            id: titleLabel
                            width: parent.width
                            text: thumbCard.winTitle
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    MouseArea {
                        id: thumbClick
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        z: -1
                        onClicked: root.focusWindow(thumbCard.modelData)
                    }
                }
            }
        }
    }
}

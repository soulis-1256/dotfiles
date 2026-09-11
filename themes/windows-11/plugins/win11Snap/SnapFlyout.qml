import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var closePopout: null
    property var parentPopout: null
    property string activeTargetAddress: ""
    property string activeHint: ""

    readonly property color winBg: Theme.popupLayerColor(Theme.surfaceContainer)
    readonly property color winText: Theme.surfaceText
    readonly property color winMuted: Theme.surfaceVariantText
    readonly property color winAccent: Theme.primary
    readonly property color winHover: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
    readonly property real winRadius: 8

    implicitWidth: 388
    implicitHeight: 184
    width: implicitWidth
    height: implicitHeight

    function triggerSnap(zone) {
        const cmd = ["hypr-snap", zone];
        if (root.activeTargetAddress) {
            cmd.push("--address", root.activeTargetAddress);
        }
        Quickshell.process(cmd);
        if (root.closePopout) {
            root.closePopout();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.winRadius
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Header: Title and Active Window info
            Row {
                width: parent.width
                height: 22

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "dashboard"
                        size: 16
                        color: root.winAccent
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Snap Layouts"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: root.winText
                    }
                }

                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(hintText.implicitWidth, 180)
                    height: 18

                    StyledText {
                        id: hintText
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        text: root.activeHint !== "" ? root.activeHint : "Click a zone to snap"
                        font.pixelSize: 11
                        color: root.activeHint !== "" ? root.winAccent : root.winMuted
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // Cards Grid: The 4 Windows 11 snap layout presets
            Row {
                width: parent.width
                spacing: 8

                // Card 1: 50 / 50 Split
                SnapCard {
                    width: 84
                    height: 62

                    Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 3

                        SnapPane {
                            width: (parent.width - 3) / 2
                            height: parent.height
                            zone: "half-left"
                            zoneLabel: "Left 50%"
                        }

                        SnapPane {
                            width: (parent.width - 3) / 2
                            height: parent.height
                            zone: "half-right"
                            zoneLabel: "Right 50%"
                        }
                    }
                }

                // Card 2: 67 / 33 Priority Split
                SnapCard {
                    width: 84
                    height: 62

                    Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 3

                        SnapPane {
                            width: Math.round((parent.width - 3) * 0.65)
                            height: parent.height
                            zone: "left-two-thirds"
                            zoneLabel: "Left 67%"
                        }

                        SnapPane {
                            width: parent.width - 3 - Math.round((parent.width - 3) * 0.65)
                            height: parent.height
                            zone: "right-one-third"
                            zoneLabel: "Right 33%"
                        }
                    }
                }

                // Card 3: 3 Columns
                SnapCard {
                    width: 84
                    height: 62

                    Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 3

                        SnapPane {
                            width: (parent.width - 6) / 3
                            height: parent.height
                            zone: "col-1"
                            zoneLabel: "Column 1 (33%)"
                        }

                        SnapPane {
                            width: (parent.width - 6) / 3
                            height: parent.height
                            zone: "col-2"
                            zoneLabel: "Center 33%"
                        }

                        SnapPane {
                            width: (parent.width - 6) / 3
                            height: parent.height
                            zone: "col-3"
                            zoneLabel: "Column 3 (33%)"
                        }
                    }
                }

                // Card 4: 4 Quadrants
                SnapCard {
                    width: 84
                    height: 62

                    Column {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 3

                        Row {
                            width: parent.width
                            height: (parent.height - 3) / 2
                            spacing: 3

                            SnapPane {
                                width: (parent.width - 3) / 2
                                height: parent.height
                                zone: "top-left"
                                zoneLabel: "Top-Left 25%"
                            }

                            SnapPane {
                                width: (parent.width - 3) / 2
                                height: parent.height
                                zone: "top-right"
                                zoneLabel: "Top-Right 25%"
                            }
                        }

                        Row {
                            width: parent.width
                            height: (parent.height - 3) / 2
                            spacing: 3

                            SnapPane {
                                width: (parent.width - 3) / 2
                                height: parent.height
                                zone: "bottom-left"
                                zoneLabel: "Bottom-Left 25%"
                            }

                            SnapPane {
                                width: (parent.width - 3) / 2
                                height: parent.height
                                zone: "bottom-right"
                                zoneLabel: "Bottom-Right 25%"
                            }
                        }
                    }
                }
            }

            // Bottom Quick Action Buttons (Maximize, Center, Retile)
            Row {
                width: parent.width
                height: 32
                spacing: 8

                QuickActionButton {
                    buttonText: "Maximize"
                    buttonIcon: "fullscreen"
                    zone: "maximize"
                    zoneLabel: "Maximize to usable work area"
                }

                QuickActionButton {
                    buttonText: "Center"
                    buttonIcon: "filter_center_focus"
                    zone: "center"
                    zoneLabel: "Center float (70%)"
                }

                QuickActionButton {
                    buttonText: "Re-Tile"
                    buttonIcon: "grid_view"
                    zone: "tile"
                    zoneLabel: "Return window to tiling tree"
                }
            }
        }
    }

    // Component: Layout Card frame
    component SnapCard: Rectangle {
        id: card
        radius: 6
        color: Qt.rgba(root.winText.r, root.winText.g, root.winText.b, 0.04)
        border.color: Qt.rgba(root.winText.r, root.winText.g, root.winText.b, 0.12)
        border.width: 1
        clip: true
    }

    // Component: Interactive Snap Zone Tile
    component SnapPane: Rectangle {
        id: pane
        property string zone: ""
        property string zoneLabel: ""
        readonly property bool isHovered: paneMouse.containsMouse

        radius: 3
        color: isHovered ? root.winAccent : Qt.rgba(root.winText.r, root.winText.g, root.winText.b, 0.10)
        border.color: isHovered ? root.winAccent : Qt.rgba(root.winText.r, root.winText.g, root.winText.b, 0.18)
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 100; easing.type: Easing.OutQuad }
        }
        Behavior on border.color {
            ColorAnimation { duration: 100; easing.type: Easing.OutQuad }
        }

        MouseArea {
            id: paneMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.activeHint = pane.zoneLabel
            onExited: {
                if (root.activeHint === pane.zoneLabel)
                    root.activeHint = "";
            }
            onClicked: root.triggerSnap(pane.zone)
        }
    }

    // Component: Bottom Quick Action Button
    component QuickActionButton: Rectangle {
        id: qBtn
        property string buttonText: ""
        property string buttonIcon: ""
        property string zone: ""
        property string zoneLabel: ""
        readonly property bool isHovered: qMouse.containsMouse

        width: (parent.width - 16) / 3
        height: 30
        radius: 5
        color: isHovered ? Qt.rgba(root.winAccent.r, root.winAccent.g, root.winAccent.b, 0.16) : Qt.rgba(root.winText.r, root.winText.g, root.winText.b, 0.05)
        border.color: isHovered ? root.winAccent : Qt.rgba(root.winText.r, root.winText.g, root.winText.b, 0.12)
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 100; easing.type: Easing.OutQuad }
        }

        Row {
            anchors.centerIn: parent
            spacing: 5

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: qBtn.buttonIcon
                size: 14
                color: qBtn.isHovered ? root.winAccent : root.winText
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: qBtn.buttonText
                font.pixelSize: 11
                color: qBtn.isHovered ? root.winAccent : root.winText
            }
        }

        MouseArea {
            id: qMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.activeHint = qBtn.zoneLabel
            onExited: {
                if (root.activeHint === qBtn.zoneLabel)
                    root.activeHint = "";
            }
            onClicked: root.triggerSnap(qBtn.zone)
        }
    }
}

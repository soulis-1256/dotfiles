import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

Rectangle {
    id: menu

    property var host: null
    property var appItem: null

    property bool open: false
    property real targetX: 0
    property real targetY: 0

    x: Math.max(8, Math.min(targetX, parent.width - width - 8))
    y: Math.max(8, Math.min(targetY, parent.height - height - 8))

    width: 230
    height: menuCol.implicitHeight + 16
    radius: 8
    color: Theme.surfaceContainer
    border.color: Theme.outline
    border.width: 1
    z: 70
    visible: open
    clip: true

    function dismiss() {
        open = false;
    }

    // Eat all pointer events inside the context menu
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    }

    Column {
        id: menuCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 6

        // Workspace header
        Row {
            spacing: 6
            anchors.left: parent.left
            anchors.leftMargin: 4
            height: 20

            DIcon {
                name: "workspaces"
                size: 13
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "Open in workspace"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Workspace grid 1..10
        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 5
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

                Rectangle {
                    id: wsCell
                    required property int modelData

                    readonly property bool isCurrent: {
                        if (typeof Hyprland !== "undefined" && Hyprland.focusedMonitor?.activeWorkspace) {
                            return Hyprland.focusedMonitor.activeWorkspace.id === modelData;
                        }
                        return false;
                    }
                    readonly property bool wsExists: {
                        if (typeof Hyprland !== "undefined" && Hyprland.workspaces?.values) {
                            return Hyprland.workspaces.values.some(w => w.id === modelData);
                        }
                        return false;
                    }

                    width: 38
                    height: 28
                    radius: 4
                    color: isCurrent ? Theme.primary : (wsHover.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerLow)
                    border.width: wsExists && !isCurrent ? 1 : 0
                    border.color: Theme.outline

                    StyledText {
                        anchors.centerIn: parent
                        text: "" + wsCell.modelData
                        font.pixelSize: 12
                        font.weight: wsCell.isCurrent ? Font.Bold : Font.Normal
                        color: wsCell.isCurrent ? Theme.onPrimary : Theme.surfaceText
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 3
                        visible: wsCell.wsExists && !wsCell.isCurrent
                        width: 4
                        height: 4
                        radius: 2
                        color: Theme.primary
                    }

                    MouseArea {
                        id: wsHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (host)
                                host.launchInWorkspace(menu.appItem, wsCell.modelData);
                            menu.dismiss();
                        }
                    }
                }
            }
        }

        // Separator
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outline
            opacity: 0.5
        }

        // Standard Launch action
        Rectangle {
            width: parent.width
            height: 32
            radius: 4
            color: launchHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                DIcon {
                    name: "launch"
                    size: 16
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Launch"
                    font.pixelSize: 12
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: launchHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (host)
                        host.launchApp(menu.appItem);
                    menu.dismiss();
                }
            }
        }

        // Run in terminal (if applicable)
        Rectangle {
            visible: !!(menu.appItem && (menu.appItem.runInTerminal || menu.appItem.terminal))
            width: parent.width
            height: visible ? 32 : 0
            radius: 4
            color: termHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                DIcon {
                    name: "terminal"
                    size: 16
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Run in terminal"
                    font.pixelSize: 12
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: termHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (host)
                        host.launchInTerminal(menu.appItem);
                    menu.dismiss();
                }
            }
        }
    }
}

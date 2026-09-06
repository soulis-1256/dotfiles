import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    function registerAsLauncher() {
        if (root.blurBarWindow)
            root.blurBarWindow.launcherButtonRef = root;

    }

    function toggleWithMode(mode) {
        root.triggerPopout();
    }

    function openWithMode(mode) {
        root.triggerPopout();
    }

    layerNamespacePlugin: "win10-start"
    popoutWidth: 948
    popoutHeight: 620
    popoutFlush: true
    Component.onCompleted: {
        registerAsLauncher();
    }
    onBlurBarWindowChanged: {
        registerAsLauncher();
    }
    Component.onDestruction: {
        if (root.blurBarWindow && root.blurBarWindow.launcherButtonRef === root)
            root.blurBarWindow.launcherButtonRef = null;

    }

    horizontalBarPill: Component {
        Item {
            id: startPillItem

            implicitWidth: 48
            implicitHeight: root.barThickness

            Rectangle {
                anchors.fill: parent
                color: pillHover.containsMouse ? (pillHover.pressed ? "#1a1a1a" : "#323232") : "transparent"
                radius: 0

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }

                }

            }

            IconImage {
                anchors.centerIn: parent
                width: 22
                height: 22
                source: Qt.resolvedUrl("cachyos.svg")
                smooth: true
                asynchronous: true
                scale: pillHover.pressed ? 0.92 : (pillHover.containsMouse ? 1.06 : 1)

                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                    }

                }

            }

            MouseArea {
                id: pillHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.triggerPopout()
            }

        }

    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.barThickness
            implicitHeight: 48

            Rectangle {
                anchors.fill: parent
                color: vPillHover.containsMouse ? (vPillHover.pressed ? "#1a1a1a" : "#323232") : "transparent"
                radius: 0

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }

                }

            }

            IconImage {
                anchors.centerIn: parent
                width: 22
                height: 22
                source: Qt.resolvedUrl("cachyos.svg")
                smooth: true
                asynchronous: true
                scale: vPillHover.pressed ? 0.92 : (vPillHover.containsMouse ? 1.06 : 1)

                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                    }

                }

            }

            MouseArea {
                id: vPillHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.triggerPopout()
            }

        }

    }

    popoutContent: Component {
        StartMenu {
        }

    }

}

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
    Component.onCompleted: registerAsLauncher()
    onBlurBarWindowChanged: registerAsLauncher()
    Component.onDestruction: {
        if (root.blurBarWindow && root.blurBarWindow.launcherButtonRef === root)
            root.blurBarWindow.launcherButtonRef = null;
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: 48
            implicitHeight: root.barThickness

            IconImage {
                anchors.centerIn: parent
                width: 22
                height: 22
                source: Qt.resolvedUrl("cachyos.svg")
                smooth: true
                asynchronous: true
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.barThickness
            implicitHeight: 48

            IconImage {
                anchors.centerIn: parent
                width: 22
                height: 22
                source: Qt.resolvedUrl("cachyos.svg")
                smooth: true
                asynchronous: true
            }
        }
    }

    popoutContent: Component {
        StartMenu {}
    }
}

import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    layerNamespacePlugin: "win10-start"

    popoutWidth: 860
    popoutHeight: 648

    horizontalBarPill: Component {
        Item {
            implicitWidth: Math.max(36, root.widgetThickness)
            implicitHeight: Math.max(20, root.widgetThickness - 8)

            IconImage {
                anchors.centerIn: parent
                width: Math.round(Math.min(parent.implicitWidth, parent.implicitHeight) * 0.72)
                height: width
                source: Qt.resolvedUrl("windows.svg")
                smooth: true
                asynchronous: true
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: Math.max(20, root.widgetThickness - 8)
            implicitHeight: Math.max(36, root.widgetThickness)

            IconImage {
                anchors.centerIn: parent
                width: Math.round(Math.min(parent.implicitWidth, parent.implicitHeight) * 0.72)
                height: width
                source: Qt.resolvedUrl("windows.svg")
                smooth: true
                asynchronous: true
            }
        }
    }

    popoutContent: Component {
        StartMenu {}
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

// Input-only overlay for screens that do not host the open modal/popout.
// Whitelisted in HyprlandFocusGrab so a click dismisses via MouseArea
// instead of compositor grab-clear (which desyncs active and breaks reopen).
PanelWindow {
    id: root

    property var modelData

    screen: modelData
    visible: DismissCatcher.active && !!modelData && !DismissCatcher.isOccupied(modelData.name)
    color: "transparent"
    updatesEnabled: false
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "dms:dismiss-catcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Component.onCompleted: KeyboardFocus.registerDismissWindow(root)
    Component.onDestruction: KeyboardFocus.unregisterDismissWindow(root)

    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: DismissCatcher.dismiss()
    }
}

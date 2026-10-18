import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string iconName: ""
    property bool isActive: false
    property bool iconBlinking: false

    // Left click expands the widget (primary detail action), right click toggles on/off.
    signal toggled
    signal expandClicked
    signal wheelEvent(var wheelEvent)

    width: parent ? ((parent.width - parent.spacing * 3) / 4) : 48
    height: 48
    radius: {
        if (Theme.cornerRadius === 0)
            return 0;
        if (Theme.fluent)
            return Theme.controlCornerRadius;
        return isActive ? Theme.cornerRadius : Theme.cornerRadius + 4;
    }

    readonly property color _tileBgActive: Theme.ccTileActiveBg
    readonly property color _tileBgInactive: Theme.ccPillInactiveBg
    readonly property color _tileRingActive: Theme.ccTileRing
    readonly property color _tileIconActive: Theme.ccTileActiveText
    readonly property color _tileIconInactive: Theme.ccTileInactiveIcon

    color: {
        if (isActive)
            return _tileBgActive;
        if (Theme.fluent)
            return (mouseArea.containsMouse || chevronArea.containsMouse) ? Theme.fluentControlFillHover : Theme.fluentControlFill;
        const baseColor = mouseArea.containsMouse ? Theme.ccPillInactiveHoverBg : _tileBgInactive;
        return baseColor;
    }
    border.color: Theme.fluent ? (isActive ? "transparent" : Theme.fluentControlStroke) : (isActive ? _tileRingActive : Theme.outlineMedium)
    border.width: Theme.fluent ? (isActive ? 0 : 1) : (isActive ? 1 : Theme.layerOutlineWidth)
    antialiasing: true
    opacity: enabled ? 1.0 : 0.6

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.hoverTint(root.color)
        opacity: mouseArea.pressed ? 0.3 : (mouseArea.containsMouse ? 0.2 : 0.0)
        visible: opacity > 0
        antialiasing: true
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }
    }

    DankIcon {
        id: tileIcon
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: Theme.fluent ? -8 : 0
        name: iconName
        size: Theme.iconSize
        color: isActive ? _tileIconActive : (Theme.fluent ? Theme.surfaceText : _tileIconInactive)

        DankBlink {
            target: tileIcon
            running: root.iconBlinking
        }
    }

    DankRipple {
        id: ripple
        cornerRadius: root.radius
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: root.enabled
        onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
        onClicked: mouse => {
            if (Theme.fluent) {
                if (mouse.button === Qt.RightButton)
                    root.expandClicked();
                else
                    root.toggled();
            } else if (mouse.button === Qt.RightButton) {
                root.toggled();
            } else {
                root.expandClicked();
            }
        }
        onWheel: function (ev) {
            root.wheelEvent(ev);
        }
    }

    Item {
        visible: Theme.fluent
        z: 2
        width: 18
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: 2

        Rectangle {
            width: 1
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            color: root.isActive ? Theme.withAlpha(root._tileIconActive, 0.35) : Theme.fluentControlStroke
        }

        DankIcon {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 2
            name: I18n.isRtl ? "chevron_left" : "chevron_right"
            size: 12
            color: root.isActive ? root._tileIconActive : Theme.surfaceVariantText
        }

        MouseArea {
            id: chevronArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandClicked()
        }
    }

    Behavior on radius {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}

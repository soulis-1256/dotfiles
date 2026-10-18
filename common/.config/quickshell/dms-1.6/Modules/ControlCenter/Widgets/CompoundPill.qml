import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string iconName: ""
    property color iconColor: Theme.surfaceText
    property bool iconBlinking: false
    property string primaryText: ""
    property string secondaryText: ""
    property bool expanded: false
    property bool isActive: false
    property bool showExpandArea: true

    signal toggled
    signal expandClicked
    signal wheelEvent(var wheelEvent)

    readonly property bool fluent: Theme.fluent
    readonly property bool showChevron: fluent && showExpandArea

    width: parent ? parent.width : 220
    height: 60
    radius: fluent ? Theme.controlCornerRadius : Theme.cornerRadius

    readonly property color _containerBg: Theme.ccPillInactiveBg

    color: {
        if (fluent) {
            if (isActive)
                return _tileBgActive;
            if (bodyMouse.containsMouse || tileMouse.containsMouse)
                return Theme.fluentControlFillHover;
            return Theme.fluentControlFill;
        }
        const baseColor = bodyMouse.containsMouse ? Theme.ccPillInactiveHoverBg : _containerBg;
        return baseColor;
    }
    border.color: fluent ? (isActive ? "transparent" : Theme.fluentControlStroke) : Theme.outlineMedium
    border.width: fluent ? (isActive ? 0 : 1) : Theme.layerOutlineWidth
    antialiasing: true

    readonly property color _labelPrimary: (fluent && isActive) ? _tileIconActive : Theme.surfaceText
    readonly property color _labelSecondary: (fluent && isActive) ? Theme.withAlpha(_tileIconActive, 0.8) : Theme.surfaceVariantText
    readonly property color _tileBgActive: Theme.ccTileActiveBg
    readonly property color _tileBgInactive: {
        return Theme.ccTileInactiveBg;
    }
    readonly property color _tileRingActive: Theme.ccTileRing
    readonly property color _tileRingInactive: Theme.outlineHeavy
    readonly property color _tileIconActive: Theme.ccTileActiveText
    readonly property color _tileIconInactive: Theme.ccTileInactiveIcon

    property int _padH: Theme.spacingS
    property int _tileSize: 48
    property int _tileRadius: Theme.cornerRadius

    Rectangle {
        id: rightHoverOverlay
        anchors.fill: parent
        radius: root.radius
        z: 0
        visible: false
        color: Theme.hoverTint(_containerBg)
        opacity: 0.08
        antialiasing: true
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }
    }

    DankRipple {
        id: bodyRipple
        cornerRadius: root.radius
    }

    Row {
        id: row
        anchors.fill: parent
        anchors.leftMargin: _padH
        anchors.rightMargin: showChevron ? 36 : Theme.spacingM
        spacing: Theme.spacingM

        Rectangle {
            id: iconTile
            z: 1
            width: root.fluent ? Theme.iconSize : _tileSize
            height: root.fluent ? Theme.iconSize : _tileSize
            anchors.verticalCenter: parent.verticalCenter
            radius: root.fluent ? 0 : _tileRadius
            color: root.fluent ? "transparent" : (isActive ? _tileBgActive : _tileBgInactive)
            border.color: root.fluent ? "transparent" : (isActive ? _tileRingActive : Theme.outlineMedium)
            border.width: root.fluent ? 0 : (isActive ? 1 : Theme.layerOutlineWidth)
            antialiasing: true

            Rectangle {
                anchors.fill: parent
                radius: _tileRadius
                color: Theme.hoverTint(iconTile.color)
                opacity: tileMouse.pressed ? 0.3 : (tileMouse.containsMouse ? 0.2 : 0.0)
                visible: opacity > 0
                antialiasing: true
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                    }
                }
            }

            DankIcon {
                id: pillIcon
                anchors.centerIn: parent
                name: iconName
                size: Theme.iconSize
                color: isActive ? _tileIconActive : (root.fluent ? Theme.surfaceText : _tileIconInactive)

                DankBlink {
                    target: pillIcon
                    running: root.iconBlinking
                }
            }

            DankRipple {
                id: tileRipple
                cornerRadius: _tileRadius
            }

            MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => tileRipple.trigger(mouse.x, mouse.y)
                onClicked: root.toggled()
            }
        }

        Item {
            id: body
            width: row.width - iconTile.width - row.spacing
            height: row.height

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXXS

                StyledText {
                    width: parent.width
                    text: root.primaryText
                    color: _labelPrimary
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    horizontalAlignment: Text.AlignLeft
                }
                StyledText {
                    width: parent.width
                    text: root.secondaryText
                    color: _labelSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    visible: text.length > 0
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    horizontalAlignment: Text.AlignLeft
                }
            }

            MouseArea {
                id: bodyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    if (root.fluent)
                        return;
                    rightHoverOverlay.visible = true;
                    rightHoverOverlay.opacity = 0.08;
                }
                onExited: {
                    rightHoverOverlay.opacity = 0.0;
                    rightHoverOverlay.visible = false;
                }
                onPressed: mouse => {
                    const pos = mapToItem(root, mouse.x, mouse.y);
                    bodyRipple.trigger(pos.x, pos.y);
                    if (!root.fluent)
                        rightHoverOverlay.opacity = 0.16;
                }
                onReleased: rightHoverOverlay.opacity = containsMouse ? 0.08 : 0.0
                onClicked: {
                    if (root.fluent)
                        root.toggled();
                    else
                        root.expandClicked();
                }
                onWheel: function (ev) {
                    root.wheelEvent(ev);
                }
            }
        }
    }

    Rectangle {
        id: chevronSegment
        visible: root.showChevron
        z: 2
        width: 36
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: chevronMouse.containsMouse ? Theme.withAlpha(root.isActive ? root._tileIconActive : Theme.surfaceText, 0.1) : "transparent"

        Rectangle {
            width: 1
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            color: root.isActive ? Theme.withAlpha(root._tileIconActive, 0.35) : Theme.fluentControlStroke
        }

        DankIcon {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 1
            name: I18n.isRtl ? "chevron_left" : "chevron_right"
            size: Theme.iconSize - 8
            color: root.isActive ? root._tileIconActive : Theme.surfaceVariantText
        }

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandClicked()
        }
    }

    focus: true
    Keys.onPressed: function (ev) {
        if (ev.key === Qt.Key_Space || ev.key === Qt.Key_Return) {
            root.toggled();
            ev.accepted = true;
        } else if (ev.key === Qt.Key_Right) {
            root.expandClicked();
            ev.accepted = true;
        }
    }
}

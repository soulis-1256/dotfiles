import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string iconName: ""
    property string text: ""
    property bool isActive: false
    property string secondaryText: ""
    property real iconRotation: 0

    signal clicked
    signal iconRotationCompleted

    width: parent ? parent.width : 200
    height: Theme.fluent ? 88 : 60
    radius: Theme.fluent ? 0 : (isActive ? Theme.cornerRadius : Theme.cornerRadius + 4)

    readonly property color _tileBgActive: Theme.ccTileActiveBg
    readonly property color _tileBgInactive: Theme.ccPillInactiveBg
    readonly property color _tileRingActive: Theme.ccTileRing

    color: Theme.fluent ? "transparent" : (mouseArea.containsMouse ? Theme.ccPillInactiveHoverBg : _tileBgInactive)
    border.color: Theme.fluent ? "transparent" : (isActive ? _tileRingActive : Theme.outlineMedium)
    border.width: Theme.fluent ? 0 : (isActive ? 1 : Theme.layerOutlineWidth)
    opacity: enabled ? 1.0 : 0.6

    readonly property color _containerBg: Theme.ccPillInactiveBg

    // Fluent Mode Layout: Button on top (48px) + Centered Labels underneath
    Item {
        id: fluentContainer
        anchors.fill: parent
        visible: Theme.fluent

        Rectangle {
            id: fluentButton
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            radius: Theme.controlCornerRadius
            color: {
                if (root.isActive)
                    return root._tileBgActive;
                if (fluentMouseArea.containsMouse)
                    return Theme.fluentControlFillHover;
                return Theme.fluentControlFill;
            }
            border.color: root.isActive ? "transparent" : Theme.fluentControlStroke
            border.width: root.isActive ? 0 : 1

            DankIcon {
                anchors.centerIn: parent
                name: root.iconName
                size: Theme.iconSize
                color: root.isActive ? Theme.ccTileActiveText : Theme.surfaceText
                rotation: root.iconRotation
                onRotationCompleted: root.iconRotationCompleted()
            }

            MouseArea {
                id: fluentMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clicked()
            }
        }

        Column {
            anchors.top: fluentButton.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 1

            StyledText {
                width: parent.width
                text: root.text
                font.pixelSize: 12
                color: Theme.surfaceText
                font.weight: Font.Medium
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                horizontalAlignment: Text.AlignHCenter
            }

            StyledText {
                width: parent.width
                text: root.secondaryText
                font.pixelSize: 10
                color: Theme.surfaceVariantText
                visible: text.length > 0
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Material Mode Layout: Traditional horizontal row
    Item {
        id: materialContainer
        anchors.fill: parent
        visible: !Theme.fluent

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: mouseArea.containsMouse ? Theme.hoverTint(_containerBg) : Theme.withAlpha(_containerBg, 0)
            opacity: mouseArea.containsMouse ? 0.08 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                }
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingL + 2
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingM

            DankIcon {
                name: root.iconName
                size: Theme.iconSize
                color: isActive ? Theme.ccTileActiveText : Theme.ccTileInactiveIcon
                anchors.verticalCenter: parent.verticalCenter
                rotation: root.iconRotation
                onRotationCompleted: root.iconRotationCompleted()
            }

            Item {
                width: parent.width - Theme.iconSize - parent.spacing
                height: parent.height

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXXS

                    StyledText {
                        width: parent.width
                        text: root.text
                        font.pixelSize: Theme.fontSizeMedium
                        color: isActive ? Theme.ccTileActiveText : Theme.surfaceText
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        horizontalAlignment: Text.AlignLeft
                    }

                    StyledText {
                        width: parent.width
                        text: root.secondaryText
                        font.pixelSize: Theme.fontSizeSmall
                        color: isActive ? Theme.ccTileActiveText : Theme.surfaceVariantText
                        visible: text.length > 0
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        horizontalAlignment: Text.AlignLeft
                    }
                }
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
            enabled: root.enabled
            onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
            onClicked: root.clicked()
        }
    }

    Behavior on radius {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}

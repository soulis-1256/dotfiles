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
    height: fluent ? 88 : 60
    radius: fluent ? 0 : Theme.cornerRadius

    readonly property color _containerBg: Theme.ccPillInactiveBg

    color: fluent ? "transparent" : (bodyMouse.containsMouse ? Theme.ccPillInactiveHoverBg : _containerBg)
    border.color: fluent ? "transparent" : Theme.outlineMedium
    border.width: fluent ? 0 : Theme.layerOutlineWidth
    antialiasing: true

    readonly property color _labelPrimary: (fluent && isActive) ? _tileIconActive : Theme.surfaceText
    readonly property color _labelSecondary: (fluent && isActive) ? Theme.withAlpha(_tileIconActive, 0.8) : Theme.surfaceVariantText
    readonly property color _tileBgActive: Theme.ccTileActiveBg
    readonly property color _tileBgInactive: Theme.ccTileInactiveBg
    readonly property color _tileRingActive: Theme.ccTileRing
    readonly property color _tileRingInactive: Theme.outlineHeavy
    readonly property color _tileIconActive: Theme.ccTileActiveText
    readonly property color _tileIconInactive: Theme.ccTileInactiveIcon

    property int _padH: Theme.spacingS
    property int _tileSize: 48
    property int _tileRadius: Theme.cornerRadius

    // Fluent Mode Layout: Button on top (48px) + Centered Labels underneath
    Item {
        id: fluentContainer
        anchors.fill: parent
        visible: root.fluent

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
                if (fluentIconMouse.containsMouse || fluentChevronMouse.containsMouse)
                    return Theme.fluentControlFillHover;
                return Theme.fluentControlFill;
            }
            border.color: root.isActive ? "transparent" : Theme.fluentControlStroke
            border.width: root.isActive ? 0 : 1
            clip: true

            Item {
                id: fluentSplitContent
                anchors.fill: parent
                visible: root.showChevron

                Item {
                    id: fluentIconPart
                    anchors.left: parent.left
                    anchors.right: fluentDivider.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Rectangle {
                        anchors.fill: parent
                        color: fluentIconMouse.pressed ? Theme.withAlpha(Theme.surfaceText, 0.08) : (fluentIconMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.05) : "transparent")
                    }

                    DankIcon {
                        id: fluentPillIcon
                        anchors.centerIn: parent
                        name: root.iconName
                        size: Theme.iconSize
                        color: root.isActive ? root._tileIconActive : Theme.surfaceText

                        DankBlink {
                            target: fluentPillIcon
                            running: root.iconBlinking
                        }
                    }

                    MouseArea {
                        id: fluentIconMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggled()
                        onWheel: function(ev) { root.wheelEvent(ev); }
                    }
                }

                Rectangle {
                    id: fluentDivider
                    width: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    color: root.isActive ? Theme.withAlpha(root._tileIconActive, 0.35) : Theme.fluentControlStroke
                }

                Item {
                    id: fluentChevronPart
                    anchors.left: fluentDivider.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Rectangle {
                        anchors.fill: parent
                        color: fluentChevronMouse.pressed ? Theme.withAlpha(Theme.surfaceText, 0.08) : (fluentChevronMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.05) : "transparent")
                    }

                    DankIcon {
                        id: fluentChevronIcon
                        anchors.centerIn: parent
                        name: I18n.isRtl ? "chevron_left" : "chevron_right"
                        size: 16
                        color: root.isActive ? root._tileIconActive : (fluentChevronMouse.containsMouse ? Theme.surfaceText : Theme.surfaceVariantText)
                        rotation: root.expanded ? 90 : 0
                        Behavior on rotation {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.variantPopoutEnterCurve
                            }
                        }
                    }

                    MouseArea {
                        id: fluentChevronMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expandClicked()
                    }
                }
            }

            Item {
                id: fluentSingleContent
                anchors.fill: parent
                visible: !root.showChevron

                DankIcon {
                    anchors.centerIn: parent
                    name: root.iconName
                    size: Theme.iconSize
                    color: root.isActive ? root._tileIconActive : Theme.surfaceText
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggled()
                    onWheel: function(ev) { root.wheelEvent(ev); }
                }
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
                text: root.primaryText
                color: Theme.surfaceText
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                horizontalAlignment: Text.AlignHCenter
            }

            StyledText {
                width: parent.width
                text: root.secondaryText
                color: Theme.surfaceVariantText
                font.pixelSize: 10
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
        visible: !root.fluent

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
                width: _tileSize
                height: _tileSize
                anchors.verticalCenter: parent.verticalCenter
                radius: _tileRadius
                color: isActive ? _tileBgActive : _tileBgInactive
                border.color: isActive ? _tileRingActive : Theme.outlineMedium
                border.width: isActive ? 1 : Theme.layerOutlineWidth
                antialiasing: true

                DankIcon {
                    id: pillIcon
                    anchors.centerIn: parent
                    name: iconName
                    size: Theme.iconSize
                    color: isActive ? _tileIconActive : _tileIconInactive

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
                    onPressed: mouse => {
                        const pos = mapToItem(root, mouse.x, mouse.y);
                        bodyRipple.trigger(pos.x, pos.y);
                    }
                    onClicked: root.expandClicked()
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

            DankIcon {
                anchors.centerIn: parent
                name: I18n.isRtl ? "chevron_left" : "chevron_right"
                size: Theme.iconSize - 8
                color: root.isActive ? root._tileIconActive : Theme.surfaceVariantText
                rotation: root.expanded ? 90 : 0
                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.variantPopoutEnterCurve
                    }
                }
            }

            MouseArea {
                id: chevronMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expandClicked()
            }
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

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    implicitHeight: layoutContent.height + Theme.spacingM
    radius: Theme.cornerRadius
    color: Theme.nestedSurface
    border.color: Theme.outlineMedium
    border.width: Theme.layerOutlineWidth

    DankFlickable {
        id: layoutContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        contentHeight: layoutColumn.height
        clip: true

        Column {
            id: layoutColumn
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: [
                    {
                        mode: "tiled",
                        title: I18n.tr("Tiled"),
                        description: I18n.tr("Standard Hyprland auto-tiling"),
                        icon: "grid_view"
                    },
                    {
                        mode: "floating",
                        title: I18n.tr("Floating"),
                        description: I18n.tr("Float all windows on workspace"),
                        icon: "layers"
                    },
                    {
                        mode: "mosaic",
                        title: I18n.tr("Mosaic"),
                        description: I18n.tr("Smart content-aware masonry layout"),
                        icon: "dashboard"
                    }
                ]
                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    readonly property bool isSelected: HyprlandService.currentLayoutMode === modelData.mode

                    width: parent.width
                    height: 64
                    radius: Theme.cornerRadius
                    color: isSelected ? Theme.surfaceLight : (itemMouse.containsMouse ? Theme.surfaceLight : Theme.surfaceContainer)
                    border.color: isSelected ? Theme.primary : Theme.outlineLight
                    border.width: isSelected ? 2 : 1

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 40
                            height: 40
                            radius: Theme.cornerRadius
                            color: isSelected ? Theme.primary : Theme.surfaceLight
                            anchors.verticalCenter: parent.verticalCenter

                            DankIcon {
                                anchors.centerIn: parent
                                name: modelData.icon
                                size: 22
                                color: isSelected ? Theme.primaryText : Theme.surfaceText
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 56 - (isSelected ? 36 : 0)
                            spacing: Theme.spacingXXS

                            StyledText {
                                text: modelData.title
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: isSelected ? Font.Bold : Font.Medium
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            StyledText {
                                text: modelData.description
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        DankIcon {
                            visible: isSelected
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: 22
                            color: Theme.primary
                        }
                    }

                    DankRipple {
                        id: itemRipple
                        cornerRadius: parent.radius
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => itemRipple.trigger(mouse.x, mouse.y)
                        onClicked: {
                            HyprlandService.setLayoutMode(modelData.mode);
                        }
                    }
                }
            }
        }
    }
}

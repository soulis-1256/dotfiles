import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property var parentModal: null
    property string categoryId: ""

    readonly property var category: {
        var structure = SettingsTabs.structure;
        for (var i = 0; i < structure.length; i++) {
            if (structure[i].id === root.categoryId)
                return structure[i];
        }
        return null;
    }

    function rowShown(item) {
        if (!item)
            return false;
        if (parentModal && parentModal.sidebar)
            return parentModal.sidebar.isItemVisible(item);
        return true;
    }

    onCategoryIdChanged: {
        if (Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None && visible) {
            hubTransitionAnim.restart();
        }
    }

    ParallelAnimation {
        id: hubTransitionAnim

        NumberAnimation {
            target: hubColumn
            property: "opacity"
            from: 0.1
            to: 1.0
            duration: Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None ? 0 : 200
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: hubColumnTranslate
            property: "y"
            from: 14
            to: 0
            duration: Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None ? 0 : 220
            easing.type: Easing.OutCubic
        }
    }

    DankFlickable {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingXL
        anchors.topMargin: Theme.spacingS
        clip: true
        contentHeight: hubColumn.implicitHeight + Theme.spacingL

        Column {
            id: hubColumn
            width: parent.width
            spacing: Theme.spacingL

            transform: Translate {
                id: hubColumnTranslate
                y: 0
            }

            StyledText {
                width: parent.width
                text: root.category ? (root.category.text || "") : ""
                font.pixelSize: 28
                font.weight: Font.Normal
                color: Theme.surfaceText
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width
                height: hubList.implicitHeight
                radius: Theme.overlayCornerRadius
                color: Theme.fluentCardFill
                border.color: Theme.fluentCardStroke
                border.width: 1
                clip: true
                visible: root.category && root.category.children && root.category.children.length > 0

                Column {
                    id: hubList
                    width: parent.width

                    Repeater {
                        id: hubRepeater
                        model: (root.category && root.category.children) ? root.category.children : []

                        delegate: Rectangle {
                            id: hubRow

                            property var rowData: modelData
                            readonly property bool shown: root.rowShown(rowData)

                            width: hubList.width
                            height: shown ? 48 : 0
                            visible: shown
                            scale: hubRowArea.pressed ? 0.992 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutQuad
                                }
                            }

                            color: {
                                if (hubRowArea.pressed)
                                    return Theme.fluentSubtlePressed;
                                if (hubRowArea.containsMouse)
                                    return Theme.fluentSubtleFill;
                                return "transparent";
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                    easing.type: Easing.OutQuad
                                }
                            }

                            DankRipple {
                                id: hubRipple
                                rippleColor: Theme.surfaceText
                                cornerRadius: Theme.controlCornerRadius
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.right: hubChevron.left
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: hubRow.rowData.icon || ""
                                    size: Theme.iconSize - 4
                                    color: hubRowArea.containsMouse ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                }

                                StyledText {
                                    text: hubRow.rowData.text || ""
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    width: Math.max(0, parent.width - Theme.iconSize - Theme.spacingM)
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            DankIcon {
                                id: hubChevron
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                name: I18n.isRtl ? "chevron_left" : "chevron_right"
                                size: Theme.iconSize - 6
                                color: hubRowArea.containsMouse ? Theme.surfaceText : Theme.surfaceVariantText

                                transform: Translate {
                                    x: (hubRowArea.containsMouse && !I18n.isRtl) ? 3 : ((hubRowArea.containsMouse && I18n.isRtl) ? -3 : 0)
                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutQuad
                                        }
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            Rectangle {
                                visible: hubRow.shown && index < hubRepeater.count - 1
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM + (Theme.iconSize - 4) + Theme.spacingM
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Theme.fluentCardStroke
                            }

                            MouseArea {
                                id: hubRowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => hubRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    if (root.parentModal && hubRow.rowData.tabIndex !== undefined)
                                        root.parentModal.setTabIndex(hubRow.rowData.tabIndex);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

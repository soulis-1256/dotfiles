import QtQuick
import qs.Common
import qs.Widgets

// Shared Start pin context menu. Both win10Start and win11Start instantiate this.
// showResize / showMoveToGroup are the Win10-only extras.

Rectangle {
    id: menu

    property var host: null
    property bool showResize: false
    property bool showMoveToGroup: false

    readonly property string menuType: host ? (host.contextMenuType || "") : ""
    readonly property var menuItem: host ? host.contextMenuItem : null
    readonly property int menuGroupId: host ? host.contextMenuGroupId : 1
    readonly property var parentFolder: host ? host.contextMenuParentFolder : null
    readonly property var workspaces: host ? (host.availableWorkspaces || []) : []
    readonly property var foldersInGroup: {
        if (!host || menuType !== "tile" || typeof host.getFoldersInGroup !== "function")
            return [];
        return host.getFoldersInGroup(menuGroupId) || [];
    }
    readonly property bool itemIsFolder: !!(menuItem && menuItem.isFolder)
    readonly property bool showWorkspace: (menuType === "app" || menuType === "tile" || menuType === "folderTile") && !itemIsFolder
    readonly property bool showPinApp: menuType === "app"
    readonly property bool showTileActions: menuType === "tile" || menuType === "folderTile"
    readonly property bool showFolderActions: menuType === "folder"
    readonly property bool showUnpin: menuType === "tile" || menuType === "folder" || menuType === "folderTile"

    readonly property color winHover: host && host.winHover !== undefined ? host.winHover : Qt.rgba(1, 1, 1, 0.08)
    readonly property color winAccent: host && host.winAccent !== undefined ? host.winAccent : Theme.primary
    readonly property color winText: host && host.winText !== undefined ? host.winText : Theme.surfaceText
    readonly property color winMuted: host && host.winMuted !== undefined ? host.winMuted : Theme.surfaceVariantText
    readonly property color winBorder: host && host.winBorder !== undefined ? host.winBorder : Qt.rgba(1, 1, 1, 0.08)
    property real menuRadius: 8

    function dismiss() {
        if (host)
            host.contextMenuVisible = false;
    }

    function wsEntry(id) {
        const list = menu.workspaces;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i];
        }
        return null;
    }

    visible: !!(host && host.contextMenuVisible)
    width: 220
    height: menuCol.implicitHeight + 8
    x: host ? Math.max(8, Math.min(host.contextMenuX, parent.width - width - 8)) : 8
    y: host ? Math.max(8, Math.min(host.contextMenuY, parent.height - height - 8)) : 8
    radius: menuRadius
    color: Theme.surfaceContainer
    border.color: winBorder
    border.width: 1
    z: 70
    clip: true

    Column {
        id: menuCol

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 4
        spacing: 0

        MenuRow {
            visible: menu.showPinApp
            iconName: (host && host.isAppPinned && host.isAppPinned(menu.menuItem)) ? "remove_circle_outline" : "push_pin"
            label: (host && host.isAppPinned && host.isAppPinned(menu.menuItem)) ? "Unpin from Start" : "Pin to Start"
            onClicked: {
                if (host)
                    host.togglePinApp(menu.menuItem);
                menu.dismiss();
            }
        }

        MenuSep {
            visible: menu.showPinApp && menu.showWorkspace
        }

        Item {
            visible: menu.showWorkspace
            width: parent.width
            height: visible ? wsCol.implicitHeight + 8 : 0

            Column {
                id: wsCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 4
                spacing: 6

                Row {
                    spacing: 6
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    height: 18

                    DankIcon {
                        name: "workspaces"
                        size: 12
                        color: menu.winMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Open in workspace"
                        font.pixelSize: 11
                        color: menu.winMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 5
                    rowSpacing: 4
                    columnSpacing: 4

                    Repeater {
                        model: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

                        Rectangle {
                            id: wsCell

                            required property int modelData
                            readonly property var info: menu.wsEntry(modelData)
                            readonly property bool isCurrent: !!(info && info.isFocused)
                            readonly property bool wsExists: !!(info && info.exists)

                            width: 36
                            height: 28
                            radius: 4
                            color: isCurrent ? menu.winAccent : (wsHover.containsMouse ? menu.winHover : "transparent")
                            border.width: wsExists && !isCurrent ? 1 : 0
                            border.color: Qt.rgba(menu.winAccent.r, menu.winAccent.g, menu.winAccent.b, 0.45)

                            StyledText {
                                anchors.centerIn: parent
                                text: "" + wsCell.modelData
                                font.pixelSize: 12
                                font.weight: wsCell.isCurrent ? Font.DemiBold : Font.Normal
                                color: wsCell.isCurrent ? Theme.primaryText : menu.winText
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 3
                                visible: wsCell.wsExists && !wsCell.isCurrent
                                width: 5
                                height: 5
                                radius: 2.5
                                color: menu.winAccent
                            }

                            MouseArea {
                                id: wsHover

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (host)
                                        host.launchInWorkspace(menu.menuItem, wsCell.modelData);
                                    menu.dismiss();
                                }
                            }
                        }
                    }
                }
            }
        }

        MenuSep {
            visible: menu.showWorkspace && (menu.showTileActions || menu.showFolderActions || menu.showResize)
        }

        Item {
            visible: menu.showResize && menuType === "tile"
            width: parent.width
            height: visible ? 50 : 0

            Column {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 4

                StyledText {
                    text: "Resize"
                    font.pixelSize: 11
                    color: menu.winMuted
                }

                Row {
                    spacing: 4
                    width: parent.width

                    Repeater {
                        model: [
                            { "id": "small", "label": "Small" },
                            { "id": "medium", "label": "Medium" },
                            { "id": "wide", "label": "Wide" },
                            { "id": "large", "label": "Large" }
                        ]

                        Rectangle {
                            required property var modelData
                            readonly property bool isCurrent: menu.menuItem && (menu.menuItem.size === modelData.id || (!menu.menuItem.size && modelData.id === (menu.menuItem.wide ? "wide" : "medium")))

                            width: 42
                            height: 24
                            radius: 4
                            color: isCurrent ? menu.winAccent : (rBtnHover.containsMouse ? menu.winHover : Qt.rgba(255, 255, 255, 0.05))
                            border.color: isCurrent ? Qt.lighter(menu.winAccent, 1.2) : Qt.rgba(255, 255, 255, 0.15)
                            border.width: 1

                            StyledText {
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                font.pixelSize: 10
                                font.weight: parent.isCurrent ? Font.DemiBold : Font.Normal
                                color: parent.isCurrent ? Theme.primaryText : menu.winText
                            }

                            MouseArea {
                                id: rBtnHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (host)
                                        host.setTileSize(menu.menuItem, parent.modelData.id);
                                    menu.dismiss();
                                }
                            }
                        }
                    }
                }
            }
        }

        MenuRow {
            visible: menu.showTileActions
            iconName: "edit"
            label: "Rename tile"
            onClicked: {
                if (host)
                    host.beginItemRename(menu.menuItem ? menu.menuItem.id : "");
                menu.dismiss();
            }
        }

        MenuRow {
            visible: menuType === "tile"
            iconName: "create_new_folder"
            label: "Group into folder"
            onClicked: {
                if (host)
                    host.createFolderWithTile(menu.menuItem, "New folder");
                menu.dismiss();
            }
        }

        Repeater {
            model: menu.foldersInGroup

            MenuRow {
                required property var modelData
                iconName: "folder"
                label: "Add to \"" + (modelData.name || "Folder") + "\""
                onClicked: {
                    if (host)
                        host.addTileToFolder(menu.menuItem, modelData.id);
                    menu.dismiss();
                }
            }
        }

        MenuRow {
            visible: menu.showMoveToGroup && menuType === "tile"
            iconName: "swap_horiz"
            label: "Move to " + (menuGroupId === 1 ? ((host && host.group2Title) || "Play & explore") : ((host && host.group1Title) || "Life at a glance"))
            onClicked: {
                if (host)
                    host.moveTileBetweenGroups(menu.menuItem);
                menu.dismiss();
            }
        }

        MenuRow {
            visible: menu.showFolderActions
            iconName: (host && menuItem && host.openFolderId === menuItem.id) ? "folder" : "folder_open"
            label: (host && menuItem && host.openFolderId === menuItem.id) ? "Close folder" : "Open folder"
            onClicked: {
                if (host && menuItem) {
                    if (host.openFolderId === menuItem.id)
                        host.closeActiveFolder();
                    else
                        host.openFolder(menuItem.id, menuGroupId);
                }
                menu.dismiss();
            }
        }

        Item {
            visible: menu.showResize && menuType === "folder"
            width: parent.width
            height: visible ? 50 : 0

            Column {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 4

                StyledText {
                    text: "Resize"
                    font.pixelSize: 11
                    color: menu.winMuted
                }

                Row {
                    spacing: 4
                    width: parent.width

                    Repeater {
                        model: [
                            { "id": "medium", "label": "Medium" },
                            { "id": "wide", "label": "Wide" }
                        ]

                        Rectangle {
                            required property var modelData
                            readonly property bool isCurrent: menu.menuItem && (menu.menuItem.size === modelData.id || (!menu.menuItem.size && modelData.id === (menu.menuItem.wide ? "wide" : "medium")))

                            width: 88
                            height: 24
                            radius: 4
                            color: isCurrent ? menu.winAccent : (fRBtnHover.containsMouse ? menu.winHover : Qt.rgba(255, 255, 255, 0.05))
                            border.color: isCurrent ? Qt.lighter(menu.winAccent, 1.2) : Qt.rgba(255, 255, 255, 0.15)
                            border.width: 1

                            StyledText {
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                font.pixelSize: 10
                                font.weight: parent.isCurrent ? Font.DemiBold : Font.Normal
                                color: parent.isCurrent ? Theme.primaryText : menu.winText
                            }

                            MouseArea {
                                id: fRBtnHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (host)
                                        host.setTileSize(menu.menuItem, parent.modelData.id);
                                    menu.dismiss();
                                }
                            }
                        }
                    }
                }
            }
        }

        MenuRow {
            visible: menu.showFolderActions
            iconName: "edit"
            label: "Rename folder"
            onClicked: {
                if (host)
                    host.beginItemRename(menuItem ? menuItem.id : "");
                menu.dismiss();
            }
        }

        MenuRow {
            visible: menu.showFolderActions
            iconName: "folder_delete"
            label: "Ungroup folder"
            onClicked: {
                if (host)
                    host.ungroupFolder(menuItem);
                menu.dismiss();
            }
        }

        MenuRow {
            visible: menu.showMoveToGroup && menuType === "folder"
            iconName: "swap_horiz"
            label: "Move to " + (menuGroupId === 1 ? ((host && host.group2Title) || "Play & explore") : ((host && host.group1Title) || "Life at a glance"))
            onClicked: {
                if (host)
                    host.moveTileBetweenGroups(menuItem);
                menu.dismiss();
            }
        }

        MenuRow {
            visible: menuType === "folderTile"
            iconName: "drive_file_move"
            label: "Remove from folder"
            onClicked: {
                if (host)
                    host.removeTileFromFolder(menuItem, parentFolder ? parentFolder.id : "");
                menu.dismiss();
            }
        }

        MenuRow {
            visible: menu.showMoveToGroup && menuType === "groupHeader"
            iconName: "edit"
            label: "Rename group"
            onClicked: {
                menu.dismiss();
                if (host)
                    host.beginGroupRename(menuGroupId);
            }
        }

        MenuSep {
            visible: menu.showUnpin
        }

        MenuRow {
            visible: menu.showUnpin
            iconName: "remove_circle_outline"
            label: menuType === "folder" ? "Unpin folder from Start" : "Unpin from Start"
            onClicked: {
                if (host)
                    host.unpinTile(menuItem);
                menu.dismiss();
            }
        }
    }

    component MenuRow: Item {
        id: pr

        property string iconName: ""
        property string label: ""
        signal clicked()

        width: parent ? parent.width : 200
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: prHover.containsMouse ? menu.winHover : "transparent"
        }

        DankIcon {
            id: prIcon
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            name: pr.iconName
            size: 16
            color: menu.winText
        }

        StyledText {
            anchors.left: prIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: pr.label
            color: menu.winText
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        MouseArea {
            id: prHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pr.clicked()
        }
    }

    component MenuSep: Rectangle {
        width: parent ? parent.width - 16 : 184
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        height: 1
        color: Qt.rgba(255, 255, 255, 0.08)
    }
}

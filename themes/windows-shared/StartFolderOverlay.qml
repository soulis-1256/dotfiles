import QtQuick
import qs.Common
import qs.Widgets
import "PinGrid.js" as PinGrid

// Shared Start folder overlay. Both win10Start and win11Start instantiate this.
// Open/close animation and slot math live here so a future pack can inherit them.
// Theme attributes: panelRadius, tileRadius, panelBorderWidth, panelBorderColor,
// centeredTiles, alignToGroup, pinIconSize, pinIconGap, pinLabelSize,
// tileColor, tileHoverColor, tileBorderHover, openDuration, closeDuration.

Item {
    id: overlay

    property var host: null
    property var coordinateItem: null
    property var paneItem: parent
    property var flickableItem: null
    property var tileRowItem: null
    property var group1Item: null
    property var group2Item: null

    property real panelRadius: 0
    property real tileRadius: 0
    property int panelBorderWidth: 0
    property color panelBorderColor: "transparent"
    property bool centeredTiles: false
    property bool alignToGroup: false
    property int pinIconSize: 36
    property int pinIconGap: 4
    property int pinLabelSize: 11
    property int overlayWidth: 300
    property int openDuration: 220
    property int closeDuration: 160
    property real openScaleFrom: 0.32
    property color tileColor: host && host.winTileBg !== undefined ? host.winTileBg : Qt.rgba(1, 1, 1, 0.10)
    property color tileHoverColor: host && host.winTileHoverBg !== undefined ? host.winTileHoverBg : Qt.rgba(1, 1, 1, 0.18)
    property color tileBorderHover: Qt.rgba(1, 1, 1, 0.4)

    readonly property var folderData: {
        if (!host || !host.openFolderId)
            return null;
        if (typeof host.getOpenFolderData === "function")
            return host.getOpenFolderData();
        return PinGrid.findFolder([host.group1Tiles || [], host.group2Tiles || []], host.openFolderId);
    }
    readonly property bool extraDropSlot: !!(host && host.isDraggingTile && host.dropTargetType === "reorder-folder" && folderData && host.draggedFromFolderId !== folderData.id)
    readonly property real calculatedHeight: {
        var count = PinGrid.folderOverlayCount(folderData, extraDropSlot);
        if (!folderData)
            return 60;
        if (count <= 0)
            return 60;
        return PinGrid.folderOverlayHeight(count);
    }
    readonly property bool folderOpen: !!(host && host.openFolderId !== "")
    readonly property bool presenting: folderOpen || closing || openProgress > 0.01

    onCalculatedHeightChanged: {
        if (folderOpen)
            place();
    }

    property bool closing: false
    property real openProgress: 0
    property real originX: overlayWidth / 2
    property real originY: 0
    property var lastSourceItem: null
    property var lastTileRect: null
    property real fromScaleX: 0.32
    property real fromScaleY: 0.32

    function folderSlotToPixel(slot) {
        var p = PinGrid.folderSlotToPixel(slot);
        return Qt.point(p.x, p.y);
    }

    function calculateFolderSlot(mx, my) {
        var totalCount = folderData && folderData.tiles ? folderData.tiles.length : 0;
        var fromThis = !!(host && folderData && host.draggedFromFolderId === folderData.id);
        return PinGrid.folderSlotFromPoint(mx, my, totalCount, fromThis);
    }

    function getFolderTileDisplacement(itemIndex) {
        if (!host || host.dragCommitting || !host.isDraggingTile || host.dropTargetType !== "reorder-folder" || !folderData || host.dropTargetFolderId !== folderData.id)
            return Qt.point(0, 0);
        var draggedIdx = (host.draggedFromFolderId === folderData.id) ? host.draggedSourceIndex : -1;
        var p = PinGrid.folderTileDisplacement(itemIndex, host.dropTargetIndex, draggedIdx);
        return Qt.point(p.x, p.y);
    }

    function hitTest(coordItem, globalX, globalY) {
        if (!presenting || !folderPanel.visible)
            return false;
        const foPt = folderPanel.mapFromItem(coordItem, globalX, globalY);
        return foPt.x >= -40 && foPt.x <= folderPanel.width + 40 && foPt.y >= -48 && foPt.y <= folderPanel.height + 48;
    }

    function slotAt(coordItem, globalX, globalY) {
        const foPt = folderPanel.mapFromItem(coordItem, globalX, globalY);
        return calculateFolderSlot(foPt.x, foPt.y);
    }

    function lookupFolder(folderId) {
        const id = folderId || (host ? host.openFolderId : "");
        if (!id)
            return null;
        if (typeof host.getOpenFolderData === "function" && host.openFolderId === id)
            return host.getOpenFolderData();
        return PinGrid.findFolder([host.group1Tiles || [], host.group2Tiles || []], id);
    }

    function resolveSourceItem(sourceItem) {
        if (sourceItem && typeof sourceItem.mapToItem === "function")
            return sourceItem;
        if (lastSourceItem && typeof lastSourceItem.mapToItem === "function")
            return lastSourceItem;
        if (!host || !host.openFolderId)
            return null;
        const gid = host.openFolderGroupId;
        const group = (gid === 2 && group2Item) ? group2Item : group1Item;
        if (group && typeof group.tileItemById === "function")
            return group.tileItemById(host.openFolderId);
        return null;
    }

    // Map the folder pin into this overlay (unscaled). Never map into
    // folderPanel — its Scale transform turns a 0-scale inverse into
    // off-screen origins.
    function sourceTileRect(sourceItem) {
        const src = resolveSourceItem(sourceItem);
        if (!src || typeof src.mapToItem !== "function")
            return lastTileRect;
        const p = src.mapToItem(overlay, 0, 0);
        if (!isFinite(p.x) || !isFinite(p.y))
            return lastTileRect;
        return {
            "x": p.x,
            "y": p.y,
            "w": Math.max(1, src.width),
            "h": Math.max(1, src.height)
        };
    }

    function paneSize() {
        return {
            "w": (paneItem && paneItem.width > 1) ? paneItem.width : ((host && host.pinnedGridWidth) ? host.pinnedGridWidth + 32 : overlay.width),
            "h": (paneItem && paneItem.height > 1) ? paneItem.height : ((host && host.pinnedPaneHeight) ? host.pinnedPaneHeight : overlay.height)
        };
    }

    function geometricFallbackPos(folderId, overlayH, paneW, paneH) {
        const data = lookupFolder(folderId);
        const col = data && typeof data.col === "number" ? data.col : 0;
        const row = data && typeof data.row === "number" ? data.row : 0;
        let marginLeft = PinGrid.FLOW_PAD_LEFT;
        let marginTop = PinGrid.FLOW_PAD_TOP;
        if (tileRowItem) {
            marginLeft = tileRowItem.anchors.leftMargin;
            marginTop = tileRowItem.anchors.topMargin;
        }
        let contentX = flickableItem ? flickableItem.contentX : 0;
        let contentY = flickableItem ? flickableItem.contentY : 0;
        if (group1Item && typeof group1Item.mapToItem === "function") {
            const g = (host && host.openFolderGroupId === 2 && group2Item && group2Item.visible) ? group2Item : group1Item;
            const gp = g.mapToItem(overlay, 0, 0);
            if (isFinite(gp.x) && isFinite(gp.y)) {
                marginLeft = gp.x;
                marginTop = gp.y;
                contentX = 0;
                contentY = 0;
            }
        } else if (host && host.openFolderGroupId === 2 && group2Item && group2Item.visible && group1Item) {
            marginLeft += group1Item.width + (tileRowItem ? tileRowItem.spacing : 16);
        }
        return PinGrid.folderOverlayPos(
            col, row, overlayWidth, overlayH,
            paneW, paneH,
            contentX, contentY,
            marginLeft, marginTop, overlay.alignToGroup
        );
    }

    function applyOriginFromTile(tile) {
        if (!tile)
            return;
        originX = tile.x + tile.w / 2 - folderPanel.x;
        originY = tile.y + tile.h / 2 - folderPanel.y;
    }

    function applyScaleFromTile(tile) {
        const panelH = Math.max(1, folderPanel.height);
        if (!tile) {
            fromScaleX = overlay.openScaleFrom;
            fromScaleY = overlay.openScaleFrom;
            return;
        }
        fromScaleX = Math.max(0.08, Math.min(0.95, tile.w / overlayWidth));
        fromScaleY = Math.max(0.08, Math.min(0.95, tile.h / panelH));
    }

    function place(folderId, sourceItem) {
        if (!host)
            return;
        const data = lookupFolder(folderId);
        if (!data && !(host && host.openFolderId))
            return;
        const pane = paneSize();
        const overlayH = PinGrid.folderOverlayHeight(PinGrid.folderOverlayCount(data, extraDropSlot));
        const tile = sourceTileRect(sourceItem);
        if (tile)
            lastTileRect = tile;

        let x;
        let y;
        if (lastTileRect) {
            x = overlay.alignToGroup ? (lastTileRect.x - 6) : (lastTileRect.x + (lastTileRect.w - overlayWidth) / 2);
            y = lastTileRect.y;
        } else {
            const pos = geometricFallbackPos(folderId, overlayH, pane.w, pane.h);
            x = pos.x;
            y = pos.y;
        }
        const pad = 8;
        const maxX = Math.max(pad, pane.w - overlayWidth - pad);
        const maxY = Math.max(pad, pane.h - overlayH - pad);
        folderPanel.x = Math.max(pad, Math.min(maxX, x));
        folderPanel.y = Math.max(pad, Math.min(maxY, y));
        applyOriginFromTile(lastTileRect);
        if (openProgress < 0.05 && !closing)
            applyScaleFromTile(lastTileRect);
    }

    function open(folderId, groupId, sourceItem) {
        if (!host || !folderId)
            return;
        closeAnim.stop();
        openAnim.stop();
        const switching = host.openFolderId !== "" && host.openFolderId !== folderId;
        closing = false;
        lastSourceItem = sourceItem || null;
        host.powerMenuOpen = false;
        host.userMenuOpen = false;
        host.contextMenuVisible = false;
        host.contextMenuItem = null;
        host.contextMenuParentFolder = null;
        host.renamingItemId = "";
        host.activeRenameInput = null;
        host.openFolderGroupId = groupId || 1;
        host.openFolderWidth = overlayWidth;
        host.openFolderId = folderId;
        place(folderId, sourceItem);
        applyScaleFromTile(lastTileRect);
        if (switching) {
            openProgress = 1;
            return;
        }
        if (openProgress >= 0.99)
            return;
        openProgress = 0;
        openAnim.start();
    }

    function close(immediate) {
        if (!host)
            return;
        if (closing && !immediate)
            return;
        host.renamingItemId = "";
        host.activeRenameInput = null;
        if (!host.openFolderId && openProgress <= 0.01) {
            finishClose();
            return;
        }
        // Re-read the pin so close shrinks back into it, not wherever
        // the overlay was clamped.
        place(host.openFolderId, lastSourceItem);
        if (immediate || openProgress <= 0.05) {
            openAnim.stop();
            closeAnim.stop();
            finishClose();
            return;
        }
        closing = true;
        openAnim.stop();
        closeAnim.start();
    }

    function finishClose() {
        closing = false;
        openProgress = 0;
        lastSourceItem = null;
        lastTileRect = null;
        if (!host)
            return;
        host.openFolderId = "";
        host.openFolderGroupId = 0;
        host.renamingItemId = "";
        host.activeRenameInput = null;
    }

    function showFolderContextMenu(mouse, fromItem) {
        if (!host || !folderData || !coordinateItem)
            return;
        const gp = fromItem.mapToItem(coordinateItem, mouse.x, mouse.y);
        host.contextMenuItem = folderData;
        host.contextMenuGroupId = host.openFolderGroupId;
        host.contextMenuType = "folder";
        host.contextMenuX = Math.min(gp.x, coordinateItem.width - 210);
        host.contextMenuY = Math.min(gp.y, coordinateItem.height - 180);
        host.contextMenuVisible = true;
    }

    anchors.fill: parent
    z: 70
    visible: presenting
    enabled: presenting

    NumberAnimation {
        id: openAnim
        target: overlay
        property: "openProgress"
        to: 1
        duration: overlay.openDuration
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: overlay
        property: "openProgress"
        to: 0
        duration: overlay.closeDuration
        easing.type: Easing.InCubic
        onStopped: {
            if (overlay.openProgress <= 0.01)
                overlay.finishClose();
        }
    }

    MouseArea {
        id: folderDismissBackdrop

        anchors.fill: parent
        z: 0
        visible: overlay.presenting && !(host && host.isDraggingTile)
        enabled: !(host && host.isDraggingTile)
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            if (host)
                host.closeActiveFolder();
        }
    }

    Item {
        id: folderPanel

        z: 1
        width: overlay.overlayWidth
        height: Math.min((overlay.paneItem ? overlay.paneItem.height : overlay.height) - y - 16, overlay.calculatedHeight)
        visible: overlay.folderData !== null && overlay.presenting
        opacity: 1
        transform: Scale {
            origin.x: overlay.originX
            origin.y: overlay.originY
            xScale: overlay.fromScaleX + (1 - overlay.fromScaleX) * overlay.openProgress
            yScale: overlay.fromScaleY + (1 - overlay.fromScaleY) * overlay.openProgress
        }

        Rectangle {
            anchors.fill: parent
            radius: overlay.panelRadius
            color: Theme.surfaceContainerHigh
            border.width: overlay.panelBorderWidth
            border.color: overlay.panelBorderColor
            clip: overlay.panelRadius > 0

            MouseArea {
                anchors.fill: parent
                z: -1
                enabled: !(host && host.isDraggingTile)
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton)
                        overlay.showFolderContextMenu(mouse, this);
                }
            }

            Column {
                id: folderInnerCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 6

                Item {
                    width: parent.width
                    height: 24

                    readonly property bool foRenaming: overlay.folderData && host && host.renamingItemId === overlay.folderData.id

                    StyledText {
                        id: foTitleText

                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - 12)
                        visible: !parent.foRenaming
                        text: overlay.folderData ? (overlay.folderData.name || "Folder") : "Folder"
                        color: foTitleMouse.containsMouse ? "#ffffff" : (host ? host.winText : Theme.surfaceText)
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: foTitleMouse

                        anchors.fill: foTitleText
                        anchors.margins: -4
                        enabled: foTitleText.visible
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: function(mouse) {
                            if (!overlay.folderData || !host)
                                return;
                            if (mouse.button === Qt.RightButton) {
                                overlay.showFolderContextMenu(mouse, this);
                                return;
                            }
                            host.beginItemRename(overlay.folderData.id);
                        }
                    }

                    TextInput {
                        id: foRenameInput

                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(Math.max(Math.ceil(contentWidth) + 2, 16), parent.width - 12)
                        visible: parent.foRenaming
                        z: 2
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: host ? host.winText : Theme.surfaceText
                        selectByMouse: true
                        selectionColor: host ? host.winAccent : Theme.primary
                        selectedTextColor: "#ffffff"
                        clip: true
                        text: overlay.folderData ? (overlay.folderData.name || "") : ""

                        onVisibleChanged: {
                            if (!host)
                                return;
                            if (visible) {
                                text = overlay.folderData ? (overlay.folderData.name || "") : "";
                                host.bindRenameInput(foRenameInput);
                            } else if (host.activeRenameInput === foRenameInput) {
                                host.activeRenameInput = null;
                            }
                        }

                        onAccepted: {
                            if (host && overlay.folderData)
                                host.renameTileOrFolder(overlay.folderData.id, text);
                            if (host)
                                host.dismissInlineRename();
                        }

                        Keys.onEscapePressed: function(event) {
                            if (host)
                                host.dismissInlineRename();
                            event.accepted = true;
                        }
                    }

                    Rectangle {
                        visible: foRenameInput.visible
                        anchors.left: foRenameInput.left
                        width: foRenameInput.width
                        anchors.top: foRenameInput.bottom
                        anchors.topMargin: 1
                        height: 1
                        color: host ? host.winAccent : Theme.primary
                    }
                }

                Item {
                    id: folderTileArea
                    width: 288
                    implicitHeight: PinGrid.folderGridHeight(PinGrid.folderOverlayCount(overlay.folderData, overlay.extraDropSlot))
                    height: implicitHeight

                    Rectangle {
                        id: foSlotPlaceholder
                        z: 10
                        visible: host && host.isDraggingTile && host.dropTargetType === "reorder-folder" && host.dropTargetFolderId === (overlay.folderData ? overlay.folderData.id : "")
                        width: 92
                        height: 92
                        radius: overlay.tileRadius
                        color: host ? Qt.rgba(host.winAccent.r, host.winAccent.g, host.winAccent.b, 0.2) : Qt.rgba(1, 1, 1, 0.2)
                        border.color: host ? host.winAccent : Theme.primary
                        border.width: 2

                        readonly property point slotPos: overlay.folderSlotToPixel(host ? host.dropTargetIndex : 0)
                        x: slotPos.x
                        y: slotPos.y
                    }

                    Repeater {
                        id: foRepeater
                        model: overlay.folderData ? (overlay.folderData.tiles || []) : []

                        Rectangle {
                            id: foTileRect

                            required property var modelData
                            required property int index

                            readonly property bool isBeingDragged: !!(host && host.isDraggingTile && host.draggedTileData && host.draggedTileData.id === modelData.id)
                            readonly property point normalPos: overlay.folderSlotToPixel(index)
                            readonly property bool renaming: !!(host && host.renamingItemId === modelData.id)

                            x: normalPos.x
                            y: normalPos.y
                            width: 92
                            height: 92
                            radius: overlay.tileRadius
                            color: foTileMouse.containsMouse ? overlay.tileHoverColor : overlay.tileColor
                            border.color: foTileMouse.containsMouse ? overlay.tileBorderHover : "transparent"
                            border.width: 1
                            opacity: isBeingDragged ? 0.0 : 1.0
                            scale: foTileMouse.pressed && (foTileMouse.pressedButtons & Qt.LeftButton) && !foTileMouse.draggingStarted ? 0.96 : 1

                            Behavior on scale {
                                NumberAnimation { duration: 80 }
                            }

                            readonly property point displacement: overlay.getFolderTileDisplacement(index)

                            transform: Translate {
                                x: foTileRect.displacement.x
                                y: foTileRect.displacement.y

                                Behavior on x {
                                    enabled: host && host.isDraggingTile && !host.dragCommitting
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                                Behavior on y {
                                    enabled: host && host.isDraggingTile && !host.dragCommitting
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                            }

                            Item {
                                anchors.fill: parent
                                visible: !overlay.centeredTiles

                                AppIconRenderer {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 16
                                    width: overlay.pinIconSize
                                    height: overlay.pinIconSize
                                    iconValue: modelData.icon || ""
                                    iconSize: overlay.pinIconSize
                                    fallbackText: (modelData.name || "?").charAt(0)
                                }

                                StyledText {
                                    visible: !foTileRect.renaming
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 6
                                    text: modelData.name || ""
                                    color: host ? host.winText : Theme.surfaceText
                                    font.pixelSize: overlay.pinLabelSize
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                TextInput {
                                    id: foTileRenameFlat

                                    visible: foTileRect.renaming
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 6
                                    width: Math.min(Math.max(Math.ceil(contentWidth) + 2, 16), parent.width - 16)
                                    font.pixelSize: overlay.pinLabelSize
                                    color: host ? host.winText : Theme.surfaceText
                                    selectByMouse: true
                                    selectionColor: host ? host.winAccent : Theme.primary
                                    selectedTextColor: "#ffffff"
                                    clip: true
                                    text: modelData.name || ""
                                    z: 2

                                    onVisibleChanged: {
                                        if (!host)
                                            return;
                                        if (visible) {
                                            text = modelData.name || "";
                                            host.bindRenameInput(foTileRenameFlat);
                                        } else if (host.activeRenameInput === foTileRenameFlat) {
                                            host.activeRenameInput = null;
                                        }
                                    }

                                    onAccepted: {
                                        if (host)
                                            host.renameTileOrFolder(modelData.id, text);
                                        if (host)
                                            host.dismissInlineRename();
                                    }

                                    Keys.onEscapePressed: function(event) {
                                        if (host)
                                            host.dismissInlineRename();
                                        event.accepted = true;
                                    }
                                }

                                Rectangle {
                                    visible: foTileRenameFlat.visible
                                    anchors.left: foTileRenameFlat.left
                                    width: foTileRenameFlat.width
                                    anchors.top: foTileRenameFlat.bottom
                                    anchors.topMargin: 1
                                    height: 1
                                    color: host ? host.winAccent : Theme.primary
                                    z: 2
                                }
                            }

                            Column {
                                visible: overlay.centeredTiles
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: overlay.pinIconGap
                                width: parent.width - 8

                                AppIconRenderer {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: overlay.pinIconSize
                                    height: overlay.pinIconSize
                                    iconValue: modelData.icon || ""
                                    iconSize: overlay.pinIconSize
                                    fallbackText: (modelData.name || "?").charAt(0)
                                }

                                StyledText {
                                    visible: !foTileRect.renaming
                                    width: parent.width
                                    text: modelData.name || ""
                                    color: host ? host.winText : Theme.surfaceText
                                    font.pixelSize: overlay.pinLabelSize
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                }

                                TextInput {
                                    id: foTileRenameCentered

                                    visible: foTileRect.renaming
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(Math.max(Math.ceil(contentWidth) + 2, 16), parent.width)
                                    font.pixelSize: overlay.pinLabelSize
                                    color: host ? host.winText : Theme.surfaceText
                                    selectByMouse: true
                                    selectionColor: host ? host.winAccent : Theme.primary
                                    selectedTextColor: "#ffffff"
                                    clip: true
                                    text: modelData.name || ""
                                    z: 2

                                    onVisibleChanged: {
                                        if (!host)
                                            return;
                                        if (visible) {
                                            text = modelData.name || "";
                                            host.bindRenameInput(foTileRenameCentered);
                                        } else if (host.activeRenameInput === foTileRenameCentered) {
                                            host.activeRenameInput = null;
                                        }
                                    }

                                    onAccepted: {
                                        if (host)
                                            host.renameTileOrFolder(modelData.id, text);
                                        if (host)
                                            host.dismissInlineRename();
                                    }

                                    Keys.onEscapePressed: function(event) {
                                        if (host)
                                            host.dismissInlineRename();
                                        event.accepted = true;
                                    }
                                }
                            }

                            Rectangle {
                                visible: overlay.centeredTiles && foTileRenameCentered.visible
                                anchors.left: foTileRenameCentered.left
                                width: foTileRenameCentered.width
                                anchors.top: foTileRenameCentered.bottom
                                anchors.topMargin: 1
                                height: 1
                                color: host ? host.winAccent : Theme.primary
                                z: 2
                            }

                            MouseArea {
                                id: foTileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                property point pressPos: Qt.point(0, 0)
                                property bool draggingStarted: false
                                enabled: host && host.renamingItemId !== modelData.id && (!host.isDraggingTile || draggingStarted)

                                onPressed: function(mouse) {
                                    if (!host)
                                        return;
                                    if (host.isDraggingTile) {
                                        if (mouse.button === Qt.RightButton) {
                                            host.cancelDraggingTile();
                                            return;
                                        }
                                    }
                                    if (mouse.button === Qt.RightButton) {
                                        if (!overlay.coordinateItem)
                                            return;
                                        const gp = mapToItem(overlay.coordinateItem, mouse.x, mouse.y);
                                        host.contextMenuItem = modelData;
                                        host.contextMenuGroupId = host.openFolderGroupId;
                                        host.contextMenuType = "folderTile";
                                        host.contextMenuParentFolder = overlay.folderData;
                                        host.contextMenuX = Math.min(gp.x, overlay.coordinateItem.width - 210);
                                        host.contextMenuY = Math.min(gp.y, overlay.coordinateItem.height - 240);
                                        host.contextMenuVisible = true;
                                        return;
                                    }
                                    if (mouse.button !== Qt.LeftButton)
                                        return;
                                    pressPos = Qt.point(mouse.x, mouse.y);
                                    draggingStarted = false;
                                    preventStealing = true;
                                }

                                onPositionChanged: function(mouse) {
                                    if (!host || !overlay.coordinateItem)
                                        return;
                                    if (pressed && (mouse.buttons & Qt.LeftButton)) {
                                        var dist = Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y);
                                        if (!host.isDraggingTile && !draggingStarted && dist > 3) {
                                            draggingStarted = true;
                                            preventStealing = true;
                                            var gp = mapToItem(overlay.coordinateItem, mouse.x, mouse.y);
                                            host.startDraggingTile(modelData, host.openFolderGroupId, host.openFolderId, index, width, height, mouse.x, mouse.y, gp.x, gp.y);
                                        } else if (host.isDraggingTile) {
                                            var gp = mapToItem(overlay.coordinateItem, mouse.x, mouse.y);
                                            host.updateDragPosition(gp.x, gp.y);
                                        }
                                    }
                                }

                                onReleased: function(mouse) {
                                    preventStealing = false;
                                    if (!host) {
                                        draggingStarted = false;
                                        return;
                                    }
                                    if (host.isDraggingTile) {
                                        if (mouse.button === Qt.RightButton)
                                            host.cancelDraggingTile();
                                        else
                                            host.endDraggingTile();
                                    } else if (!draggingStarted) {
                                        if (mouse.button === Qt.RightButton)
                                            return;
                                        if (containsMouse) {
                                            host.launchById(modelData.id);
                                            host.closeMenu();
                                        }
                                    }
                                    draggingStarted = false;
                                }

                                onCanceled: {
                                    preventStealing = false;
                                    if (host && host.isDraggingTile)
                                        host.cancelDraggingTile();
                                    draggingStarted = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

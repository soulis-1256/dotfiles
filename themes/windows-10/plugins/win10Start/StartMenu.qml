import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    // ==========================================
    // SUB-COMPONENTS
    // ==========================================

    id: root

    property var closePopout: null
    property var parentPopout: null
    readonly property color winBg: "#101010"
    readonly property color winPanel: "#101010"
    readonly property color winHover: "#2b2b2b"
    readonly property color winAccent: "#0078d7"
    readonly property color winText: "#ffffff"
    readonly property color winMuted: "#a0a0a0"
    readonly property color winRail: "#101010"
    readonly property color winBorder: "#1a1a1a"
    readonly property color winTileBg: Qt.rgba(1, 1, 1, 0.10)
    readonly property color winTileHoverBg: Qt.rgba(1, 1, 1, 0.18)
    readonly property bool hasGroup1: root.group1Tiles && root.group1Tiles.length > 0
    readonly property bool hasGroup2: root.group2Tiles && root.group2Tiles.length > 0
    readonly property real dynamicTileWidth: {
        if (hasGroup1 && hasGroup2)
            return 640;

        if (hasGroup1 || hasGroup2)
            return 320;

        return 0;
    }
    property bool powerMenuOpen: false
    property bool userMenuOpen: false
    property bool alphabetZoomOpen: false
    property bool isSearchMode: false
    property string query: ""
    property string activeSearchCategory: "all"
    property var flatAppListModel: []
    property var letterIndices: ({
    })
    property var activeLetters: ({
    })
    property var group1Tiles: []
    property var group2Tiles: []
    property var searchResults: []
    property var bestMatchApp: null
    property bool contextMenuVisible: false
    property var contextMenuItem: null
    property string contextMenuType: ""
    property real contextMenuX: 0
    property real contextMenuY: 0

    function closeMenu() {
        root.powerMenuOpen = false;
        root.userMenuOpen = false;
        root.alphabetZoomOpen = false;
        root.contextMenuVisible = false;
        root.query = "";
        root.isSearchMode = false;
        if (root.closePopout)
            root.closePopout();

    }

    function enterSearchMode(initialChar) {
        root.isSearchMode = true;
        root.query = initialChar || "";
        root.updateSearch();
        Qt.callLater(function() {
            searchField.forceActiveFocus();
            searchField.cursorPosition = searchField.text.length;
        });
    }

    function exitSearchMode() {
        root.isSearchMode = false;
        root.query = "";
        root.updateSearch();
        root.forceActiveFocus();
    }

    function lookupEntry(id) {
        if (!id)
            return null;

        let entry = DesktopEntries.heuristicLookup(id);
        if (entry)
            return entry;

        if (typeof DesktopEntries.byId === "function")
            entry = DesktopEntries.byId(id);

        return entry || null;
    }

    function toRow(entry) {
        if (!entry)
            return null;

        return {
            "id": entry.id || "",
            "name": entry.name || "",
            "icon": entry.icon || "",
            "comment": entry.comment || "",
            "exec": entry.exec || ""
        };
    }

    function getAvailableApps() {
        let apps = AppSearchService.getVisibleApplications() || [];
        if (apps.length === 0 && typeof DesktopEntries !== "undefined" && DesktopEntries.applications)
            apps = DesktopEntries.applications.values || [];

        return apps;
    }

    function resolveApp(queryText) {
        const q = (queryText || "").toLowerCase().trim();
        if (!q)
            return null;

        const apps = getAvailableApps();
        let fuzzy = null;
        for (let i = 0; i < apps.length; i++) {
            const app = apps[i];
            const name = (app.name || "").toLowerCase();
            const id = (app.id || "").toLowerCase();
            if (name === q || id === q || id === q + ".desktop")
                return app;

            if (!fuzzy && (name.indexOf(q) !== -1 || id.indexOf(q) !== -1))
                fuzzy = app;

        }
        return fuzzy;
    }

    function buildAppListModel() {
        const ranked = AppUsageHistoryData.getRankedApps() || [];
        const mostUsed = [];
        const seenMostUsed = {
        };
        for (let i = 0; i < ranked.length && mostUsed.length < 5; i++) {
            const row = toRow(lookupEntry(ranked[i].id));
            if (!row || !row.name)
                continue;

            const key = row.id || row.name;
            if (seenMostUsed[key])
                continue;

            seenMostUsed[key] = true;
            mostUsed.push(row);
        }
        const allVisible = getAvailableApps();
        const appRows = [];
        const seenApps = {
        };
        for (let j = 0; j < allVisible.length; j++) {
            const r = toRow(allVisible[j]);
            if (!r || !r.name)
                continue;

            const k = r.id || r.name;
            if (seenApps[k])
                continue;

            seenApps[k] = true;
            appRows.push(r);
        }
        appRows.sort(function(a, b) {
            return (a.name || "").localeCompare(b.name || "");
        });
        const groups = {
        };
        const letterOrder = ["#"];
        for (let c = 65; c <= 90; c++) {
            letterOrder.push(String.fromCharCode(c));
        }
        for (let k = 0; k < appRows.length; k++) {
            const app = appRows[k];
            const first = (app.name || "").trim().charAt(0).toUpperCase();
            let section = "#";
            if (first >= "A" && first <= "Z")
                section = first;

            if (!groups[section])
                groups[section] = [];

            groups[section].push(app);
        }
        const model = [];
        const indices = {
        };
        const active = {
        };
        if (mostUsed.length > 0) {
            model.push({
                "itemType": "header",
                "title": "Most used",
                "key": "most_used"
            });
            for (let m = 0; m < mostUsed.length; m++) {
                model.push({
                    "itemType": "app",
                    "id": mostUsed[m].id,
                    "name": mostUsed[m].name,
                    "icon": mostUsed[m].icon
                });
            }
        }
        for (let l = 0; l < letterOrder.length; l++) {
            const letter = letterOrder[l];
            if (groups[letter] && groups[letter].length > 0) {
                active[letter] = true;
                indices[letter] = model.length;
                model.push({
                    "itemType": "letter",
                    "title": letter,
                    "key": letter
                });
                const list = groups[letter];
                for (let a = 0; a < list.length; a++) {
                    model.push({
                        "itemType": "app",
                        "id": list[a].id,
                        "name": list[a].name,
                        "icon": list[a].icon
                    });
                }
            }
        }
        root.letterIndices = indices;
        root.activeLetters = active;
        root.flatAppListModel = model;
    }

    function defaultGroup1Queries() {
        return [{
            "q": "zen",
            "wide": true
        }, {
            "q": "dolphin",
            "wide": false
        }, {
            "q": "ghostty",
            "wide": true
        }, {
            "q": "zed",
            "wide": false
        }, {
            "q": "brave",
            "wide": false
        }, {
            "q": "localsend",
            "wide": false
        }, {
            "q": "gparted",
            "wide": false
        }];
    }

    function defaultGroup2Queries() {
        return [{
            "q": "steam",
            "wide": false
        }, {
            "q": "spotify",
            "wide": true
        }, {
            "q": "vesktop",
            "wide": false
        }, {
            "q": "vlc",
            "wide": false
        }, {
            "q": "protonup",
            "wide": false
        }];
    }

    function buildTilesFromQueries(queries, fallbackStart) {
        const out = [];
        const seen = {
        };
        for (let i = 0; i < queries.length; i++) {
            const item = queries[i];
            const app = resolveApp(item.q);
            if (!app || !app.name)
                continue;

            const key = app.id || app.name;
            if (seen[key])
                continue;

            seen[key] = true;
            out.push({
                "id": app.id || "",
                "name": app.name,
                "icon": app.icon || "",
                "wide": !!item.wide
            });
        }
        if (out.length < 4) {
            const fallbackApps = getAvailableApps();
            const startIdx = fallbackStart || 0;
            for (let k = startIdx; k < fallbackApps.length && out.length < 6; k++) {
                const fa = fallbackApps[k];
                const kId = fa.id || fa.name;
                if (!fa || !fa.name || seen[kId])
                    continue;

                seen[kId] = true;
                out.push({
                    "id": fa.id || "",
                    "name": fa.name,
                    "icon": fa.icon || "",
                    "wide": false
                });
            }
        }
        return out;
    }

    function refreshTiles() {
        const saved = SettingsData.getPluginSettingsForPlugin("win10Start");
        if (saved && saved.group1Tiles && saved.group1Tiles.length > 0) {
            root.group1Tiles = saved.group1Tiles;
            root.group2Tiles = saved.group2Tiles || [];
            return ;
        }
        root.group1Tiles = buildTilesFromQueries(defaultGroup1Queries(), 0);
        root.group2Tiles = buildTilesFromQueries(defaultGroup2Queries(), 6);
    }

    function saveTilesState() {
        SettingsData.setPluginSetting("win10Start", "group1Tiles", root.group1Tiles);
        SettingsData.setPluginSetting("win10Start", "group2Tiles", root.group2Tiles);
    }

    function pinAppToStart(app) {
        if (!app || !app.id)
            return ;

        const exists1 = root.group1Tiles.some((t) => {
            return t.id === app.id;
        });
        const exists2 = root.group2Tiles.some((t) => {
            return t.id === app.id;
        });
        if (exists1 || exists2)
            return ;

        const newTiles = root.group1Tiles.slice();
        newTiles.push({
            "id": app.id,
            "name": app.name,
            "icon": app.icon || "",
            "wide": false
        });
        root.group1Tiles = newTiles;
        saveTilesState();
    }

    function unpinTile(tile) {
        if (!tile || !tile.id)
            return ;

        root.group1Tiles = root.group1Tiles.filter((t) => {
            return t.id !== tile.id;
        });
        root.group2Tiles = root.group2Tiles.filter((t) => {
            return t.id !== tile.id;
        });
        saveTilesState();
    }

    function toggleTileSize(tile) {
        if (!tile || !tile.id)
            return ;

        const update = (list) => {
            return list.map((t) => {
                if (t.id === tile.id)
                    return {
                        "id": t.id,
                        "name": t.name,
                        "icon": t.icon,
                        "wide": !t.wide
                    };

                return t;
            });
        };
        root.group1Tiles = update(root.group1Tiles);
        root.group2Tiles = update(root.group2Tiles);
        saveTilesState();
    }

    function updateSearch() {
        const q = root.query.trim();
        if (!q) {
            root.searchResults = [];
            root.bestMatchApp = null;
            return ;
        }
        const hits = AppSearchService.searchApplications(q) || [];
        const out = [];
        for (let i = 0; i < hits.length; i++) {
            const row = toRow(hits[i]);
            if (row && row.name)
                out.push(row);

        }
        root.searchResults = out;
        root.bestMatchApp = out.length > 0 ? out[0] : null;
    }

    function launchById(id) {
        const entry = lookupEntry(id);
        if (!entry)
            return ;

        SessionService.launchDesktopEntry(entry);
        AppUsageHistoryData.addAppUsage(entry);
        root.closeMenu();
    }

    function launchBestMatch() {
        if (root.bestMatchApp) {
            launchById(root.bestMatchApp.id);
            return ;
        }
        if (root.query.trim().length > 0) {
            Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(root.query.trim())]);
            root.closeMenu();
        }
    }

    function doPower(action) {
        root.powerMenuOpen = false;
        if (root.closePopout)
            root.closePopout();

        if (action === "lock") {
            Quickshell.execDetached(["loginctl", "lock-session"]);
            return ;
        }
        if (action === "suspend")
            SessionService.suspend();
        else if (action === "reboot")
            SessionService.reboot();
        else if (action === "poweroff")
            SessionService.poweroff();
        else if (action === "logout")
            SessionService.logout();
    }

    implicitWidth: 48 + 260 + dynamicTileWidth
    implicitHeight: 620
    width: implicitWidth
    height: implicitHeight
    onImplicitWidthChanged: {
        if (root.parentPopout)
            root.parentPopout.contentWidth = root.implicitWidth;

    }
    onParentPopoutChanged: {
        if (root.parentPopout)
            root.parentPopout.contentWidth = root.implicitWidth;

    }
    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (root.contextMenuVisible) {
                root.contextMenuVisible = false;
                event.accepted = true;
                return ;
            }
            if (root.alphabetZoomOpen) {
                root.alphabetZoomOpen = false;
                event.accepted = true;
                return ;
            }
            if (root.powerMenuOpen || root.userMenuOpen) {
                root.powerMenuOpen = false;
                root.userMenuOpen = false;
                event.accepted = true;
                return ;
            }
            if (root.isSearchMode) {
                root.exitSearchMode();
                event.accepted = true;
                return ;
            }
            if (root.closePopout) {
                root.closePopout();
                event.accepted = true;
                return ;
            }
        }
        if (!root.isSearchMode && event.text && event.text.length > 0 && event.text.charCodeAt(0) >= 32) {
            root.enterSearchMode(event.text);
            event.accepted = true;
        }
    }
    Component.onCompleted: {
        buildAppListModel();
        refreshTiles();
    }

    Connections {
        function onOpened() {
            root.query = "";
            root.isSearchMode = false;
            root.powerMenuOpen = false;
            root.userMenuOpen = false;
            root.alphabetZoomOpen = false;
            root.contextMenuVisible = false;
            buildAppListModel();
            root.forceActiveFocus();
        }

        target: root.parentPopout
    }

    Connections {
        function onAppUsageRankingChanged() {
            if (!root.isSearchMode)
                buildAppListModel();

        }

        target: AppUsageHistoryData
    }

    Rectangle {
        id: menuBackground

        anchors.fill: parent
        color: root.winBg
        border.width: 0
        clip: true

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.contextMenuVisible = false;
                root.powerMenuOpen = false;
                root.userMenuOpen = false;
                if (root.alphabetZoomOpen)
                    root.alphabetZoomOpen = false;

            }
        }

        // ==========================================
        // NORMAL START MENU VIEW (App List + Tiles)
        // ==========================================
        Row {
            id: standardRow

            anchors.fill: parent
            spacing: 0
            visible: !root.isSearchMode

            // Left rail placeholder
            Item {
                id: railSpace

                width: 48
                height: parent.height
            }

            // Middle: App List
            Item {
                id: appListPane

                width: 260
                height: parent.height

                ListView {
                    id: appListView

                    anchors.fill: parent
                    anchors.margins: 4
                    anchors.topMargin: 8
                    anchors.rightMargin: 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    boundsMovement: Flickable.StopAtBounds
                    flickDeceleration: 2500
                    maximumFlickVelocity: 4000
                    pixelAligned: false
                    model: root.flatAppListModel
                    spacing: 0
                    cacheBuffer: 400

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const pixelY = event.pixelDelta ? event.pixelDelta.y : 0;
                            const angleY = event.angleDelta ? event.angleDelta.y : 0;
                            let dy = 0;
                            if (pixelY !== 0)
                                dy = -pixelY * 2.4;
                            else if (angleY !== 0)
                                dy = -(angleY / 120) * 152;
                            if (dy === 0)
                                return;
                            if (appListView.flicking)
                                appListView.cancelFlick();
                            const maxY = Math.max(0, appListView.contentHeight - appListView.height);
                            appListView.contentY = Math.max(0, Math.min(maxY, appListView.contentY + dy));
                            event.accepted = true;
                        }
                    }

                    delegate: Item {
                        id: appRowItem

                        required property var modelData
                        required property int index

                        width: appListView.width
                        height: modelData.itemType === "header" ? 28 : (modelData.itemType === "letter" ? 34 : 38)

                        // 1. Section Header ("Most used")
                        Item {
                            visible: modelData.itemType === "header"
                            anchors.fill: parent

                            StyledText {
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.title || ""
                                color: root.winText
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                        }

                        // 2. Letter Jump Button ('#', 'A', 'B'...)
                        Item {
                            visible: modelData.itemType === "letter"
                            anchors.fill: parent

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                height: 28
                                color: letterHover.containsMouse ? root.winHover : "transparent"

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.title || ""
                                    color: root.winText
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: letterHover

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.alphabetZoomOpen = true;
                                    }
                                }

                            }

                        }

                        // 3. App Item
                        Item {
                            visible: modelData.itemType === "app"
                            anchors.fill: parent

                            Rectangle {
                                anchors.fill: parent
                                color: rowHover.containsMouse ? root.winHover : "transparent"
                            }

                            AppIconRenderer {
                                id: rowIcon

                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                height: 22
                                iconValue: modelData.icon || ""
                                iconSize: 22
                                fallbackText: (modelData.name || "?").charAt(0)
                            }

                            StyledText {
                                anchors.left: rowIcon.right
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name || ""
                                color: root.winText
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: rowHover

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        const globalPos = mapToItem(menuBackground, mouse.x, mouse.y);
                                        root.contextMenuItem = modelData;
                                        root.contextMenuType = "app";
                                        root.contextMenuX = Math.min(globalPos.x, menuBackground.width - 180);
                                        root.contextMenuY = Math.min(globalPos.y, menuBackground.height - 100);
                                        root.contextMenuVisible = true;
                                        return ;
                                    }
                                    root.launchById(modelData.id);
                                }
                            }

                        }

                    }

                    ScrollBar.vertical: ScrollBar {
                        id: appListScrollBar

                        readonly property bool expanded: hovered || pressed

                        policy: ScrollBar.AsNeeded
                        interactive: true
                        hoverEnabled: true
                        padding: 0
                        implicitWidth: 16
                        minimumSize: 0.08
                        active: hovered || pressed || size < 1.0

                        contentItem: Item {
                            implicitWidth: 16

                            Rectangle {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.rightMargin: 2
                                width: appListScrollBar.expanded ? 10 : 3
                                color: appListScrollBar.pressed ? "#d0d0d0" : (appListScrollBar.expanded ? "#a6a6a6" : "#6a6a6a")
                                radius: 0

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }
                        }

                        background: Rectangle {
                            implicitWidth: 16
                            color: appListScrollBar.expanded ? "#1a1a1a" : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }
                    }

                }

                // Alphabet Zoom Grid Overlay
                Rectangle {
                    id: alphabetZoomOverlay

                    visible: root.alphabetZoomOpen
                    anchors.fill: parent
                    color: root.winBg
                    z: 30

                    MouseArea {
                        anchors.fill: parent
                    }

                    StyledText {
                        id: zoomTitle

                        anchors.top: parent.top
                        anchors.topMargin: 14
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        text: "All apps"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: root.winText
                    }

                    Grid {
                        id: zoomGrid

                        readonly property real cellWidth: Math.floor((width - 3 * spacing) / 4)
                        readonly property real cellHeight: 40

                        anchors.top: zoomTitle.bottom
                        anchors.topMargin: 14
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        columns: 4
                        spacing: 6

                        Repeater {
                            model: ["#", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

                            Rectangle {
                                required property string modelData
                                readonly property bool isActive: !!root.activeLetters[modelData]

                                width: zoomGrid.cellWidth
                                height: zoomGrid.cellHeight
                                color: isActive ? (letterZoomHover.containsMouse ? Qt.lighter(root.winAccent, 1.15) : root.winAccent) : "#252525"
                                border.color: isActive && letterZoomHover.containsMouse ? "#ffffff" : "transparent"
                                border.width: 1

                                StyledText {
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    color: parent.isActive ? "#ffffff" : "#555555"
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: letterZoomHover

                                    anchors.fill: parent
                                    hoverEnabled: parent.isActive
                                    cursorShape: parent.isActive ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (parent.isActive) {
                                            const targetIdx = root.letterIndices[parent.modelData];
                                            if (targetIdx !== undefined)
                                                appListView.positionViewAtIndex(targetIdx, ListView.Beginning);

                                            root.alphabetZoomOpen = false;
                                        }
                                    }
                                }

                            }

                        }

                    }

                }

            }

            // Right: Dynamic Tiles Area
            Item {
                id: tileArea

                width: parent.width - 48 - 260
                height: parent.height
                visible: root.hasGroup1 || root.hasGroup2

                Flickable {
                    id: tileFlickable

                    anchors.fill: parent
                    contentWidth: tileRow.implicitWidth + 32
                    contentHeight: Math.max(parent.height, tileRow.implicitHeight + 24)
                    boundsBehavior: Flickable.StopAtBounds
                    boundsMovement: Flickable.StopAtBounds
                    flickDeceleration: 2500
                    maximumFlickVelocity: 4000
                    clip: true
                    flickableDirection: Flickable.VerticalFlick

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const pixelY = event.pixelDelta ? event.pixelDelta.y : 0;
                            const angleY = event.angleDelta ? event.angleDelta.y : 0;
                            let dy = 0;
                            if (pixelY !== 0)
                                dy = -pixelY * 2.4;
                            else if (angleY !== 0)
                                dy = -(angleY / 120) * 152;
                            if (dy === 0)
                                return;
                            if (tileFlickable.flicking)
                                tileFlickable.cancelFlick();
                            const maxY = Math.max(0, tileFlickable.contentHeight - tileFlickable.height);
                            tileFlickable.contentY = Math.max(0, Math.min(maxY, tileFlickable.contentY + dy));
                            event.accepted = true;
                        }
                    }

                    Row {
                        id: tileRow

                        anchors.top: parent.top
                        anchors.topMargin: 12
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        spacing: 16

                        // Group 1: "Life at a glance" (width = 288px)
                        TileGroup {
                            visible: root.hasGroup1
                            groupTitle: "Life at a glance"
                            tilesModel: root.group1Tiles
                            groupWidth: 288
                        }

                        // Group 2: "Play & explore" (width = 288px)
                        TileGroup {
                            visible: root.hasGroup2
                            groupTitle: "Play & explore"
                            tilesModel: root.group2Tiles
                            groupWidth: 288
                        }

                    }

                }

            }

        }

        // ==========================================
        // WINDOWS 10 SEARCH VIEW
        // ==========================================
        Item {
            id: searchView

            anchors.left: parent.left
            anchors.leftMargin: 48
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: root.isSearchMode

            // Top Search Input bar
            Rectangle {
                id: topSearchBar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 48
                color: root.winPanel
                border.width: 0

                DankIcon {
                    id: searchBarIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 20
                    color: root.winMuted
                }

                TextField {
                    id: searchField

                    anchors.left: searchBarIcon.right
                    anchors.leftMargin: 10
                    anchors.right: clearSearchBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 36
                    color: root.winText
                    font.pixelSize: 15
                    placeholderText: "Type here to search"
                    placeholderTextColor: "#808080"
                    selectByMouse: true
                    text: root.query
                    onTextChanged: {
                        root.query = text;
                        root.updateSearch();
                        if (text.length === 0)
                            root.exitSearchMode();

                    }
                    Keys.onReturnPressed: root.launchBestMatch()
                    Keys.onEnterPressed: root.launchBestMatch()
                    Keys.onEscapePressed: root.exitSearchMode()

                    background: Item {
                    }

                }

                Item {
                    id: clearSearchBtn

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    visible: root.query.length > 0

                    DankIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 16
                        color: clearHover.containsMouse ? "#ffffff" : root.winMuted
                    }

                    MouseArea {
                        id: clearHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.exitSearchMode()
                    }

                }

            }

            // Category Tabs ("All", "Apps", "Web")
            Row {
                id: searchCategoryRow

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.top: topSearchBar.bottom
                anchors.topMargin: 8
                spacing: 12

                CategoryTab {
                    label: "All"
                    isActive: root.activeSearchCategory === "all"
                    onClicked: root.activeSearchCategory = "all"
                }

                CategoryTab {
                    label: "Apps"
                    isActive: root.activeSearchCategory === "apps"
                    onClicked: root.activeSearchCategory = "apps"
                }

                CategoryTab {
                    label: "Web"
                    isActive: root.activeSearchCategory === "web"
                    onClicked: root.activeSearchCategory = "web"
                }

            }

            // Search Content Row
            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: searchCategoryRow.bottom
                anchors.topMargin: 12
                anchors.bottom: parent.bottom
                anchors.margins: 16
                spacing: 20

                // Left: Best Match + Apps list
                Item {
                    width: 420
                    height: parent.height

                    Column {
                        anchors.fill: parent
                        spacing: 12

                        // "Best match" section
                        Item {
                            width: parent.width
                            height: bestMatchCol.implicitHeight
                            visible: root.bestMatchApp !== null

                            Column {
                                id: bestMatchCol

                                width: parent.width
                                spacing: 8

                                StyledText {
                                    text: "Best match"
                                    color: root.winText
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 68
                                    color: bestMatchHover.containsMouse ? root.winHover : "#252525"
                                    border.color: bestMatchHover.containsMouse ? root.winAccent : "transparent"
                                    border.width: 1

                                    AppIconRenderer {
                                        id: bestMatchIcon

                                        anchors.left: parent.left
                                        anchors.leftMargin: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 36
                                        height: 36
                                        iconValue: (root.bestMatchApp && root.bestMatchApp.icon ? root.bestMatchApp.icon : "")
                                        iconSize: 36
                                        fallbackText: (root.bestMatchApp && root.bestMatchApp.name ? root.bestMatchApp.name : "?")
                                    }

                                    Column {
                                        anchors.left: bestMatchIcon.right
                                        anchors.leftMargin: 12
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        StyledText {
                                            width: parent.width
                                            text: (root.bestMatchApp && root.bestMatchApp.name ? root.bestMatchApp.name : "")
                                            color: root.winText
                                            font.pixelSize: 15
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            text: "App"
                                            color: root.winMuted
                                            font.pixelSize: 11
                                        }

                                    }

                                    MouseArea {
                                        id: bestMatchHover

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.launchBestMatch()
                                    }

                                }

                            }

                        }

                        // Secondary matches
                        Item {
                            width: parent.width
                            height: parent.height - (root.bestMatchApp ? 100 : 0)

                            Column {
                                anchors.fill: parent
                                spacing: 6

                                StyledText {
                                    visible: root.searchResults.length > 1
                                    text: "Apps"
                                    color: root.winText
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }

                                ListView {
                                    id: searchResultsView
                                    width: parent.width
                                    height: parent.height - 24
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: root.searchResults.slice(1, 8)
                                    spacing: 2

                                    WheelHandler {
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        onWheel: event => {
                                            const pixelY = event.pixelDelta ? event.pixelDelta.y : 0;
                                            const angleY = event.angleDelta ? event.angleDelta.y : 0;
                                            let dy = 0;
                                            if (pixelY !== 0)
                                                dy = -pixelY * 2.4;
                                            else if (angleY !== 0)
                                                dy = -(angleY / 120) * 114;
                                            if (dy === 0)
                                                return;
                                            if (searchResultsView.flicking)
                                                searchResultsView.cancelFlick();
                                            const maxY = Math.max(0, searchResultsView.contentHeight - searchResultsView.height);
                                            searchResultsView.contentY = Math.max(0, Math.min(maxY, searchResultsView.contentY + dy));
                                            event.accepted = true;
                                        }
                                    }

                                    delegate: Item {
                                        required property var modelData

                                        width: parent.width
                                        height: 38

                                        Rectangle {
                                            anchors.fill: parent
                                            color: searchRowHover.containsMouse ? root.winHover : "transparent"
                                        }

                                        AppIconRenderer {
                                            id: subIcon

                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 22
                                            height: 22
                                            iconValue: modelData.icon || ""
                                            iconSize: 22
                                            fallbackText: (modelData.name || "?").charAt(0)
                                        }

                                        StyledText {
                                            anchors.left: subIcon.right
                                            anchors.leftMargin: 10
                                            anchors.right: parent.right
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name || ""
                                            color: root.winText
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                        }

                                        MouseArea {
                                            id: searchRowHover

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.launchById(modelData.id)
                                        }

                                    }

                                }

                            }

                        }

                    }

                }

                // Right: Best Match Preview Pane
                Rectangle {
                    width: parent.width - 440
                    height: parent.height - 16
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 0
                    visible: root.bestMatchApp !== null

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16

                        AppIconRenderer {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 54
                            height: 54
                            iconValue: (root.bestMatchApp && root.bestMatchApp.icon ? root.bestMatchApp.icon : "")
                            iconSize: 54
                            fallbackText: (root.bestMatchApp && root.bestMatchApp.name ? root.bestMatchApp.name : "?")
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (root.bestMatchApp && root.bestMatchApp.name ? root.bestMatchApp.name : "")
                            color: root.winText
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Desktop app"
                            color: root.winMuted
                            font.pixelSize: 12
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.winBorder
                        }

                        SearchActionButton {
                            iconName: "launch"
                            label: "Open"
                            onClicked: root.launchBestMatch()
                        }

                        SearchActionButton {
                            iconName: "push_pin"
                            label: "Pin to Start"
                            onClicked: {
                                root.pinAppToStart(root.bestMatchApp);
                                root.exitSearchMode();
                            }
                        }

                        SearchActionButton {
                            iconName: "public"
                            label: "Search web for '" + root.query + "'"
                            onClicked: {
                                Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(root.query.trim())]);
                                root.closeMenu();
                            }
                        }

                    }

                }

            }

        }

        // ==========================================
        // LEFT RAIL DRAWER (Human, Settings, Power)
        // ==========================================
        Rectangle {
            id: railDrawer

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 48
            color: root.winRail
            border.width: 0
            z: 50

            // Bottom: User (Human), Settings, Power
            Column {
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 0

                RailActionRow {
                    id: userActionRow

                    width: parent.width
                    iconName: "person"
                    labelText: UserInfoService.fullName || UserInfoService.username || "User"
                    onClicked: {
                        root.userMenuOpen = !root.userMenuOpen;
                        root.powerMenuOpen = false;
                    }
                }

                RailActionRow {
                    id: settingsActionRow

                    width: parent.width
                    iconName: "settings"
                    labelText: "Settings"
                    onClicked: {
                        PopoutService.openSettings();
                        root.closeMenu();
                    }
                }

                RailActionRow {
                    id: powerActionRow

                    width: parent.width
                    iconName: "power_settings_new"
                    labelText: "Power"
                    onClicked: {
                        root.powerMenuOpen = !root.powerMenuOpen;
                        root.userMenuOpen = false;
                    }
                }

            }

        }

        // ==========================================
        // POWER FLYOUT
        // ==========================================
        Rectangle {
            id: powerFlyout

            visible: root.powerMenuOpen
            width: 180
            height: powerCol.implicitHeight + 8
            x: 52
            y: parent.height - height - 8
            color: "#252525"
            border.color: root.winBorder
            border.width: 1
            z: 60

            Column {
                id: powerCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                spacing: 0

                PowerRow {
                    iconName: "bedtime"
                    label: "Sleep"
                    onClicked: root.doPower("suspend")
                }

                PowerRow {
                    iconName: "power_settings_new"
                    label: "Shut down"
                    onClicked: root.doPower("poweroff")
                }

                PowerRow {
                    iconName: "restart_alt"
                    label: "Restart"
                    onClicked: root.doPower("reboot")
                }

                PowerRow {
                    iconName: "lock"
                    label: "Lock"
                    onClicked: root.doPower("lock")
                }

            }

        }

        // ==========================================
        // USER FLYOUT
        // ==========================================
        Rectangle {
            id: userFlyout

            visible: root.userMenuOpen
            width: 210
            height: userCol.implicitHeight + 8
            x: 52
            y: parent.height - (48 * 3) - height - 4
            color: "#252525"
            border.color: root.winBorder
            border.width: 1
            z: 60

            Column {
                id: userCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                spacing: 0

                PowerRow {
                    iconName: "manage_accounts"
                    label: "Account settings"
                    onClicked: {
                        PopoutService.openSettings();
                        root.closeMenu();
                    }
                }

                PowerRow {
                    iconName: "lock"
                    label: "Lock"
                    onClicked: root.doPower("lock")
                }

                PowerRow {
                    iconName: "logout"
                    label: "Sign out"
                    onClicked: root.doPower("logout")
                }

            }

        }

        // ==========================================
        // CONTEXT MENU (Pin/Unpin/Resize)
        // ==========================================
        Rectangle {
            id: contextMenuOverlay

            visible: root.contextMenuVisible
            width: 170
            height: contextMenuCol.implicitHeight + 8
            x: root.contextMenuX
            y: root.contextMenuY
            color: "#252525"
            border.color: root.winBorder
            border.width: 1
            z: 70

            Column {
                id: contextMenuCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                spacing: 0

                PowerRow {
                    visible: root.contextMenuType === "app"
                    iconName: "push_pin"
                    label: "Pin to Start"
                    onClicked: {
                        root.pinAppToStart(root.contextMenuItem);
                        root.contextMenuVisible = false;
                    }
                }

                PowerRow {
                    visible: root.contextMenuType === "tile"
                    iconName: "remove_circle_outline"
                    label: "Unpin from Start"
                    onClicked: {
                        root.unpinTile(root.contextMenuItem);
                        root.contextMenuVisible = false;
                    }
                }

                PowerRow {
                    visible: root.contextMenuType === "tile"
                    iconName: "aspect_ratio"
                    label: (root.contextMenuItem && root.contextMenuItem.wide) ? "Resize to Medium" : "Resize to Wide"
                    onClicked: {
                        root.toggleTileSize(root.contextMenuItem);
                        root.contextMenuVisible = false;
                    }
                }

                PowerRow {
                    iconName: "launch"
                    label: "Launch"
                    onClicked: {
                        root.launchById(root.contextMenuItem ? root.contextMenuItem.id : "");
                        root.contextMenuVisible = false;
                    }
                }

            }

        }

    }

    component RailActionRow: Item {
        id: rar

        property string iconName: ""
        property string labelText: ""

        signal clicked()

        width: 48
        height: 48

        Rectangle {
            anchors.fill: parent
            color: rarHover.containsMouse ? root.winHover : "transparent"
        }

        DankIcon {
            anchors.centerIn: parent
            name: rar.iconName
            size: 20
            color: root.winText
        }

        MouseArea {
            id: rarHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rar.clicked()
        }

        Rectangle {
            id: rarTooltip

            visible: rarHover.containsMouse && rar.labelText !== ""
            anchors.left: parent.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: rarTooltipText.implicitWidth + 16
            height: 28
            color: "#2b2b2b"
            border.color: "#3a3a3a"
            border.width: 1
            z: 100

            StyledText {
                id: rarTooltipText

                anchors.centerIn: parent
                text: rar.labelText
                color: "#ffffff"
                font.pixelSize: 12
            }

        }

    }

    component PowerRow: Item {
        id: pr

        property string iconName: ""
        property string label: ""

        signal clicked()

        width: parent.width
        height: 34

        Rectangle {
            anchors.fill: parent
            color: prHover.containsMouse ? root.winHover : "transparent"
        }

        DankIcon {
            id: prIcon

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            name: pr.iconName
            size: 16
            color: root.winText
        }

        StyledText {
            anchors.left: prIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: pr.label
            color: root.winText
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

    component TileGroup: Item {
        id: tg

        property string groupTitle: ""
        property var tilesModel: []
        property real groupWidth: 288

        implicitWidth: groupWidth
        width: groupWidth
        implicitHeight: tgCol.implicitHeight
        height: tgCol.implicitHeight

        Column {
            id: tgCol

            width: parent.width
            spacing: 8

            // Header with hover drag lines icon
            Item {
                width: parent.width
                height: 24

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: tg.groupTitle
                    color: root.winText
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                DankIcon {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: "drag_handle"
                    size: 18
                    color: tgHeaderHover.containsMouse ? "#ffffff" : "transparent"
                }

                MouseArea {
                    id: tgHeaderHover

                    anchors.fill: parent
                    hoverEnabled: true
                }

            }

            // 3-Column Tile Flow (medium = 92px, wide = 190px, spacing = 6px)
            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: tg.tilesModel

                    Rectangle {
                        id: tileRect

                        required property var modelData
                        required property int index

                        width: modelData.wide ? 190 : 92
                        height: 92
                        color: tileMouse.containsMouse ? root.winTileHoverBg : root.winTileBg
                        border.color: tileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.4) : "transparent"
                        border.width: 1
                        scale: tileMouse.pressed ? 0.96 : 1

                        AppIconRenderer {
                            anchors.centerIn: parent
                            width: 36
                            height: 36
                            iconValue: modelData.icon || ""
                            iconSize: 36
                            fallbackText: (modelData.name || "?").charAt(0)
                        }

                        StyledText {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            text: modelData.name || ""
                            color: "#ffffff"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }

                        MouseArea {
                            id: tileMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    const globalPos = mapToItem(menuBackground, mouse.x, mouse.y);
                                    root.contextMenuItem = modelData;
                                    root.contextMenuType = "tile";
                                    root.contextMenuX = Math.min(globalPos.x, menuBackground.width - 180);
                                    root.contextMenuY = Math.min(globalPos.y, menuBackground.height - 120);
                                    root.contextMenuVisible = true;
                                    return ;
                                }
                                root.launchById(modelData.id);
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 80
                            }

                        }

                    }

                }

            }

        }

    }

    component CategoryTab: Item {
        id: ct

        property string label: ""
        property bool isActive: false

        signal clicked()

        width: ctText.implicitWidth + 16
        height: 28

        Rectangle {
            anchors.fill: parent
            color: ct.isActive ? root.winHover : (ctHover.containsMouse ? "#252525" : "transparent")
            border.color: ct.isActive ? root.winAccent : "transparent"
            border.width: 1
        }

        StyledText {
            id: ctText

            anchors.centerIn: parent
            text: ct.label
            color: ct.isActive ? "#ffffff" : root.winMuted
            font.pixelSize: 12
            font.weight: ct.isActive ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            id: ctHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ct.clicked()
        }

    }

    component SearchActionButton: Item {
        id: sab

        property string iconName: ""
        property string label: ""

        signal clicked()

        width: parent.width
        height: 38

        Rectangle {
            anchors.fill: parent
            color: sabHover.containsMouse ? root.winHover : "transparent"
            border.color: sabHover.containsMouse ? root.winAccent : root.winBorder
            border.width: 1
        }

        DankIcon {
            id: sabIcon

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            name: sab.iconName
            size: 18
            color: root.winText
        }

        StyledText {
            anchors.left: sabIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: sab.label
            color: root.winText
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        MouseArea {
            id: sabHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sab.clicked()
        }

    }

}

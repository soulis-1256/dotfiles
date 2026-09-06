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
    readonly property color winBg: Theme.surfaceContainer
    readonly property color winPanel: Theme.surfaceContainer
    readonly property color winHover: Theme.surfaceContainerHigh
    readonly property color winAccent: Theme.primary
    readonly property color winText: Theme.surfaceText
    readonly property color winMuted: Theme.surfaceVariantText
    readonly property color winRail: Theme.surfaceContainer
    readonly property color winBorder: Theme.outline
    readonly property color winTileBg: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.10)
    readonly property color winTileHoverBg: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.18)
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
    property bool railPinnedOpen: false
    property bool isSearchMode: false
    property string query: ""
    property string activeSearchCategory: "apps"
    property int selectedSearchIndex: 0
    property var hoveredSearchItem: null
    property var flatAppListModel: []
    property var letterIndices: ({})
    property var activeLetters: ({})
    property var group1Tiles: []
    property var group2Tiles: []
    property var searchResults: []
    property var bestMatchApp: null
    readonly property var currentPreviewItem: hoveredSearchItem || (selectedSearchIndex >= 0 && selectedSearchIndex < searchResults.length ? searchResults[selectedSearchIndex] : bestMatchApp)
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
        root.railPinnedOpen = false;
        if (typeof railDrawer !== "undefined" && railDrawer) {
            railDrawer.railHovered = false;
            railDrawer.railTemporarilyDismissed = false;
        }
        root.query = "";
        root.isSearchMode = false;
        root.selectedSearchIndex = 0;
        root.hoveredSearchItem = null;
        if (root.closePopout)
            root.closePopout();
    }

    function enterSearchMode(initialChar) {
        root.isSearchMode = true;
        root.query = initialChar || "";
        root.selectedSearchIndex = 0;
        root.hoveredSearchItem = null;
        root.updateSearch();
        Qt.callLater(function() {
            if (typeof searchField !== "undefined" && searchField) {
                searchField.forceActiveFocus();
                searchField.text = root.query;
                searchField.cursorPosition = searchField.text.length;
            }
        });
    }

    function exitSearchMode() {
        root.isSearchMode = false;
        root.query = "";
        root.selectedSearchIndex = 0;
        root.hoveredSearchItem = null;
        root.activeSearchCategory = "apps";
        root.updateSearch();
        root.forceActiveFocus();
    }

    function toggleSearchCategory() {
        if (root.activeSearchCategory === "apps") {
            root.activeSearchCategory = "web";
        } else {
            root.activeSearchCategory = "apps";
        }
        root.selectedSearchIndex = 0;
        root.hoveredSearchItem = null;
        root.updateSearch();
        if (typeof searchField !== "undefined" && searchField) {
            searchField.forceActiveFocus();
            searchField.cursorPosition = searchField.text.length;
        }
    }

    function navigateDown() {
        const total = root.searchResults.length;
        if (total === 0)
            return;
        if (root.selectedSearchIndex < total - 1) {
            root.selectedSearchIndex++;
            root.hoveredSearchItem = null;
            if (root.selectedSearchIndex > 0 && typeof searchResultsView !== "undefined" && searchResultsView) {
                searchResultsView.positionViewAtIndex(root.selectedSearchIndex - 1, ListView.Contain);
            }
        }
    }

    function navigateUp() {
        const total = root.searchResults.length;
        if (total === 0)
            return;
        if (root.selectedSearchIndex > 0) {
            root.selectedSearchIndex--;
            root.hoveredSearchItem = null;
            if (root.selectedSearchIndex > 0 && typeof searchResultsView !== "undefined" && searchResultsView) {
                searchResultsView.positionViewAtIndex(root.selectedSearchIndex - 1, ListView.Contain);
            }
        }
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

    function isAppPinned(app) {
        if (!app || !app.id)
            return false;
        return root.group1Tiles.some(t => t.id === app.id) || root.group2Tiles.some(t => t.id === app.id);
    }

    function togglePinApp(app) {
        if (!app || !app.id)
            return;
        if (isAppPinned(app))
            unpinTile(app);
        else
            pinAppToStart(app);
    }

    function getTopApps() {
        const ranked = AppUsageHistoryData.getRankedApps() || [];
        const top = [];
        const seen = {};
        for (let i = 0; i < ranked.length && top.length < 5; i++) {
            const row = toRow(lookupEntry(ranked[i].id));
            if (!row || !row.name)
                continue;
            const k = row.id || row.name;
            if (seen[k])
                continue;
            seen[k] = true;
            top.push(row);
        }
        if (top.length < 5) {
            const all = getAvailableApps();
            for (let j = 0; j < all.length && top.length < 5; j++) {
                const r = toRow(all[j]);
                if (!r || !r.name)
                    continue;
                const k = r.id || r.name;
                if (seen[k])
                    continue;
                seen[k] = true;
                top.push(r);
            }
        }
        return top;
    }

    function updateSearch() {
        const q = root.query.trim();
        root.selectedSearchIndex = 0;
        root.hoveredSearchItem = null;

        if (!q) {
            root.searchResults = [];
            root.bestMatchApp = null;
            return;
        }

        if (root.activeSearchCategory === "web") {
            const webItems = [
                {
                    id: "web:google",
                    name: "Search Google for \"" + q + "\"",
                    icon: "public",
                    comment: "Web search",
                    url: "https://www.google.com/search?q=" + encodeURIComponent(q),
                    isWeb: true
                },
                {
                    id: "web:duckduckgo",
                    name: "Search DuckDuckGo for \"" + q + "\"",
                    icon: "public",
                    comment: "Web search",
                    url: "https://duckduckgo.com/?q=" + encodeURIComponent(q),
                    isWeb: true
                },
                {
                    id: "web:github",
                    name: "Search GitHub for \"" + q + "\"",
                    icon: "public",
                    comment: "Web search",
                    url: "https://github.com/search?q=" + encodeURIComponent(q),
                    isWeb: true
                },
                {
                    id: "web:archwiki",
                    name: "Search ArchWiki for \"" + q + "\"",
                    icon: "public",
                    comment: "Web search",
                    url: "https://wiki.archlinux.org/index.php?search=" + encodeURIComponent(q),
                    isWeb: true
                },
                {
                    id: "web:youtube",
                    name: "Search YouTube for \"" + q + "\"",
                    icon: "public",
                    comment: "Web search",
                    url: "https://www.youtube.com/results?search_query=" + encodeURIComponent(q),
                    isWeb: true
                },
                {
                    id: "web:bing",
                    name: "Search Bing for \"" + q + "\"",
                    icon: "public",
                    comment: "Web search",
                    url: "https://www.bing.com/search?q=" + encodeURIComponent(q),
                    isWeb: true
                }
            ];
            root.searchResults = webItems;
            root.bestMatchApp = webItems[0];
            return;
        }

        // Apps mode (default)
        const hits = AppSearchService.searchApplications(q) || [];
        const out = [];
        for (let i = 0; i < hits.length; i++) {
            const row = toRow(hits[i]);
            if (row && row.name)
                out.push(row);
        }

        const webRow = {
            id: "web:google",
            name: "Search the web for \"" + q + "\"",
            icon: "public",
            comment: "Press Tab to switch to Web Search",
            url: "https://www.google.com/search?q=" + encodeURIComponent(q),
            isWeb: true
        };

        if (out.length === 0) {
            root.searchResults = [webRow];
            root.bestMatchApp = webRow;
            return;
        } else {
            out.push(webRow);
        }

        root.searchResults = out;
        root.bestMatchApp = out.length > 0 ? out[0] : null;
    }

    function launchById(id) {
        const entry = lookupEntry(id);
        if (!entry)
            return;

        SessionService.launchDesktopEntry(entry);
        AppUsageHistoryData.addAppUsage(entry);
        root.closeMenu();
    }

    function launchItem(item) {
        if (!item)
            return;
        if (item.isWeb && item.url) {
            Quickshell.execDetached(["xdg-open", item.url]);
            root.closeMenu();
            return;
        }
        if (item.id && !item.isWeb) {
            launchById(item.id);
            return;
        }
        if (root.query.trim().length > 0) {
            Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(root.query.trim())]);
            root.closeMenu();
        }
    }

    function launchSelectedItem() {
        const item = root.currentPreviewItem;
        if (item) {
            root.launchItem(item);
            return;
        }
        if (root.query.trim().length > 0) {
            Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(root.query.trim())]);
            root.closeMenu();
        }
    }

    function launchBestMatch() {
        root.launchSelectedItem();
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

    implicitWidth: root.isSearchMode ? Math.max(880, 48 + 260 + dynamicTileWidth) : (48 + 260 + dynamicTileWidth)
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
                return;
            }
            if (root.alphabetZoomOpen) {
                root.alphabetZoomOpen = false;
                event.accepted = true;
                return;
            }
            if (root.powerMenuOpen || root.userMenuOpen) {
                root.powerMenuOpen = false;
                root.userMenuOpen = false;
                event.accepted = true;
                return;
            }
            if (root.isSearchMode) {
                root.exitSearchMode();
                event.accepted = true;
                return;
            }
            if (root.closePopout) {
                root.closePopout();
                event.accepted = true;
                return;
            }
        }
        if (root.isSearchMode && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
            root.toggleSearchCategory();
            event.accepted = true;
            return;
        }
        if (!root.isSearchMode && event.text && event.text.length > 0 && event.text.charCodeAt(0) >= 32) {
            root.enterSearchMode(event.text);
            event.accepted = true;
            return;
        }
        if (root.isSearchMode && (typeof searchField !== "undefined" && searchField && !searchField.activeFocus) && event.text && event.text.length > 0 && event.text.charCodeAt(0) >= 32) {
            searchField.forceActiveFocus();
            searchField.text += event.text;
            searchField.cursorPosition = searchField.text.length;
            root.query = searchField.text;
            root.updateSearch();
            event.accepted = true;
            return;
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
            root.activeSearchCategory = "apps";
            root.powerMenuOpen = false;
            root.userMenuOpen = false;
            root.alphabetZoomOpen = false;
            root.contextMenuVisible = false;
            root.railPinnedOpen = false;
            if (typeof railDrawer !== "undefined" && railDrawer) {
                railDrawer.railHovered = false;
                railDrawer.railTemporarilyDismissed = false;
            }
            buildAppListModel();
            root.forceActiveFocus();
        }

        function onShouldBeVisibleChanged() {
            if (root.parentPopout && root.parentPopout.shouldBeVisible) {
                root.forceActiveFocus();
            } else {
                root.railPinnedOpen = false;
                if (typeof railDrawer !== "undefined" && railDrawer) {
                    railDrawer.railHovered = false;
                    railDrawer.railTemporarilyDismissed = false;
                }
            }
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
                                color: appListScrollBar.pressed ? Theme.surfaceText : (appListScrollBar.expanded ? Theme.surfaceVariantText : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4))
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
                            color: appListScrollBar.expanded ? Theme.surfaceContainerHigh : "transparent"

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
                                color: isActive ? (letterZoomHover.containsMouse ? Qt.lighter(root.winAccent, 1.15) : root.winAccent) : Theme.surfaceContainer
                                border.color: isActive && letterZoomHover.containsMouse ? Theme.primaryText : "transparent"
                                border.width: 1

                                StyledText {
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    color: parent.isActive ? Theme.primaryText : Theme.surfaceVariantText
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

            // Top Search Input bar (Windows 10 authentic top search box)
            Rectangle {
                id: topSearchBar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 46
                color: root.winPanel

                // Bottom subtle border
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.08)
                }

                // Active focus underline indicator (Windows 10 style)
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 2
                    color: root.winAccent
                    visible: searchField.activeFocus
                }

                DankIcon {
                    id: searchBarIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 18
                    color: searchField.activeFocus ? root.winAccent : root.winMuted
                }

                Item {
                    id: searchInputContainer

                    anchors.left: searchBarIcon.right
                    anchors.leftMargin: 12
                    anchors.right: searchControlsRow.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 32

                    // Custom placeholder text (no floating label bugs!)
                    StyledText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.activeSearchCategory === "web" ? "Type here to search the web..." : "Type here to search apps..."
                        color: root.winMuted
                        font.pixelSize: 14
                        visible: searchField.text.length === 0
                    }

                    TextInput {
                        id: searchField

                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        color: root.winText
                        font.pixelSize: 14
                        selectByMouse: true
                        selectionColor: root.winAccent
                        selectedTextColor: "#ffffff"
                        clip: true
                        text: root.query

                        onTextEdited: {
                            root.query = text;
                            root.updateSearch();
                        }

                        Keys.onTabPressed: event => {
                            root.toggleSearchCategory();
                            event.accepted = true;
                        }

                        Keys.onBacktabPressed: event => {
                            root.toggleSearchCategory();
                            event.accepted = true;
                        }

                        Keys.onDownPressed: event => {
                            root.navigateDown();
                            event.accepted = true;
                        }

                        Keys.onUpPressed: event => {
                            root.navigateUp();
                            event.accepted = true;
                        }

                        Keys.onReturnPressed: root.launchSelectedItem()
                        Keys.onEnterPressed: root.launchSelectedItem()

                        Keys.onEscapePressed: event => {
                            if (searchField.text.length > 0) {
                                searchField.text = "";
                                root.query = "";
                                root.updateSearch();
                            } else {
                                root.exitSearchMode();
                            }
                            event.accepted = true;
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                root.toggleSearchCategory();
                                event.accepted = true;
                                return;
                            }
                            if (event.key === Qt.Key_Backspace && searchField.text.length === 0) {
                                root.exitSearchMode();
                                event.accepted = true;
                                return;
                            }
                        }
                    }
                }

                Row {
                    id: searchControlsRow

                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Clear button
                    Item {
                        width: 32
                        height: 32
                        visible: searchField.text.length > 0

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: clearHover.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                        }

                        DankIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 16
                            color: clearHover.containsMouse ? root.winText : root.winMuted
                        }

                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = "";
                                root.query = "";
                                root.updateSearch();
                                searchField.forceActiveFocus();
                            }
                        }
                    }

                    // Back to Start button
                    Item {
                        width: 32
                        height: 32

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: backHover.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                        }

                        DankIcon {
                            anchors.centerIn: parent
                            name: "arrow_back"
                            size: 16
                            color: backHover.containsMouse ? root.winText : root.winMuted
                        }

                        MouseArea {
                            id: backHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.exitSearchMode()
                        }
                    }
                }
            }

            // Category Tabs ("Apps" and "Search")
            Row {
                id: searchCategoryRow

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.top: topSearchBar.bottom
                anchors.topMargin: 8
                spacing: 16

                CategoryTab {
                    label: "Apps"
                    isActive: root.activeSearchCategory === "apps"
                    onClicked: {
                        root.activeSearchCategory = "apps";
                        root.updateSearch();
                        searchField.forceActiveFocus();
                    }
                }

                CategoryTab {
                    label: "Search"
                    isActive: root.activeSearchCategory === "web"
                    onClicked: {
                        root.activeSearchCategory = "web";
                        root.updateSearch();
                        searchField.forceActiveFocus();
                    }
                }
            }

            // Search Content Container
            Item {
                id: searchContentArea

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: searchCategoryRow.bottom
                anchors.topMargin: 12
                anchors.bottom: parent.bottom
                anchors.margins: 16

                // 1. Windows 10 Search Home View (when query is empty)
                Item {
                    id: searchHomeView
                    anchors.fill: parent
                    visible: root.query.length === 0

                    Row {
                        anchors.fill: parent
                        spacing: 20

                        // Left Column: Top apps + Quick searches
                        Column {
                            width: 440
                            height: parent.height
                            spacing: 20

                            // Top apps section
                            Column {
                                width: parent.width
                                spacing: 10

                                StyledText {
                                    text: "Top apps"
                                    color: root.winText
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }

                                Row {
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: root.getTopApps()

                                        Rectangle {
                                            required property var modelData
                                            required property int index

                                            width: 78
                                            height: 80
                                            color: topAppHover.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : Qt.rgba(255, 255, 255, 0.04)
                                            border.width: 0

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 6

                                                AppIconRenderer {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: 34
                                                    height: 34
                                                    iconValue: modelData.icon || ""
                                                    iconSize: 34
                                                    fallbackText: (modelData.name || "?").charAt(0)
                                                }

                                                StyledText {
                                                    width: 70
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: modelData.name || ""
                                                    color: root.winText
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                    wrapMode: Text.NoWrap
                                                }
                                            }

                                            MouseArea {
                                                id: topAppHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.launchById(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }

                            // Quick searches section
                            Column {
                                width: parent.width
                                spacing: 10

                                StyledText {
                                    text: "Quick searches"
                                    color: root.winText
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }

                                Column {
                                    width: parent.width
                                    spacing: 4

                                    QuickSearchRow {
                                        iconName: "settings"
                                        title: "Settings"
                                        subtitle: "Adjust system and desktop preferences"
                                        onClicked: {
                                            PopoutService.openSettings();
                                            root.closeMenu();
                                        }
                                    }

                                    QuickSearchRow {
                                        iconName: "folder"
                                        title: "File Manager"
                                        subtitle: "Browse files and folders"
                                        onClicked: {
                                            const fm = root.resolveApp("dolphin") || root.resolveApp("nautilus") || root.resolveApp("thunar");
                                            if (fm) root.launchById(fm.id);
                                            else Quickshell.execDetached(["xdg-open", "/home/soulis"]);
                                            root.closeMenu();
                                        }
                                    }

                                    QuickSearchRow {
                                        iconName: "terminal"
                                        title: "Terminal"
                                        subtitle: "Launch command line terminal"
                                        onClicked: {
                                            const term = root.resolveApp("ghostty") || root.resolveApp("kitty") || root.resolveApp("alacritty") || root.resolveApp("foot");
                                            if (term) root.launchById(term.id);
                                            else Quickshell.execDetached(["ghostty"]);
                                            root.closeMenu();
                                        }
                                    }

                                    QuickSearchRow {
                                        iconName: "public"
                                        title: "Search the Web"
                                        subtitle: "Open browser and search online"
                                        onClicked: {
                                            Quickshell.execDetached(["xdg-open", "https://www.google.com"]);
                                            root.closeMenu();
                                        }
                                    }
                                }
                            }
                        }

                        // Right Column: Search Windows welcome banner
                        Rectangle {
                            width: parent.width - 460
                            height: parent.height - 16
                            color: Qt.rgba(0, 0, 0, 0.20)
                            border.width: 0

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 1
                                color: Qt.rgba(255, 255, 255, 0.07)
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 14
                                width: parent.width - 48

                                DankIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: "search"
                                    size: 52
                                    color: root.winAccent
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "Search Windows"
                                    color: root.winText
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: "Start typing to find apps, files, and web results."
                                    color: root.winMuted
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }

                // 2. Active Search Results View (when query is not empty)
                Item {
                    id: searchResultsContent
                    anchors.fill: parent
                    visible: root.query.length > 0

                    Row {
                        anchors.fill: parent
                        spacing: 20

                        // Left: Best Match + Results List
                        Item {
                            width: 420
                            height: parent.height

                            Column {
                                anchors.fill: parent
                                spacing: 10

                                // Best match section
                                Item {
                                    width: parent.width
                                    height: bestMatchCol.implicitHeight
                                    visible: root.bestMatchApp !== null

                                    Column {
                                        id: bestMatchCol

                                        width: parent.width
                                        spacing: 6

                                        StyledText {
                                            text: "Best match"
                                            color: root.winText
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                        }

                                        Rectangle {
                                            readonly property bool isSelected: root.selectedSearchIndex === 0 && !root.hoveredSearchItem
                                            width: parent.width
                                            height: 68
                                            color: isSelected ? Qt.rgba(255, 255, 255, 0.09) : (bestMatchHover.containsMouse ? Qt.rgba(255, 255, 255, 0.07) : Qt.rgba(255, 255, 255, 0.04))
                                            border.width: 0

                                            // Left accent indicator
                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: 3
                                                color: root.winAccent
                                                visible: parent.isSelected || bestMatchHover.containsMouse
                                            }

                                            AppIconRenderer {
                                                id: bestMatchIcon

                                                anchors.left: parent.left
                                                anchors.leftMargin: 14
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 36
                                                height: 36
                                                iconValue: (root.bestMatchApp && root.bestMatchApp.icon ? root.bestMatchApp.icon : (root.bestMatchApp && root.bestMatchApp.isWeb ? "public" : ""))
                                                iconSize: 36
                                                fallbackText: (root.bestMatchApp && root.bestMatchApp.name ? root.bestMatchApp.name.charAt(0) : "?")
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
                                                    wrapMode: Text.NoWrap
                                                }

                                                StyledText {
                                                    width: parent.width
                                                    text: (root.bestMatchApp && root.bestMatchApp.isWeb ? "Web search" : (root.bestMatchApp && root.bestMatchApp.comment ? root.bestMatchApp.comment : "App"))
                                                    color: root.winMuted
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                    wrapMode: Text.NoWrap
                                                }
                                            }

                                            MouseArea {
                                                id: bestMatchHover

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: root.hoveredSearchItem = root.bestMatchApp
                                                onExited: {
                                                    if (root.hoveredSearchItem === root.bestMatchApp)
                                                        root.hoveredSearchItem = null;
                                                }
                                                onClicked: root.launchItem(root.bestMatchApp)
                                            }
                                        }
                                    }
                                }

                                // Secondary matches section
                                Item {
                                    width: parent.width
                                    height: parent.height - (root.bestMatchApp ? 96 : 0)

                                    Column {
                                        anchors.fill: parent
                                        spacing: 6

                                        StyledText {
                                            visible: root.searchResults.length > 1
                                            text: root.activeSearchCategory === "web" ? "Web Search Engines" : "Search results"
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
                                            model: root.searchResults.slice(1, 10)
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
                                                required property int index

                                                readonly property bool isSelected: root.selectedSearchIndex === (index + 1) && !root.hoveredSearchItem
                                                width: parent.width
                                                height: 38

                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: isSelected ? Qt.rgba(255, 255, 255, 0.09) : (searchRowHover.containsMouse ? Qt.rgba(255, 255, 255, 0.06) : "transparent")
                                                    border.width: 0

                                                    // Left accent indicator
                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: 3
                                                        color: root.winAccent
                                                        visible: isSelected || searchRowHover.containsMouse
                                                    }
                                                }

                                                AppIconRenderer {
                                                    id: subIcon

                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 12
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 22
                                                    height: 22
                                                    iconValue: modelData.icon || (modelData.isWeb ? "public" : "")
                                                    iconSize: 22
                                                    fallbackText: (modelData.name || "?").charAt(0)
                                                }

                                                StyledText {
                                                    anchors.left: subIcon.right
                                                    anchors.leftMargin: 12
                                                    anchors.right: typeLabel.left
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.name || ""
                                                    color: root.winText
                                                    font.pixelSize: 13
                                                    elide: Text.ElideRight
                                                    wrapMode: Text.NoWrap
                                                }

                                                StyledText {
                                                    id: typeLabel
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 12
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.isWeb ? "Web" : "App"
                                                    color: root.winMuted
                                                    font.pixelSize: 11
                                                }

                                                MouseArea {
                                                    id: searchRowHover

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onEntered: root.hoveredSearchItem = modelData
                                                    onExited: {
                                                        if (root.hoveredSearchItem === modelData)
                                                            root.hoveredSearchItem = null;
                                                    }
                                                    onClicked: root.launchItem(modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Right: Preview & Quick Actions Pane (Windows 10 authentic layout)
                        Rectangle {
                            width: parent.width - 440
                            height: parent.height - 16
                            color: Qt.rgba(0, 0, 0, 0.22)
                            border.width: 0
                            visible: root.currentPreviewItem !== null

                            // Left vertical separator
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 1
                                color: Qt.rgba(255, 255, 255, 0.07)
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 14

                                AppIconRenderer {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 56
                                    height: 56
                                    iconValue: (root.currentPreviewItem && root.currentPreviewItem.icon ? root.currentPreviewItem.icon : (root.currentPreviewItem && root.currentPreviewItem.isWeb ? "public" : ""))
                                    iconSize: 56
                                    fallbackText: (root.currentPreviewItem && root.currentPreviewItem.name ? root.currentPreviewItem.name.charAt(0) : "?")
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    width: parent.width - 16
                                    text: (root.currentPreviewItem && root.currentPreviewItem.name ? root.currentPreviewItem.name : "")
                                    color: root.winText
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    width: parent.width - 16
                                    text: (root.currentPreviewItem && root.currentPreviewItem.isWeb ? "Web search" : (root.currentPreviewItem && root.currentPreviewItem.comment ? root.currentPreviewItem.comment : "Desktop app"))
                                    color: root.winMuted
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Qt.rgba(255, 255, 255, 0.08)
                                }

                                // Clean Action rows (borderless, Windows 10 style)
                                Column {
                                    width: parent.width
                                    spacing: 4

                                    SearchActionButton {
                                        iconName: (root.currentPreviewItem && root.currentPreviewItem.isWeb ? "open_in_browser" : "launch")
                                        label: (root.currentPreviewItem && root.currentPreviewItem.isWeb ? "Open in browser" : "Open")
                                        onClicked: root.launchItem(root.currentPreviewItem)
                                    }

                                    SearchActionButton {
                                        visible: root.currentPreviewItem && !root.currentPreviewItem.isWeb && root.currentPreviewItem.id
                                        iconName: "push_pin"
                                        label: root.isAppPinned(root.currentPreviewItem) ? "Unpin from Start" : "Pin to Start"
                                        onClicked: {
                                            root.togglePinApp(root.currentPreviewItem);
                                        }
                                    }

                                    SearchActionButton {
                                        visible: root.currentPreviewItem && !root.currentPreviewItem.isWeb
                                        iconName: "public"
                                        label: "Search web for '" + root.query + "'"
                                        onClicked: {
                                            Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(root.query.trim())]);
                                            root.closeMenu();
                                        }
                                    }

                                    SearchActionButton {
                                        visible: root.currentPreviewItem && root.currentPreviewItem.isWeb && root.currentPreviewItem.id !== "web:google"
                                        iconName: "search"
                                        label: "Search with Google"
                                        onClicked: {
                                            Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(root.query.trim())]);
                                            root.closeMenu();
                                        }
                                    }
                                }
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

            property bool railHovered: false
            property bool railTemporarilyDismissed: false

            readonly property bool isRailExpanded: (railHovered && !railTemporarilyDismissed) || root.railPinnedOpen || root.powerMenuOpen || root.userMenuOpen

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: isRailExpanded ? 220 : 48
            color: root.winRail
            border.width: 0
            clip: true
            z: 50

            Behavior on width {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Timer {
                id: railExpandTimer
                interval: 180
                repeat: false
                onTriggered: {
                    railDrawer.railHovered = true;
                }
            }

            Timer {
                id: railCollapseTimer
                interval: 120
                repeat: false
                onTriggered: {
                    railDrawer.railHovered = false;
                }
            }

            HoverHandler {
                id: railHoverHandler

                onHoveredChanged: {
                    if (!hovered) {
                        railDrawer.railTemporarilyDismissed = false;
                        railExpandTimer.stop();
                        railCollapseTimer.restart();
                    } else {
                        railCollapseTimer.stop();
                        if (!railDrawer.railTemporarilyDismissed) {
                            railExpandTimer.restart();
                        }
                    }
                }
            }

            // Absorb clicks on empty drawer space so they don't fall through to app list beneath
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {}
            }

            // Subtle 1px right divider when expanded
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Qt.rgba(255, 255, 255, 0.08)
                visible: railDrawer.width > 48
            }

            // Top: Search button
            Column {
                anchors.top: parent.top
                width: parent.width
                spacing: 0

                RailActionRow {
                    width: parent.width
                    iconName: "search"
                    labelText: "Search"
                    onClicked: {
                        if (root.isSearchMode) {
                            if (typeof searchField !== "undefined" && searchField)
                                searchField.forceActiveFocus();
                        } else {
                            root.enterSearchMode("");
                        }
                    }
                }
            }

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

        // Drop shadow for expanded left rail
        Rectangle {
            anchors.left: railDrawer.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 14
            z: 49
            visible: railDrawer.width > 50
            opacity: Math.min(1.0, Math.max(0.0, (railDrawer.width - 48) / 30))
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
                GradientStop { position: 1.0; color: "transparent" }
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
            x: railDrawer.width + 4
            y: parent.height - height - 8
            color: Theme.surfaceContainer
            border.color: root.winBorder
            border.width: 1
            z: 60

            Behavior on x {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

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
            x: railDrawer.width + 4
            y: parent.height - (48 * 3) - height - 4
            color: Theme.surfaceContainer
            border.color: root.winBorder
            border.width: 1
            z: 60

            Behavior on x {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

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
            color: Theme.surfaceContainer
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

        width: parent.width
        height: 48

        Rectangle {
            anchors.fill: parent
            color: rarHover.containsMouse ? root.winHover : "transparent"
        }

        Item {
            id: iconSlot

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 48

            DankIcon {
                anchors.centerIn: parent
                name: rar.iconName
                size: 20
                color: root.winText
            }
        }

        StyledText {
            id: rarLabel

            anchors.left: iconSlot.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: rar.labelText
            color: root.winText
            font.pixelSize: 13
            font.weight: rar.iconName === "menu" ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            opacity: Math.max(0.0, Math.min(1.0, (railDrawer.width - 64) / (220 - 64)))
            visible: opacity > 0.01
        }

        MouseArea {
            id: rarHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rar.clicked()
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
                    color: tgHeaderHover.containsMouse ? root.winText : "transparent"
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
                            color: root.winText
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

        width: ctText.implicitWidth + 20
        height: 30

        Rectangle {
            anchors.fill: parent
            color: ctHover.containsMouse && !ct.isActive ? Qt.rgba(255, 255, 255, 0.05) : "transparent"
            border.width: 0
        }

        StyledText {
            id: ctText

            anchors.centerIn: parent
            text: ct.label
            color: ct.isActive ? root.winText : root.winMuted
            font.pixelSize: 13
            font.weight: ct.isActive ? Font.DemiBold : Font.Normal
        }

        // Active accent underline (Windows 10 authentic tab indicator)
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: root.winAccent
            visible: ct.isActive
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
        height: 36

        Rectangle {
            anchors.fill: parent
            color: sabHover.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
            border.width: 0
        }

        DankIcon {
            id: sabIcon

            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            name: sab.iconName
            size: 16
            color: root.winText
        }

        StyledText {
            anchors.left: sabIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
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

    component QuickSearchRow: Item {
        id: qsr

        property string iconName: ""
        property string title: ""
        property string subtitle: ""

        signal clicked()

        width: parent.width
        height: 44

        Rectangle {
            anchors.fill: parent
            color: qsrHover.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03)
            border.width: 0
        }

        DankIcon {
            id: qsrIcon

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            name: qsr.iconName
            size: 18
            color: root.winAccent
        }

        Column {
            anchors.left: qsrIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                width: parent.width
                text: qsr.title
                color: root.winText
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            StyledText {
                width: parent.width
                text: qsr.subtitle
                color: root.winMuted
                font.pixelSize: 10
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }

        MouseArea {
            id: qsrHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: qsr.clicked()
        }

    }

}

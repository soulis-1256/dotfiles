import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.I3
import qs.Common
import qs.Services
import qs.Widgets
import "PinGrid.js" as PinGrid

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
    readonly property var pinGridOpts: ({ "cols": 6 })
    readonly property bool hasGroup1: (root.group1Tiles && root.group1Tiles.length > 0) || root.group1Title !== ""
    readonly property bool hasGroup2: (root.group2Tiles && root.group2Tiles.length > 0) || root.group2Title !== "" || (root.isDraggingTile && root.dropTargetGroupId === 2)
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
    onIsSearchModeChanged: {
        if (root.isSearchMode)
            root.closeSidebarAndPopovers();
    }
    property string query: ""
    property string activeSearchCategory: "apps"
    property int selectedSearchIndex: 0
    property var hoveredSearchItem: null
    property var flatAppListModel: []
    property var letterIndices: ({})
    property var activeLetters: ({})
    property string group1Title: "Life at a glance"
    property string group2Title: "Play & explore"
    property var group1Tiles: []
    property var group2Tiles: []
    property string renamingItemId: ""
    property var activeRenameInput: null

    function dismissInlineRename() {
        root.renamingItemId = "";
        root.activeRenameInput = null;
        if (typeof tileGroup1 !== "undefined" && tileGroup1)
            tileGroup1.isEditingHeader = false;
        if (typeof tileGroup2 !== "undefined" && tileGroup2)
            tileGroup2.isEditingHeader = false;
    }

    function beginItemRename(id) {
        if (typeof tileGroup1 !== "undefined" && tileGroup1)
            tileGroup1.isEditingHeader = false;
        if (typeof tileGroup2 !== "undefined" && tileGroup2)
            tileGroup2.isEditingHeader = false;
        root.renamingItemId = id || "";
    }

    function beginGroupRename(groupId) {
        root.renamingItemId = "";
        root.activeRenameInput = null;
        if (typeof tileGroup1 !== "undefined" && tileGroup1)
            tileGroup1.isEditingHeader = (groupId === 1);
        if (typeof tileGroup2 !== "undefined" && tileGroup2)
            tileGroup2.isEditingHeader = (groupId === 2);
    }

    function bindRenameInput(input) {
        root.activeRenameInput = input;
        if (!input)
            return;
        Qt.callLater(function() {
            if (root.activeRenameInput === input && input.visible) {
                input.forceActiveFocus();
                input.selectAll();
            }
        });
    }
    property var searchResults: []
    property var bestMatchApp: null
    readonly property var currentPreviewItem: hoveredSearchItem || (selectedSearchIndex >= 0 && selectedSearchIndex < searchResults.length ? searchResults[selectedSearchIndex] : bestMatchApp)
    property bool contextMenuVisible: false
    property var contextMenuItem: null
    property string contextMenuType: ""
    property int contextMenuGroupId: 1
    property var contextMenuParentFolder: null
    property real contextMenuX: 0
    property real contextMenuY: 0
    onContextMenuVisibleChanged: {
        if (root.contextMenuVisible)
            root.refreshAvailableWorkspaces();
    }
    property var availableWorkspaces: []

    // Windows 10 Open Folder Overlay State
    property string openFolderId: ""
    property int openFolderGroupId: 0
    property real openFolderX: 16
    property real openFolderY: 12
    property real openFolderWidth: 300

    function openFolder(folderId, groupId, sourceItem) {
        root.powerMenuOpen = false;
        root.userMenuOpen = false;
        root.contextMenuVisible = false;
        root.contextMenuItem = null;
        root.contextMenuParentFolder = null;
        root.renamingItemId = "";
        root.activeRenameInput = null;
        root.openFolderId = folderId;
        root.openFolderGroupId = groupId || 1;
        root.openFolderWidth = 300;

        if (sourceItem && typeof tileArea !== "undefined" && typeof tileFlickable !== "undefined") {
            const pt = sourceItem.mapToItem(tileArea, 0, 0);
            const tgX = (groupId === 2 && tileGroup2.visible ? 320 : 16) - tileFlickable.contentX;
            root.openFolderX = tgX - 6;
            const fH = (typeof folderOverlayContainer !== "undefined" && folderOverlayContainer) ? folderOverlayContainer.calculatedHeight : 142;
            const fY = Math.max(8, Math.min(tileArea.height - fH - 16, pt.y));
            root.openFolderY = fY;
        } else {
            const defaultX = (groupId === 2 && tileGroup2.visible ? 320 : 16) - (typeof tileFlickable !== "undefined" ? tileFlickable.contentX : 0);
            root.openFolderX = defaultX - 6;
            root.openFolderY = 12;
        }
    }

    function closeActiveFolder() {
        root.openFolderId = "";
        root.openFolderGroupId = 0;
        root.renamingItemId = "";
        root.activeRenameInput = null;
    }

    function getOpenFolderData() {
        if (!root.openFolderId) return null;
        const findIn = function(list) {
            for (let i = 0; i < (list || []).length; i++) {
                if (list[i].id === root.openFolderId && list[i].isFolder) return list[i];
            }
            return null;
        };
        return findIn(root.group1Tiles) || findIn(root.group2Tiles);
    }

    // Drag & Drop State
    property bool isDraggingTile: false
    property var draggedTileData: null
    property int draggedFromGroupId: 0
    property string draggedFromFolderId: ""
    property int draggedSourceIndex: -1
    property real dragGhostX: 0
    property real dragGhostY: 0
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property real dragTileWidth: 92
    property real dragTileHeight: 92

    // Drop Target State
    property string dropTargetType: "none"
    property int dropTargetGroupId: 0
    property string dropTargetFolderId: ""
    property string dropTargetTileId: ""
    property int dropTargetIndex: -1
    property int dropTargetCol: 0
    property int dropTargetRow: 0
    property string dropActionBadge: ""

    StartDrag {
        id: startDrag
    }

    // Slow-hold timings in StartDrag.qml. Spatial 30/40/30 is in PinGrid.
    readonly property real dragSlowEnterSpeed: startDrag.slowEnter
    readonly property real dragSlowLeaveSpeed: startDrag.slowLeave
    readonly property int dragSlowHoldMs: startDrag.slowHoldMs
    readonly property real dragFolderSpeedMin: startDrag.folderSpeedMin
    property real dragPointerSpeed: 0
    property real dragLastMouseX: 0
    property real dragLastMouseY: 0
    property real dragLastSampleMs: 0
    property real dragSlowSinceMs: 0
    property bool dragReorderLive: false
    property bool dragCommitting: false
    property string dragFolderStickyId: ""
    property int dragFolderStickyGroupId: 0
    property string dragFolderHoverId: ""
    property real dragFolderHoverSinceMs: 0
    property var dragLiveDisplacedMap: ({})

    function toFolderChild(tile) {
        if (!tile)
            return null;
        return {
            "id": tile.id,
            "name": tile.name,
            "icon": tile.icon || "",
            "size": "medium",
            "wide": false,
            "isFolder": false
        };
    }

    function sampleDragMotion(globalX, globalY) {
        const next = startDrag.sampleMotion({
            "lastX": root.dragLastMouseX,
            "lastY": root.dragLastMouseY,
            "lastMs": root.dragLastSampleMs,
            "speed": root.dragPointerSpeed,
            "slowSinceMs": root.dragSlowSinceMs,
            "live": root.dragReorderLive
        }, globalX, globalY);
        root.dragLastMouseX = next.lastX;
        root.dragLastMouseY = next.lastY;
        root.dragLastSampleMs = next.lastMs;
        root.dragPointerSpeed = next.speed;
        root.dragSlowSinceMs = next.slowSinceMs;
        root.dragReorderLive = next.live;
    }

    function resetDragMotion() {
        root.dragPointerSpeed = 0;
        root.dragLastMouseX = 0;
        root.dragLastMouseY = 0;
        root.dragLastSampleMs = 0;
        root.dragSlowSinceMs = 0;
        root.dragReorderLive = false;
        root.dragCommitting = false;
        root.dragFolderStickyId = "";
        root.dragFolderStickyGroupId = 0;
        root.dragFolderHoverId = "";
        root.dragFolderHoverSinceMs = 0;
        root.dragLiveDisplacedMap = ({});
    }

    function resetMenuState() {
        // 1. Windows 10 Folders
        root.closeActiveFolder();

        // 2. Sidebar / Left Navigation Rail
        root.railPinnedOpen = false;
        if (typeof railDrawer !== "undefined" && railDrawer) {
            railDrawer.railHovered = false;
            railDrawer.railTemporarilyDismissed = false;
        }
        if (typeof railExpandTimer !== "undefined" && railExpandTimer)
            railExpandTimer.stop();
        if (typeof railCollapseTimer !== "undefined" && railCollapseTimer)
            railCollapseTimer.stop();

        // 3. Popovers & Menus
        root.powerMenuOpen = false;
        root.userMenuOpen = false;
        root.alphabetZoomOpen = false;
        root.contextMenuVisible = false;
        root.contextMenuItem = null;
        root.contextMenuParentFolder = null;
        root.dismissInlineRename();

        // 4. Search State
        root.isSearchMode = false;
        root.query = "";
        root.selectedSearchIndex = 0;
        root.hoveredSearchItem = null;
        root.activeSearchCategory = "apps";

        // 5. Drag & Drop State
        root.cancelDraggingTile();

        // 6. Scroll positions
        if (typeof appListScroller !== "undefined" && appListScroller)
            appListScroller.reset();
        if (typeof searchScroller !== "undefined" && searchScroller)
            searchScroller.reset();
        if (typeof tileScroller !== "undefined" && tileScroller)
            tileScroller.reset();
    }

    function closeSidebarAndPopovers() {
        root.powerMenuOpen = false;
        root.userMenuOpen = false;
        root.contextMenuVisible = false;
        root.contextMenuItem = null;
        root.contextMenuParentFolder = null;
        root.dismissInlineRename();
        if (!root.isDraggingTile) {
            root.closeActiveFolder();
            root.cancelDraggingTile();
        }
        if (typeof railDrawer !== "undefined" && railDrawer) {
            railDrawer.railHovered = false;
            railDrawer.railTemporarilyDismissed = true;
        }
        if (typeof railExpandTimer !== "undefined" && railExpandTimer)
            railExpandTimer.stop();
        if (typeof railCollapseTimer !== "undefined" && railCollapseTimer)
            railCollapseTimer.stop();
    }

    function closeMenu() {
        root.resetMenuState();
        if (root.closePopout)
            root.closePopout();
    }

    function enterSearchMode(initialChar) {
        root.closeSidebarAndPopovers();
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
            "q": "discord",
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

    function packTilesGrid(list) {
        return PinGrid.pack(list, root.pinGridOpts);
    }

    function normalizeTiles(tiles) {
        if (!tiles || !Array.isArray(tiles)) return [];
        var norm = tiles.map(function(item) {
            if (!item) return null;
            const copy = Object.assign({}, item);
            if (copy.isFolder) {
                copy.name = copy.name || "Folder";
                copy.size = copy.size || (copy.wide ? "wide" : "medium");
                copy.wide = (copy.size === "wide" || copy.size === "large");
                copy.isExpanded = !!copy.isExpanded;
                copy.tiles = (copy.tiles || []).map(function(t) {
                    return root.toFolderChild(t);
                }).filter(function(t) { return t !== null; });
                return copy;
            }
            copy.name = copy.name || "App";
            copy.size = copy.size || (copy.wide ? "wide" : "medium");
            copy.wide = (copy.size === "wide" || copy.size === "large");
            copy.isFolder = false;
            return copy;
        }).filter(function(t) { return t !== null; });

        return packTilesGrid(PinGrid.sortByGeometry(norm, root.pinGridOpts));
    }

    function refreshTiles() {
        const saved = SettingsData.getPluginSettingsForPlugin("win10Start");
        root.group1Title = (saved && saved.group1Title) || "Life at a glance";
        root.group2Title = (saved && saved.group2Title) || "Play & explore";
        if (saved && saved.group1Tiles && saved.group1Tiles.length > 0) {
            root.group1Tiles = normalizeTiles(saved.group1Tiles);
            root.group2Tiles = normalizeTiles(saved.group2Tiles || []);
            return ;
        }
        root.group1Tiles = normalizeTiles(buildTilesFromQueries(defaultGroup1Queries(), 0));
        const g2Raw = buildTilesFromQueries(defaultGroup2Queries(), 6);
        const folderCandidates = [];
        const remainingG2 = [];
        for (let i = 0; i < g2Raw.length; i++) {
            const t = g2Raw[i];
            const lower = ((t.name || "") + " " + (t.id || "")).toLowerCase();
            if (lower.indexOf("vesktop") !== -1 || lower.indexOf("discord") !== -1 || lower.indexOf("vlc") !== -1 || lower.indexOf("proton") !== -1) {
                folderCandidates.push(t);
            } else {
                remainingG2.push(t);
            }
        }
        if (folderCandidates.length >= 2) {
            remainingG2.push({
                "id": "folder_media_chat",
                "isFolder": true,
                "name": "Media & Chat",
                "size": "medium",
                "wide": false,
                "isExpanded": false,
                "tiles": folderCandidates
            });
            root.group2Tiles = normalizeTiles(remainingG2);
        } else {
            root.group2Tiles = normalizeTiles(g2Raw);
        }
    }

    function saveTilesState() {
        SettingsData.setPluginSetting("win10Start", "group1Title", root.group1Title);
        SettingsData.setPluginSetting("win10Start", "group2Title", root.group2Title);
        SettingsData.setPluginSetting("win10Start", "group1Tiles", root.group1Tiles);
        SettingsData.setPluginSetting("win10Start", "group2Tiles", root.group2Tiles);
    }

    function isAppPinned(app) {
        if (!app || !app.id)
            return false;
        const checkList = function(list) {
            return (list || []).some(function(item) {
                if (item.id === app.id) return true;
                if (item.isFolder && item.tiles) {
                    return item.tiles.some(function(t) { return t.id === app.id; });
                }
                return false;
            });
        };
        return checkList(root.group1Tiles) || checkList(root.group2Tiles);
    }

    function pinAppToStart(app) {
        if (!app || !app.id)
            return ;

        if (isAppPinned(app))
            return ;

        const newTiles = root.group1Tiles.slice();
        newTiles.push({
            "id": app.id,
            "name": app.name,
            "icon": app.icon || "",
            "size": "medium",
            "wide": false,
            "isFolder": false
        });
        root.group1Tiles = packTilesGrid(newTiles);
        saveTilesState();
    }

    function unpinTile(tile) {
        if (!tile || !tile.id)
            return ;

        const filterList = function(list) {
            const out = [];
            for (let i = 0; i < (list || []).length; i++) {
                const item = list[i];
                if (item.id === tile.id)
                    continue;
                if (item.isFolder && item.tiles) {
                    const sub = item.tiles.filter(function(t) { return t.id !== tile.id; });
                    if (sub.length > 0) {
                        out.push(Object.assign({}, item, { tiles: sub }));
                    }
                } else {
                    out.push(item);
                }
            }
            return out;
        };
        root.group1Tiles = packTilesGrid(filterList(root.group1Tiles));
        root.group2Tiles = packTilesGrid(filterList(root.group2Tiles));
        saveTilesState();
    }

    function setTileSize(tile, newSize) {
        if (!tile || !tile.id)
            return ;

        const updateList = function(list) {
            return (list || []).map(function(item) {
                if (item.id === tile.id) {
                    const c = Object.assign({}, item);
                    c.size = newSize;
                    c.wide = (newSize === "wide" || newSize === "large");
                    return c;
                }
                return item;
            });
        };
        root.group1Tiles = packTilesGrid(updateList(root.group1Tiles));
        root.group2Tiles = packTilesGrid(updateList(root.group2Tiles));
        saveTilesState();
    }

    function toggleTileSize(tile) {
        if (!tile)
            return ;

        const current = tile.size || (tile.wide ? "wide" : "medium");
        const next = current === "wide" ? "medium" : "wide";
        setTileSize(tile, next);
    }

    function renameTileOrFolder(id, newName) {
        if (!id || !newName || !newName.trim())
            return ;

        const clean = newName.trim();
        const updateList = function(list) {
            return (list || []).map(function(item) {
                if (item.id === id) {
                    return Object.assign({}, item, { name: clean });
                }
                if (item.isFolder && item.tiles) {
                    const sub = item.tiles.map(function(t) {
                        if (t.id === id) {
                            return Object.assign({}, t, { name: clean });
                        }
                        return t;
                    });
                    return Object.assign({}, item, { tiles: sub });
                }
                return item;
            });
        };
        root.group1Tiles = updateList(root.group1Tiles);
        root.group2Tiles = updateList(root.group2Tiles);
        saveTilesState();
    }

    function toggleFolderExpanded(folderId) {
        if (!folderId) return;
        if (root.openFolderId === folderId) {
            root.closeActiveFolder();
        } else {
            let gId = 1;
            if ((root.group2Tiles || []).some(function(it) { return it.id === folderId; }))
                gId = 2;
            root.openFolder(folderId, gId);
        }
    }

    function createFolderWithTile(tile, folderName) {
        if (!tile || !tile.id)
            return ;

        const fName = (folderName && folderName.trim()) ? folderName.trim() : "New folder";
        const newFolder = {
            "id": "folder_" + Date.now() + "_" + Math.floor(Math.random() * 10000),
            "isFolder": true,
            "name": fName,
            "size": "medium",
            "wide": false,
            "isExpanded": true,
            "tiles": [root.toFolderChild(tile)]
        };
        const replaceIn = function(list) {
            const idx = list.findIndex(function(t) { return t.id === tile.id; });
            if (idx !== -1) {
                const c = list.slice();
                c[idx] = newFolder;
                return c;
            }
            return list;
        };
        root.group1Tiles = packTilesGrid(replaceIn(root.group1Tiles));
        root.group2Tiles = packTilesGrid(replaceIn(root.group2Tiles));
        saveTilesState();
    }

    function addTileToFolder(tile, folderId) {
        if (!tile || !tile.id || !folderId)
            return ;

        const remove = function(list) {
            return (list || []).filter(function(t) { return t.id !== tile.id; });
        };
        const g1 = remove(root.group1Tiles);
        const g2 = remove(root.group2Tiles);

        const addIn = function(list) {
            return (list || []).map(function(item) {
                if (item.id === folderId && item.isFolder) {
                    const sub = (item.tiles || []).slice();
                    if (!sub.some(function(t) { return t.id === tile.id; })) {
                        sub.push(root.toFolderChild(tile));
                    }
                    return Object.assign({}, item, { tiles: sub, isExpanded: true });
                }
                return item;
            });
        };
        root.group1Tiles = packTilesGrid(addIn(g1));
        root.group2Tiles = packTilesGrid(addIn(g2));
        saveTilesState();
    }

    function removeTileFromFolder(tile, folderId) {
        if (!tile || !tile.id)
            return ;

        let targetGroup = 1;
        const extract = function(list, gNum) {
            return (list || []).map(function(item) {
                if (item.id === folderId && item.isFolder && item.tiles) {
                    targetGroup = gNum;
                    const sub = item.tiles.filter(function(t) { return t.id !== tile.id; });
                    return Object.assign({}, item, { tiles: sub });
                }
                return item;
            });
        };
        root.group1Tiles = extract(root.group1Tiles, 1);
        root.group2Tiles = extract(root.group2Tiles, 2);

        const extractedTile = Object.assign({}, root.toFolderChild(tile), {
            "size": tile.size || "medium",
            "wide": !!tile.wide
        });
        if (targetGroup === 1) {
            const c = root.group1Tiles.slice();
            c.push(extractedTile);
            root.group1Tiles = packTilesGrid(c);
            root.group2Tiles = packTilesGrid(root.group2Tiles);
        } else {
            const c = root.group2Tiles.slice();
            c.push(extractedTile);
            root.group2Tiles = packTilesGrid(c);
            root.group1Tiles = packTilesGrid(root.group1Tiles);
        }
        saveTilesState();
    }

    function ungroupFolder(folder) {
        if (!folder || !folder.id)
            return ;

        const unpack = function(list) {
            const out = [];
            for (let i = 0; i < (list || []).length; i++) {
                const item = list[i];
                if (item.id === folder.id && item.isFolder) {
                    const children = item.tiles || [];
                    for (let c = 0; c < children.length; c++) {
                        out.push(children[c]);
                    }
                } else {
                    out.push(item);
                }
            }
            return out;
        };
        root.group1Tiles = packTilesGrid(unpack(root.group1Tiles));
        root.group2Tiles = packTilesGrid(unpack(root.group2Tiles));
        saveTilesState();
    }

    function moveTileBetweenGroups(tile) {
        if (!tile || !tile.id)
            return ;

        const inG1 = root.group1Tiles.some(function(t) { return t.id === tile.id; });
        if (inG1) {
            root.group1Tiles = packTilesGrid(root.group1Tiles.filter(function(t) { return t.id !== tile.id; }));
            const c = root.group2Tiles.slice();
            c.push(tile);
            root.group2Tiles = packTilesGrid(c);
        } else {
            root.group2Tiles = packTilesGrid(root.group2Tiles.filter(function(t) { return t.id !== tile.id; }));
            const c = root.group1Tiles.slice();
            c.push(tile);
            root.group1Tiles = packTilesGrid(c);
        }
        saveTilesState();
    }

    function moveTileOrder(groupId, fromIdx, toIdx) {
        const list = (groupId === 1 ? root.group1Tiles : root.group2Tiles).slice();
        if (fromIdx < 0 || fromIdx >= list.length || toIdx < 0 || toIdx >= list.length)
            return ;

        const item = list.splice(fromIdx, 1)[0];
        list.splice(toIdx, 0, item);
        if (groupId === 1)
            root.group1Tiles = packTilesGrid(list);
        else
            root.group2Tiles = packTilesGrid(list);
        saveTilesState();
    }

    function getFoldersInGroup(groupId) {
        const list = groupId === 1 ? root.group1Tiles : root.group2Tiles;
        return (list || []).filter(function(item) { return item.isFolder; });
    }

    function startDraggingTile(tile, fromGroupId, fromFolderId, sourceIdx, w, h, localX, localY, globalX, globalY) {
        if (!tile || !tile.id)
            return;
        root.draggedTileData = tile;
        root.draggedFromGroupId = fromGroupId;
        root.draggedFromFolderId = fromFolderId || "";
        root.draggedSourceIndex = sourceIdx;
        root.dragTileWidth = w;
        root.dragTileHeight = h;
        root.dragOffsetX = localX;
        root.dragOffsetY = localY;
        root.dragGhostX = globalX - localX;
        root.dragGhostY = globalY - localY;
        root.contextMenuVisible = false;
        root.dismissInlineRename();
        root.dropTargetType = fromFolderId ? "reorder-folder" : "reorder";
        root.dropTargetGroupId = fromGroupId;
        root.dropTargetFolderId = fromFolderId || "";
        root.dropTargetTileId = "";
        root.dropTargetIndex = sourceIdx;
        root.dropTargetCol = (tile && typeof tile.col === "number") ? tile.col : 0;
        root.dropTargetRow = (tile && typeof tile.row === "number") ? tile.row : 0;
        root.dragLastMouseX = globalX;
        root.dragLastMouseY = globalY;
        root.dragLastSampleMs = Date.now();
        root.dragPointerSpeed = 0;
        root.dragSlowSinceMs = 0;
        root.dragReorderLive = !!fromFolderId;
        root.dragCommitting = false;
        root.dragFolderStickyId = "";
        root.dragFolderStickyGroupId = 0;
        root.dragFolderHoverId = "";
        root.dragFolderHoverSinceMs = 0;
        root.dragLiveDisplacedMap = ({});
        root.isDraggingTile = true;
        updateDragPosition(globalX, globalY);
    }

    function updateDragPosition(globalX, globalY) {
        if (!root.isDraggingTile || !root.draggedTileData)
            return;
        root.dragGhostX = globalX - root.dragOffsetX;
        root.dragGhostY = globalY - root.dragOffsetY;
        root.sampleDragMotion(globalX, globalY);

        if (typeof tileGroup1 === "undefined" || !tileGroup1 || typeof tileGroup2 === "undefined" || !tileGroup2)
            return;

        // Inside an open folder: always live-reorder. Leaving the overlay is the only "mode" change.
        if (root.openFolderId !== "" && typeof folderOverlayContainer !== "undefined" && folderOverlayContainer.visible) {
            const foPt = folderOverlayContainer.mapFromItem(menuBackground, globalX, globalY);
            const padX = 40;
            const padY = 48;
            if (foPt.x >= -padX && foPt.x <= folderOverlayContainer.width + padX && foPt.y >= -padY && foPt.y <= folderOverlayContainer.height + padY) {
                root.dragReorderLive = true;
                root.dragFolderStickyId = "";
                root.dragFolderStickyGroupId = 0;
                root.dragFolderHoverId = "";
                root.dragFolderHoverSinceMs = 0;
                root.dragLiveDisplacedMap = ({});
                root.dropTargetType = "reorder-folder";
                root.dropTargetGroupId = root.openFolderGroupId;
                root.dropTargetFolderId = root.openFolderId;
                root.dropTargetTileId = "";
                root.dropTargetIndex = (typeof folderOverlayContainer.calculateFolderSlot === "function") ? folderOverlayContainer.calculateFolderSlot(foPt.x, foPt.y) : 0;
                root.dropActionBadge = "Reorder in folder";
                return;
            }
        }

        let targetTg = tileGroup1;
        let targetGId = 1;

        if (root.hasGroup2 && tileGroup2.visible) {
            const p2 = tileGroup2.mapFromItem(menuBackground, globalX, globalY);
            const p2Tile = tileGroup2.mapFromItem(menuBackground, root.dragGhostX + root.dragTileWidth / 2, root.dragGhostY + root.dragTileHeight / 2);
            if (p2.x >= -16 || p2Tile.x >= 0) {
                targetTg = tileGroup2;
                targetGId = 2;
            } else {
                targetTg = tileGroup1;
                targetGId = 1;
            }
        } else {
            targetTg = tileGroup1;
            targetGId = 1;
        }

        const lp = (typeof targetTg.mapToFlow === "function")
            ? targetTg.mapToFlow(globalX, globalY)
            : targetTg.mapFromItem(menuBackground, globalX, globalY);
        const items = targetTg.getOtherItems();
        const resolved = PinGrid.resolveDropTarget(Object.assign({}, root.pinGridOpts, {
            "lx": lp.x,
            "ly": lp.y,
            "items": items,
            "draggedTile": root.draggedTileData,
            "sourceIndex": (!root.draggedFromFolderId && root.draggedFromGroupId === targetGId) ? root.draggedSourceIndex : -1,
            "fromFolder": !!root.draggedFromFolderId,
            "stickyId": root.dragFolderStickyId,
            "prevInsertIndex": (root.dropTargetGroupId === targetGId) ? root.dropTargetIndex : -1,
            "prevDropType": (root.dropTargetGroupId === targetGId) ? root.dropTargetType : ""
        }));

        root.dropTargetType = resolved.dropType;
        root.dropTargetGroupId = targetGId;
        root.dropTargetFolderId = resolved.folderId || "";
        root.dropTargetTileId = resolved.tileId || "";
        root.dropTargetIndex = resolved.targetIndex;
        root.dropTargetCol = resolved.targetCol;
        root.dropTargetRow = resolved.targetRow;
        root.dropActionBadge = resolved.badge;
        root.dragFolderStickyId = resolved.stickyId || "";
        root.dragFolderHoverId = resolved.hoverId || "";
        root.dragFolderHoverSinceMs = resolved.hoverSince || 0;
        root.dragLiveDisplacedMap = resolved.displacedMap || ({});
    }

    function cancelDraggingTile() {
        root.isDraggingTile = false;
        root.resetDragMotion();

        root.draggedTileData = null;
        root.draggedFromGroupId = 0;
        root.draggedFromFolderId = "";
        root.draggedSourceIndex = -1;
        root.dropTargetType = "none";
        root.dropTargetGroupId = 0;
        root.dropTargetFolderId = "";
        root.dropTargetTileId = "";
        root.dropTargetIndex = -1;
        root.dropTargetCol = 0;
        root.dropTargetRow = 0;
        root.dropActionBadge = "";
    }

    function endDraggingTile() {
        if (!root.isDraggingTile || !root.draggedTileData) {
            cancelDraggingTile();
            return;
        }

        const tile = root.draggedTileData;
        const fromGId = root.draggedFromGroupId;
        const fromFId = root.draggedFromFolderId;
        const targetType = root.dropTargetType;
        const targetGId = root.dropTargetGroupId || fromGId || 1;
        const targetFolderId = root.dropTargetFolderId;
        const targetIndex = root.dropTargetIndex;
        if (targetType === "none") {
            cancelDraggingTile();
            return;
        }

        // Prepare updated lists locally without intermediate triggering of Repeater models
        let g1 = (root.group1Tiles || []).slice();
        let g2 = (root.group2Tiles || []).slice();

        // 1. Remove from source
        if (fromFId) {
            const removeFromF = function(list) {
                return (list || []).map(function(item) {
                    if (item.id === fromFId && item.isFolder && item.tiles) {
                        const sub = item.tiles.filter(function(t) { return t.id !== tile.id; });
                        return Object.assign({}, item, { tiles: sub });
                    }
                    return item;
                });
            };
            g1 = removeFromF(g1);
            g2 = removeFromF(g2);
        } else {
            const removeTop = function(list) {
                return (list || []).filter(function(t) { return t.id !== tile.id; });
            };
            if (fromGId === 1)
                g1 = removeTop(g1);
            else if (fromGId === 2)
                g2 = removeTop(g2);
        }

        // 2. Insert into target
        if (targetType === "add-to-folder") {
            const addToF = function(list) {
                return (list || []).map(function(item) {
                    if (item.id === targetFolderId && item.isFolder) {
                        const sub = (item.tiles || []).filter(function(t) { return t.id !== tile.id; });
                        sub.push(root.toFolderChild(tile));
                        return Object.assign({}, item, { tiles: sub });
                    }
                    return item;
                });
            };
            g1 = addToF(g1);
            g2 = addToF(g2);
        } else if (targetType === "reorder-folder") {
            const reorderF = function(list) {
                return (list || []).map(function(item) {
                    if (item.id === targetFolderId && item.isFolder && item.tiles) {
                        const sub = item.tiles.filter(function(t) { return t.id !== tile.id; });
                        const clamped = Math.max(0, Math.min(targetIndex, sub.length));
                        sub.splice(clamped, 0, root.toFolderChild(tile));
                        return Object.assign({}, item, { tiles: sub });
                    }
                    return item;
                });
            };
            g1 = reorderF(g1);
            g2 = reorderF(g2);
        } else if (targetType === "create-folder") {
            const createF = function(list) {
                return (list || []).map(function(item) {
                    if (item.id === root.dropTargetTileId) {
                        return {
                            "id": "folder_" + Date.now() + "_" + Math.floor(Math.random() * 10000),
                            "isFolder": true,
                            "name": "New folder",
                            "size": "medium",
                            "wide": false,
                            "isExpanded": false,
                            "col": (typeof item.col === "number") ? item.col : 0,
                            "row": (typeof item.row === "number") ? item.row : 0,
                            "tiles": [
                                root.toFolderChild(item),
                                root.toFolderChild(tile)
                            ]
                        };
                    }
                    return item;
                });
            };
            if (targetGId === 1)
                g1 = createF(g1);
            else if (targetGId === 2)
                g2 = createF(g2);
        } else if (targetType === "reorder") {
            const droppedTile = {
                "id": tile.id,
                "name": tile.name,
                "icon": tile.icon || "",
                "size": tile.size || (tile.wide ? "wide" : "medium"),
                "wide": (tile.size === "wide" || tile.size === "large" || !!tile.wide),
                "isFolder": !!tile.isFolder,
                "tiles": tile.tiles || []
            };
            if (targetGId === 1) {
                const insertAt = Math.max(0, Math.min(targetIndex, g1.length));
                g1.splice(insertAt, 0, droppedTile);
            } else {
                const insertAt = Math.max(0, Math.min(targetIndex, g2.length));
                g2.splice(insertAt, 0, droppedTile);
            }
        }

        // Clean up empty folders and unpack 1-tile folders
        const cleanEmpty = function(list) {
            const res = [];
            for (let i = 0; i < (list || []).length; i++) {
                const it = list[i];
                if (it.isFolder) {
                    if (!it.tiles || it.tiles.length === 0) continue;
                    if (it.tiles.length === 1) {
                        const single = Object.assign({}, it.tiles[0], {
                            col: (typeof it.col === "number") ? it.col : 0,
                            row: (typeof it.row === "number") ? it.row : 0,
                            isFolder: false
                        });
                        res.push(single);
                        continue;
                    }
                }
                res.push(it);
            }
            return res;
        };
        g1 = packTilesGrid(cleanEmpty(g1));
        g2 = packTilesGrid(cleanEmpty(g2));

        // Repeater rebuilds the group; freeze motion so new delegates don't fly from (0,0).
        root.dragCommitting = true;
        root.group1Tiles = g1;
        root.group2Tiles = g2;

        // If open folder was emptied or removed, close it
        if (root.openFolderId) {
            const openFolderExists = (root.group1Tiles || []).concat(root.group2Tiles || []).some(function(it) {
                return it.id === root.openFolderId && it.isFolder && it.tiles && it.tiles.length > 0;
            });
            if (!openFolderExists)
                root.closeActiveFolder();
        }

        saveTilesState();
        cancelDraggingTile();
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

    function refreshAvailableWorkspaces() {
        const list = [];
        const seen = {};
        let focusedWsId = 1;

        if (typeof CompositorService !== "undefined" && CompositorService.isHyprland) {
            if (typeof Hyprland !== "undefined") {
                focusedWsId = (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id !== undefined) ? Hyprland.focusedWorkspace.id : 1;
                const raw = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : [];
                const hyprlandToplevels = (Hyprland.toplevels && Hyprland.toplevels.values) ? Array.from(Hyprland.toplevels.values) : [];
                for (let i = 0; i < raw.length; i++) {
                    const ws = raw[i];
                    if (!ws) continue;
                    const name = ws.name || "";
                    if (name === "special" || name.startsWith("special:")) continue;

                    const id = ws.id;
                    seen[id] = true;
                    const hasWindows = hyprlandToplevels.some(function(tl) {
                        return tl.workspace && tl.workspace.id === id;
                    });
                    list.push({
                        "id": id,
                        "name": (name && name !== String(id)) ? name : ("Workspace " + id),
                        "rawName": name,
                        "monitor": ws.monitor ? ws.monitor.name : "",
                        "isFocused": id === focusedWsId,
                        "hasWindows": hasWindows,
                        "exists": true
                    });
                }
            }
        } else if (typeof CompositorService !== "undefined" && CompositorService.isNiri) {
            if (typeof NiriService !== "undefined" && NiriService.workspaces) {
                const niriMap = NiriService.workspaces;
                for (const k in niriMap) {
                    const ws = niriMap[k];
                    if (!ws) continue;
                    seen[ws.id] = true;
                    list.push({
                        "id": ws.id,
                        "name": ws.name ? ("Workspace: " + ws.name) : ("Workspace " + (ws.idx !== undefined ? (ws.idx + 1) : ws.id)),
                        "rawName": ws.name || String(ws.id),
                        "monitor": ws.output || "",
                        "isFocused": !!ws.is_focused,
                        "hasWindows": true,
                        "exists": true
                    });
                }
            }
        }

        // Always ensure standard numeric workspaces 1 through 10 are available
        for (let num = 1; num <= 10; num++) {
            if (!seen[num]) {
                list.push({
                    "id": num,
                    "name": "Workspace " + num,
                    "rawName": String(num),
                    "monitor": "",
                    "isFocused": num === focusedWsId,
                    "hasWindows": false,
                    "exists": false
                });
            }
        }

        list.sort(function(a, b) {
            const aNum = (typeof a.id === "number" && a.id > 0) ? a.id : 9999;
            const bNum = (typeof b.id === "number" && b.id > 0) ? b.id : 9999;
            if (aNum !== bNum) return aNum - bNum;
            return (a.name || "").localeCompare(b.name || "");
        });

        root.availableWorkspaces = list;
    }

    function launchInWorkspace(item, workspaceId) {
        if (!item)
            return;

        root.contextMenuVisible = false;

        const appId = item.id || "";
        const entry = appId ? lookupEntry(appId) : null;

        if (typeof CompositorService !== "undefined" && CompositorService.isHyprland) {
            let cmdParts = [];
            if (entry && entry.command && entry.command.length > 0) {
                cmdParts = Array.from(entry.command);
            } else if (entry && entry.exec) {
                cmdParts = [entry.exec];
            } else if (appId) {
                cmdParts = [appId];
            } else if (item.isWeb && item.url) {
                cmdParts = ["xdg-open", item.url];
            }

            if (cmdParts.length > 0) {
                if (typeof SessionData !== "undefined" && SessionData.getAppOverride && appId) {
                    const override = SessionData.getAppOverride(appId);
                    if (override && override.extraFlags) {
                        const extraArgs = override.extraFlags.trim().split(/\s+/).filter(function(arg) { return arg.length > 0; });
                        cmdParts = cmdParts.concat(extraArgs);
                    }
                }

                if (entry && entry.runInTerminal) {
                    const term = (typeof SessionData !== "undefined" && SessionData.resolveTerminal)
                        ? (SessionData.resolveTerminal() || "ghostty")
                        : "ghostty";
                    cmdParts = [term, "-e"].concat(cmdParts);
                }

                const escaped = cmdParts.map(function(arg) {
                    return "'" + String(arg).replace(/'/g, "'\\''") + "'";
                }).join(" ");

                const execCmd = `[workspace ${workspaceId}] ${escaped}`;
                if (typeof HyprlandService !== "undefined" && HyprlandService.luaConfigActive) {
                    Hyprland.dispatch(`hl.dsp.exec_cmd(${JSON.stringify(execCmd)})`);
                    Hyprland.dispatch(`hl.dsp.focus({ workspace = ${JSON.stringify(String(workspaceId))} })`);
                } else if (typeof Hyprland !== "undefined") {
                    Hyprland.dispatch(`exec ${execCmd}`);
                    Hyprland.dispatch(`workspace ${workspaceId}`);
                }

                if (entry && typeof AppUsageHistoryData !== "undefined") {
                    AppUsageHistoryData.addAppUsage(entry);
                }
                root.closeMenu();
                return;
            }
        }

        // Shift focus to workspace for non-Hyprland compositors
        if (typeof CompositorService !== "undefined" && CompositorService.isHyprland) {
            if (typeof HyprlandService !== "undefined") {
                HyprlandService.focusWorkspace(workspaceId);
            }
        } else if (typeof CompositorService !== "undefined" && CompositorService.isNiri) {
            if (typeof NiriService !== "undefined") {
                NiriService.switchToWorkspace(workspaceId);
            }
        } else if (typeof CompositorService !== "undefined" && CompositorService.isMango && typeof MangoService !== "undefined") {
            MangoService.switchToTag("", workspaceId);
        } else if (typeof CompositorService !== "undefined" && (CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle)) {
            try {
                if (typeof I3 !== "undefined") {
                    I3.dispatch(`workspace number ${workspaceId}`);
                }
            } catch (_) {}
        }

        if (appId) {
            root.launchById(appId);
        } else {
            root.launchItem(item);
        }
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
        root.resetMenuState();
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
            if (root.renamingItemId !== "" || (typeof tileGroup1 !== "undefined" && tileGroup1 && tileGroup1.isEditingHeader) || (typeof tileGroup2 !== "undefined" && tileGroup2 && tileGroup2.isEditingHeader)) {
                root.dismissInlineRename();
                event.accepted = true;
                return;
            }
            if (root.contextMenuVisible) {
                root.contextMenuVisible = false;
                event.accepted = true;
                return;
            }
            if (root.openFolderId !== "") {
                root.closeActiveFolder();
                event.accepted = true;
                return;
            }
            if (root.alphabetZoomOpen) {
                root.alphabetZoomOpen = false;
                event.accepted = true;
                return;
            }
            if (root.powerMenuOpen || root.userMenuOpen) {
                root.closeSidebarAndPopovers();
                event.accepted = true;
                return;
            }
            if (typeof railDrawer !== "undefined" && railDrawer && railDrawer.isRailExpanded) {
                root.closeSidebarAndPopovers();
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
            root.closeSidebarAndPopovers();
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

    onVisibleChanged: {
        if (!visible) {
            root.resetMenuState();
        }
    }

    Connections {
        target: root.parentPopout

        function onOpened() {
            root.resetMenuState();
            buildAppListModel();
            root.forceActiveFocus();
            Qt.callLater(function() {
                if (typeof appListView !== "undefined" && appListView) {
                    if (appListView.flicking) appListView.cancelFlick();
                    appListView.contentY = 0;
                    appListView.positionViewAtBeginning();
                }
                if (typeof tileFlickable !== "undefined" && tileFlickable) {
                    if (tileFlickable.flicking) tileFlickable.cancelFlick();
                    tileFlickable.contentY = 0;
                }
            });
        }

        function onPopoutClosed() {
            root.resetMenuState();
        }

        function onShouldBeVisibleChanged() {
            if (root.parentPopout && root.parentPopout.shouldBeVisible) {
                root.resetMenuState();
                buildAppListModel();
                root.forceActiveFocus();
                Qt.callLater(function() {
                    if (typeof appListView !== "undefined" && appListView) {
                        if (appListView.flicking) appListView.cancelFlick();
                        appListView.contentY = 0;
                        appListView.positionViewAtBeginning();
                    }
                    if (typeof tileFlickable !== "undefined" && tileFlickable) {
                        if (tileFlickable.flicking) tileFlickable.cancelFlick();
                        tileFlickable.contentY = 0;
                    }
                });
            } else {
                root.resetMenuState();
            }
        }
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

                    SmoothScrollHandler {
                        id: appListScroller
                        stepSize: 140
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
                                            if (targetIdx !== undefined) {
                                                if (typeof appListScroller !== "undefined" && appListScroller)
                                                    appListScroller.stop();
                                                appListView.positionViewAtIndex(targetIdx, ListView.Beginning);
                                                if (typeof appListScroller !== "undefined" && appListScroller)
                                                    appListScroller.targetContentY = appListView.contentY;
                                            }

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
                    interactive: !root.isDraggingTile

                    SmoothScrollHandler {
                        id: tileScroller
                        stepSize: 152
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: {
                            root.closeSidebarAndPopovers();
                        }
                    }

                    Row {
                        id: tileRow

                        anchors.top: parent.top
                        anchors.topMargin: 12
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        spacing: 16

                        // Group 1 (width = 288px)
                        TileGroup {
                            id: tileGroup1
                            groupId: 1
                            visible: root.hasGroup1
                            groupTitle: root.group1Title
                            tilesModel: root.group1Tiles
                            groupWidth: 288
                            onTitleChanged: function(newTitle) {
                                root.group1Title = newTitle;
                                root.saveTilesState();
                            }
                        }

                        // Group 2 (width = 288px)
                        TileGroup {
                            id: tileGroup2
                            groupId: 2
                            visible: root.hasGroup2
                            groupTitle: root.group2Title
                            tilesModel: root.group2Tiles
                            groupWidth: 288
                            onTitleChanged: function(newTitle) {
                                root.group2Title = newTitle;
                                root.saveTilesState();
                            }
                        }

                    }

                }

                // ==========================================
                // FOLDER DISMISS BACKDROP (Clicks on empty space in pinned area close folder)
                // ==========================================
                MouseArea {
                    id: folderDismissBackdrop

                    anchors.fill: parent
                    z: 70
                    visible: root.openFolderId !== "" && !root.isDraggingTile
                    enabled: !root.isDraggingTile
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: {
                        root.closeActiveFolder();
                    }
                }

                // ==========================================
                // WINDOWS 10 FOLDER OVERLAY (Draws over pinned area items)
                // ==========================================
                Item {
                    id: folderOverlayContainer

                    readonly property var folderData: root.getOpenFolderData()
                    readonly property real calculatedHeight: {
                        var fD = folderData;
                        if (!fD || !fD.tiles || fD.tiles.length === 0) return 60;
                        var count = fD.tiles.length;
                        if (root.isDraggingTile && root.dropTargetType === "reorder-folder" && root.draggedFromFolderId !== fD.id) {
                            count += 1;
                        }
                        var rows = Math.ceil(count / 3);
                        return 36 + rows * 98 + 8;
                    }
                    visible: root.openFolderId !== "" && folderData !== null
                    z: 75

                    x: root.openFolderX
                    y: root.openFolderY
                    width: root.openFolderWidth
                    height: Math.min(tileArea.height - y - 16, calculatedHeight)

                    function folderSlotToPixel(slot) {
                        var c = slot % 3;
                        var r = Math.floor(slot / 3);
                        return Qt.point(c * 98, r * 98);
                    }

                    function calculateFolderSlot(mx, my) {
                        var totalCount = folderData ? (folderData.tiles ? folderData.tiles.length : 0) : 0;
                        if (totalCount === 0) return 0;

                        var isDragFromThisFolder = (root.draggedFromFolderId === folderData.id);
                        var maxSlot = isDragFromThisFolder ? Math.max(0, totalCount - 1) : totalCount;

                        var lx = Math.max(0, mx - 6);
                        var ly = Math.max(0, my - 36);

                        var col = Math.max(0, Math.min(2, Math.floor(lx / 98)));
                        var row = Math.max(0, Math.floor(ly / 98));
                        var slot = row * 3 + col;

                        return Math.max(0, Math.min(maxSlot, slot));
                    }

                    function getFolderTileDisplacement(itemIndex) {
                        if (root.dragCommitting || !root.isDraggingTile || root.dropTargetType !== "reorder-folder" || !folderData || root.dropTargetFolderId !== folderData.id) {
                            return Qt.point(0, 0);
                        }
                        var targetSlot = root.dropTargetIndex;
                        var draggedIdx = (root.draggedFromFolderId === folderData.id) ? root.draggedSourceIndex : -1;

                        if (itemIndex === draggedIdx) {
                            return Qt.point(0, 0);
                        }

                        var visSlot = itemIndex;
                        if (draggedIdx !== -1) {
                            if (draggedIdx < targetSlot) {
                                if (itemIndex > draggedIdx && itemIndex <= targetSlot) {
                                    visSlot = itemIndex - 1;
                                }
                            } else if (draggedIdx > targetSlot) {
                                if (itemIndex >= targetSlot && itemIndex < draggedIdx) {
                                    visSlot = itemIndex + 1;
                                }
                            }
                        } else {
                            if (itemIndex >= targetSlot) {
                                visSlot = itemIndex + 1;
                            }
                        }

                        var normalPos = folderSlotToPixel(itemIndex);
                        var visPos = folderSlotToPixel(visSlot);
                        return Qt.point(visPos.x - normalPos.x, visPos.y - normalPos.y);
                    }

                    // Main folder panel surface (100% OPAQUE solid surface - NO transparency)
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.surfaceContainerHigh
                        border.width: 0

                        // Absorb clicks on folder background so it doesn't dismiss
                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            enabled: !root.isDraggingTile
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton && folderOverlayContainer.folderData) {
                                    root.contextMenuItem = folderOverlayContainer.folderData;
                                    root.contextMenuGroupId = root.openFolderGroupId;
                                    root.contextMenuType = "folder";
                                    const gp = mapToItem(menuBackground, mouse.x, mouse.y);
                                    root.contextMenuX = Math.min(gp.x, menuBackground.width - 210);
                                    root.contextMenuY = Math.min(gp.y, menuBackground.height - 180);
                                    root.contextMenuVisible = true;
                                }
                            }
                        }

                        Column {
                            id: folderInnerCol

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 6
                            spacing: 6

                            // Folder Header — click the title to rename in place
                            Item {
                                width: parent.width
                                height: 24

                                readonly property bool foRenaming: folderOverlayContainer.folderData && root.renamingItemId === folderOverlayContainer.folderData.id

                                StyledText {
                                    id: foTitleText

                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, parent.width - 12)
                                    visible: !parent.foRenaming
                                    text: folderOverlayContainer.folderData ? (folderOverlayContainer.folderData.name || "Folder") : "Folder"
                                    color: foTitleMouse.containsMouse ? "#ffffff" : root.winText
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
                                        if (!folderOverlayContainer.folderData)
                                            return;
                                        if (mouse.button === Qt.RightButton) {
                                            root.contextMenuItem = folderOverlayContainer.folderData;
                                            root.contextMenuGroupId = root.openFolderGroupId;
                                            root.contextMenuType = "folder";
                                            const gp = mapToItem(menuBackground, mouse.x, mouse.y);
                                            root.contextMenuX = Math.min(gp.x, menuBackground.width - 210);
                                            root.contextMenuY = Math.min(gp.y, menuBackground.height - 180);
                                            root.contextMenuVisible = true;
                                            return;
                                        }
                                        root.beginItemRename(folderOverlayContainer.folderData.id);
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
                                    color: root.winText
                                    selectByMouse: true
                                    selectionColor: root.winAccent
                                    selectedTextColor: "#ffffff"
                                    clip: true
                                    text: folderOverlayContainer.folderData ? (folderOverlayContainer.folderData.name || "") : ""

                                    onVisibleChanged: {
                                        if (visible) {
                                            text = folderOverlayContainer.folderData ? (folderOverlayContainer.folderData.name || "") : "";
                                            root.bindRenameInput(foRenameInput);
                                        } else if (root.activeRenameInput === foRenameInput) {
                                            root.activeRenameInput = null;
                                        }
                                    }

                                    onAccepted: {
                                        if (folderOverlayContainer.folderData)
                                            root.renameTileOrFolder(folderOverlayContainer.folderData.id, text);
                                        root.dismissInlineRename();
                                    }

                                    Keys.onEscapePressed: function(event) {
                                        root.dismissInlineRename();
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
                                    color: root.winAccent
                                }
                            }

                            // Child Tiles Grid Area (Exact same visual placeholder & displacement as TileGroup)
                            Item {
                                id: folderTileArea
                                width: 288
                                implicitHeight: Math.ceil(((folderOverlayContainer.folderData && folderOverlayContainer.folderData.tiles) ? folderOverlayContainer.folderData.tiles.length : 0) / 3) * 98
                                height: implicitHeight

                                // Animated Slot Placeholder inside folder (Windows 10 accent outline - identical to TileGroup)
                                Rectangle {
                                    id: foSlotPlaceholder
                                    z: 10
                                    visible: root.isDraggingTile && root.dropTargetType === "reorder-folder" && root.dropTargetFolderId === (folderOverlayContainer.folderData ? folderOverlayContainer.folderData.id : "")
                                    width: 92
                                    height: 92
                                    color: Qt.rgba(root.winAccent.r, root.winAccent.g, root.winAccent.b, 0.2)
                                    border.color: root.winAccent
                                    border.width: 2

                                    readonly property point slotPos: folderOverlayContainer.folderSlotToPixel(root.dropTargetIndex)
                                    x: slotPos.x
                                    y: slotPos.y
                                }

                                Repeater {
                                    id: foRepeater
                                    model: folderOverlayContainer.folderData ? (folderOverlayContainer.folderData.tiles || []) : []

                                    Rectangle {
                                        id: foTileRect

                                        required property var modelData
                                        required property int index

                                        readonly property bool isBeingDragged: root.isDraggingTile && root.draggedTileData && root.draggedTileData.id === modelData.id

                                        readonly property point normalPos: folderOverlayContainer.folderSlotToPixel(index)
                                        x: normalPos.x
                                        y: normalPos.y

                                        width: 92
                                        height: 92
                                        color: foTileMouse.containsMouse ? root.winTileHoverBg : root.winTileBg
                                        border.color: foTileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.4) : "transparent"
                                        border.width: 1
                                        opacity: isBeingDragged ? 0.0 : 1.0
                                        scale: foTileMouse.pressed && (foTileMouse.pressedButtons & Qt.LeftButton) && !foTileMouse.draggingStarted ? 0.96 : 1

                                        Behavior on scale {
                                            NumberAnimation { duration: 80 }
                                        }

                                        // Dynamic displacement to make room for dragged item
                                        readonly property point displacement: folderOverlayContainer.getFolderTileDisplacement(index)

                                        transform: Translate {
                                            x: foTileRect.displacement.x
                                            y: foTileRect.displacement.y

                                            Behavior on x {
                                                enabled: root.isDraggingTile && !root.dragCommitting
                                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                            }
                                            Behavior on y {
                                                enabled: root.isDraggingTile && !root.dragCommitting
                                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                            }
                                        }

                                        AppIconRenderer {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 16
                                            width: 36
                                            height: 36
                                            iconValue: modelData.icon || ""
                                            iconSize: 36
                                            fallbackText: (modelData.name || "?").charAt(0)
                                        }

                                        StyledText {
                                            visible: root.renamingItemId !== modelData.id
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

                                        TextInput {
                                            id: foTileRenameInput

                                            visible: root.renamingItemId === modelData.id
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 6
                                            width: Math.min(Math.max(Math.ceil(contentWidth) + 2, 16), parent.width - 16)
                                            font.pixelSize: 11
                                            color: root.winText
                                            selectByMouse: true
                                            selectionColor: root.winAccent
                                            selectedTextColor: "#ffffff"
                                            clip: true
                                            text: modelData.name || ""
                                            z: 2

                                            onVisibleChanged: {
                                                if (visible) {
                                                    text = modelData.name || "";
                                                    root.bindRenameInput(foTileRenameInput);
                                                } else if (root.activeRenameInput === foTileRenameInput) {
                                                    root.activeRenameInput = null;
                                                }
                                            }

                                            onAccepted: {
                                                root.renameTileOrFolder(modelData.id, text);
                                                root.dismissInlineRename();
                                            }

                                            Keys.onEscapePressed: function(event) {
                                                root.dismissInlineRename();
                                                event.accepted = true;
                                            }
                                        }

                                        Rectangle {
                                            visible: foTileRenameInput.visible
                                            anchors.left: foTileRenameInput.left
                                            width: foTileRenameInput.width
                                            anchors.top: foTileRenameInput.bottom
                                            anchors.topMargin: 1
                                            height: 1
                                            color: root.winAccent
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
                                            enabled: root.renamingItemId !== modelData.id && (!root.isDraggingTile || draggingStarted)

                                            onPressed: function(mouse) {
                                                if (root.isDraggingTile) {
                                                    if (mouse.button === Qt.RightButton) {
                                                        root.cancelDraggingTile();
                                                        return;
                                                    }
                                                }
                                                if (mouse.button === Qt.RightButton) {
                                                    const gp = mapToItem(menuBackground, mouse.x, mouse.y);
                                                    root.contextMenuItem = modelData;
                                                    root.contextMenuGroupId = root.openFolderGroupId;
                                                    root.contextMenuType = "folderTile";
                                                    root.contextMenuParentFolder = folderOverlayContainer.folderData;
                                                    root.contextMenuX = Math.min(gp.x, menuBackground.width - 210);
                                                    root.contextMenuY = Math.min(gp.y, menuBackground.height - 240);
                                                    root.contextMenuVisible = true;
                                                    return;
                                                }
                                                if (mouse.button !== Qt.LeftButton) {
                                                    return;
                                                }
                                                pressPos = Qt.point(mouse.x, mouse.y);
                                                draggingStarted = false;
                                                preventStealing = true;
                                            }

                                            onPositionChanged: function(mouse) {
                                                if (pressed && (mouse.buttons & Qt.LeftButton)) {
                                                    var dist = Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y);
                                                    if (!root.isDraggingTile && !draggingStarted && dist > 3) {
                                                        draggingStarted = true;
                                                        preventStealing = true;
                                                        var gp = mapToItem(menuBackground, mouse.x, mouse.y);
                                                        root.startDraggingTile(modelData, root.openFolderGroupId, root.openFolderId, index, width, height, mouse.x, mouse.y, gp.x, gp.y);
                                                    } else if (root.isDraggingTile) {
                                                        var gp = mapToItem(menuBackground, mouse.x, mouse.y);
                                                        root.updateDragPosition(gp.x, gp.y);
                                                    }
                                                }
                                            }

                                            onReleased: function(mouse) {
                                                preventStealing = false;
                                                if (root.isDraggingTile) {
                                                    if (mouse.button === Qt.RightButton) {
                                                        root.cancelDraggingTile();
                                                    } else {
                                                        root.endDraggingTile();
                                                    }
                                                } else if (!draggingStarted) {
                                                    if (mouse.button === Qt.RightButton) {
                                                        return;
                                                    }
                                                    if (containsMouse) {
                                                        root.launchById(modelData.id);
                                                        root.closeMenu();
                                                    }
                                                }
                                                draggingStarted = false;
                                            }

                                            onCanceled: {
                                                preventStealing = false;
                                                if (root.isDraggingTile) {
                                                    root.cancelDraggingTile();
                                                }
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

                        onActiveFocusChanged: {
                            if (activeFocus)
                                root.closeSidebarAndPopovers();
                        }

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
                                            PopoutService.openSettingsWithTab("theme");
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
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: root.hoveredSearchItem = root.bestMatchApp
                                                onExited: {
                                                    if (root.hoveredSearchItem === root.bestMatchApp)
                                                        root.hoveredSearchItem = null;
                                                }
                                                onClicked: function(mouse) {
                                                    if (mouse.button === Qt.RightButton && root.bestMatchApp && !root.bestMatchApp.isWeb) {
                                                        const gp = mapToItem(menuBackground, mouse.x, mouse.y);
                                                        root.contextMenuItem = root.bestMatchApp;
                                                        root.contextMenuType = "app";
                                                        root.contextMenuX = Math.min(gp.x, menuBackground.width - 210);
                                                        root.contextMenuY = Math.min(gp.y, menuBackground.height - 180);
                                                        root.contextMenuVisible = true;
                                                        return;
                                                    }
                                                    root.launchItem(root.bestMatchApp);
                                                }
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

                                            SmoothScrollHandler {
                                                id: searchScroller
                                                stepSize: 114
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
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                    cursorShape: Qt.PointingHandCursor
                                                    onEntered: root.hoveredSearchItem = modelData
                                                    onExited: {
                                                        if (root.hoveredSearchItem === modelData)
                                                            root.hoveredSearchItem = null;
                                                    }
                                                    onClicked: function(mouse) {
                                                        if (mouse.button === Qt.RightButton && !modelData.isWeb) {
                                                            const gp = mapToItem(menuBackground, mouse.x, mouse.y);
                                                            root.contextMenuItem = modelData;
                                                            root.contextMenuType = "app";
                                                            root.contextMenuX = Math.min(gp.x, menuBackground.width - 210);
                                                            root.contextMenuY = Math.min(gp.y, menuBackground.height - 180);
                                                            root.contextMenuVisible = true;
                                                            return;
                                                        }
                                                        root.launchItem(modelData);
                                                    }
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
                                        id: previewOpenInWsBtn
                                        visible: root.currentPreviewItem && !root.currentPreviewItem.isWeb && root.currentPreviewItem.id
                                        iconName: "workspaces"
                                        label: "Open in workspace"
                                        onClicked: {
                                            root.contextMenuItem = root.currentPreviewItem;
                                            root.contextMenuType = "app";
                                            const gp = previewOpenInWsBtn.mapToItem(menuBackground, 0, 0);
                                            root.contextMenuX = Math.max(8, Math.min(gp.x - 204, menuBackground.width - 210));
                                            root.contextMenuY = Math.max(8, Math.min(gp.y, menuBackground.height - 200));
                                            root.contextMenuVisible = true;
                                            root.openWorkspaceSubmenu(null);
                                        }
                                    }

                                    SearchActionButton {
                                        visible: root.currentPreviewItem && !root.currentPreviewItem.isWeb && root.currentPreviewItem.id
                                        iconName: root.isAppPinned(root.currentPreviewItem) ? "remove_circle_outline" : "push_pin"
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
        // BACKDROP DISMISSER FOR POPOVERS & EXPANDED SIDEBAR
        // ==========================================
        MouseArea {
            id: popoverDismissBackdrop

            anchors.fill: parent
            z: 48
            visible: root.powerMenuOpen || root.userMenuOpen || root.contextMenuVisible
            hoverEnabled: false
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function(mouse) {
                root.closeSidebarAndPopovers();
            }
        }

        // ==========================================
        // LEFT RAIL DRAWER (Human, Settings, Power)
        // ==========================================
        Rectangle {
            id: railDrawer

            property bool railHovered: false
            property bool railTemporarilyDismissed: false

            readonly property bool isFlyoutHovered: (root.powerMenuOpen && powerFlyoutHover.hovered) || (root.userMenuOpen && userFlyoutHover.hovered)
            readonly property bool isRailExpanded: ((railHovered || isFlyoutHovered) && !railTemporarilyDismissed) || root.railPinnedOpen || root.powerMenuOpen || root.userMenuOpen

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: isRailExpanded ? 220 : 48
            color: root.winRail
            border.width: 0
            clip: true
            z: 50

            Behavior on width {
                enabled: (root.parentPopout ? root.parentPopout.shouldBeVisible : root.visible)
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
                    if (!hovered && !railDrawer.isFlyoutHovered) {
                        railExpandTimer.stop();
                        railCollapseTimer.restart();
                    } else if (hovered) {
                        railDrawer.railTemporarilyDismissed = false;
                        railCollapseTimer.stop();
                        if (!railDrawer.railTemporarilyDismissed) {
                            railExpandTimer.restart();
                        }
                    }
                }
            }

            // Absorb clicks on empty drawer space & close popovers
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {
                    root.closeSidebarAndPopovers();
                }
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
                        root.closeSidebarAndPopovers();
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
                    useAvatar: true
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
                        PopoutService.openSettingsWithTab("theme");
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
        // POWER FLYOUT (Directly above Power button)
        // ==========================================
        Rectangle {
            id: powerFlyout

            visible: root.powerMenuOpen
            width: 220
            height: powerCol.implicitHeight + 8
            x: 0
            y: parent.height - 48 - height
            color: Theme.surfaceContainer
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            z: 60

            HoverHandler {
                id: powerFlyoutHover
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

        // Elevation shadows for power flyout (outer top and right edges)
        Rectangle {
            anchors.left: powerFlyout.right
            anchors.top: powerFlyout.top
            anchors.bottom: powerFlyout.bottom
            width: 12
            z: 59
            visible: root.powerMenuOpen
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.4) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Rectangle {
            anchors.left: powerFlyout.left
            anchors.right: powerFlyout.right
            anchors.bottom: powerFlyout.top
            height: 8
            z: 59
            visible: root.powerMenuOpen
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.25) }
            }
        }

        // ==========================================
        // USER FLYOUT (Directly above User button)
        // ==========================================
        Rectangle {
            id: userFlyout

            visible: root.userMenuOpen
            width: 220
            height: userCol.implicitHeight + 8
            x: 0
            y: parent.height - 144 - height
            color: Theme.surfaceContainer
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            z: 60

            HoverHandler {
                id: userFlyoutHover
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
                        PopoutService.openSettingsWithTab("users");
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

        // Elevation shadows for user flyout (outer top and right edges)
        Rectangle {
            anchors.left: userFlyout.right
            anchors.top: userFlyout.top
            anchors.bottom: userFlyout.bottom
            width: 12
            z: 59
            visible: root.userMenuOpen
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.4) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Rectangle {
            anchors.left: userFlyout.left
            anchors.right: userFlyout.right
            anchors.bottom: userFlyout.top
            height: 8
            z: 59
            visible: root.userMenuOpen
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.25) }
            }
        }

        StartContextMenu {
            id: contextMenuOverlay
            host: root
            showResize: true
            showMoveToGroup: true
        }

        // Click-away catcher for inline rename (Enter commits; Escape / click away dismisses)
        MouseArea {
            id: renameClickAway

            anchors.fill: parent
            z: 80
            enabled: root.renamingItemId !== "" || (typeof tileGroup1 !== "undefined" && tileGroup1 && tileGroup1.isEditingHeader) || (typeof tileGroup2 !== "undefined" && tileGroup2 && tileGroup2.isEditingHeader)
            hoverEnabled: false
            propagateComposedEvents: true
            onPressed: function(mouse) {
                var inp = root.activeRenameInput;
                if (inp && inp.visible) {
                    var p = mapToItem(inp, mouse.x, mouse.y);
                    if (p.x >= -6 && p.y >= -6 && p.x <= inp.width + 6 && p.y <= inp.height + 10) {
                        mouse.accepted = false;
                        return;
                    }
                }
                root.dismissInlineRename();
                mouse.accepted = true;
            }
        }

        // ==========================================
        // FLOATING DRAG GHOST (Tile following cursor)
        // ==========================================
        Item {
            id: dragGhostContainer

            visible: root.isDraggingTile && root.draggedTileData !== null
            x: root.dragGhostX
            y: root.dragGhostY
            width: root.dragTileWidth
            height: root.dragTileHeight
            z: 999

            Rectangle {
                anchors.fill: parent
                color: root.winAccent
                opacity: 0.92
                scale: 1.04

                // Outer elevation drop shadow
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    color: "transparent"
                    border.color: Qt.rgba(0, 0, 0, 0.5)
                    border.width: 4
                    z: -1
                }

                // If folder, show 2x2 grid preview
                Grid {
                    visible: !!(root.draggedTileData && root.draggedTileData.isFolder)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    columns: 2
                    spacing: 4

                    Repeater {
                        model: (root.draggedTileData && root.draggedTileData.tiles ? root.draggedTileData.tiles : []).slice(0, 4)

                        Rectangle {
                            required property var modelData
                            width: 20
                            height: 20
                            color: Qt.rgba(255, 255, 255, 0.15)

                            AppIconRenderer {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                iconValue: modelData.icon || ""
                                iconSize: 16
                                fallbackText: (modelData.name || "?").charAt(0)
                            }
                        }
                    }
                }

                // If regular app tile, show app icon
                AppIconRenderer {
                    visible: !(root.draggedTileData && root.draggedTileData.isFolder)
                    anchors.centerIn: parent
                    width: parent.height > 60 ? 36 : 22
                    height: parent.height > 60 ? 36 : 22
                    iconValue: (root.draggedTileData && root.draggedTileData.icon) ? root.draggedTileData.icon : ""
                    iconSize: parent.height > 60 ? 36 : 22
                    fallbackText: ((root.draggedTileData && root.draggedTileData.name) || "?").charAt(0)
                }

                // Tile / Folder Name
                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: (root.draggedTileData && root.draggedTileData.name) || ""
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    visible: parent.height > 45
                }
            }

            // Action Badge (e.g. "+ Create folder", "+ Add to folder", "Move here")
            Rectangle {
                visible: root.dropActionBadge !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 8
                width: badgeText.implicitWidth + 16
                height: 24
                color: Qt.rgba(0, 0, 0, 0.88)
                border.color: root.winAccent
                border.width: 1

                StyledText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.dropActionBadge
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
        }

    }

    }

    component RailActionRow: Item {
        id: rar

        property string iconName: ""
        property string labelText: ""
        property bool useAvatar: false

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
                visible: !rar.useAvatar
                name: rar.iconName
                size: 20
                color: root.winText
            }

            DankCircularImage {
                anchors.centerIn: parent
                visible: rar.useAvatar
                width: 28
                height: 28
                imageSource: {
                    if (!rar.useAvatar || PortalService.profileImage === "")
                        return "";
                    if (PortalService.profileImage.startsWith("/"))
                        return "file://" + PortalService.profileImage;
                    return PortalService.profileImage;
                }
                fallbackIcon: rar.iconName || "person"
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

        property int groupId: 1
        property string groupTitle: ""
        property var tilesModel: []
        property real groupWidth: 288
        property bool isEditingHeader: false

        signal titleChanged(string newTitle)

        function cellToPixel(c, r) {
            var p = PinGrid.cellToPixel(c, r);
            return Qt.point(p.x, p.y);
        }

        readonly property real contentHeight: PinGrid.contentPixelHeight(tg.tilesModel, root.pinGridOpts)

        function mapToFlow(globalX, globalY) {
            if (typeof tileFlowItem !== "undefined" && tileFlowItem)
                return tileFlowItem.mapFromItem(menuBackground, globalX, globalY);
            return tg.mapFromItem(menuBackground, globalX, globalY);
        }

        function getOtherItems() {
            var draggedId = "";
            var exclude = false;
            if (root.isDraggingTile && root.draggedTileData && root.draggedFromGroupId === tg.groupId && !root.draggedFromFolderId) {
                draggedId = root.draggedTileData.id;
                exclude = true;
            }
            return PinGrid.otherItems(tg.tilesModel, draggedId, exclude);
        }

        readonly property var liveDisplacedMap: {
            if (!root.isDraggingTile || root.dragCommitting || root.dropTargetGroupId !== tg.groupId)
                return ({});
            return root.dragLiveDisplacedMap || ({});
        }

        implicitWidth: groupWidth
        width: groupWidth
        implicitHeight: tgCol.implicitHeight
        height: tgCol.implicitHeight

        Column {
            id: tgCol

            width: parent.width
            spacing: 8

            // ==========================================
            // GROUP HEADER (Click title to rename, hover handle)
            // ==========================================
            Item {
                width: parent.width
                height: 28

                StyledText {
                    id: headerTitleText

                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - (dragHandleIcon.visible ? 32 : 12))
                    text: tg.groupTitle || "Name group"
                    color: tg.groupTitle ? (headerMouse.containsMouse ? "#ffffff" : Qt.lighter(root.winText, 1.1)) : root.winMuted
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    visible: !tg.isEditingHeader && (tg.groupTitle !== "" || headerMouse.containsMouse)
                }

                Column {
                    id: dragHandleIcon

                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    visible: headerMouse.containsMouse && !tg.isEditingHeader

                    Rectangle { width: 14; height: 1.5; color: root.winMuted }
                    Rectangle { width: 14; height: 1.5; color: root.winMuted }
                }

                MouseArea {
                    id: headerMouse

                    anchors.fill: parent
                    enabled: !tg.isEditingHeader
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (root.powerMenuOpen || root.userMenuOpen || (typeof railDrawer !== "undefined" && railDrawer && railDrawer.isRailExpanded && !railDrawer.railHovered)) {
                            root.closeSidebarAndPopovers();
                            return;
                        }
                        if (mouse.button === Qt.RightButton) {
                            root.contextMenuItem = null;
                            root.contextMenuGroupId = tg.groupId;
                            root.contextMenuType = "groupHeader";
                            const gp = mapToItem(menuBackground, mouse.x, mouse.y);
                            root.contextMenuX = Math.min(gp.x, menuBackground.width - 210);
                            root.contextMenuY = Math.min(gp.y, menuBackground.height - 100);
                            root.contextMenuVisible = true;
                            return;
                        }
                        root.beginGroupRename(tg.groupId);
                    }
                }

                StyledText {
                    id: headerRenamePlaceholder

                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Name group"
                    color: root.winMuted
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    visible: tg.isEditingHeader && headerEditInput.text.length === 0
                }

                TextInput {
                    id: headerEditInput

                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(Math.max(Math.ceil(contentWidth) + 2, headerRenamePlaceholder.implicitWidth), parent.width - 12)
                    visible: tg.isEditingHeader
                    z: 2
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: root.winText
                    selectByMouse: true
                    selectionColor: root.winAccent
                    selectedTextColor: "#ffffff"
                    clip: true
                    text: tg.groupTitle

                    onVisibleChanged: {
                        if (visible) {
                            text = tg.groupTitle;
                            root.bindRenameInput(headerEditInput);
                        } else if (root.activeRenameInput === headerEditInput) {
                            root.activeRenameInput = null;
                        }
                    }

                    onAccepted: {
                        tg.titleChanged(text.trim());
                        root.dismissInlineRename();
                    }

                    Keys.onEscapePressed: function(event) {
                        root.dismissInlineRename();
                        event.accepted = true;
                    }
                }

                Rectangle {
                    visible: tg.isEditingHeader
                    anchors.left: headerEditInput.left
                    width: headerEditInput.width
                    anchors.top: headerEditInput.bottom
                    anchors.topMargin: 1
                    height: 1
                    color: root.winAccent
                }
            }

            // ==========================================
            // TILE FLOW & FOLDERS
            // ==========================================
            Item {
                id: tileFlowItem

                width: parent.width
                implicitHeight: Math.max(tg.contentHeight, (slotPlaceholder.visible ? (slotPlaceholder.y + slotPlaceholder.height) : 0))
                height: implicitHeight

                // Slot Placeholder (Windows 10 accent outline)
                Rectangle {
                    id: slotPlaceholder

                    z: 10
                    visible: root.isDraggingTile && root.dropTargetType === "reorder" && root.dropTargetGroupId === tg.groupId
                    width: (root.dragTileWidth > 0) ? root.dragTileWidth : 92
                    height: (root.dragTileHeight > 0) ? root.dragTileHeight : 92
                    color: Qt.rgba(root.winAccent.r, root.winAccent.g, root.winAccent.b, 0.2)
                    border.color: root.winAccent
                    border.width: 2

                    readonly property point slotPos: tg.cellToPixel(root.dropTargetCol, root.dropTargetRow)
                    x: slotPos.x
                    y: slotPos.y
                }

                Item {
                    id: tileContainer

                    width: parent.width
                    height: tg.contentHeight

                    Repeater {
                        id: tileRepeater
                        model: tg.tilesModel

                        Item {
                            id: tileDelegateRoot

                            required property var modelData
                            required property int index

                            readonly property bool isTileFolder: !!modelData.isFolder
                            readonly property string currentTileSize: modelData.size || (modelData.wide ? "wide" : "medium")
                            readonly property bool isBeingDragged: root.isDraggingTile && root.draggedTileData && root.draggedTileData.id === modelData.id

                            readonly property point normalPos: tg.cellToPixel(
                                (typeof modelData.col === "number") ? modelData.col : 0,
                                (typeof modelData.row === "number") ? modelData.row : 0
                            )
                            x: normalPos.x
                            y: normalPos.y

                            width: currentTileSize === "small" ? 43 : ((currentTileSize === "wide" || currentTileSize === "large") ? 190 : 92)
                            height: currentTileSize === "small" ? 43 : (currentTileSize === "large" ? 190 : 92)
                            opacity: (isBeingDragged || (tileDelegateRoot.isTileFolder && root.openFolderId === modelData.id)) ? 0.0 : 1.0

                            // Dynamic displacement to make room for dragged item
                            readonly property point displacement: {
                                if (root.dragCommitting || !root.isDraggingTile || root.dropTargetGroupId !== tg.groupId || isBeingDragged)
                                    return Qt.point(0, 0);
                                var map = tg.liveDisplacedMap;
                                if (!map || !map[modelData.id])
                                    return Qt.point(0, 0);
                                var targetCell = map[modelData.id];
                                var newPx = tg.cellToPixel(targetCell.x, targetCell.y);
                                return Qt.point(newPx.x - normalPos.x, newPx.y - normalPos.y);
                            }

                            transform: Translate {
                                x: tileDelegateRoot.displacement.x
                                y: tileDelegateRoot.displacement.y

                                Behavior on x {
                                    enabled: root.isDraggingTile && !root.dragCommitting
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                                Behavior on y {
                                    enabled: root.isDraggingTile && !root.dragCommitting
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                            }

                            // ==========================================
                            // CASE 1: COLLAPSED FOLDER TILE
                            // ==========================================
                            Rectangle {
                                anchors.fill: parent
                                visible: tileDelegateRoot.isTileFolder
                                color: folderTileMouse.containsMouse ? root.winTileHoverBg : root.winTileBg
                                border.color: (root.isDraggingTile && root.dropTargetType === "add-to-folder" && root.dropTargetFolderId === modelData.id) ? root.winAccent : (folderTileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.4) : "transparent")
                                border.width: (root.isDraggingTile && root.dropTargetType === "add-to-folder" && root.dropTargetFolderId === modelData.id) ? 2 : 1
                                scale: (root.isDraggingTile && root.dropTargetType === "add-to-folder" && root.dropTargetFolderId === modelData.id) ? 0.96 : (folderTileMouse.pressed && (folderTileMouse.pressedButtons & Qt.LeftButton) && !folderTileMouse.draggingStarted ? 0.96 : 1)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 80
                                    }
                                }

                                // Overlay cue when dragging a tile over this folder
                                Rectangle {
                                    anchors.fill: parent
                                    color: Qt.rgba(0, 0, 0, 0.65)
                                    border.color: root.winAccent
                                    border.width: 2
                                    visible: root.isDraggingTile && root.dropTargetType === "add-to-folder" && root.dropTargetFolderId === modelData.id
                                    z: 50

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        DankIcon { name: "folder_open"; size: 14; color: root.winAccent }
                                        StyledText { text: "Add to folder"; color: "#ffffff"; font.pixelSize: 10; font.weight: Font.DemiBold }
                                    }
                                }

                                // 2x2 Mini Preview Grid
                                Grid {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 12
                                    columns: 2
                                    spacing: 4

                                    Repeater {
                                        model: (modelData.tiles || []).slice(0, 4)

                                        Rectangle {
                                            required property var modelData
                                            width: 20
                                            height: 20
                                            color: Qt.rgba(255, 255, 255, 0.08)

                                            AppIconRenderer {
                                                anchors.centerIn: parent
                                                width: 16
                                                height: 16
                                                iconValue: modelData.icon || ""
                                                iconSize: 16
                                                fallbackText: (modelData.name || "?").charAt(0)
                                            }
                                        }
                                    }
                                }

                                // Folder Label & Chevron at bottom
                                Item {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 6
                                    height: 16

                                    StyledText {
                                        id: folderLabelText

                                        anchors.left: parent.left
                                        anchors.right: folderChevron.left
                                        anchors.rightMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: root.renamingItemId !== modelData.id
                                        text: modelData.name || "Folder"
                                        color: root.winText
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                    }

                                    DankIcon {
                                        id: folderChevron

                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: root.renamingItemId !== modelData.id
                                        name: "expand_more"
                                        size: 12
                                        color: root.winMuted
                                    }

                                    TextInput {
                                        id: folderRenameInput

                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(Math.max(Math.ceil(contentWidth) + 2, 16), parent.width)
                                        visible: root.renamingItemId === modelData.id
                                        font.pixelSize: 11
                                        color: root.winText
                                        selectByMouse: true
                                        selectionColor: root.winAccent
                                        selectedTextColor: "#ffffff"
                                        clip: true
                                        text: modelData.name || ""
                                        z: 2

                                        onVisibleChanged: {
                                            if (visible) {
                                                text = modelData.name || "";
                                                root.bindRenameInput(folderRenameInput);
                                            } else if (root.activeRenameInput === folderRenameInput) {
                                                root.activeRenameInput = null;
                                            }
                                        }

                                        onAccepted: {
                                            root.renameTileOrFolder(modelData.id, text);
                                            root.dismissInlineRename();
                                        }

                                        Keys.onEscapePressed: function(event) {
                                            root.dismissInlineRename();
                                            event.accepted = true;
                                        }
                                    }

                                    Rectangle {
                                        visible: folderRenameInput.visible
                                        anchors.left: folderRenameInput.left
                                        width: folderRenameInput.width
                                        anchors.top: folderRenameInput.bottom
                                        anchors.topMargin: 1
                                        height: 1
                                        color: root.winAccent
                                        z: 2
                                    }
                                }

                                MouseArea {
                                    id: folderTileMouse

                                    anchors.fill: parent
                                    enabled: root.renamingItemId !== modelData.id
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor

                                    property point pressPos: Qt.point(0, 0)
                                    property bool draggingStarted: false

                                    onPressed: function(mouse) {
                                        if (root.isDraggingTile) {
                                            if (mouse.button === Qt.RightButton) {
                                                root.cancelDraggingTile();
                                                return;
                                            }
                                        }
                                        if (root.powerMenuOpen || root.userMenuOpen || (typeof railDrawer !== "undefined" && railDrawer && railDrawer.isRailExpanded && !railDrawer.railHovered)) {
                                            root.closeSidebarAndPopovers();
                                            return;
                                        }
                                        if (mouse.button === Qt.RightButton) {
                                            const globalPos = mapToItem(menuBackground, mouse.x, mouse.y);
                                            root.contextMenuItem = modelData;
                                            root.contextMenuGroupId = tg.groupId;
                                            root.contextMenuType = "folder";
                                            root.contextMenuX = Math.min(globalPos.x, menuBackground.width - 210);
                                            root.contextMenuY = Math.min(globalPos.y, menuBackground.height - 180);
                                            root.contextMenuVisible = true;
                                            return;
                                        }
                                        if (mouse.button !== Qt.LeftButton) {
                                            return;
                                        }
                                        pressPos = Qt.point(mouse.x, mouse.y);
                                        draggingStarted = false;
                                        preventStealing = true;
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (pressed && (mouse.buttons & Qt.LeftButton)) {
                                            var dist = Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y);
                                            if (!root.isDraggingTile && !draggingStarted && dist > 3) {
                                                draggingStarted = true;
                                                preventStealing = true;
                                                var globalPos = mapToItem(menuBackground, mouse.x, mouse.y);
                                                root.startDraggingTile(modelData, tg.groupId, "", index, width, height, mouse.x, mouse.y, globalPos.x, globalPos.y);
                                            } else if (root.isDraggingTile) {
                                                var globalPos = mapToItem(menuBackground, mouse.x, mouse.y);
                                                root.updateDragPosition(globalPos.x, globalPos.y);
                                            }
                                        }
                                    }

                                    onReleased: function(mouse) {
                                        preventStealing = false;
                                        if (root.isDraggingTile) {
                                            if (mouse.button === Qt.RightButton) {
                                                root.cancelDraggingTile();
                                            } else {
                                                root.endDraggingTile();
                                            }
                                        } else if (!draggingStarted) {
                                            if (mouse.button === Qt.RightButton) {
                                                return;
                                            }
                                            if (containsMouse) {
                                                root.openFolder(modelData.id, tg.groupId, tileDelegateRoot);
                                            }
                                        }
                                        draggingStarted = false;
                                    }

                                    onCanceled: {
                                        preventStealing = false;
                                        if (root.isDraggingTile) {
                                            root.cancelDraggingTile();
                                        }
                                        draggingStarted = false;
                                    }
                                }
                            }

                            // ==========================================
                            // CASE 2: REGULAR APP TILE
                            // ==========================================
                            Rectangle {
                                anchors.fill: parent
                                visible: !tileDelegateRoot.isTileFolder
                                color: tileMouse.containsMouse ? root.winTileHoverBg : root.winTileBg
                                border.color: (root.isDraggingTile && root.dropTargetType === "create-folder" && root.dropTargetTileId === modelData.id) ? root.winAccent : (tileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.4) : "transparent")
                                border.width: (root.isDraggingTile && root.dropTargetType === "create-folder" && root.dropTargetTileId === modelData.id) ? 2 : 1
                                scale: (root.isDraggingTile && root.dropTargetType === "create-folder" && root.dropTargetTileId === modelData.id) ? 0.96 : (tileMouse.pressed && (tileMouse.pressedButtons & Qt.LeftButton) && !tileMouse.draggingStarted ? 0.96 : 1)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 80
                                    }
                                }

                                // Overlay cue when dragging a tile over this regular tile to create a folder
                                Rectangle {
                                    anchors.fill: parent
                                    color: Qt.rgba(0, 0, 0, 0.65)
                                    border.color: root.winAccent
                                    border.width: 2
                                    visible: root.isDraggingTile && root.dropTargetType === "create-folder" && root.dropTargetTileId === modelData.id
                                    z: 50

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        DankIcon { name: "create_new_folder"; size: 14; color: root.winAccent }
                                        StyledText { text: "Create folder"; color: "#ffffff"; font.pixelSize: 10; font.weight: Font.DemiBold }
                                    }
                                }

                                AppIconRenderer {
                                    anchors.horizontalCenter: tileDelegateRoot.currentTileSize === "wide" ? undefined : parent.horizontalCenter
                                    anchors.left: tileDelegateRoot.currentTileSize === "wide" ? parent.left : undefined
                                    anchors.leftMargin: tileDelegateRoot.currentTileSize === "wide" ? 16 : 0
                                    anchors.verticalCenter: (tileDelegateRoot.currentTileSize === "small" || tileDelegateRoot.currentTileSize === "wide") ? parent.verticalCenter : undefined
                                    y: (tileDelegateRoot.currentTileSize === "small" || tileDelegateRoot.currentTileSize === "wide") ? 0 : (tileDelegateRoot.currentTileSize === "large" ? 44 : 16)
                                    width: tileDelegateRoot.currentTileSize === "small" ? 22 : (tileDelegateRoot.currentTileSize === "large" ? 54 : 36)
                                    height: tileDelegateRoot.currentTileSize === "small" ? 22 : (tileDelegateRoot.currentTileSize === "large" ? 54 : 36)
                                    iconValue: modelData.icon || ""
                                    iconSize: tileDelegateRoot.currentTileSize === "small" ? 22 : (tileDelegateRoot.currentTileSize === "large" ? 54 : 36)
                                    fallbackText: (modelData.name || "?").charAt(0)
                                }

                                // Tile Display Name (Normal)
                                StyledText {
                                    id: tileNameText

                                    visible: tileDelegateRoot.currentTileSize !== "small" && root.renamingItemId !== modelData.id
                                    anchors.left: parent.left
                                    anchors.leftMargin: tileDelegateRoot.currentTileSize === "large" ? 12 : 8
                                    anchors.right: parent.right
                                    anchors.rightMargin: tileDelegateRoot.currentTileSize === "large" ? 12 : 8
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: tileDelegateRoot.currentTileSize === "large" ? 10 : 6
                                    text: modelData.name || ""
                                    color: root.winText
                                    font.pixelSize: tileDelegateRoot.currentTileSize === "large" ? 12 : 11
                                    font.weight: tileDelegateRoot.currentTileSize === "large" ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                TextInput {
                                    id: tileRenameInput

                                    visible: root.renamingItemId === modelData.id
                                    anchors.left: parent.left
                                    anchors.leftMargin: tileDelegateRoot.currentTileSize === "large" ? 12 : 8
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: tileDelegateRoot.currentTileSize === "large" ? 10 : 6
                                    width: Math.min(Math.max(Math.ceil(contentWidth) + 2, 16), parent.width - (tileDelegateRoot.currentTileSize === "large" ? 24 : 16))
                                    font.pixelSize: tileDelegateRoot.currentTileSize === "large" ? 12 : 11
                                    font.weight: tileDelegateRoot.currentTileSize === "large" ? Font.DemiBold : Font.Normal
                                    color: root.winText
                                    selectByMouse: true
                                    selectionColor: root.winAccent
                                    selectedTextColor: "#ffffff"
                                    clip: true
                                    text: modelData.name || ""
                                    z: 2

                                    onVisibleChanged: {
                                        if (visible) {
                                            text = modelData.name || "";
                                            root.bindRenameInput(tileRenameInput);
                                        } else if (root.activeRenameInput === tileRenameInput) {
                                            root.activeRenameInput = null;
                                        }
                                    }

                                    onAccepted: {
                                        root.renameTileOrFolder(modelData.id, text);
                                        root.dismissInlineRename();
                                    }

                                    Keys.onEscapePressed: function(event) {
                                        root.dismissInlineRename();
                                        event.accepted = true;
                                    }
                                }

                                Rectangle {
                                    visible: tileRenameInput.visible
                                    anchors.left: tileRenameInput.left
                                    width: tileRenameInput.width
                                    anchors.top: tileRenameInput.bottom
                                    anchors.topMargin: 1
                                    height: 1
                                    color: root.winAccent
                                    z: 2
                                }

                                MouseArea {
                                    id: tileMouse

                                    anchors.fill: parent
                                    enabled: root.renamingItemId !== modelData.id
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor

                                    property point pressPos: Qt.point(0, 0)
                                    property bool draggingStarted: false

                                    onPressed: function(mouse) {
                                        if (root.isDraggingTile) {
                                            if (mouse.button === Qt.RightButton) {
                                                root.cancelDraggingTile();
                                                return;
                                            }
                                        }
                                        if (root.powerMenuOpen || root.userMenuOpen || (typeof railDrawer !== "undefined" && railDrawer && railDrawer.isRailExpanded && !railDrawer.railHovered)) {
                                            root.closeSidebarAndPopovers();
                                            return;
                                        }
                                        if (mouse.button === Qt.RightButton) {
                                            const globalPos = mapToItem(menuBackground, mouse.x, mouse.y);
                                            root.contextMenuItem = modelData;
                                            root.contextMenuGroupId = tg.groupId;
                                            root.contextMenuType = "tile";
                                            root.contextMenuX = Math.min(globalPos.x, menuBackground.width - 210);
                                            root.contextMenuY = Math.min(globalPos.y, menuBackground.height - 240);
                                            root.contextMenuVisible = true;
                                            return;
                                        }
                                        if (mouse.button !== Qt.LeftButton) {
                                            return;
                                        }
                                        pressPos = Qt.point(mouse.x, mouse.y);
                                        draggingStarted = false;
                                        preventStealing = true;
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (pressed && (mouse.buttons & Qt.LeftButton)) {
                                            var dist = Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y);
                                            if (!root.isDraggingTile && !draggingStarted && dist > 3) {
                                                draggingStarted = true;
                                                preventStealing = true;
                                                var globalPos = mapToItem(menuBackground, mouse.x, mouse.y);
                                                root.startDraggingTile(modelData, tg.groupId, "", index, width, height, mouse.x, mouse.y, globalPos.x, globalPos.y);
                                            } else if (root.isDraggingTile) {
                                                var globalPos = mapToItem(menuBackground, mouse.x, mouse.y);
                                                root.updateDragPosition(globalPos.x, globalPos.y);
                                            }
                                        }
                                    }

                                    onReleased: function(mouse) {
                                        preventStealing = false;
                                        if (root.isDraggingTile) {
                                            if (mouse.button === Qt.RightButton) {
                                                root.cancelDraggingTile();
                                            } else {
                                                root.endDraggingTile();
                                            }
                                        } else if (!draggingStarted) {
                                            if (mouse.button === Qt.RightButton) {
                                                return;
                                            }
                                            if (containsMouse) {
                                                root.launchById(modelData.id);
                                            }
                                        }
                                        draggingStarted = false;
                                    }

                                    onCanceled: {
                                        preventStealing = false;
                                        if (root.isDraggingTile) {
                                            root.cancelDraggingTile();
                                        }
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

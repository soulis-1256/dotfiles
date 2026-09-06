import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var closePopout: null
    property var parentPopout: null

    readonly property color winBg: "#1f1f1f"
    readonly property color winPanel: "#181818"
    readonly property color winHover: "#3d3d3d"
    readonly property color winAccent: "#0078d7"
    readonly property color winText: "#ffffff"
    readonly property color winMuted: "#c8c8c8"
    readonly property color winSearch: "#2b2b2b"
    readonly property color winRail: "#101010"

    readonly property var tilePalette: ["#0078d7", "#107c10", "#ca5010", "#881798", "#e81123", "#0099bc", "#744da9", "#2d7d9a", "#c239b3", "#038387"]

    implicitWidth: 844
    implicitHeight: 632
    width: parent ? parent.width : implicitWidth

    property bool showAllApps: false
    property bool powerMenuOpen: false
    property string query: ""
    property var appModel: []
    property var tileModel: []

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

    function resolveApp(queryText) {
        const q = (queryText || "").toLowerCase().trim();
        if (!q)
            return null;
        const apps = AppSearchService.getVisibleApplications() || [];
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

    function toRow(entry) {
        if (!entry)
            return null;
        return {
            "id": entry.id || "",
            "name": entry.name || "",
            "icon": entry.icon || ""
        };
    }

    function mostUsed() {
        const ranked = AppUsageHistoryData.getRankedApps() || [];
        const out = [];
        const seen = {};
        for (let i = 0; i < ranked.length && out.length < 14; i++) {
            const row = toRow(lookupEntry(ranked[i].id));
            if (!row || !row.name)
                continue;
            const key = row.id || row.name;
            if (seen[key])
                continue;
            seen[key] = true;
            out.push(row);
        }
        if (out.length > 0)
            return out;
        const fallback = AppSearchService.getVisibleApplications() || [];
        for (let j = 0; j < fallback.length && out.length < 14; j++) {
            const row = toRow(fallback[j]);
            if (row && row.name)
                out.push(row);
        }
        return out;
    }

    function allApps() {
        const apps = AppSearchService.getVisibleApplications() || [];
        const out = [];
        for (let i = 0; i < apps.length; i++) {
            const row = toRow(apps[i]);
            if (row && row.name)
                out.push(row);
        }
        out.sort(function (a, b) {
            return a.name.localeCompare(b.name, Qt.locale().name);
        });
        return out;
    }

    function refreshApps() {
        if (root.query.length > 0) {
            const hits = AppSearchService.searchApplications(root.query) || [];
            const out = [];
            for (let i = 0; i < hits.length; i++) {
                const row = toRow(hits[i]);
                if (row && row.name)
                    out.push(row);
            }
            root.appModel = out;
            return;
        }
        root.appModel = root.showAllApps ? allApps() : mostUsed();
    }

    function defaultTileQueries() {
        return ["steam", "zen", "spotify", "dolphin", "ghostty", "brave", "zed", "vesktop", "firefox", "code", "discord", "vlc"];
    }

    function refreshTiles() {
        const queries = defaultTileQueries();
        const tiles = [];
        const seen = {};
        for (let i = 0; i < queries.length && tiles.length < 9; i++) {
            const app = resolveApp(queries[i]);
            if (!app || !app.name)
                continue;
            const key = app.id || app.name;
            if (seen[key])
                continue;
            seen[key] = true;
            tiles.push({
                "id": app.id || "",
                "name": app.name,
                "icon": app.icon || "",
                "color": tilePalette[tiles.length % tilePalette.length],
                "wide": tiles.length === 1 || tiles.length === 4
            });
        }
        root.tileModel = tiles;
    }

    function launchById(id) {
        const entry = lookupEntry(id);
        if (!entry)
            return;
        SessionService.launchDesktopEntry(entry);
        AppUsageHistoryData.addAppUsage(entry);
        root.powerMenuOpen = false;
        if (root.closePopout)
            root.closePopout();
    }

    function doPower(action) {
        root.powerMenuOpen = false;
        if (root.closePopout)
            root.closePopout();
        if (action === "lock") {
            Quickshell.execDetached(["loginctl", "lock-session"]);
            return;
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

    Component.onCompleted: {
        refreshApps();
        refreshTiles();
    }

    Connections {
        target: root.parentPopout
        function onOpened() {
            root.query = "";
            root.showAllApps = false;
            root.powerMenuOpen = false;
            refreshApps();
            Qt.callLater(function () {
                searchField.forceActiveFocus();
            });
        }
    }

    Connections {
        target: AppUsageHistoryData
        function onAppUsageRankingChanged() {
            if (root.query.length === 0 && !root.showAllApps)
                refreshApps();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.winBg

        Row {
            id: bodyRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: searchBar.top
            spacing: 0

            // Left rail
            Rectangle {
                id: rail
                width: 48
                height: parent.height
                color: root.winRail

                RailButton {
                    anchors.top: parent.top
                    iconName: "menu"
                    tooltipText: root.showAllApps ? "Most used" : "All apps"
                    onClicked: {
                        root.showAllApps = !root.showAllApps;
                        if (root.query.length === 0)
                            refreshApps();
                    }
                }

                Column {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    spacing: 0

                    RailButton {
                        iconName: "person"
                        tooltipText: UserInfoService.fullName || UserInfoService.username || "User"
                    }

                    RailButton {
                        iconName: "power_settings_new"
                        tooltipText: "Power"
                        onClicked: root.powerMenuOpen = !root.powerMenuOpen
                    }
                }
            }

            // App list
            Item {
                id: listPane
                width: 280
                height: parent.height

                StyledText {
                    id: listHeader
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    text: {
                        if (root.query.length > 0)
                            return "Best match";
                        return root.showAllApps ? "All apps" : "Most used";
                    }
                    color: root.winText
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                ListView {
                    id: appList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: listHeader.bottom
                    anchors.topMargin: 8
                    anchors.bottom: parent.bottom
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.appModel
                    spacing: 0

                    delegate: Item {
                        required property var modelData
                        width: appList.width
                        height: 40

                        Rectangle {
                            anchors.fill: parent
                            color: rowHover.containsMouse ? root.winHover : "transparent"
                        }

                        AppIconRenderer {
                            id: appIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            iconValue: modelData.icon || ""
                            iconSize: 24
                            fallbackText: (modelData.name || "?").charAt(0)
                        }

                        StyledText {
                            anchors.left: appIcon.right
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
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchById(modelData.id)
                        }
                    }
                }
            }

            // Tiles
            Item {
                id: tilePane
                width: parent.width - rail.width - listPane.width
                height: parent.height

                StyledText {
                    id: tileHeader
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    text: "Life at a glance"
                    color: root.winText
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Flow {
                    id: tileFlow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: tileHeader.bottom
                    anchors.topMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 8

                    Repeater {
                        model: root.tileModel

                        Rectangle {
                            required property var modelData
                            required property int index
                            width: modelData.wide ? 228 : 110
                            height: 110
                            color: tileHover.containsMouse ? Qt.lighter(modelData.color, 1.12) : modelData.color

                            AppIconRenderer {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.top: parent.top
                                anchors.topMargin: 12
                                width: 32
                                height: 32
                                iconValue: modelData.icon || ""
                                iconSize: 32
                                fallbackText: (modelData.name || "?").charAt(0)
                                fallbackBackgroundColor: Qt.darker(modelData.color, 1.2)
                                fallbackTextColor: "#ffffff"
                            }

                            StyledText {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.bottomMargin: 10
                                text: modelData.name || ""
                                color: "#ffffff"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }

                            MouseArea {
                                id: tileHover
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

        // Search
        Rectangle {
            id: searchBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 48
            color: root.winSearch

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: "#2f2f2f"
            }

            DankIcon {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 18
                color: root.winMuted
            }

            TextField {
                id: searchField
                anchors.left: searchIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 32
                color: root.winText
                font.pixelSize: 14
                placeholderText: "Type here to search"
                placeholderTextColor: "#8a8a8a"
                background: Item {}
                selectByMouse: true
                onTextChanged: {
                    root.query = text;
                    refreshApps();
                }
                Keys.onReturnPressed: {
                    if (root.appModel.length > 0)
                        root.launchById(root.appModel[0].id);
                }
                Keys.onEnterPressed: {
                    if (root.appModel.length > 0)
                        root.launchById(root.appModel[0].id);
                }
                Keys.onEscapePressed: {
                    if (root.closePopout)
                        root.closePopout();
                }
            }
        }

        // Power flyout
        Rectangle {
            visible: root.powerMenuOpen
            width: 180
            height: powerCol.implicitHeight + 8
            x: 52
            y: parent.height - searchBar.height - height - 8
            color: "#2b2b2b"
            border.color: "#3d3d3d"
            border.width: 1
            z: 20

            Column {
                id: powerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                spacing: 0

                PowerRow {
                    label: "Sleep"
                    onClicked: root.doPower("suspend")
                }
                PowerRow {
                    label: "Shut down"
                    onClicked: root.doPower("poweroff")
                }
                PowerRow {
                    label: "Restart"
                    onClicked: root.doPower("reboot")
                }
                PowerRow {
                    label: "Lock"
                    onClicked: root.doPower("lock")
                }
            }
        }
    }

    component RailButton: Item {
        id: rb
        property string iconName: ""
        property string tooltipText: ""
        signal clicked

        width: 48
        height: 48

        Rectangle {
            anchors.fill: parent
            color: rbHover.containsMouse ? root.winHover : "transparent"
        }

        DankIcon {
            anchors.centerIn: parent
            name: rb.iconName
            size: 20
            color: root.winText
        }

        MouseArea {
            id: rbHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rb.clicked()
        }
    }

    component PowerRow: Item {
        id: pr
        property string label: ""
        signal clicked

        width: parent.width
        height: 36

        Rectangle {
            anchors.fill: parent
            color: prHover.containsMouse ? root.winHover : "transparent"
        }

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: pr.label
            color: root.winText
            font.pixelSize: 13
        }

        MouseArea {
            id: prHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pr.clicked()
        }
    }
}

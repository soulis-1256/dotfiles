import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

FocusScope {
    id: root

    property var closePopout: null
    property var parentPopout: null

    implicitWidth: 620
    implicitHeight: 660

    property string searchQuery: ""
    property bool userFlyoutOpen: false
    property bool powerFlyoutOpen: false

    function closeMenu() {
        closePopovers();
        if (typeof closePopout === "function") {
            closePopout();
        } else if (parentPopout && typeof parentPopout.close === "function") {
            parentPopout.close();
        }
    }

    function closePopovers() {
        userFlyoutOpen = false;
        powerFlyoutOpen = false;
        contextMenu.dismiss();
    }

    function launchApp(app) {
        if (!app)
            return;
        const entry = app.data || app;
        SessionService.launchDesktopEntry(entry);
        if (typeof AppUsageHistoryData !== "undefined") {
            AppUsageHistoryData.addAppUsage(entry);
        }
        closeMenu();
    }

    function launchInWorkspace(app, workspaceId) {
        if (!app)
            return;
        const entry = app.data || app;

        let cmdParts = [];
        if (entry.command && entry.command.length > 0) {
            cmdParts = Array.from(entry.command);
        } else if (entry.exec) {
            cmdParts = [entry.exec];
        } else if (entry.id) {
            cmdParts = [entry.id];
        }

        if (cmdParts.length > 0) {
            if (typeof SessionData !== "undefined" && SessionData.getAppOverride) {
                const override = SessionData.getAppOverride(entry.id || "");
                if (override && override.extraFlags) {
                    const extraArgs = override.extraFlags.trim().split(/\s+/).filter(a => a.length > 0);
                    cmdParts = cmdParts.concat(extraArgs);
                }
            }

            if (entry.runInTerminal || entry.terminal) {
                const term = (typeof SessionData !== "undefined" && SessionData.resolveTerminal)
                    ? (SessionData.resolveTerminal() || "ghostty")
                    : "ghostty";
                cmdParts = [term, "-e"].concat(cmdParts);
            }

            const escaped = cmdParts.map(arg => "'" + String(arg).replace(/'/g, "'\\''") + "'").join(" ");
            const execCmd = `[workspace ${workspaceId}] ${escaped}`;

            if (typeof HyprlandService !== "undefined" && HyprlandService.luaConfigActive) {
                Hyprland.dispatch(`hl.dsp.exec_cmd(${JSON.stringify(execCmd)})`);
                Hyprland.dispatch(`hl.dsp.focus({ workspace = ${JSON.stringify(String(workspaceId))} })`);
            } else if (typeof Hyprland !== "undefined") {
                Hyprland.dispatch(`exec ${execCmd}`);
                Hyprland.dispatch(`workspace ${workspaceId}`);
            }

            if (typeof AppUsageHistoryData !== "undefined") {
                AppUsageHistoryData.addAppUsage(entry);
            }
        }
        closeMenu();
    }

    function launchInTerminal(app) {
        if (!app)
            return;
        const entry = app.data || app;
        const cmdParts = entry.command?.length ? Array.from(entry.command) : [entry.exec || entry.id];
        const term = (typeof SessionData !== "undefined" && SessionData.resolveTerminal)
            ? (SessionData.resolveTerminal() || "ghostty")
            : "ghostty";
        Quickshell.process([term, "-e", ...cmdParts]);
        closeMenu();
    }

    function openContextMenu(app, gx, gy) {
        powerFlyoutOpen = false;
        userFlyoutOpen = false;
        contextMenu.appItem = app;
        contextMenu.targetX = gx;
        contextMenu.targetY = gy;
        contextMenu.open = true;
    }

    property var allAppsList: []

    function updateAppList() {
        const apps = (typeof AppSearchService !== "undefined" && AppSearchService.getVisibleApplications) ? AppSearchService.getVisibleApplications() : [];
        const q = searchQuery.trim().toLowerCase();

        if (q === "") {
            const sorted = apps.slice().sort((a, b) => (a.name || "").localeCompare(b.name || ""));
            const result = [];
            let currentLetter = "";
            for (let i = 0; i < sorted.length; i++) {
                const app = sorted[i];
                const first = (app.name || "").charAt(0).toUpperCase();
                const letter = (first >= "A" && first <= "Z") ? first : "#";
                if (letter !== currentLetter) {
                    currentLetter = letter;
                    result.push({
                        itemType: "header",
                        title: currentLetter
                    });
                }
                result.push({
                    itemType: "app",
                    app: app
                });
            }
            allAppsList = result;
            return;
        }

        const filtered = apps.filter(app => {
            const name = (app.name || "").toLowerCase();
            const comment = (app.comment || "").toLowerCase();
            const id = (app.id || "").toLowerCase();
            return name.includes(q) || comment.includes(q) || id.includes(q);
        }).sort((a, b) => {
            const aName = (a.name || "").toLowerCase();
            const bName = (b.name || "").toLowerCase();
            const aStarts = aName.startsWith(q);
            const bStarts = bName.startsWith(q);
            if (aStarts && !bStarts)
                return -1;
            if (!aStarts && bStarts)
                return 1;
            return aName.localeCompare(bName);
        });

        allAppsList = filtered.map(app => ({
            itemType: "app",
            app: app
        }));
    }

    onSearchQueryChanged: updateAppList()

    Component.onCompleted: {
        updateAppList();
        Qt.callLater(() => {
            searchInput.forceActiveFocus();
        });
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (userFlyoutOpen || powerFlyoutOpen || contextMenu.open) {
                closePopovers();
                event.accepted = true;
                return;
            }
            if (searchQuery.length > 0) {
                searchQuery = "";
                searchInput.text = "";
                event.accepted = true;
                return;
            }
            closeMenu();
            event.accepted = true;
        }
    }

    Rectangle {
        id: menuBackground
        anchors.fill: parent
        radius: 12
        color: Theme.surfaceContainer
        border.color: Theme.outline
        border.width: 1
        clip: true

        // Top Search Bar
        Rectangle {
            id: searchBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 18
            height: 40
            radius: 8
            color: searchInput.activeFocus ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
            border.color: searchInput.activeFocus ? Theme.primary : Theme.outline
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                DIcon {
                    name: "search"
                    size: 18
                    color: searchInput.activeFocus ? Theme.primary : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                    id: searchInput
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 56
                    font.pixelSize: 13
                    color: Theme.surfaceText
                    clip: true

                    property string placeholderText: "Type here to search..."

                    StyledText {
                        anchors.fill: parent
                        text: searchInput.placeholderText
                        color: Theme.surfaceVariantText
                        font.pixelSize: 13
                        visible: !searchInput.text && !searchInput.inputMethodComposing
                    }

                    onTextChanged: {
                        root.searchQuery = text;
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.allAppsList.length > 0) {
                                for (let i = 0; i < root.allAppsList.length; i++) {
                                    if (root.allAppsList[i].itemType === "app") {
                                        root.launchApp(root.allAppsList[i].app);
                                        event.accepted = true;
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }

                DIcon {
                    name: "close"
                    size: 16
                    color: Theme.surfaceVariantText
                    visible: searchInput.text.length > 0
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = "";
                            root.searchQuery = "";
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // All Apps List
        ListView {
            id: appListView
            anchors.top: searchBar.bottom
            anchors.bottom: footerBar.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            boundsMovement: Flickable.StopAtBounds
            model: root.allAppsList
            spacing: 2

            delegate: Item {
                id: rowDelegate
                required property var modelData

                width: appListView.width
                height: modelData.itemType === "header" ? 28 : 38

                // Letter Header
                Item {
                    visible: modelData.itemType === "header"
                    anchors.fill: parent

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.title || ""
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.primary
                    }
                }

                // App Row
                Rectangle {
                    visible: modelData.itemType === "app"
                    anchors.fill: parent
                    radius: 6
                    color: rowMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        AppIconRenderer {
                            anchors.verticalCenter: parent.verticalCenter
                            iconValue: modelData.app ? (modelData.app.icon || "") : ""
                            iconSize: 22
                            fallbackText: modelData.app ? (modelData.app.name || "?").charAt(0) : "?"
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 44
                            text: modelData.app ? (modelData.app.name || "") : ""
                            font.pixelSize: 13
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        property bool rightPressed: false
                        property point pressPos: Qt.point(0, 0)

                        onPressed: function(mouse) {
                            pressPos = Qt.point(mouse.x, mouse.y);
                            if (mouse.button === Qt.RightButton) {
                                rightPressed = true;
                                const gp = mapToItem(menuBackground, mouse.x, mouse.y);
                                root.openContextMenu(modelData.app, gp.x, gp.y);
                                mouse.accepted = true;
                                return;
                            }
                            rightPressed = false;
                        }

                        onPositionChanged: function(mouse) {
                            if (rightPressed) {
                                mouse.accepted = true;
                            }
                        }

                        onReleased: function(mouse) {
                            if (rightPressed || mouse.button === Qt.RightButton) {
                                rightPressed = false;
                                mouse.accepted = true;
                                return;
                            }

                            if (mouse.button === Qt.LeftButton) {
                                const dist = Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y);
                                if (dist < 10 && containsMouse) {
                                    root.launchApp(modelData.app);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Popover dismiss backdrop (eats clicks outside open context menu or flyouts)
        MouseArea {
            id: popoverBackdrop
            anchors.fill: parent
            z: 45
            visible: root.userFlyoutOpen || root.powerFlyoutOpen || contextMenu.open
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function(mouse) {
                root.closePopovers();
            }
        }

        // Bottom Footer Bar (Settings & Power on right, Sign out on left)
        Item {
            id: footerBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 56
            z: 50

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.outline
                opacity: 0.35
            }

            // Left: User Profile Chip
            Rectangle {
                id: userChip
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(userRow.implicitWidth + 20, parent.width * 0.5)
                height: 40
                radius: 8
                color: userHover.containsMouse || root.userFlyoutOpen ? Theme.surfaceContainerHighest : "transparent"

                Row {
                    id: userRow
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: Theme.surfaceContainerHighest
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: {
                                if (typeof PortalService !== "undefined" && PortalService.profileImage) {
                                    return PortalService.profileImage.startsWith("/") ? "file://" + PortalService.profileImage : PortalService.profileImage;
                                }
                                return "";
                            }
                            visible: status === Image.Ready
                            fillMode: Image.PreserveAspectCrop
                        }

                        DIcon {
                            name: "person"
                            size: 18
                            color: Theme.surfaceText
                            anchors.centerIn: parent
                            visible: !parent.children[0].visible
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (typeof UserInfoService !== "undefined" && (UserInfoService.fullName || UserInfoService.username)) || "User"
                        color: Theme.surfaceText
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 160)
                    }
                }

                MouseArea {
                    id: userHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.userFlyoutOpen = !root.userFlyoutOpen;
                        root.powerFlyoutOpen = false;
                        contextMenu.dismiss();
                    }
                }
            }

            // Right: Settings and Power Buttons
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Settings Button
                Rectangle {
                    width: 38
                    height: 38
                    radius: 8
                    color: settingsHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                    DIcon {
                        anchors.centerIn: parent
                        name: "settings"
                        size: 20
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: settingsHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.process(["dms", "ipc", "call", "settings", "open"]);
                            root.closeMenu();
                        }
                    }
                }

                // Power Button
                Rectangle {
                    width: 38
                    height: 38
                    radius: 8
                    color: powerHover.containsMouse || root.powerFlyoutOpen ? Theme.surfaceContainerHighest : "transparent"

                    DIcon {
                        anchors.centerIn: parent
                        name: "power_settings_new"
                        size: 20
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: powerHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.powerFlyoutOpen = !root.powerFlyoutOpen;
                            root.userFlyoutOpen = false;
                            contextMenu.dismiss();
                        }
                    }
                }
            }
        }

        // User Flyout (Directly above User Chip)
        Rectangle {
            id: userFlyout
            visible: root.userFlyoutOpen
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.bottom: footerBar.top
            anchors.bottomMargin: 8
            width: 170
            height: userCol.implicitHeight + 12
            radius: 8
            color: Theme.surfaceContainer
            border.color: Theme.outline
            border.width: 1
            z: 60
            clip: true

            Column {
                id: userCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 2

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 6
                    color: lockHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 10

                        DIcon {
                            name: "lock"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Lock"
                            font.pixelSize: 13
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: lockHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.process(["dms", "ipc", "call", "lock", "lock"]);
                            root.closeMenu();
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 6
                    color: logoutHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 10

                        DIcon {
                            name: "logout"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Sign out"
                            font.pixelSize: 13
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: logoutHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SessionService.logout();
                            root.closeMenu();
                        }
                    }
                }
            }
        }

        // Power Flyout (Directly above Power Button)
        Rectangle {
            id: powerFlyout
            visible: root.powerFlyoutOpen
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: footerBar.top
            anchors.bottomMargin: 8
            width: 170
            height: powerCol.implicitHeight + 12
            radius: 8
            color: Theme.surfaceContainer
            border.color: Theme.outline
            border.width: 1
            z: 60
            clip: true

            Column {
                id: powerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 2

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 6
                    color: sleepHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 10

                        DIcon {
                            name: "bedtime"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Sleep"
                            font.pixelSize: 13
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: sleepHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SessionService.suspend();
                            root.closeMenu();
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 6
                    color: rebootHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 10

                        DIcon {
                            name: "restart_alt"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Restart"
                            font.pixelSize: 13
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: rebootHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SessionService.reboot();
                            root.closeMenu();
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 6
                    color: shutHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 10

                        DIcon {
                            name: "power_settings_new"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Shut down"
                            font.pixelSize: 13
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: shutHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SessionService.poweroff();
                            root.closeMenu();
                        }
                    }
                }
            }
        }

        // App Right-Click Context Menu
        StartContextMenu {
            id: contextMenu
            host: root
        }
    }
}

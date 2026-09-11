import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    WindowBlur {
        targetWindow: root
        blurX: menuContainer.x
        blurY: menuContainer.y
        blurWidth: root.visible ? menuContainer.width : 0
        blurHeight: root.visible ? menuContainer.height : 0
        blurRadius: Theme.cornerRadius
    }

    WlrLayershell.namespace: "dms:dock-context-menu"

    property var appData: null
    property var anchorItem: null
    property int margin: 10
    property bool hidePin: false
    property var desktopEntry: null
    property bool isDmsWindow: appData?.appId === "org.quickshell" || appData?.appId === "com.danklinux.dms"

    property bool isVertical: false
    property string edge: "top"
    property point anchorPos: Qt.point(0, 0)
    readonly property bool workspaceScoped: Array.isArray(appData?.workspaceWindows)
    readonly property int closeAllWindowCount: {
        if (workspaceScoped)
            return appData.workspaceWindows.length;
        if (appData?.type === "grouped")
            return appData.windowCount || (appData.allWindows || []).length || 0;
        return 0;
    }
    readonly property bool showCloseWindowItem: {
        if (!appData)
            return false;
        if (workspaceScoped)
            return appData.type !== "grouped";
        return appData.type === "window";
    }
    readonly property bool showCloseAllItem: {
        if (!appData)
            return false;
        if (workspaceScoped)
            return closeAllWindowCount > 1;
        return appData.type === "grouped" && appData.windowCount > 0;
    }
    readonly property bool hasCloseItems: showCloseWindowItem || showCloseAllItem

    function showAt(x, y, vertical, barEdge, data, hidePinOption, entry, targetScreen) {
        if (targetScreen) {
            root.screen = targetScreen;
        }

        anchorPos = Qt.point(x, y);
        isVertical = vertical ?? false;
        edge = barEdge ?? "top";

        appData = data;
        hidePin = hidePinOption || false;
        desktopEntry = entry || null;

        visible = true;

        if (targetScreen) {
            TrayMenuManager.registerMenu(targetScreen.name, root);
        }
    }

    function close() {
        visible = false;

        if (root.screen) {
            TrayMenuManager.unregisterMenu(root.screen.name);
        }
    }

    function resolveCloseableToplevel(win) {
        if (!win)
            return null;
        if (win.toplevel && win.toplevel.close)
            return win.toplevel;
        if (win.wayland && win.wayland.close)
            return win.wayland;
        if (win.close)
            return win;
        return null;
    }

    function collectGroupedToplevels() {
        if (!root.appData || root.appData.type !== "grouped")
            return [];

        const fromData = [];
        const windows = root.appData.allWindows || [];
        for (let i = 0; i < windows.length; i++) {
            const toplevel = resolveCloseableToplevel(windows[i]);
            if (toplevel)
                fromData.push(toplevel);
        }
        if (fromData.length > 0)
            return fromData;

        const targetId = root.appData.appId;
        if (!targetId)
            return [];

        const toplevels = [];
        const allToplevels = ToplevelManager.toplevels.values;
        for (let i = 0; i < allToplevels.length; i++) {
            const toplevel = allToplevels[i];
            const rawId = toplevel.appId || "";
            if (rawId === targetId || Paths.moddedAppId(rawId) === targetId)
                toplevels.push(toplevel);
        }
        return toplevels;
    }

    function closeToplevel(toplevel, address) {
        if (toplevel && toplevel.close) {
            toplevel.close();
            return true;
        }
        const windowAddress = address || toplevel?.address;
        if (CompositorService.isHyprland && windowAddress) {
            HyprlandService.closeWindow(windowAddress);
            return true;
        }
        return false;
    }

    function closeWindowsFromList(windows) {
        if (!windows)
            return;
        for (let i = 0; i < windows.length; i++) {
            const win = windows[i];
            closeToplevel(win?.toplevel || win?.wayland || win, win?.address || win?.toplevel?.address);
        }
    }

    function closeGroupedWindows() {
        if (root.workspaceScoped) {
            closeWindowsFromList(root.appData.workspaceWindows);
            return;
        }

        const toplevels = collectGroupedToplevels();
        let closed = 0;
        for (let i = 0; i < toplevels.length; i++) {
            if (closeToplevel(toplevels[i]))
                closed++;
        }
        if (closed > 0)
            return;

        closeWindowsFromList(root.appData?.allWindows || []);
    }

    screen: null
    visible: false
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Component.onDestruction: {
        if (root.screen) {
            TrayMenuManager.unregisterMenu(root.screen.name);
        }
    }

    Connections {
        target: PopoutManager
        function onPopoutOpening() {
            root.close();
        }
    }

    Rectangle {
        id: menuContainer

        x: {
            if (root.isVertical) {
                if (root.edge === "left") {
                    return Math.min(root.width - width - 10, root.anchorPos.x);
                } else {
                    return Math.max(10, root.anchorPos.x - width);
                }
            } else {
                const left = 10;
                const right = root.width - width - 10;
                const want = root.anchorPos.x - width / 2;
                return Math.max(left, Math.min(right, want));
            }
        }
        y: {
            if (root.isVertical) {
                const top = 10;
                const bottom = root.height - height - 10;
                const want = root.anchorPos.y - height / 2;
                return Math.max(top, Math.min(bottom, want));
            } else {
                if (root.edge === "top") {
                    return Math.min(root.height - height - 10, root.anchorPos.y);
                } else {
                    return Math.max(10, root.anchorPos.y - height);
                }
            }
        }

        width: Math.min(400, Math.max(180, menuColumn.implicitWidth + Theme.spacingS * 2))
        height: Math.max(60, menuColumn.implicitHeight + Theme.spacingS * 2)
        color: Theme.floatingSurface
        radius: Theme.cornerRadius
        border.color: BlurService.borderColor
        border.width: BlurService.borderWidth

        opacity: root.visible ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: -1
        }

        Column {
            id: menuColumn
            width: parent.width - Theme.spacingS * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingS
            spacing: 1

            // Window list for grouped apps
            Repeater {
                model: {
                    ToplevelManager.toplevels.values;
                    root.appData;
                    return root.collectGroupedToplevels();
                }

                Rectangle {
                    implicitWidth: Theme.spacingS + windowTitle.implicitWidth + Theme.spacingXS + closeButton.width + Theme.spacingXS
                    width: parent.width
                    height: 28
                    radius: Theme.cornerRadius
                    color: windowArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)

                    StyledText {
                        id: windowTitle
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: closeButton.left
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        text: (modelData && modelData.title) ? modelData.title : I18n.tr("(Unnamed)")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }

                    Rectangle {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 10
                        color: closeMouseArea.containsMouse ? Theme.errorPressed : Theme.withAlpha(Theme.errorPressed, 0)

                        DankIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 12
                            color: closeMouseArea.containsMouse ? Theme.error : Theme.surfaceText
                        }

                        MouseArea {
                            id: closeMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.closeToplevel(modelData);
                                root.close();
                            }
                        }
                    }

                    DankRipple {
                        id: windowRipple
                        rippleColor: Theme.surfaceText
                        cornerRadius: Theme.cornerRadius
                    }

                    MouseArea {
                        id: windowArea
                        anchors.fill: parent
                        anchors.rightMargin: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => windowRipple.trigger(mouse.x, mouse.y)
                        onClicked: {
                            if (modelData && modelData.activate) {
                                modelData.activate();
                            }
                            root.close();
                        }
                    }
                }
            }

            Rectangle {
                visible: {
                    if (!root.appData)
                        return false;
                    if (root.appData.type !== "grouped")
                        return false;
                    return root.appData.windowCount > 0;
                }
                width: parent.width
                height: 1
                color: Theme.outlineHeavy
            }

            Repeater {
                model: root.desktopEntry && root.desktopEntry.actions ? root.desktopEntry.actions : []

                Rectangle {
                    implicitWidth: Theme.spacingS * 2 + (actionIcon.visible ? actionIcon.width + Theme.spacingXS : 0) + actionLabel.implicitWidth
                    width: parent.width
                    height: 28
                    radius: Theme.cornerRadius
                    color: actionArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)

                    Item {
                        id: actionIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        visible: modelData.icon && modelData.icon !== ""

                        IconImage {
                            anchors.fill: parent
                            source: modelData.icon ? Paths.resolveIconPath(modelData.icon) : ""
                            smooth: true
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                    }

                    StyledText {
                        id: actionLabel
                        anchors.left: actionIcon.visible ? actionIcon.right : parent.left
                        anchors.leftMargin: actionIcon.visible ? Theme.spacingXS : Theme.spacingS
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name || ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }

                    DankRipple {
                        id: actionRipple
                        rippleColor: Theme.surfaceText
                        cornerRadius: Theme.cornerRadius
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => actionRipple.trigger(mouse.x, mouse.y)
                        onClicked: {
                            if (modelData) {
                                SessionService.launchDesktopAction(root.desktopEntry, modelData);
                            }
                            root.close();
                        }
                    }
                }
            }

            Rectangle {
                visible: {
                    if (!root.desktopEntry?.actions || root.desktopEntry.actions.length === 0) {
                        return false;
                    }
                    return !root.hidePin || (!root.isDmsWindow && root.desktopEntry && SessionService.nvidiaCommand);
                }
                width: parent.width
                height: 1
                color: Theme.outlineHeavy
            }

            Rectangle {
                visible: !root.hidePin
                implicitWidth: Theme.spacingS * 2 + pinLabel.implicitWidth
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: pinArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)

                StyledText {
                    id: pinLabel
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.appData && root.appData.isPinned ? I18n.tr("Unpin from Dock") : I18n.tr("Pin to Dock")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                DankRipple {
                    id: pinRipple
                    rippleColor: Theme.surfaceText
                    cornerRadius: Theme.cornerRadius
                }

                MouseArea {
                    id: pinArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => pinRipple.trigger(mouse.x, mouse.y)
                    onClicked: {
                        if (!root.appData) {
                            return;
                        }
                        if (root.appData.isPinned) {
                            SessionData.removeBarPinnedApp(root.appData.appId);
                        } else {
                            SessionData.addBarPinnedApp(root.appData.appId);
                        }
                        root.close();
                    }
                }
            }

            Rectangle {
                visible: {
                    const hasNvidia = !root.isDmsWindow && root.desktopEntry && SessionService.nvidiaCommand;
                    const hasWindow = root.hasCloseItems;
                    const hasPinOption = !root.hidePin;
                    const hasContentAbove = hasPinOption || hasNvidia;
                    return hasContentAbove && hasWindow;
                }
                width: parent.width
                height: 1
                color: Theme.outlineHeavy
            }

            Rectangle {
                visible: !root.isDmsWindow && root.desktopEntry && SessionService.nvidiaCommand
                implicitWidth: Theme.spacingS * 2 + nvidiaLabel.implicitWidth
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: nvidiaArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)

                StyledText {
                    id: nvidiaLabel
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Launch on dGPU")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                DankRipple {
                    id: nvidiaRipple
                    rippleColor: Theme.surfaceText
                    cornerRadius: Theme.cornerRadius
                }

                MouseArea {
                    id: nvidiaArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => nvidiaRipple.trigger(mouse.x, mouse.y)
                    onClicked: {
                        if (root.desktopEntry) {
                            SessionService.launchDesktopEntry(root.desktopEntry, true);
                        }
                        root.close();
                    }
                }
            }

            Repeater {
                model: {
                    const items = [];
                    if (root.showCloseWindowItem)
                        items.push({
                                       "key": "close-window",
                                       "closeAll": false,
                                       "label": I18n.tr("Close Window")
                                   });
                    if (root.showCloseAllItem)
                        items.push({
                                       "key": "close-all",
                                       "closeAll": true,
                                       "label": I18n.tr("Close All Windows")
                                   });
                    return items;
                }

                Rectangle {
                    implicitWidth: Theme.spacingS * 2 + closeLabel.implicitWidth
                    width: parent.width
                    height: 28
                    radius: Theme.cornerRadius
                    color: closeArea.containsMouse ? Theme.errorHover : Theme.withAlpha(Theme.errorHover, 0)

                    StyledText {
                        id: closeLabel
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.pixelSize: Theme.fontSizeSmall
                        color: closeArea.containsMouse ? Theme.error : Theme.surfaceText
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }

                    DankRipple {
                        id: closeRipple
                        rippleColor: Theme.error
                        cornerRadius: Theme.cornerRadius
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => closeRipple.trigger(mouse.x, mouse.y)
                        onClicked: {
                            if (modelData.closeAll)
                                root.closeGroupedWindows();
                            else
                                root.closeToplevel(root.appData?.toplevel, root.appData?.address);
                            root.close();
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.close()
    }
}

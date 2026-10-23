import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.DCommon.Widgets
import qs.Modals.DLauncherV2
import qs.Modules.ControlCenter
import qs.Services
import qs.Widgets

DPopout {
    id: appDrawerPopout

    layerNamespace: "dms:app-launcher"

    property string _pendingMode: ""
    property string _pendingQuery: ""
    property bool _powerMenuOwned: false
    readonly property bool powerMenuOpen: PopoutService.powerMenuModalLoader?.item?.shouldBeVisible ?? false

    backgroundInteractive: !powerMenuOpen
    hoverDismissSuspended: powerMenuOpen
    customKeyboardFocus: powerMenuOpen ? WlrKeyboardFocus.None : null

    function show() {
        open();
    }

    function openPowerMenuHere() {
        const loader = PopoutService.powerMenuModalLoader;
        if (!loader)
            return;
        loader.active = true;
        if (!loader.item)
            return;
        const bounds = Qt.rect(alignedX, alignedY, popupWidth, popupHeight);
        _powerMenuOwned = true;
        loader.item.openFromControlCenter(bounds, screen);
    }

    function _closeIfPowerMenuOwned() {
        if (!_powerMenuOwned)
            return;
        _powerMenuOwned = false;
        close();
    }

    function openWithMode(mode) {
        _pendingMode = mode || "";
        open();
    }

    function toggleWithMode(mode) {
        if (shouldBeVisible) {
            close();
            return;
        }
        openWithMode(mode);
    }

    function openWithQuery(query) {
        _pendingQuery = query || "";
        open();
    }

    function toggleWithQuery(query) {
        if (shouldBeVisible) {
            close();
            return;
        }
        openWithQuery(query);
    }

    popupWidth: 560
    popupHeight: 696
    triggerWidth: 40
    positioning: ""
    contentHandlesKeys: contentLoader.item?.launcherContent?.editMode ?? false

    onBackgroundClicked: {
        if (contentLoader.item?.launcherContent?.editMode) {
            contentLoader.item.launcherContent.closeEditMode();
            return;
        }
        close();
    }

    onOpened: {
        var lc = contentLoader.item?.launcherContent;
        if (!lc)
            return;

        const query = _pendingQuery;
        const mode = _pendingMode || SessionData.appDrawerLastMode || "apps";
        _pendingMode = "";
        _pendingQuery = "";

        if (lc.searchField) {
            lc.searchField.text = query;
            lc.searchField.forceActiveFocus();
        }
        if (lc.controller) {
            lc.controller.explicitQuerySession = !!query;
            lc.controller.searchMode = mode;
            lc.controller.pluginFilter = "";
            lc.controller.searchQuery = "";
            if (query) {
                lc.controller.setSearchQuery(query);
            } else {
                lc.controller.performSearch();
            }
        }
        lc.resetScroll?.();
        lc.actionPanel?.hide();
    }

    Connections {
        target: contentLoader.item?.launcherContent?.controller ?? null
        function onModeChanged(mode) {
            if (contentLoader.item.launcherContent.controller.autoSwitchedToFiles)
                return;
            SessionData.setAppDrawerLastMode(mode);
        }
    }

    Connections {
        target: PopoutService.powerMenuModalLoader?.item ?? null
        function onPowerActionRequested(action, title, message) {
            appDrawerPopout._closeIfPowerMenuOwned();
        }
        function onLockRequested() {
            appDrawerPopout._closeIfPowerMenuOwned();
        }
        function onDialogClosed() {
            Qt.callLater(() => appDrawerPopout._powerMenuOwned = false);
        }
    }

    content: Component {
        Rectangle {
            id: contentContainer

            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            property alias launcherContent: launcherContent

            color: "transparent"

            QtObject {
                id: modalAdapter
                property bool spotlightOpen: appDrawerPopout.shouldBeVisible
                property bool isClosing: appDrawerPopout.isClosing
                readonly property var effectiveScreen: appDrawerPopout.screen
                readonly property real alignedX: appDrawerPopout.renderedAlignedX
                readonly property real alignedY: appDrawerPopout.renderedAlignedY

                function hide() {
                    appDrawerPopout.close();
                }
            }

            FocusScope {
                anchors.fill: parent
                focus: true

                Item {
                    id: launcherContentContainer
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: win11BottomBar.top
                    clip: true

                    LauncherContent {
                        id: launcherContent
                        anchors.fill: parent
                        parentModal: modalAdapter
                        viewModeContext: "appDrawer"
                        transientSurfaceTracker: appDrawerPopout.transientSurfaceTracker
                    }
                }

                Keys.onEscapePressed: event => {
                    if (appDrawerPopout.powerMenuOpen) {
                        event.accepted = true;
                        return;
                    }
                    if (launcherContent.editMode) {
                        launcherContent.closeEditMode();
                        event.accepted = true;
                        return;
                    }
                    appDrawerPopout.close();
                    event.accepted = true;
                }

                Rectangle {
                    id: win11BottomBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 56
                    bottomLeftRadius: Theme.windowRadius
                    bottomRightRadius: Theme.windowRadius
                    color: "transparent"

                    MouseArea {
                        anchors.fill: parent
                        // Consume clicks in empty footer area so they don't dismiss popout
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.outlineVariant
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingL
                        anchors.right: actionsRow.left
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        height: 40

                        UserIdentity {
                            anchors.fill: parent
                            live: appDrawerPopout.shouldBeVisible
                            avatarSize: 36
                            textGap: Theme.spacingM
                            stacked: false
                            contentColor: Theme.onSurface
                            mutedColor: Theme.onSurfaceVariant
                        }
                    }

                    Row {
                        id: actionsRow
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingL
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DActionButton {
                            width: 44
                            height: 36
                            buttonSize: 36
                            circular: false
                            radius: Theme.cornerRadiusM
                            backgroundColor: CcMetrics.tileInactiveColor
                            border.width: Theme.layerOutlineWidth
                            border.color: Theme.outlineMedium
                            iconName: "settings"
                            iconSize: Theme.iconSizeMedium
                            iconColor: CcMetrics.tileInactiveIcon
                            tooltipText: I18n.tr("Settings")
                            tooltipSide: "top"
                            onClicked: {
                                appDrawerPopout.close();
                                PopoutService.openSettings();
                            }
                        }

                        DActionButton {
                            width: 44
                            height: 36
                            buttonSize: 36
                            circular: false
                            radius: Theme.cornerRadiusM
                            backgroundColor: CcMetrics.tileInactiveColor
                            border.width: Theme.layerOutlineWidth
                            border.color: Theme.outlineMedium
                            iconName: "power_settings_new"
                            iconSize: Theme.iconSizeMedium
                            iconColor: Theme.error
                            tooltipText: I18n.tr("Power")
                            tooltipSide: "top"
                            onClicked: appDrawerPopout.openPowerMenuHere()
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                topLeftRadius: appDrawerPopout.surfaceCornerRadii.x
                topRightRadius: appDrawerPopout.surfaceCornerRadii.y
                bottomRightRadius: appDrawerPopout.surfaceCornerRadii.z
                bottomLeftRadius: appDrawerPopout.surfaceCornerRadii.w
                color: Qt.rgba(0, 0, 0, Theme.scrimAlpha)
                opacity: appDrawerPopout.powerMenuOpen ? 1 : 0
                visible: opacity > 0
                z: CcMetrics.overlayZ

                Behavior on opacity {
                    enabled: CcMetrics.animationsEnabled
                    NumberAnimation {
                        duration: CcMetrics.fadeDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                    }
                }
            }
        }
    }
}

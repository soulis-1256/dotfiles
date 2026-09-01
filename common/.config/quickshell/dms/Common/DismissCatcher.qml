pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

// Other-monitor input surfaces so click-outside can dismiss when the
// compositor would otherwise see no surface (empty wallpaper). Origin
// screens keep their existing same-monitor catcher / fullscreen hole.
Singleton {
    id: root

    property bool active: false
    property var occupiedScreenNames: []
    property bool _dismissing: false

    function isOccupied(screenName) {
        if (!screenName)
            return false;
        return occupiedScreenNames.indexOf(screenName) !== -1;
    }

    function dismiss() {
        if (_dismissing)
            return;
        _dismissing = true;
        ModalManager.closeAllModalsExcept(null);
        PopoutManager.closeAllPopouts();
        TrayMenuManager.closeAllMenus();
        _dismissing = false;
    }

    function _refresh() {
        const occupied = [];
        let dismissible = false;

        const modals = ModalManager.currentModalsByScreen || {};
        for (const screenName in modals) {
            const modal = modals[screenName];
            if (!_isPresentedModal(modal))
                continue;
            if (screenName && screenName !== "unknown" && occupied.indexOf(screenName) === -1)
                occupied.push(screenName);
            if (_isDismissibleModal(modal))
                dismissible = true;
        }

        const popouts = PopoutManager.currentPopoutsByScreen || {};
        for (const screenName in popouts) {
            const popout = popouts[screenName];
            if (!_isPresentedPopout(popout))
                continue;
            if (screenName && screenName !== "unknown" && occupied.indexOf(screenName) === -1)
                occupied.push(screenName);
            dismissible = true;
        }

        occupiedScreenNames = occupied;
        active = dismissible && Quickshell.screens.length > 1;
    }

    function _isPresentedModal(modal) {
        if (!modal)
            return false;
        try {
            return !!(modal.shouldBeVisible || modal.spotlightOpen || modal.isClosing);
        } catch (e) {
            return false;
        }
    }

    function _isDismissibleModal(modal) {
        if (!_isPresentedModal(modal))
            return false;
        try {
            if (modal.closeOnBackgroundClick === false)
                return false;
        } catch (e) {}
        return true;
    }

    function _isPresentedPopout(popout) {
        if (!popout)
            return false;
        try {
            if (popout.dashVisible)
                return true;
            if (popout.notificationHistoryVisible)
                return true;
            return !!(popout.shouldBeVisible || popout.isClosing);
        } catch (e) {
            return false;
        }
    }

    Connections {
        target: ModalManager
        function onModalChanged() {
            root._refresh();
        }
        function onCloseAllModalsExcept(excludedModal) {
            Qt.callLater(() => root._refresh());
        }
    }

    Connections {
        target: PopoutManager
        function onPopoutChanged() {
            root._refresh();
        }
        function onPopoutOpening() {
            root._refresh();
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root._refresh();
        }
    }
}

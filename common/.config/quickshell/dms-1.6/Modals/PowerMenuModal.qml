import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Modules.PowerMenu

DankModal {
    id: root

    layerNamespace: "dms:power-menu"
    keepPopoutsOpen: true
    useOverlayLayer: true

    property rect parentBounds: Qt.rect(0, 0, 0, 0)
    property var parentScreen: null

    signal powerActionRequested(string action, string title, string message)
    signal lockRequested
    signal switchUserRequested

    function openCentered() {
        parentBounds = Qt.rect(0, 0, 0, 0);
        parentScreen = null;
        open();
    }

    function openFromControlCenter(bounds, targetScreen) {
        parentBounds = bounds;
        parentScreen = targetScreen;
        open();
    }

    shouldBeVisible: false
    modalWidth: contentLoader.item?.desiredWidth ?? 400
    modalHeight: contentLoader.item ? contentLoader.item.implicitHeight : 300
    enableShadow: true
    targetScreen: parentScreen
    positioning: "custom"
    customPosition: {
        const scr = parentScreen ?? (effectiveScreen ?? null);
        const screenW = scr?.width ?? 1920;
        const screenH = scr?.height ?? 1080;
        const margin = Theme.spacingL;
        const bar = SettingsData.getPrimaryBarConfig();
        const barPosition = bar?.position ?? SettingsData.Position.Top;
        const effectiveBarThickness = Theme.barThickness(bar?.innerPadding ?? 4, CompositorService.getScreenScale(scr));
        const barExclusionZone = effectiveBarThickness + (bar?.spacing ?? 4) + (bar?.bottomGap ?? 0);
        const topChrome = Math.max(bar && barPosition === SettingsData.Position.Top ? barExclusionZone : 0, SettingsData.dankIslandEdgeOffset(scr, "top"));
        const bottomChrome = Math.max(bar && barPosition === SettingsData.Position.Bottom ? barExclusionZone : 0, SettingsData.dankIslandEdgeOffset(scr, "bottom"));
        const leftChrome = Math.max(bar && barPosition === SettingsData.Position.Left ? barExclusionZone : 0, SettingsData.dankIslandEdgeOffset(scr, "left"));
        const rightChrome = Math.max(bar && barPosition === SettingsData.Position.Right ? barExclusionZone : 0, SettingsData.dankIslandEdgeOffset(scr, "right"));
        const barEdge = barPosition === SettingsData.Position.Bottom ? "bottom" : (barPosition === SettingsData.Position.Left ? "left" : (barPosition === SettingsData.Position.Right ? "right" : "top"));

        let targetX = 0;
        let targetY = 0;

        if (parentBounds.width > 0) {
            targetX = parentBounds.x + (parentBounds.width - modalWidth) / 2;
            if (barEdge === "bottom")
                targetY = screenH - modalHeight - bottomChrome - margin;
            else if (barEdge === "top")
                targetY = topChrome + margin;
            else
                targetY = parentBounds.y + (parentBounds.height - modalHeight) / 2;
        } else if (barEdge === "left") {
            targetX = leftChrome + margin;
            targetY = (screenH - modalHeight) / 2;
        } else if (barEdge === "right") {
            targetX = screenW - modalWidth - rightChrome - margin;
            targetY = (screenH - modalHeight) / 2;
        } else if (barEdge === "bottom") {
            targetX = (screenW - modalWidth) / 2;
            targetY = screenH - modalHeight - bottomChrome - margin;
        } else {
            targetX = (screenW - modalWidth) / 2;
            targetY = topChrome + margin;
        }

        const minY = topChrome + margin;
        const maxY = screenH - modalHeight - bottomChrome - margin;
        const minX = leftChrome + margin;
        const maxX = screenW - modalWidth - rightChrome - margin;
        targetX = Math.max(minX, Math.min(maxX, targetX));
        targetY = Math.max(minY, Math.min(maxY, targetY));
        return Qt.point(targetX, targetY);
    }
    onBackgroundClicked: () => {
        contentLoader.item?.cancelHold();
        close();
    }
    onShouldBeVisibleChanged: {
        if (!shouldBeVisible)
            return;
        contentLoader.item?.resetState();
    }
    onShouldHaveFocusChanged: {
        if (!shouldHaveFocus)
            return;
        Qt.callLater(() => contentLoader.item?.forceActiveFocus());
    }
    onDialogClosed: () => {
        contentLoader.item?.cancelHold();
    }

    content: Component {
        PowerMenuContent {
            anchors.fill: parent
            focus: true
            onPowerActionRequested: action => root.powerActionRequested(action, "", "")
            onLockRequested: root.lockRequested()
            onSwitchUserRequested: root.switchUserRequested()
            onCloseRequested: root.close()
        }
    }
}

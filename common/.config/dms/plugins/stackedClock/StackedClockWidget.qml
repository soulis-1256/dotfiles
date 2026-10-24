import QtQuick
import Quickshell
import qs.Common
import qs.Modules.DBar
import qs.Modules.DBar.Widgets
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

PluginComponent {
    id: root

    layerNamespacePlugin: "stacked-clock"

    property var popoutService: null
    property var widgetData: null

    readonly property bool showNotificationBadge: SettingsData.widgetOption("clock", widgetData, "clockNotificationBadge")
    readonly property int notificationCount: surfaceContext?.notificationCount ?? (NotificationService.notifications ? NotificationService.notifications.length : 0)

    readonly property color contentColor: Theme.widgetTextColor
    readonly property color dateColor: contentColor

    property var locale: I18n.locale()

    SystemClock {
        id: systemClock
        enabled: root.surfaceLive
        precision: SettingsData.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Connections {
        target: SessionService
        function onSessionResumed() {
            systemClock.enabled = false;
            systemClock.enabled = Qt.binding(() => root.surfaceLive);
        }
    }

    property date date: systemClock.date

    readonly property string timeText: date ? date.toLocaleTimeString(locale, SettingsData.getEffectiveTimeFormat()) : ""
    readonly property string dateText: date ? date.toLocaleDateString(locale, SettingsData.getEffectiveDateFormat()) : ""

    readonly property string displayMode: SettingsData.widgetOption("clock", widgetData, "clockCompactMode") ? "time" : "both"
    readonly property bool showTime: displayMode !== "date"
    readonly property bool showDate: displayMode !== "time"

    readonly property int baseFontSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
    readonly property int timeFontSize: Math.max(10, Math.round(baseFontSize * 1.0))
    readonly property int dateFontSize: Math.max(9, Math.round(baseFontSize * 0.9))

    property bool _pendingOpen: false
    property var _pendingPos: null

    Component.onCompleted: {
        if (PopoutService.dankDashPopoutLoader && !PopoutService.dankDashPopoutLoader.active) {
            PopoutService.dankDashPopoutLoader.active = true;
        }
    }

    Connections {
        target: PopoutService
        function onDankDashPopoutLoaderChanged() {
            if (PopoutService.dankDashPopoutLoader && !PopoutService.dankDashPopoutLoader.active) {
                PopoutService.dankDashPopoutLoader.active = true;
            }
        }
        function onDankDashPopoutChanged() {
            if (root._pendingOpen && PopoutService.dankDashPopout) {
                root._pendingOpen = false;
                const pos = root._pendingPos || {};
                root.openClockPopout(pos.x, pos.y, pos.width, pos.section, pos.screen);
            }
        }
    }

    function openClockPopout(x, y, width, section, screen) {
        const loader = PopoutService.dankDashPopoutLoader;
        if (!loader)
            return;

        if (!loader.active) {
            loader.active = true;
        }

        const popout = loader.item || PopoutService.dankDashPopout;
        if (!popout) {
            root._pendingOpen = true;
            root._pendingPos = {
                x: x,
                y: y,
                width: width,
                section: section,
                screen: screen
            };
            return;
        }

        const currentScreen = screen || root.parentScreen;
        const effectiveBarConfig = root.barConfig;
        const barPos = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
        const bottomGap = effectiveBarConfig?.bottomGap ?? 0;
        const barThickness = root.barThickness;
        const barSpacing = root.barSpacing ?? 4;
        const triggerSection = section || root.section || "center";
        const triggerSource = (effectiveBarConfig?.id ?? "default") + "-" + triggerSection + "-overview";

        if (popout.setBarContext) {
            popout.setBarContext(barPos, bottomGap);
        }

        popout.triggerScreen = currentScreen;

        if (popout.setTriggerPosition) {
            popout.setTriggerPosition(
                x,
                y,
                width,
                triggerSection,
                currentScreen,
                barPos,
                barThickness,
                barSpacing,
                effectiveBarConfig,
                root
            );
        }

        if (typeof popout.prepareForTrigger === "function") {
            popout.prepareForTrigger(triggerSource, "click");
        }

        if (typeof popout.requestTab === "function") {
            popout.requestTab("overview");
        }

        PopoutManager.requestPopout(popout, undefined, triggerSource);
    }

    pillClickAction: (x, y, width, section, screen) => {
        root.openClockPopout(x, y, width, section, screen);
    }

    pillRightClickAction: (x, y, width, section, screen) => {
        popoutService?.toggleNotificationCenter(x, y, width, section, screen);
    }

    horizontalBarPill: Component {
        Item {
            id: contentRoot

            implicitWidth: clockRow.implicitWidth
            implicitHeight: root.widgetThickness

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Column {
                    id: clockCol
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.ceil(Math.max(timeItem.reservedWidth, root.showDate ? dateItem.reservedWidth : 0))
                    spacing: 0

                    NumericText {
                        id: timeItem
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.timeText
                        reserveText: text.replace(/\d/g, "0")
                        width: Math.ceil(reservedWidth)
                        horizontalAlignment: Text.AlignHCenter
                        isMonospace: false
                        color: root.contentColor
                        font.pixelSize: root.timeFontSize
                        font.weight: Theme.fontWeightMedium
                    }

                    NumericText {
                        id: dateItem
                        visible: root.showDate
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.dateText
                        reserveText: text.replace(/\d/g, "0")
                        width: Math.ceil(reservedWidth)
                        horizontalAlignment: Text.AlignHCenter
                        isMonospace: false
                        color: root.dateColor
                        font.pixelSize: root.dateFontSize
                    }
                }

                Rectangle {
                    visible: root.showNotificationBadge && root.notificationCount > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(height, badgeText.implicitWidth + Theme.spacingXS * 2)
                    height: badgeText.implicitHeight + Theme.spacingXXS * 2
                    radius: Theme.fullRadius(width, height)
                    color: Theme.error

                    StyledText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: root.notificationCount
                        font.pixelSize: Math.round(root.dateFontSize * 0.85)
                        font.weight: Theme.fontWeightMedium
                        color: Theme.onError
                    }
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            id: vContentRoot

            implicitWidth: root.widgetThickness
            implicitHeight: vLayout.implicitHeight

            Column {
                id: vLayout
                anchors.centerIn: parent
                spacing: Theme.spacingXXS

                ClockContent {
                    id: vClock
                    vertical: true
                    segmented: false
                    displayMode: root.displayMode
                    fontSize: root.baseFontSize
                    availableWidth: root.widgetThickness
                    textColor: root.contentColor
                    dateColor: Theme.primary
                }

                Rectangle {
                    visible: root.showNotificationBadge && root.notificationCount > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(height, vBadgeText.implicitWidth + Theme.spacingXS * 2)
                    height: vBadgeText.implicitHeight + Theme.spacingXXS * 2
                    radius: Theme.fullRadius(width, height)
                    color: Theme.error

                    StyledText {
                        id: vBadgeText
                        anchors.centerIn: parent
                        text: root.notificationCount
                        font.pixelSize: Math.round(root.baseFontSize * 0.75)
                        font.weight: Theme.fontWeightMedium
                        color: Theme.onError
                    }
                }
            }
        }
    }
}

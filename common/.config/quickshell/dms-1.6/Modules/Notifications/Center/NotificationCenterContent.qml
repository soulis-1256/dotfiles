pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankDash.Overview
import qs.Services

Item {
    id: root

    required property var host
    property var externalKeyboardController: null
    property real cachedHeaderHeight: 32
    readonly property bool showCalendar: SettingsData.notificationCenterShowCalendar
    readonly property real calendarBlockHeight: showCalendar ? 280 : 0
    readonly property int bodySpacingCount: showCalendar ? 2 : 1

    readonly property alias notificationList: notificationList
    readonly property alias notificationHeader: notificationHeader
    readonly property int currentTab: notificationHeader.currentTab
    readonly property bool hostOwnsHeight: root.host.hostOwnsHeight ?? false

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property real maxContentHeight: {
        const requested = root.host.maxContentHeight ?? 0;
        if (requested > 0)
            return requested;
        return (root.host.screen?.height ?? 1080) * 0.8;
    }

    readonly property real targetImplicitHeight: {
        let baseHeight = Theme.spacingL * 2;
        baseHeight += cachedHeaderHeight;
        baseHeight += Theme.spacingM * bodySpacingCount;

        let listHeight = 200;
        if (notificationHeader.currentTab === 0) {
            if (NotificationService.groupedNotifications.length === 0) {
                listHeight = 200;
            } else if (root.hostOwnsHeight) {
                const est = notificationList.sessionContentHeight > 0 ? notificationList.sessionContentHeight : notificationList.estimateContentHeight(NotificationService.groupedNotifications.length);
                listHeight = Math.max(200, est);
            } else {
                const actual = root.host.shouldBeVisible ? notificationList.stableContentHeight : notificationList.listContentHeight;
                listHeight = Math.max(200, actual);
            }
        } else if (NotificationService.historyList.length > 0) {
            listHeight = Math.max(200, NotificationService.historyList.length * 80);
        }

        if (!root.hostOwnsHeight)
            listHeight = Math.min(listHeight, showCalendar ? 360 : 600);

        baseHeight += listHeight;
        baseHeight += calendarBlockHeight;
        return Math.max(300, Math.min(baseHeight, maxContentHeight));
    }

    implicitHeight: root.hostOwnsHeight ? height : targetImplicitHeight

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            root.host.close();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Left) {
            if (notificationHeader.currentTab > 0) {
                notificationHeader.currentTab = 0;
                event.accepted = true;
            }
            return;
        }

        if (event.key === Qt.Key_Right) {
            if (notificationHeader.currentTab === 0 && SettingsData.notificationHistoryEnabled) {
                notificationHeader.currentTab = 1;
                event.accepted = true;
            }
            return;
        }

        if (notificationHeader.currentTab === 1) {
            historyList.handleKey(event);
            return;
        }

        if (root.externalKeyboardController)
            root.externalKeyboardController.handleKey(event);
    }

    FocusScope {
        id: contentColumn

        anchors.fill: parent
        anchors.margins: Theme.spacingL
        focus: true

        Column {
            id: contentColumnInner

            anchors.fill: parent
            spacing: Theme.spacingM

            NotificationHeader {
                id: notificationHeader

                objectName: "notificationHeader"
                transientSurfaceTracker: root.host.transientSurfaceTracker ?? null
                tapToClose: root.host.headerTogglesClose ?? false
                onHeaderTapped: root.host.close()
                onHeightChanged: root.cachedHeaderHeight = height
                onSettingsRequested: {
                    if (typeof root.host.requestSettings === "function")
                        root.host.requestSettings();
                }
            }

            Item {
                visible: notificationHeader.currentTab === 0
                width: parent.width
                height: parent.height - root.cachedHeaderHeight - root.calendarBlockHeight - contentColumnInner.spacing * root.bodySpacingCount

                KeyboardNavigatedNotificationList {
                    id: notificationList

                    objectName: "notificationList"
                    anchors.fill: parent
                    anchors.leftMargin: -shadowHorizontalGutter
                    anchors.rightMargin: -shadowHorizontalGutter
                    anchors.topMargin: -(shadowVerticalGutter + delegateShadowGutter / 2)
                    anchors.bottomMargin: -(shadowVerticalGutter + delegateShadowGutter / 2)
                    cardAnimateExpansion: root.host.animateCardExpansion ?? true
                    trackStableContentHeight: !root.hostOwnsHeight
                    trackSessionContentHeight: root.hostOwnsHeight
                    lightweightCards: root.host.lightweightNotifications ?? false
                    transientSurfaceTracker: root.host.transientSurfaceTracker ?? null
                }
            }

            HistoryNotificationList {
                id: historyList

                visible: notificationHeader.currentTab === 1
                width: parent.width
                height: parent.height - root.cachedHeaderHeight - root.calendarBlockHeight - contentColumnInner.spacing * root.bodySpacingCount
            }

            CalendarOverviewCard {
                visible: root.showCalendar
                width: parent.width
                height: root.calendarBlockHeight
                compactEmbed: true
                onCloseDash: root.host.close()
            }
        }
    }

    NotificationKeyboardHints {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingL
        showHints: notificationHeader.currentTab === 0 ? (root.externalKeyboardController?.showKeyboardHints ?? false) : historyList.showKeyboardHints
        z: 200
    }
}

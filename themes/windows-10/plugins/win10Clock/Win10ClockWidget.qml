import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    property var popoutService: null

    layerNamespacePlugin: "win10-clock"

    pillClickAction: (x, y, w, s, scr, barPosition, barTh, barSp, cfg) => {
        popoutService?.toggleNotificationCenter(x, y, w, s, scr || parentScreen, barPosition, barTh, barSp, cfg);
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: clockCol.implicitWidth + 12
            implicitHeight: root.barThickness

            SystemClock {
                id: systemClock

                precision: SettingsData.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
            }

            Column {
                id: clockCol

                spacing: 0
                anchors.centerIn: parent

                StyledText {
                    text: {
                        const d = systemClock.date;
                        if (!d)
                            return "";

                        if (SettingsData.use24HourClock)
                            return Qt.formatTime(d, SettingsData.showSeconds ? "HH:mm:ss" : "HH:mm");

                        return Qt.formatTime(d, SettingsData.showSeconds ? "h:mm:ss AP" : "h:mm AP");
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : 1, root.barConfig ? root.barConfig.maximizeWidgetText : false)
                    color: Theme.widgetTextColor
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        const d = systemClock.date;
                        if (!d)
                            return "";

                        if (SettingsData.clockDateFormat && SettingsData.clockDateFormat.length > 0)
                            return d.toLocaleDateString(Qt.locale(), SettingsData.clockDateFormat);

                        return d.toLocaleDateString(Qt.locale(), "ddd d MMM yyyy");
                    }
                    font.pixelSize: Math.max(10, Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : 1, root.barConfig ? root.barConfig.maximizeWidgetText : false) - 2)
                    color: Theme.widgetTextColor
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

            }

            Rectangle {
                visible: NotificationService.notifications.length > 0
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.top: parent.top
                anchors.topMargin: 6
                width: Math.max(16, badgeLabel.implicitWidth + 8)
                height: 16
                color: Theme.primary

                StyledText {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: NotificationService.notifications.length > 9 ? "9+" : String(NotificationService.notifications.length)
                    color: Theme.primaryText
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }

        }

    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.barThickness
            implicitHeight: vCol.implicitHeight + 16

            SystemClock {
                id: vClock

                precision: SystemClock.Minutes
            }

            Column {
                id: vCol

                spacing: 0
                anchors.centerIn: parent

                StyledText {
                    text: vClock.date ? Qt.formatTime(vClock.date, SettingsData.use24HourClock ? "HH:mm" : "h:mm") : ""
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : 1, root.barConfig ? root.barConfig.maximizeWidgetText : false)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: vClock.date ? Qt.formatDate(vClock.date, "dd/MM") : ""
                    font.pixelSize: Math.max(10, Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : 1, root.barConfig ? root.barConfig.maximizeWidgetText : false) - 2)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

            }

        }

    }

}

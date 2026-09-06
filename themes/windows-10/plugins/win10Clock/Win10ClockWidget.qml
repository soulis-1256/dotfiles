import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    layerNamespacePlugin: "win10-clock"
    popoutWidth: 340
    popoutHeight: 430
    popoutFlush: true

    horizontalBarPill: Component {
        Item {
            implicitWidth: clockCol.implicitWidth + 24
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

    popoutContent: Component {
        CalendarFlyout {
        }

    }

}

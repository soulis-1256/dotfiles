import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

PluginComponent {
    id: root

    layerNamespacePlugin: "custom-weather"

    Component.onCompleted: {
        WeatherService.addRef();
    }
    Component.onDestruction: {
        WeatherService.removeRef();
    }

    pillClickAction: (x, y, width, section, screen) => {
        PopoutService?.toggleDankDash("weather", x, y, width, section, screen);
    }

    horizontalBarPill: Component {
        Item {
            id: hContent
            implicitWidth: SettingsData.weatherEnabled ? weatherRow.implicitWidth : 0
            implicitHeight: root.widgetThickness
            visible: SettingsData.weatherEnabled

            Row {
                id: weatherRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                WeatherIcon {
                    code: WeatherService.weather.wCode
                    isDay: WeatherService.weather.isDay
                    size: Theme.barIconSize(root.barThickness, -2, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    anchors.verticalCenter: parent.verticalCenter
                }

                NumericText {
                    isMonospace: false
                    text: WeatherService.currentTempText(false)
                    reserveText: text.replace(/\d/g, "0")
                    width: Math.ceil(Math.max(implicitWidth, reservedWidth))
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            id: vContent
            implicitWidth: root.widgetThickness
            implicitHeight: SettingsData.weatherEnabled ? weatherCol.implicitHeight : 0
            visible: SettingsData.weatherEnabled

            Column {
                id: weatherCol
                anchors.centerIn: parent
                spacing: 1

                WeatherIcon {
                    code: WeatherService.weather.wCode
                    isDay: WeatherService.weather.isDay
                    size: Theme.barIconSize(root.barThickness, -2, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (!WeatherService.weather.available) {
                            return "--";
                        }
                        return SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp;
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}

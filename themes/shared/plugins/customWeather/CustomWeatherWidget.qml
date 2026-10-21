import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

PluginComponent {
    id: root

    layerNamespacePlugin: "custom-weather"

    property bool _pendingOpen: false

    Component.onCompleted: {
        WeatherService.addRef();
    }
    Component.onDestruction: {
        WeatherService.removeRef();
    }

    Connections {
        target: PopoutService.dankDashPopoutLoader ?? null
        function onLoaded() {
            if (root._pendingOpen) {
                root._pendingOpen = false;
                root.openWeatherPopout();
            }
        }
    }

    function openWeatherPopout() {
        const loader = PopoutService.dankDashPopoutLoader;
        if (!loader)
            return;

        loader.active = true;
        const popout = loader.item || PopoutService.dankDashPopout;
        if (!popout) {
            _pendingOpen = true;
            return;
        }

        const anchor = root.pillAnchor();
        if (!anchor)
            return;

        const effectiveBarConfig = root.barConfig;
        const barPos = anchor.position !== undefined ? anchor.position : (effectiveBarConfig?.position ?? (root.isVertical ? 2 : 1));
        const bottomGap = effectiveBarConfig?.bottomGap ?? 0;

        if (popout.setBarContext) {
            popout.setBarContext(barPos, bottomGap);
        }

        popout.triggerScreen = anchor.screen;

        if (popout.setTriggerPosition) {
            popout.setTriggerPosition(
                anchor.trigger.x,
                anchor.trigger.y,
                anchor.trigger.width,
                root.section,
                anchor.screen,
                barPos,
                anchor.thickness,
                anchor.spacing,
                anchor.config,
                root
            );
        }

        if (typeof popout.prepareForTrigger === "function") {
            popout.prepareForTrigger("weather", "click");
        }

        if (typeof popout.requestTab === "function") {
            popout.requestTab("weather");
        }

        PopoutManager.requestPopout(popout, "weather", "weather");
    }

    pillClickAction: () => {
        root.openWeatherPopout();
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

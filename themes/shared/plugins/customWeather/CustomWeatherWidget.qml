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
    property var _pendingPos: null

    Component.onCompleted: {
        WeatherService.addRef();
        if (PopoutService.dankDashPopoutLoader && !PopoutService.dankDashPopoutLoader.active) {
            PopoutService.dankDashPopoutLoader.active = true;
        }
    }
    Component.onDestruction: {
        WeatherService.removeRef();
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
                root.openWeatherPopout(pos.x, pos.y, pos.width, pos.section, pos.screen);
            }
        }
    }

    function openWeatherPopout(x, y, width, section, screen) {
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
        const triggerSource = (effectiveBarConfig?.id ?? "default") + "-" + triggerSection + "-weather";

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
            popout.requestTab("weather");
        }

        PopoutManager.requestPopout(popout, undefined, triggerSource);
    }

    pillClickAction: (x, y, width, section, screen) => {
        root.openWeatherPopout(x, y, width, section, screen);
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

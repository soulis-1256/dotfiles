import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property real barThickness: 48
    property var barConfig: null
    property real sizeOffset: SettingsData.launcherLogoSizeOffset
    property real customSize: 0

    readonly property real effectiveSize: customSize > 0 ? customSize : Theme.barIconSize(barThickness, sizeOffset, barConfig?.maximizeWidgetIcons, barConfig?.iconScale)
    readonly property real appIconSize: customSize > 0 ? customSize : Theme.barIconSize(barThickness, -4, barConfig?.maximizeWidgetIcons, barConfig?.iconScale)

    implicitWidth: effectiveSize
    implicitHeight: effectiveSize

    DankIcon {
        visible: SettingsData.launcherLogoMode === "apps"
        anchors.centerIn: parent
        name: "apps"
        size: root.appIconSize
        color: Theme.widgetIconColor
    }

    SystemLogo {
        visible: SettingsData.launcherLogoMode === "os"
        anchors.centerIn: parent
        width: root.effectiveSize
        height: root.effectiveSize
        colorOverride: Theme.effectiveLogoColor
        brightnessOverride: SettingsData.launcherLogoBrightness
        contrastOverride: SettingsData.launcherLogoContrast
    }

    IconImage {
        visible: SettingsData.launcherLogoMode === "dank"
        anchors.centerIn: parent
        width: root.effectiveSize
        height: root.effectiveSize
        smooth: true
        mipmap: true
        asynchronous: true
        source: "file://" + Theme.shellDir + "/assets/danklogo.svg"
        layer.enabled: Theme.effectiveLogoColor !== ""
        layer.smooth: true
        layer.mipmap: true
        layer.effect: MultiEffect {
            saturation: 0
            colorization: 1
            colorizationColor: Theme.effectiveLogoColor
        }
    }

    IconImage {
        visible: SettingsData.launcherLogoMode === "compositor" && (CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango || CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle || CompositorService.isLabwc)
        anchors.centerIn: parent
        width: root.effectiveSize
        height: root.effectiveSize
        smooth: true
        asynchronous: true
        source: {
            if (CompositorService.isNiri) {
                return "file://" + Theme.shellDir + "/assets/niri.svg";
            } else if (CompositorService.isHyprland) {
                return "file://" + Theme.shellDir + "/assets/hyprland.svg";
            } else if (CompositorService.isMango) {
                return "file://" + Theme.shellDir + "/assets/mango.png";
            } else if (CompositorService.isSway) {
                return "file://" + Theme.shellDir + "/assets/sway.svg";
            } else if (CompositorService.isScroll) {
                return "file://" + Theme.shellDir + "/assets/sway.svg";
            } else if (CompositorService.isMiracle) {
                return "file://" + Theme.shellDir + "/assets/miraclewm.svg";
            } else if (CompositorService.isLabwc) {
                return "file://" + Theme.shellDir + "/assets/labwc.png";
            }
            return "";
        }
        layer.enabled: Theme.effectiveLogoColor !== ""
        layer.effect: MultiEffect {
            saturation: 0
            colorization: 1
            colorizationColor: Theme.effectiveLogoColor
            brightness: SettingsData.launcherLogoBrightness
            contrast: SettingsData.launcherLogoContrast
        }
    }

    IconImage {
        visible: SettingsData.launcherLogoMode === "custom" && SettingsData.launcherLogoCustomPath !== ""
        anchors.centerIn: parent
        width: root.effectiveSize
        height: root.effectiveSize
        smooth: true
        asynchronous: true
        source: SettingsData.launcherLogoCustomPath ? "file://" + SettingsData.launcherLogoCustomPath.replace("file://", "") : ""
        layer.enabled: Theme.effectiveLogoColor !== ""
        layer.effect: MultiEffect {
            saturation: 0
            colorization: 1
            colorizationColor: Theme.effectiveLogoColor
            brightness: SettingsData.launcherLogoBrightness
            contrast: SettingsData.launcherLogoContrast
        }
    }
}

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Row {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var defaultSource: AudioService.source
    property color sliderTrackColor: "transparent"
    property real sliderTrackOpacity: Theme.ccSliderTrackOpacity
    property bool showChevron: true
    property bool isExpanded: false
    signal chevronClicked()

    height: 40
    spacing: Theme.spacingS

    Rectangle {
        id: iconBtn
        width: 36
        height: 36
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.fluent ? Theme.controlCornerRadius : (Theme.iconSize + Theme.spacingS * 2) / 2
        color: Theme.fluent ? (iconArea.pressed ? Theme.withAlpha(Theme.surfaceText, 0.05) : (iconArea.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")) : (iconArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primary, 0))

        DankRipple {
            id: iconRipple
            cornerRadius: parent.radius
        }

        MouseArea {
            id: iconArea
            anchors.fill: parent
            visible: defaultSource !== null
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => {
                if (!Theme.fluent)
                    iconRipple.trigger(mouse.x, mouse.y);
            }
            onClicked: {
                if (defaultSource?.audio) {
                    SessionData.suppressOSDTemporarily();
                    defaultSource.audio.muted = !defaultSource.audio.muted;
                }
            }
        }

        DankIcon {
            anchors.centerIn: parent
            name: {
                if (!defaultSource?.audio)
                    return "mic_off";

                let volume = defaultSource.audio.volume;
                let muted = defaultSource.audio.muted;

                if (muted || volume === 0.0)
                    return "mic_off";
                return "mic";
            }
            size: Theme.iconSize
            color: {
                const audible = defaultSource?.audio && !defaultSource.audio.muted && defaultSource.audio.volume > 0;
                if (Theme.fluent)
                    return audible ? Theme.surfaceText : Theme.surfaceVariantText;
                return audible ? Theme.primary : Theme.surfaceText;
            }
        }
    }

    DankSlider {
        id: micSlider

        readonly property real actualVolumePercent: defaultSource?.audio ? Math.round(defaultSource.audio.volume * 100) : 0

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - iconBtn.width - (root.showChevron ? (chevronBtn.width + parent.spacing) : 0) - parent.spacing
        enabled: defaultSource?.audio != null
        minimum: 0
        maximum: 100
        value: defaultSource?.audio ? Math.min(100, Math.round(defaultSource.audio.volume * 100)) : 0
        showValue: true
        unit: "%"
        valueOverride: actualVolumePercent
        thumbOutlineColor: Theme.surfaceContainer
        trackColor: root.sliderTrackColor.a > 0 ? root.sliderTrackColor : Theme.ccSliderTrackColor
        trackOpacity: root.sliderTrackOpacity
        onSliderValueChanged: function (newValue) {
            if (defaultSource?.audio) {
                SessionData.suppressOSDTemporarily();
                defaultSource.audio.volume = newValue / 100.0;
                if (newValue > 0 && defaultSource.audio.muted) {
                    defaultSource.audio.muted = false;
                }
            }
        }
    }

    Rectangle {
        id: chevronBtn
        visible: root.showChevron
        width: 36
        height: 36
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.controlCornerRadius
        color: chevronArea.pressed ? Theme.withAlpha(Theme.surfaceText, 0.05) : (chevronArea.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")

        DankIcon {
            id: chevronIcon
            anchors.centerIn: parent
            name: I18n.isRtl ? "chevron_left" : "chevron_right"
            size: Theme.iconSize - 6
            color: chevronArea.containsMouse ? Theme.surfaceText : Theme.surfaceVariantText
            rotation: root.isExpanded ? 90 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.variantPopoutEnterCurve
                }
            }
        }

        MouseArea {
            id: chevronArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.chevronClicked()
        }
    }
}

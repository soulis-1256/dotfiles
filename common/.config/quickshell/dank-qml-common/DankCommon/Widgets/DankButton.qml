import QtQuick
import qs.DankCommon.Common
import qs.DankCommon.Widgets

Rectangle {
    id: root

    property string text: ""
    property string iconName: ""
    property int iconSize: Style.iconSizeSmall
    property bool hovered: mouseArea.containsMouse
    property bool pressed: mouseArea.pressed
    readonly property bool fluent: Style.theme?.fluent ?? false
    property color backgroundColor: fluent ? (Style.theme?.fluentControlFill ?? Style.buttonBg) : Style.buttonBg
    property color textColor: fluent ? Style.surfaceText : Style.buttonText
    property int buttonHeight: 40
    property int horizontalPadding: Style.spacingL
    property bool enableScaleAnimation: false
    property bool enableRipple: Style.enableRippleEffects && !fluent

    signal clicked

    width: Math.max(contentRow.implicitWidth + horizontalPadding * 2, 64)
    height: buttonHeight
    radius: Style.cornerRadius
    color: backgroundColor
    border.width: fluent ? 1 : 0
    border.color: fluent ? (Style.theme?.fluentControlStroke ?? Style.outline) : "transparent"
    opacity: enabled ? 1 : 0.4
    scale: (enableScaleAnimation && pressed) ? 0.98 : 1.0
    activeFocusOnTab: enabled

    Keys.onPressed: event => {
        if (!root.enabled)
            return;
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.clicked();
            event.accepted = true;
            break;
        }
    }

    FocusRing {}

    Behavior on scale {
        enabled: enableScaleAnimation && Style.currentAnimationSpeed !== Style.AnimationSpeed.None
        NumberAnimation {
            easing.type: Easing.BezierSpline
            duration: 100
            easing.bezierCurve: Style.expressiveCurves.standard
        }
    }

    Rectangle {
        id: stateLayer
        anchors.fill: parent
        radius: parent.radius
        color: {
            if (root.fluent) {
                if (pressed)
                    return Style.theme?.fluentSubtlePressed ?? Style.withAlpha(root.textColor, 0.04);
                if (hovered)
                    return Style.theme?.fluentSubtleFill ?? Style.withAlpha(root.textColor, 0.06);
                return "transparent";
            }
            if (pressed)
                return Style.withAlpha(root.textColor, 0.20);
            if (hovered)
                return Style.withAlpha(root.textColor, 0.12);
            return Style.withAlpha(root.textColor, 0);
        }

        Behavior on color {
            ColorAnimation {
                duration: Style.shorterDuration
                easing.type: Style.standardEasing
            }
        }
    }

    DankRipple {
        id: rippleLayer
        rippleColor: root.textColor
        cornerRadius: root.radius
        enableRipple: root.enableRipple
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Style.spacingS

        DankIcon {
            name: root.iconName
            size: root.iconSize
            color: root.textColor
            visible: root.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.text
            font.pixelSize: Style.fontSizeMedium
            font.weight: root.fluent ? Font.Normal : Font.Medium
            color: root.textColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        onPressed: mouse => {
            if (root.enableRipple)
                rippleLayer.trigger(mouse.x, mouse.y);
        }
        onClicked: root.clicked()
    }
}

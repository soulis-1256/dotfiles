import QtQuick
import qs.Common

Item {
    id: root

    property string name: ""
    property int size: Math.round(Theme.fontSizeMedium)
    property alias color: icon.color
    property bool filled: false
    property real fill: filled ? 1.0 : 0.0
    property int grade: Theme.isLightMode ? 0 : -25
    property int weight: filled ? 500 : 400
    property bool smoothTransform: false

    implicitWidth: Math.round(size)
    implicitHeight: Math.round(size)

    signal rotationCompleted

    readonly property bool _variable: IconPackService.usesVariableAxes
    readonly property string _glyph: IconPackService.glyph(root.name, root.filled, root.weight)
    readonly property string _family: IconPackService.family(root.filled, root.weight)
    readonly property real _opticalScale: IconPackService.opticalScale(root.name)

    StyledText {
        id: icon

        anchors.fill: parent

        text: root._glyph
        font.family: root._family
        // Slot stays `size`; pixelSize is optically scaled so Phosphor glyphs share a keyline.
        // Floor so rounding cannot push oversized glyphs back up a pixel.
        font.pixelSize: Math.max(1, Math.floor(root.size * root._opticalScale))
        font.weight: root._variable ? root.weight : Font.Normal
        font.hintingPreference: Font.PreferNoHinting
        color: Theme.surfaceText
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.NoWrap
        elide: Text.ElideNone
        renderType: root.smoothTransform ? Text.QtRendering : Text.NativeRendering

        font.variableAxes: root._variable ? ({
                "FILL": root.fill.toFixed(1),
                "GRAD": root.grade,
                "opsz": 24,
                "wght": root.weight
            }) : ({})

        Behavior on font.weight {
            enabled: root._variable
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    Behavior on fill {
        enabled: root._variable
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Timer {
        id: rotationTimer
        interval: 16
        repeat: false
        onTriggered: root.rotationCompleted()
    }

    onRotationChanged: {
        rotationTimer.restart();
    }
}

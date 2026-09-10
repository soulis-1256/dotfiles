import QtQuick
import qs.Widgets

ListView {
    id: root

    property alias stepSize: scroller.stepSize
    property alias snapIncrement: scroller.snapIncrement
    property alias scroller: scroller

    boundsBehavior: Flickable.StopAtBounds

    SmoothScrollHandler {
        id: scroller
    }
}

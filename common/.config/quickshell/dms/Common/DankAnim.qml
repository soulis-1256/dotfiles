import QtQuick
import qs.Common

// Reusable NumberAnimation wrapper
NumberAnimation {
    duration: Theme.expressiveDurations.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.expressiveCurves.standard
}

import QtQuick

Item {
    id: root

    property var flickable: parent
    property real stepSize: 140
    property real minDuration: 180
    property real maxDuration: 300
    property int easingType: Easing.OutCubic
    property real snapIncrement: 0
    property real targetContentY: flickable ? flickable.contentY : 0

    anchors.fill: parent

    function stop() {
        scrollAnim.stop();
        if (flickable)
            targetContentY = flickable.contentY;
    }

    function reset() {
        scrollAnim.stop();
        if (flickable) {
            if (flickable.flicking)
                flickable.cancelFlick();
            const minY = flickable.originY !== undefined ? flickable.originY : 0;
            flickable.contentY = minY;
            targetContentY = minY;
            if (typeof flickable.positionViewAtBeginning === "function")
                flickable.positionViewAtBeginning();
        }
    }

    function jumpTo(pos) {
        scrollAnim.stop();
        if (flickable) {
            flickable.contentY = pos;
            targetContentY = pos;
        }
    }

    NumberAnimation {
        id: scrollAnim
        target: root.flickable
        property: "contentY"
        duration: 220
        easing.type: root.easingType
    }

    Connections {
        target: root.flickable
        function onMovementStarted() { root.stop(); }
        function onFlickStarted() { root.stop(); }
    }

    WheelHandler {
        id: wheelHandler
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (!root.flickable)
                return;

            const pixelY = event.pixelDelta ? event.pixelDelta.y : 0;
            const angleY = event.angleDelta ? event.angleDelta.y : 0;
            if (pixelY === 0 && angleY === 0)
                return;

            if (root.flickable.flicking)
                root.flickable.cancelFlick();

            const minY = root.flickable.originY !== undefined ? root.flickable.originY : 0;
            const maxY = Math.max(minY, root.flickable.contentHeight - root.flickable.height + minY);
            if (maxY <= minY)
                return;

            if (pixelY !== 0) {
                // High-precision touchpad
                scrollAnim.stop();
                const dy = -pixelY * 2.4;
                root.flickable.contentY = Math.max(minY, Math.min(maxY, root.flickable.contentY + dy));
                root.targetContentY = root.flickable.contentY;
            } else {
                // Stepped mouse wheel
                let step = 0;
                if (root.snapIncrement > 0) {
                    step = angleY > 0 ? -root.snapIncrement : root.snapIncrement;
                } else {
                    step = -(angleY / 120) * root.stepSize;
                }
                if (step === 0)
                    return;

                const currentTarget = scrollAnim.running ? root.targetContentY : root.flickable.contentY;
                let newTarget = currentTarget + step;
                if (root.snapIncrement > 0) {
                    newTarget = Math.round((newTarget - minY) / root.snapIncrement) * root.snapIncrement + minY;
                }
                newTarget = Math.max(minY, Math.min(maxY, newTarget));
                root.targetContentY = newTarget;

                scrollAnim.stop();
                scrollAnim.from = root.flickable.contentY;
                scrollAnim.to = newTarget;
                const dist = Math.abs(newTarget - root.flickable.contentY);
                scrollAnim.duration = Math.min(root.maxDuration, Math.max(root.minDuration, dist * (root.snapIncrement > 0 ? 1.2 : 0.8)));
                scrollAnim.start();
            }
            event.accepted = true;
        }
    }
}

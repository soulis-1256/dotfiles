import QtQuick
import QtQuick.Controls
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import "ScrollConstants.js" as Scroll
import "../Common/WheelInput.js" as WheelInput

ListView {
    id: listView

    property real scrollBarTopMargin: 0
    property real mouseWheelSpeed: Scroll.mouseWheelSpeed
    property real savedY: 0
    property bool justChanged: false
    property bool isUserScrolling: false
    property real momentumVelocity: 0
    property bool isMomentumActive: false
    property real friction: Scroll.friction

    flickDeceleration: Scroll.flickDeceleration
    maximumFlickVelocity: Scroll.maximumFlickVelocity
    boundsBehavior: Flickable.StopAtBounds
    boundsMovement: Flickable.FollowBoundsBehavior
    pressDelay: 0
    flickableDirection: Flickable.VerticalFlick

    add: ListViewTransitions.add
    remove: ListViewTransitions.remove
    displaced: ListViewTransitions.displaced
    move: ListViewTransitions.move

    // QQmlDelegateModel can release a delegate back to its cache without hiding it,
    // leaving a stale row painted over live ones. Hide anything the view no longer claims.
    Connections {
        target: listView.model?.objectName !== undefined ? listView.model : null
        ignoreUnknownSignals: true
        function onRowsInserted() {
            orphanSweep.arm();
        }
        function onRowsRemoved() {
            orphanSweep.arm();
        }
        function onRowsMoved() {
            orphanSweep.arm();
        }
        function onModelReset() {
            orphanSweep.arm();
        }
    }

    FrameAnimation {
        id: orphanSweep

        property int frames: 0

        function arm() {
            frames = 0;
            running = true;
        }

        onTriggered: {
            const kids = listView.contentItem.children;
            const rows = [];
            for (let i = 0; i < kids.length; i++) {
                const c = kids[i];
                if (!c || c.index === undefined)
                    continue;
                const claimed = listView.itemAtIndex(c.index) === c;
                if (claimed && !c.visible) {
                    c.visible = true;
                    continue;
                }
                if (c.visible)
                    rows.push({
                        item: c,
                        claimed: claimed
                    });
            }
            for (let a = 0; a < rows.length; a++) {
                if (rows[a].claimed)
                    continue;
                for (let b = 0; b < rows.length; b++) {
                    if (a === b || !rows[b].claimed)
                        continue;
                    if (Math.abs(rows[a].item.y - rows[b].item.y) < rows[b].item.height / 2) {
                        rows[a].item.visible = false;
                        break;
                    }
                }
            }
            if (++frames >= 3)
                running = false;
        }
    }

    property real targetContentY: contentY

    NumberAnimation {
        id: smoothScrollAnim
        target: listView
        property: "contentY"
        duration: 220
        easing.type: Easing.OutCubic
        onRunningChanged: {
            if (!running) {
                isUserScrolling = false;
                vbar.hideTimer.restart();
            }
        }
    }

    onMovementStarted: {
        smoothScrollAnim.stop();
        targetContentY = contentY;
        isUserScrolling = true;
        vbar._scrollBarActive = true;
        vbar.hideTimer.stop();
    }
    onMovementEnded: {
        isUserScrolling = false;
        vbar.hideTimer.restart();
    }
    onFlickStarted: {
        smoothScrollAnim.stop();
        targetContentY = contentY;
    }

    onContentYChanged: {
        if (!justChanged && isUserScrolling) {
            savedY = contentY;
        }
        justChanged = false;
    }

    onModelChanged: {
        justChanged = true;
        contentY = savedY;
    }

    WheelHandler {
        id: wheelHandler
        property real touchpadSpeed: Scroll.touchpadSpeed
        property real lastWheelTime: 0
        property real momentum: 0
        property var velocitySamples: []
        property bool sessionUsedMouseWheel: false

        function startMomentum() {
            isMomentumActive = true;
            momentumAnim.running = true;
        }

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            isUserScrolling = true;
            vbar._scrollBarActive = true;
            vbar.hideTimer.restart();

            const currentTime = Date.now();
            const timeDelta = currentTime - lastWheelTime;
            lastWheelTime = currentTime;

            const kind = WheelInput.verticalKind(event);
            const deltaY = event.angleDelta.y;

            if (kind === WheelInput.Kind.wheel || kind === WheelInput.Kind.highResWheel) {
                isUserScrolling = true;
                sessionUsedMouseWheel = true;
                momentumAnim.running = false;
                isMomentumActive = false;
                velocitySamples = [];
                momentum = 0;
                momentumVelocity = 0;

                let scrollAmount = 0;
                if (kind === WheelInput.Kind.wheel) {
                    const lines = Math.max(1, Math.round(Math.abs(deltaY) / 120));
                    scrollAmount = (deltaY > 0 ? -lines : lines) * mouseWheelSpeed;
                } else {
                    scrollAmount = -(deltaY / 8) * touchpadSpeed;
                }

                const minY = listView.originY !== undefined ? listView.originY : 0;
                const maxY = Math.max(minY, listView.contentHeight - listView.height + minY);
                const currentTarget = smoothScrollAnim.running ? targetContentY : listView.contentY;
                let newTarget = currentTarget + scrollAmount;
                newTarget = Math.max(minY, Math.min(maxY, newTarget));
                targetContentY = newTarget;

                if (listView.flicking) {
                    listView.cancelFlick();
                }

                smoothScrollAnim.stop();
                smoothScrollAnim.from = listView.contentY;
                smoothScrollAnim.to = newTarget;
                const dist = Math.abs(newTarget - listView.contentY);
                smoothScrollAnim.duration = Math.min(280, Math.max(160, dist * 0.7));
                smoothScrollAnim.start();
                savedY = newTarget;
            } else if (kind === WheelInput.Kind.touchpad) {
                smoothScrollAnim.stop();
                targetContentY = listView.contentY;
                sessionUsedMouseWheel = false;
                momentumAnim.running = false;
                isMomentumActive = false;

                let delta = event.pixelDelta.y * touchpadSpeed;

                velocitySamples.push({
                    "delta": delta,
                    "time": currentTime
                });
                velocitySamples = velocitySamples.filter(s => currentTime - s.time < Scroll.velocitySampleWindowMs);

                if (velocitySamples.length > 1) {
                    const totalDelta = velocitySamples.reduce((sum, s) => sum + s.delta, 0);
                    const timeSpan = currentTime - velocitySamples[0].time;
                    if (timeSpan > 0) {
                        momentumVelocity = Math.max(-Scroll.maxMomentumVelocity, Math.min(Scroll.maxMomentumVelocity, totalDelta / timeSpan * 1000));
                    }
                }

                if (timeDelta < Scroll.momentumTimeThreshold) {
                    momentum = momentum * Scroll.momentumRetention + delta * Scroll.momentumDeltaFactor;
                    delta += momentum;
                } else {
                    momentum = 0;
                }

                let newY = listView.contentY - delta;
                const maxY = Math.max(0, listView.contentHeight - listView.height + listView.originY);
                newY = Math.max(listView.originY, Math.min(maxY, newY));

                if (listView.flicking) {
                    listView.cancelFlick();
                }

                listView.contentY = newY;
                savedY = newY;
            }

            event.accepted = true;
        }

        onActiveChanged: {
            if (!active) {
                isUserScrolling = false;
                if (!sessionUsedMouseWheel && Math.abs(momentumVelocity) >= Scroll.minMomentumVelocity) {
                    startMomentum();
                } else {
                    velocitySamples = [];
                    momentumVelocity = 0;
                }
            }
        }
    }

    FrameAnimation {
        id: momentumAnim
        running: false

        onTriggered: {
            const dt = frameTime;
            const newY = contentY - momentumVelocity * dt;
            const maxY = Math.max(0, contentHeight - height + originY);
            const minY = originY;

            if (newY < minY || newY > maxY) {
                contentY = newY < minY ? minY : maxY;
                savedY = contentY;
                running = false;
                isMomentumActive = false;
                momentumVelocity = 0;
                return;
            }

            contentY = newY;
            savedY = newY;
            momentumVelocity *= Math.pow(friction, dt / 0.016);

            if (Math.abs(momentumVelocity) < Scroll.momentumStopThreshold) {
                running = false;
                isMomentumActive = false;
                momentumVelocity = 0;
            }
        }
    }

    ScrollBar.vertical: DankScrollbar {
        id: vbar
        topPadding: listView.scrollBarTopMargin
    }
}

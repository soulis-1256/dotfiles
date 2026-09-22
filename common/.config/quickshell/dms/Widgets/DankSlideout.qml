pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property string layerNamespace: "dms:slideout"
    WlrLayershell.namespace: layerNamespace

    property bool isVisible: false
    property bool hoverDismissEnabled: false
    property bool hoverDismissSuspended: false
    property var targetScreen: null
    property var modelData: null
    property bool triggerUsesOverlayLayer: false
    // Drop off the Overlay layer (back to Top) while an overlay modal
    property bool suppressOverlayLayer: false
    property real slideoutWidth: 480
    property bool expandable: false
    property bool expandedWidth: false
    property real expandedWidthValue: 960
    property real edgeGap: 0
    property string slideEdge: "right"
    readonly property bool slideFromLeft: slideEdge === "left"
    readonly property real surfaceOriginX: slideFromLeft ? 0 : Math.max(0, (modelData?.width ?? width) - width)
    property Component content: null
    property string title: ""
    property alias container: contentContainer
    property alias loadedItem: contentLoader.item
    property real customTransparency: -1
    property bool mappedVisible: false
    // Set when the slide-out animation finishes, before unmap. Hides the
    // layer-backed panel and drops blur so the last committed frame is empty
    // instead of a 1-frame snap back to the rest position.
    property bool closeSettled: false
    // Click inside the panel. On-demand for the whole time it is open gives
    // this layer the seat keyboard without changing the active window, so a
    // later click on that same window never sends wl_keyboard.enter.
    // None→OnDemand does not move the keyboard; the grab's start does.
    property bool keyboardHeld: false
    // Armed a turn after the press so the on-demand commit is already queued
    // before the grab asks Hyprland to refocus this surface.
    property bool grabArmed: false
    readonly property bool keyboardGrabWanted: root.isVisible && root.keyboardHeld && !root.closeSettled
    // False until the grab has stayed up past the press that created it.
    // A clear before that is the startup race, not an outside click.
    property bool grabSettled: false
    property int grabSettleTries: 0
    property bool rearmedThisPress: false
    property int _focusRequest: 0
    property int _pendingFocusRequest: 0
    property string _pendingFocusAddress: ""
    // cursorpos, clients (bottom to top), and monitors, split by this marker.
    readonly property string _focusProbeCommand: "set -e; hyprctl cursorpos -j; echo @@SLIDEOUT@@; hyprctl clients -j; echo @@SLIDEOUT@@; hyprctl monitors -j"
    signal aboutToHide
    signal revealed

    // Set when the compositor drops the grab. The outside click is also
    // delivered to this layer, sometimes after that drop, and must not
    // take the keyboard back on the same press.
    property bool ignoreHold: false

    function holdKeyboard() {
        if (!root.isVisible || root.closeSettled || root.ignoreHold)
            return;
        const fresh = !root.keyboardHeld;
        root.keyboardHeld = true;
        if (!fresh)
            return;
        root.grabSettled = false;
        root.grabSettleTries = 0;
        root.rearmedThisPress = false;
        Qt.callLater(() => {
            if (root.keyboardHeld && !root.ignoreHold)
                root.grabArmed = true;
        });
    }

    function releaseKeyboard() {
        root.grabArmed = false;
        root.grabSettled = false;
        root.keyboardHeld = false;
    }

    function releaseKeyboardFromGrab() {
        // The click that ends the grab is not delivered to the window under
        // the pointer. Hyprland then refocuses whichever window was still
        // marked active, so a different window needs a second click. Ask for
        // the window under the cursor, drop the seat, then focus that window
        // after refocusLastWindow has run.
        root.ignoreHold = true;
        ignoreHoldTimer.restart();
        const request = ++root._focusRequest;
        Proc.runCommand("slideout-focus-" + (root.screen?.name || "out"), ["sh", "-c", root._focusProbeCommand], (output, exitCode) => {
            if (request !== root._focusRequest)
                return;
            const hit = exitCode === 0 ? root._windowUnderPointer(output) : null;
            const address = (hit && !hit.inside) ? hit.address : "";
            slideoutKeyboardGrab._compositorCleared = true;
            root.releaseKeyboard();
            root._pendingFocusRequest = request;
            root._pendingFocusAddress = address;
            if (address)
                pendingFocusTimer.restart();
            else
                pendingFocusTimer.stop();
        }, 0, 1500);
    }

    function _windowUnderPointer(output) {
        const parts = String(output || "").split("@@SLIDEOUT@@").map(part => part.trim()).filter(part => part.length > 0);
        if (parts.length < 3)
            return null;
        let cursor, clients, monitors;
        try {
            cursor = JSON.parse(parts[0]);
            clients = JSON.parse(parts[1]);
            monitors = JSON.parse(parts[2]);
        } catch (e) {
            return null;
        }
        if (!cursor || !clients || !clients.length || !monitors || !monitors.length)
            return null;
        const mon = root._monitorAt(monitors, cursor.x, cursor.y);
        return {
            inside: root._pointerInsideSlideout(cursor, monitors),
            address: mon ? root._addressAt(cursor, clients, mon) : ""
        };
    }

    function _monitorAt(monitors, x, y) {
        for (let i = 0; i < monitors.length; i++) {
            const mon = monitors[i];
            if (x >= mon.x && y >= mon.y && x < mon.x + mon.width && y < mon.y + mon.height)
                return mon;
        }
        return null;
    }

    function _pointerInsideSlideout(cursor, monitors) {
        const name = root.screen?.name || "";
        let mon = null;
        for (let i = 0; i < monitors.length; i++) {
            if (monitors[i].name === name) {
                mon = monitors[i];
                break;
            }
        }
        // Unknown screen: keep the notepad seat rather than focusing whatever
        // window sits behind the panel.
        if (!mon)
            return true;
        return root.containsScreenPoint(cursor.x - mon.x, cursor.y - mon.y, 0);
    }

    function _onWorkspace(client, mon) {
        if (!client || client.mapped === false || client.hidden === true || client.visible === false || client.acceptsInput === false)
            return false;
        if (client.pinned)
            return true;
        const ws = client.workspace ? client.workspace.id : -1;
        const special = mon.specialWorkspace && mon.specialWorkspace.id > 0 ? mon.specialWorkspace.id : 0;
        if (special)
            return ws === special;
        const active = mon.activeWorkspace ? mon.activeWorkspace.id : -1;
        return ws === active;
    }

    function _boxContains(client, x, y) {
        const at = client.at;
        const size = client.size;
        if (!at || !size || at.length < 2 || size.length < 2)
            return false;
        return x >= at[0] && y >= at[1] && x < at[0] + size[0] && y < at[1] + size[1];
    }

    function _topmost(clients, accept) {
        for (let i = clients.length - 1; i >= 0; i--) {
            if (accept(clients[i]))
                return clients[i].address || "";
        }
        return "";
    }

    // Match Hyprland's hit test: pinned, then fullscreen, then floating,
    // then tiled. clients is bottom-to-top, so the walk starts at the end.
    function _addressAt(cursor, clients, mon) {
        const x = cursor.x;
        const y = cursor.y;
        const pinned = root._topmost(clients, client => root._onWorkspace(client, mon) && client.pinned && root._boxContains(client, x, y));
        if (pinned)
            return pinned;
        const fullscreen = root._topmost(clients, client => {
            return root._onWorkspace(client, mon) && client.fullscreen === 2 && client.monitor === mon.id;
        });
        if (fullscreen)
            return fullscreen;
        const maximized = root._topmost(clients, client => {
            return root._onWorkspace(client, mon) && client.fullscreen === 1 && root._boxContains(client, x, y);
        });
        if (maximized)
            return maximized;
        const floating = root._topmost(clients, client => {
            return root._onWorkspace(client, mon) && client.floating && !client.pinned && root._boxContains(client, x, y);
        });
        if (floating)
            return floating;
        return root._topmost(clients, client => {
            return root._onWorkspace(client, mon) && !client.floating && root._boxContains(client, x, y);
        });
    }

    function show() {
        unmapTimer.stop();
        closeSettled = false;
        mappedVisible = true;
        Qt.callLater(() => {
            isVisible = true;
            revealed();
        });
    }

    function hide() {
        aboutToHide();
        root._focusRequest++;
        pendingFocusTimer.stop();
        root.releaseKeyboard();
        isVisible = false;
    }

    function hideFromHoverDismiss() {
        if (hoverDismissSuspended)
            return;
        hoverDismissEnabled = false;
        slideAnimation.duration = Math.round(Theme.expressiveDurations.expressiveDefaultSpatial);
        hide();
    }

    function cancelHoverDismiss() {
        hoverDismissTracker.cancelPending();
    }

    function containsScreenPoint(localX, localY, padding) {
        if (!isVisible || !modelData)
            return false;
        const pad = padding || 0;
        const topLeft = slideContainer.mapToItem(null, 0, 0);
        const x = surfaceOriginX + topLeft.x;
        const y = topLeft.y;
        return localX >= x - pad && localX < x + slideContainer.width + pad && localY >= y - pad && localY < y + slideContainer.height + pad;
    }

    function containsGlobalPoint(gx, gy) {
        return containsScreenPoint(gx, gy, 24);
    }

    function toggle() {
        if (isVisible) {
            hide();
        } else {
            show();
        }
    }

    visible: root.mappedVisible
    screen: modelData

    anchors.top: true
    anchors.bottom: true
    anchors.right: !root.slideFromLeft
    anchors.left: root.slideFromLeft

    implicitWidth: expandable ? expandedWidthValue : slideoutWidth
    implicitHeight: modelData ? modelData.height : 800

    color: "transparent"

    HoverDismissTracker {
        id: hoverDismissTracker
        parent: root.contentItem
        enabled: root.hoverDismissEnabled && !root.hoverDismissSuspended && root.isVisible
        shouldDismiss: function () {
            return !PopoutManager.cursorOverBar(PopoutManager.hoverCursorGlobalX, PopoutManager.hoverCursorGlobalY);
        }
        onDismissRequested: root.hideFromHoverDismiss()
        onHoverMoved: (sceneX, sceneY) => PopoutManager.updateHoverCursor(root.surfaceOriginX + sceneX, sceneY)
    }

    readonly property bool slideoutBlurActive: root.visible && !root.closeSettled && BlurService.enabled && Theme.connectedSurfaceBlurEnabled

    WlrLayershell.layer: (!suppressOverlayLayer && (triggerUsesOverlayLayer || CompositorService.framePeerSurfacesUseOverlayForScreen(modelData))) ? WlrLayershell.Overlay : WlrLayershell.Top
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: KeyboardFocus.keyboardFocus(root.keyboardGrabWanted)

    // Grab start moves the seat keyboard onto this layer. An outside click
    // clears the grab and is not delivered to the window under the pointer.
    // Dropping keyboard mode hands the seat back to the window that was
    // never unmarked active; the click target is focused after that.
    DankFocusGrab {
        id: slideoutKeyboardGrab
        clientWindows: [root]
        wanted: KeyboardFocus.wantsGrab(root.keyboardGrabWanted && root.grabArmed, null)
        restoreFocus: false
    }

    Timer {
        id: grabSettleTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (!root.keyboardHeld)
                return;
            if (slideoutKeyboardGrab.active) {
                root.grabSettled = true;
                return;
            }
            root.grabSettleTries += 1;
            if (root.grabSettleTries < 5)
                grabSettleTimer.restart();
        }
    }

    // Runs after keyboard None has made Hyprland refocus the previously
    // active window, so this focus is the one that sticks.
    Timer {
        id: pendingFocusTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (root._pendingFocusRequest !== root._focusRequest || root.keyboardHeld)
                return;
            if (root._pendingFocusAddress)
                HyprlandService.focusWindow(root._pendingFocusAddress);
        }
    }

    Timer {
        id: ignoreHoldTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (!slideoutPress.active)
                root.ignoreHold = false;
        }
    }

    Connections {
        target: slideoutKeyboardGrab
        function onActiveChanged() {
            if (slideoutKeyboardGrab.active) {
                if (!root.grabSettled)
                    grabSettleTimer.restart();
                return;
            }
            if (!root.keyboardHeld)
                return;
            // The press that arms the grab can clear it before the surface
            // is committed. Try once more without handing the keyboard back.
            if (!root.grabSettled && !root.rearmedThisPress) {
                root.rearmedThisPress = true;
                Qt.callLater(() => {
                    if (root.keyboardHeld && !root.grabSettled && !slideoutKeyboardGrab.active)
                        slideoutKeyboardGrab.active = true;
                });
                return;
            }
            root.releaseKeyboardFromGrab();
        }
    }

    readonly property real dpr: CompositorService.getScreenScale(root.screen)
    readonly property real alignedWidth: Theme.px(expandable && expandedWidth ? expandedWidthValue : slideoutWidth, dpr)
    readonly property real alignedHeight: Theme.px(modelData ? modelData.height : 800, dpr)
    readonly property real alignedEdgeGap: Theme.px(edgeGap, dpr)
    readonly property real slideoutSlideSnapX: Theme.snap(slideContainer.slideOffset, dpr)

    mask: Region {
        item: Rectangle {
            x: root.slideFromLeft ? root.alignedEdgeGap : (root.width - slideContainer.width - root.alignedEdgeGap)
            y: root.alignedEdgeGap
            width: slideContainer.width
            height: root.height - root.alignedEdgeGap * 2
        }
    }

    Item {
        id: slideContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: root.slideFromLeft ? undefined : parent.right
        anchors.left: root.slideFromLeft ? parent.left : undefined
        anchors.topMargin: root.alignedEdgeGap
        anchors.bottomMargin: root.alignedEdgeGap
        anchors.rightMargin: root.alignedEdgeGap
        anchors.leftMargin: root.alignedEdgeGap
        width: root.alignedWidth
        height: root.alignedHeight - root.alignedEdgeGap * 2

        property real slideOffset: root.slideFromLeft ? -root.alignedWidth : root.alignedWidth

        Connections {
            target: root
            function onIsVisibleChanged() {
                slideContainer.slideOffset = root.isVisible ? 0 : (root.slideFromLeft ? -slideContainer.width : slideContainer.width);
            }
        }

        Behavior on slideOffset {
            NumberAnimation {
                id: slideAnimation
                duration: 450
                easing.type: Easing.OutCubic

                onRunningChanged: {
                    if (running)
                        return;
                    if (!root.isVisible) {
                        root.closeSettled = true;
                        unmapTimer.restart();
                    }
                    slideAnimation.duration = 450;
                }
            }
        }

        Behavior on width {
            enabled: root.expandable
            NumberAnimation {
                duration: Theme.popoutAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: contentRect
            visible: !root.closeSettled
            layer.enabled: !root.closeSettled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
            layer.smooth: false
            layer.textureSize: Qt.size(0, 0)
            opacity: 1

            readonly property color slideoutSurfaceColor: root.customTransparency >= 0 ? Theme.withAlpha(Theme.surfaceContainer, root.customTransparency) : Theme.popupLayerColor(Theme.surfaceContainer)

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            x: root.slideoutSlideSnapX

            Rectangle {
                anchors.fill: parent
                color: contentRect.slideoutSurfaceColor
                radius: Theme.connectedSurfaceRadius
                border.color: Theme.isConnectedEffect ? Theme.withAlpha(BlurService.borderColor, 0) : BlurService.borderColor
                border.width: Theme.isConnectedEffect ? 0 : BlurService.borderWidth
            }

            Column {
                id: headerColumn
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM
                visible: root.title !== ""

                Row {
                    width: parent.width
                    height: 32

                    Column {
                        width: parent.width - buttonRow.width
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: root.title
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }
                    }

                    Row {
                        id: buttonRow
                        spacing: Theme.spacingXS

                        DankActionButton {
                            id: expandButton
                            iconName: root.expandedWidth ? "unfold_less" : "unfold_more"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            visible: root.expandable
                            onClicked: root.expandedWidth = !root.expandedWidth

                            transform: Rotation {
                                angle: 90
                                origin.x: expandButton.width / 2
                                origin.y: expandButton.height / 2
                            }
                        }

                        DankActionButton {
                            id: closeButton
                            iconName: "close"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: root.hide()
                        }
                    }
                }
            }

            Item {
                id: contentContainer
                anchors.top: root.title !== "" ? headerColumn.bottom : parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: root.title !== "" ? 0 : Theme.spacingL
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.bottomMargin: Theme.spacingL

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    sourceComponent: root.content
                }
            }
        }

        // On the unlayered parent. A handler on the layered card does not
        // see presses that land on the text field. Passive, so the field
        // still receives the click.
        PointHandler {
            id: slideoutPress
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything
            onActiveChanged: {
                if (active)
                    root.holdKeyboard();
                else
                    root.ignoreHold = false;
            }
        }
    }

    Timer {
        id: unmapTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (!root.isVisible)
                root.mappedVisible = false;
        }
    }

    WindowBlur {
        id: slideoutBlur
        targetWindow: root
        blurEnabled: Theme.connectedSurfaceBlurEnabled && root.slideoutBlurActive
        // Keep last geometry on close so we _clear() instead of publishing a
        // 0-size region (which can flash the full layer for one frame).
        blurX: slideContainer.x + root.slideoutSlideSnapX
        blurY: slideContainer.y
        blurWidth: slideContainer.width
        blurHeight: slideContainer.height
        blurRadius: Theme.connectedSurfaceRadius
        // Intersect with the rest rect so the off-screen tail of the slide
        // cannot leave a blur sliver at the edge.
        clipEnabled: true
        clipX: slideContainer.x
        clipY: slideContainer.y
        clipWidth: slideContainer.width
        clipHeight: slideContainer.height
    }
}

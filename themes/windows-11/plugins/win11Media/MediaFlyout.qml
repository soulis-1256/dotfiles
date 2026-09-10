import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var closePopout: null
    property var parentPopout: null

    readonly property color winBg: Theme.popupLayerColor(Theme.surfaceContainer)
    readonly property color winText: Theme.surfaceText
    readonly property color winMuted: Theme.surfaceVariantText
    readonly property color winAccent: Theme.primary
    readonly property color winHover: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
    readonly property real winRadius: 8

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool isPlaying: !!player && player.playbackState === 1
    readonly property real trackLength: MprisController.activePlayerStableLength || (player && player.lengthSupported ? player.length : 0)

    property real currentPosition: 0

    implicitWidth: 320
    implicitHeight: 268
    width: implicitWidth
    height: implicitHeight

    Timer {
        interval: 500
        running: root.visible && !!root.player && root.player.positionSupported
        repeat: true
        onTriggered: {
            if (root.player && root.player.positionSupported)
                root.player.positionChanged();
            root.currentPosition = root.player ? (root.player.position || 0) : 0;
        }
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0 || !isFinite(seconds))
            return "0:00";
        const s = Math.floor(seconds % 60);
        const m = Math.floor(seconds / 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function seekTo(ratio) {
        if (!root.player || !root.trackLength)
            return;
        const target = Math.max(0.1, Math.min(root.trackLength * 0.99, ratio * root.trackLength));
        root.player.position = target;
        root.currentPosition = target;
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.winRadius
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Item {
                width: parent.width
                height: 120

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 120
                    height: 120
                    radius: 8
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: "album"
                        size: 40
                        color: root.winMuted
                        visible: !root.player || !root.player.trackArtUrl
                    }
                }
            }

            StyledText {
                width: parent.width
                text: MprisController.stableTitle || (root.player ? root.player.identity : "") || "Not playing"
                color: root.winText
                font.pixelSize: 15
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            StyledText {
                width: parent.width
                text: MprisController.stableArtist || ""
                color: root.winMuted
                font.pixelSize: 12
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                visible: text.length > 0
            }

            Item {
                width: parent.width
                height: 18
                visible: root.trackLength > 1

                Rectangle {
                    id: seekTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 3
                    radius: 1.5
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.16)

                    Rectangle {
                        width: parent.width * (root.trackLength > 0 ? Math.min(1, root.currentPosition / root.trackLength) : 0)
                        height: parent.height
                        radius: parent.radius
                        color: root.winAccent
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -6
                        anchors.bottomMargin: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => root.seekTo(mouse.x / Math.max(1, seekTrack.width))
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18

                Item {
                    width: 32
                    height: 32
                    opacity: (root.player && root.player.canGoPrevious) ? 1 : 0.35

                    DankIcon {
                        anchors.centerIn: parent
                        name: "skip_previous"
                        size: 22
                        color: root.winText
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !!(root.player && root.player.canGoPrevious)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.previousOrRewind()
                    }
                }

                Rectangle {
                    width: 40
                    height: 32
                    radius: 6
                    color: playHover.containsMouse ? root.winHover : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: root.isPlaying ? "pause" : "play_arrow"
                        size: 24
                        color: root.winText
                    }

                    MouseArea {
                        id: playHover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !!root.player
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.player)
                                root.player.togglePlaying();
                        }
                    }
                }

                Item {
                    width: 32
                    height: 32
                    opacity: (root.player && root.player.canGoNext) ? 1 : 0.35

                    DankIcon {
                        anchors.centerIn: parent
                        name: "skip_next"
                        size: 22
                        color: root.winText
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !!(root.player && root.player.canGoNext)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.player)
                                MprisController.next();
                        }
                    }
                }
            }
        }
    }
}

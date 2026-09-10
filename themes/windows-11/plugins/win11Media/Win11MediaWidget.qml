import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: activePlayer !== null
    readonly property bool isPlaying: !!activePlayer && activePlayer.playbackState === 1 && !MprisController.isFirefoxYoutubeHoverPreview(activePlayer)

    layerNamespacePlugin: "win11-media"
    popoutWidth: 320
    popoutHeight: 280
    popoutFlush: true

    horizontalBarPill: Component {
        Item {
            id: mediaPill
            implicitWidth: root.playerAvailable ? mediaRow.implicitWidth + 20 : 0
            implicitHeight: root.barThickness
            visible: root.playerAvailable
            clip: true

            Row {
                id: mediaRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                spacing: 8

                Item {
                    width: 22
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: "music_note"
                        size: 16
                        color: Theme.widgetTextColor
                        visible: !root.activePlayer || !root.activePlayer.trackArtUrl
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 160)
                    text: {
                        if (!root.activePlayer)
                            return "";
                        const title = MprisController.stableTitle || root.activePlayer.identity || "";
                        const artist = MprisController.stableArtist || "";
                        if (title && artist)
                            return title + " • " + artist;
                        return title;
                    }
                    color: Theme.widgetTextColor
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : 1, root.barConfig ? root.barConfig.maximizeWidgetText : false)
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                Item {
                    width: 22
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        anchors.centerIn: parent
                        name: root.isPlaying ? "pause" : "play_arrow"
                        size: 16
                        color: Theme.widgetTextColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer)
                                root.activePlayer.togglePlaying();
                        }
                    }
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.barThickness
            implicitHeight: root.playerAvailable ? 48 : 0
            visible: root.playerAvailable

            DankIcon {
                anchors.centerIn: parent
                name: root.isPlaying ? "pause" : "music_note"
                size: 18
                color: Theme.widgetTextColor
            }
        }
    }

    popoutContent: Component {
        MediaFlyout {}
    }
}

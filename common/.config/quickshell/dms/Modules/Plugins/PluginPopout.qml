import QtQuick
import qs.Common
import qs.Widgets

DankPopout {
    id: root

    layerNamespace: "dms:plugins:" + layerNamespacePlugin

    property var triggerScreen: null
    property Component pluginContent: null
    property real contentWidth: 400
    property real contentHeight: 0
    property bool flushContent: false
    readonly property real contentPadding: flushContent ? 0 : Theme.spacingS

    popupWidth: contentWidth
    popupHeight: contentHeight
    screen: triggerScreen
    shouldBeVisible: false
    contentHandlesKeys: true

    onBackgroundClicked: close()

    content: Component {
        Rectangle {
            id: popoutContainer

            implicitHeight: popoutColumn.implicitHeight + (root.flushContent ? 0 : Theme.spacingL * 2)
            color: "transparent"
            focus: true

            Component.onCompleted: {
                if (root.shouldBeVisible) {
                    if (popoutContentLoader.item) {
                        popoutContentLoader.item.forceActiveFocus();
                    } else {
                        forceActiveFocus();
                    }
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
                    if (root.shouldBeVisible) {
                        Qt.callLater(() => {
                            if (popoutContentLoader.item) {
                                popoutContentLoader.item.forceActiveFocus();
                            } else {
                                popoutContainer.forceActiveFocus();
                            }
                        });
                    }
                }
                function onOpened() {
                    Qt.callLater(() => {
                        if (popoutContentLoader.item) {
                            popoutContentLoader.item.forceActiveFocus();
                        }
                    });
                }
            }

            Column {
                id: popoutColumn
                width: parent.width - root.contentPadding * 2
                x: root.contentPadding
                y: root.contentPadding
                spacing: root.flushContent ? 0 : Theme.spacingS

                Loader {
                    id: popoutContentLoader
                    width: parent.width
                    sourceComponent: root.pluginContent

                    onLoaded: {
                        if (item && "closePopout" in item) {
                            item.closePopout = function () {
                                root.close();
                            };
                        }
                        if (item && "parentPopout" in item) {
                            item.parentPopout = root;
                        }
                        if (item) {
                            root.contentHeight = Qt.binding(() => item.implicitHeight + root.contentPadding * 2);
                            if (root.shouldBeVisible) {
                                Qt.callLater(() => {
                                    item.forceActiveFocus();
                                });
                            }
                        }
                    }
                }
            }
        }
    }
}

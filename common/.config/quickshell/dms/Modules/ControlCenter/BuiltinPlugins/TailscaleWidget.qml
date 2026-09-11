import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    Ref {
        service: TailscaleService
    }

    ccWidgetIcon: "device_hub"
    ccWidgetPrimaryText: I18n.tr("Tailscale", "Tailscale mesh VPN widget title")
    ccWidgetSecondaryText: {
        if (!TailscaleService.available)
            return I18n.tr("Not available", "Tailscale service not available");
        if (!TailscaleService.connected)
            return I18n.tr("Disconnected", "Tailscale disconnected status");
        const count = TailscaleService.onlinePeerCount;
        return I18n.tr("%1 online", "Number of online Tailscale peers").arg(count);
    }
    ccWidgetIsActive: TailscaleService.connected

    onCcWidgetToggled: {
        if (!TailscaleService.available)
            return;
        if (TailscaleService.connected)
            TailscaleService.disconnectTailscale(null);
        else
            TailscaleService.connectTailscale(null);
    }

    ccDetailContent: Component {
        Rectangle {
            id: detailRoot

            property string searchQuery: ""
            property int filterIndex: 2
            property string expandedHostname: ""
            property string copiedKey: ""

            function copyText(key, value) {
                if (!value)
                    return;
                Quickshell.execDetached(["dms", "cl", "copy", value]);
                copiedKey = key;
                copiedReset.restart();
            }

            Timer {
                id: copiedReset
                interval: 1500
                onTriggered: detailRoot.copiedKey = ""
            }

            property var filteredPeers: {
                let base;
                switch (filterIndex) {
                case 0:
                    base = TailscaleService.myOnlinePeers;
                    break;
                case 1:
                    base = TailscaleService.onlinePeers;
                    break;
                default:
                    base = TailscaleService.allPeersList;
                    break;
                }
                if (searchQuery.length > 0)
                    return TailscaleService.searchPeers(searchQuery, base);
                return base;
            }

            implicitHeight: {
                if (!TailscaleService.available)
                    return 180;
                if (!TailscaleService.connected)
                    return 200;
                return 560;
            }
            radius: Theme.cornerRadius
            color: Theme.nestedSurface
            border.color: Theme.outlineMedium
            border.width: Theme.layerOutlineWidth

            Item {
                visible: !TailscaleService.available
                anchors.fill: parent

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "vpn_key_off"
                        size: 36
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: I18n.tr("Tailscale not available", "Warning when Tailscale service is not running")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            ColumnLayout {
                visible: TailscaleService.available
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        StyledText {
                            text: TailscaleService.connected ? I18n.tr("Connected", "Tailscale connection status: connected") : I18n.tr("Disconnected", "Tailscale connection status: disconnected")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            visible: TailscaleService.connected && TailscaleService.tailnetName.length > 0
                            text: TailscaleService.tailnetName
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        id: connButton
                        Layout.alignment: Qt.AlignVCenter
                        height: 28
                        radius: 14
                        width: connButtonRow.implicitWidth + Theme.spacingM * 2

                        readonly property bool isConnected: TailscaleService.connected
                        color: {
                            if (!connButtonArea.containsMouse)
                                return Theme.surfaceLight;
                            return isConnected ? Theme.errorHover : Theme.primaryHoverLight;
                        }

                        Row {
                            id: connButtonRow
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            DankIcon {
                                name: connButton.isConnected ? "link_off" : "link"
                                size: Theme.fontSizeSmall
                                color: connButton.isConnected ? Theme.surfaceText : Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: connButton.isConnected ? I18n.tr("Disconnect", "Tailscale disconnect button") : I18n.tr("Connect", "Tailscale connect button")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: connButton.isConnected ? Theme.surfaceText : Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: connButtonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (TailscaleService.connected)
                                    TailscaleService.disconnectTailscale(null);
                                else
                                    TailscaleService.connectTailscale(null);
                            }
                        }
                    }
                }

                Column {
                    id: controlsColumn
                    Layout.fillWidth: true
                    spacing: Theme.spacingS
                    visible: TailscaleService.connected

                    readonly property string noneLabel: I18n.tr("None", "Tailscale exit node: none selected")

                    DankDropdown {
                        width: parent.width
                        text: I18n.tr("Exit node", "Tailscale exit node selector label")
                        currentValue: TailscaleService.currentExitNode ? TailscaleService.currentExitNode.hostname : controlsColumn.noneLabel
                        options: {
                            const opts = [controlsColumn.noneLabel];
                            for (const p of TailscaleService.exitNodeOptions)
                                opts.push(p.hostname);
                            return opts;
                        }
                        onValueChanged: value => {
                            if (value === controlsColumn.noneLabel) {
                                TailscaleService.clearExitNode(null);
                                return;
                            }
                            const peer = TailscaleService.exitNodeOptions.find(p => p.hostname === value);
                            if (peer)
                                TailscaleService.setExitNode(peer.id, null);
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Allow LAN access", "Tailscale allow LAN access toggle")
                        description: I18n.tr("Reach local network devices while using an exit node", "Tailscale allow LAN access description")
                        visible: TailscaleService.currentExitNode !== null
                        checked: TailscaleService.exitNodeAllowLanAccess
                        onToggled: value => TailscaleService.setAllowLanAccess(value, null)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    DankTextField {
                        Layout.fillWidth: true
                        placeholderText: I18n.tr("Search devices...", "Tailscale device search placeholder")
                        leftIconName: "search"
                        showClearButton: true
                        text: detailRoot.searchQuery
                        onTextEdited: detailRoot.searchQuery = text
                    }

                    DankActionButton {
                        iconName: "sync"
                        buttonSize: 28
                        iconSize: 16
                        iconColor: Theme.surfaceVariantText
                        tooltipText: I18n.tr("Refresh", "Refresh Tailscale device status")
                        onClicked: TailscaleService.refresh(null)
                    }
                }

                DankFilterChips {
                    Layout.fillWidth: true
                    currentIndex: detailRoot.filterIndex
                    showCounts: true
                    chipHeight: 26
                    model: [
                        {
                            "label": I18n.tr("My Online", "Tailscale filter: my online devices"),
                            "count": TailscaleService.myOnlinePeers.length
                        },
                        {
                            "label": I18n.tr("Online", "Tailscale filter: all online devices"),
                            "count": TailscaleService.onlinePeers.length
                        },
                        {
                            "label": I18n.tr("All", "Tailscale filter: all devices"),
                            "count": TailscaleService.allPeersList.length
                        }
                    ]
                    onSelectionChanged: index => {
                        detailRoot.filterIndex = index;
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: peerList
                        anchors.fill: parent
                        clip: true
                        spacing: Theme.spacingXS
                        boundsBehavior: Flickable.StopAtBounds
                        model: detailRoot.filteredPeers
                        ScrollBar.vertical: DankScrollbar {
                            policy: peerList.contentHeight > peerList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            readonly property bool isSelf: {
                                const self = TailscaleService.selfNode;
                                if (!self || !modelData)
                                    return false;
                                if (modelData.id && self.id)
                                    return modelData.id === self.id;
                                return modelData.hostname === self.hostname;
                            }
                            readonly property bool isExpanded: detailRoot.expandedHostname === modelData.hostname

                            width: Math.max(0, (ListView.view ? ListView.view.width : 0) - Theme.spacingL)
                            implicitHeight: peerCardColumn.implicitHeight + Theme.spacingS * 2
                            height: implicitHeight
                            radius: Theme.cornerRadius
                            color: peerMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                            border.color: isSelf ? Theme.primary : Theme.outlineLight
                            border.width: isSelf ? 2 : 1

                            Column {
                                id: peerCardColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingXXS

                                RowLayout {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: modelData.online ? Theme.success : Theme.surfaceVariantText
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    StyledText {
                                        text: modelData.hostname || ""
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: isSelf ? Font.Medium : Font.Normal
                                        color: Theme.surfaceText
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        visible: isSelf
                                        text: I18n.tr("This device", "Label for the user's own device in Tailscale")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                        font.weight: Font.Medium
                                    }
                                }

                                RowLayout {
                                    width: parent.width
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: modelData.tailscaleIp || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceTextMedium
                                        Layout.fillWidth: true
                                    }

                                    DankActionButton {
                                        readonly property bool copied: detailRoot.copiedKey === "ip:" + (modelData.hostname || "")
                                        iconName: copied ? "check" : "content_copy"
                                        buttonSize: 20
                                        iconSize: 11
                                        iconColor: copied ? Theme.success : Theme.surfaceVariantText
                                        tooltipText: copied ? I18n.tr("Copied", "Clipboard copy confirmation") : I18n.tr("Copy IP", "Copy Tailscale IP to clipboard")
                                        onClicked: detailRoot.copyText("ip:" + (modelData.hostname || ""), modelData.tailscaleIp)
                                    }
                                }

                                StyledText {
                                    text: {
                                        const parts = [];
                                        if (modelData.os)
                                            parts.push(modelData.os);
                                        if (modelData.online) {
                                            parts.push(modelData.relay ? I18n.tr("relay: %1", "Tailscale relay server name").arg(modelData.relay) : I18n.tr("direct", "Tailscale direct connection"));
                                        } else if (modelData.lastSeen) {
                                            parts.push(I18n.tr("last seen %1", "Tailscale peer last seen time").arg(modelData.lastSeen));
                                        }
                                        return parts.join(" \u2022 ");
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                    elide: Text.ElideRight
                                }

                                Column {
                                    visible: isExpanded
                                    width: parent.width
                                    spacing: Theme.spacingXXS
                                    topPadding: 4

                                    RowLayout {
                                        width: parent.width
                                        spacing: Theme.spacingXS
                                        visible: (modelData.dnsName || "").length > 0

                                        StyledText {
                                            text: modelData.dnsName || ""
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        DankActionButton {
                                            readonly property bool copied: detailRoot.copiedKey === "dns:" + (modelData.hostname || "")
                                            iconName: copied ? "check" : "content_copy"
                                            buttonSize: 20
                                            iconSize: 11
                                            iconColor: copied ? Theme.success : Theme.surfaceVariantText
                                            tooltipText: copied ? I18n.tr("Copied", "Clipboard copy confirmation") : I18n.tr("Copy DNS name", "Copy Tailscale DNS name to clipboard")
                                            onClicked: detailRoot.copyText("dns:" + (modelData.hostname || ""), modelData.dnsName)
                                        }
                                    }

                                    StyledText {
                                        visible: (modelData.tags || []).length > 0
                                        text: I18n.tr("Tags: %1", "Tailscale device tags").arg((modelData.tags || []).join(", "))
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        visible: (modelData.owner || "").length > 0
                                        text: I18n.tr("Owner: %1", "Tailscale device owner").arg(modelData.owner || "")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            MouseArea {
                                id: peerMouseArea
                                z: -1
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: detailRoot.expandedHostname = (detailRoot.expandedHostname === modelData.hostname) ? "" : modelData.hostname
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: peerList.count === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            DankIcon {
                                name: "devices"
                                size: 28
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: detailRoot.searchQuery.length > 0 ? I18n.tr("No matching devices", "No Tailscale devices match search") : I18n.tr("No peers found", "No Tailscale peers found")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}

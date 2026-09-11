import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

Item {
    id: root

    property string pluginId: "win11Snap"
    property var pluginService: null

    SnapTopBar {
        id: topHoverBar
    }

    IpcHandler {
        target: "win11Snap"

        function toggle(): string {
            topHoverBar.toggle();
            return topHoverBar.isExpanded ? "expanded" : "collapsed";
        }

        function expand(): string {
            topHoverBar.expand();
            return "expanded";
        }

        function collapse(): string {
            topHoverBar.forceCollapse();
            return "collapsed";
        }

        function setZone(zone: string): string {
            topHoverBar.expand();
            topHoverBar.setZone(zone);
            return "zone: " + zone;
        }

        function drop(): string {
            if (topHoverBar.activeZone) {
                var z = topHoverBar.activeZone;
                topHoverBar.triggerSnap(z);
                return "dropped: " + z;
            }
            topHoverBar.forceCollapse();
            return "dropped: none";
        }
    }
}

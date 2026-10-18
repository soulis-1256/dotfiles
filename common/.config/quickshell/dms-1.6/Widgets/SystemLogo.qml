import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.DankCommon.Common
import qs.DankCommon.Widgets

Item {
    id: root

    property string colorOverride: ""
    property real brightnessOverride: 0.5
    property real contrastOverride: 1

    readonly property bool hasColorOverride: colorOverride !== ""

    property bool useNerdFont: false
    property string nerdFontIcon: ""
    property string _imageSource: ""

    // Read once when this logo is created. An async shell callback loses the
    // widget when a theme switch rebuilds the bar, and the colorize layer
    // then keeps the empty texture until another DMS start.
    FileView {
        id: osReleaseFile
        path: "/etc/os-release"
        blockLoading: true
        watchChanges: false
        printErrors: false
    }

    IconImage {
        id: iconImage
        anchors.fill: parent
        visible: !root.useNerdFont
        smooth: true
        asynchronous: false
        source: root._imageSource
        layer.enabled: root.hasColorOverride && status === Image.Ready
        layer.effect: MultiEffect {
            colorization: 1
            colorizationColor: root.colorOverride
            brightness: root.brightnessOverride
            contrast: root.contrastOverride
        }
    }

    DankNFIcon {
        id: nfIcon
        anchors.centerIn: parent
        visible: root.useNerdFont
        name: root.nerdFontIcon
        size: Math.min(root.width, root.height)
        color: root.hasColorOverride ? root.colorOverride : Style.surfaceText
    }

    function _osReleaseField(text, key) {
        const lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const trimmed = lines[i].trim();
            if (!trimmed || trimmed.startsWith("#"))
                continue;
            const eq = trimmed.indexOf("=");
            if (eq < 0 || trimmed.slice(0, eq) !== key)
                continue;
            let value = trimmed.slice(eq + 1).trim();
            if (value.length >= 2 && ((value.startsWith("\"") && value.endsWith("\"")) || (value.startsWith("'") && value.endsWith("'"))))
                value = value.slice(1, -1);
            return value;
        }
        return "";
    }

    function _resolveLogo() {
        let text = "";
        try {
            text = osReleaseFile.text();
        } catch (e) {
            return;
        }
        const distroId = _osReleaseField(text, "ID");
        const supportedDistroNFs = ["debian", "arch", "archcraft", "fedora", "freebsd", "nixos", "ubuntu", "guix", "gentoo", "endeavouros", "manjaro", "opensuse"];
        if (distroId && supportedDistroNFs.includes(distroId)) {
            root.useNerdFont = true;
            root.nerdFontIcon = distroId;
            return;
        }
        const logo = _osReleaseField(text, "LOGO");
        if (!logo)
            return;
        if (logo === "cachyos") {
            root._imageSource = "file:///usr/share/icons/cachyos.svg";
            return;
        }
        if (logo === "guix-icon") {
            root._imageSource = "file:///run/current-system/profile/share/icons/hicolor/scalable/apps/guix-icon.svg";
            return;
        }
        if (logo === "zirconium") {
            root._imageSource = "file:///usr/share/zirconium/pixmaps/logo-z.svg";
            return;
        }
        root._imageSource = Quickshell.iconPath(logo, true);
    }

    Component.onCompleted: _resolveLogo()
}

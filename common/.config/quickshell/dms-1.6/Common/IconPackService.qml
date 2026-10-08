pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import "../Widgets/IconPacks.js" as Packs

Singleton {
    id: root

    readonly property string packId: {
        if (typeof SettingsData !== "undefined" && SettingsData.iconPack)
            return SettingsData.iconPack;
        return "lucide";
    }
    readonly property var pack: Packs.getPack(packId)
    readonly property string packLabel: pack.label
    readonly property var packLabels: Packs.labels()
    readonly property bool usesVariableAxes: Packs.usesVariableAxes(packId)

    FontLoader {
        id: materialFont
        source: Qt.resolvedUrl("../assets/fonts/material-design-icons/variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf")
    }

    FontLoader {
        id: lucideFont
        source: Qt.resolvedUrl("../assets/fonts/lucide/lucide.ttf")
    }

    FontLoader {
        id: phosphorRegular
        source: Qt.resolvedUrl("../assets/fonts/phosphor/Phosphor.ttf")
    }

    FontLoader {
        id: phosphorFill
        source: Qt.resolvedUrl("../assets/fonts/phosphor/Phosphor-Fill.ttf")
    }

    FontLoader {
        id: phosphorBold
        source: Qt.resolvedUrl("../assets/fonts/phosphor/Phosphor-Bold.ttf")
    }

    function glyph(name, filled, weight) {
        return Packs.resolveGlyph(root.packId, name, filled, weight);
    }

    function opticalScale(name) {
        return Packs.opticalScale(root.packId, name);
    }

    function family(filled, weight) {
        const role = Packs.fontRole(root.packId, filled, weight);
        if (root.packId === "phosphor") {
            if (role === "fill")
                return phosphorFill.name;
            if (role === "bold")
                return phosphorBold.name;
            return phosphorRegular.name;
        }
        if (root.packId === "lucide")
            return lucideFont.name;
        return materialFont.name;
    }

    function idForLabel(label) {
        return Packs.idForLabel(label);
    }

    function labelForId(id) {
        return Packs.labelForId(id);
    }
}

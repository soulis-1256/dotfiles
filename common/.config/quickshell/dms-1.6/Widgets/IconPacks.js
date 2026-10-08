.pragma library

.import "./PhosphorMap.js" as Phosphor
.import "./LucideMap.js" as Lucide

// UI glyph packs for DankIcon.
//
// Adding a pack:
//   1. Drop fonts in assets/fonts/<pack-id>/
//   2. Add a map JS file (or reuse identityResolve if names already match)
//   3. Push an entry into PACKS below (opticalScale is optional; default 1)
//   4. Add FontLoader(s) and a family() branch in Common/IconPackService.qml
//
// Widgets keep using Material Symbols names as canonical IDs. Packs translate
// those IDs at render time, so switching packs never requires rewriting QML.

function identityResolve(name) {
    return name || "";
}

function phosphorResolve(name, role) {
    return Phosphor.resolve(name);
}

function phosphorOpticalScale(name) {
    return Phosphor.opticalScale(name);
}

function lucideResolve(name, role) {
    return Lucide.resolve(name);
}

function lucideOpticalScale(name) {
    return Lucide.opticalScale(name);
}

function lucideFontRole(filled, weight) {
    return "regular";
}

function phosphorFontRole(filled, weight) {
    if (filled)
        return "fill";
    if (weight >= 600)
        return "bold";
    return "regular";
}

function materialFontRole(filled, weight) {
    return "regular";
}

var PACKS = [
    {
        id: "lucide",
        label: "Lucide",
        description: "Lucide Icons — consistent stroke set, Feather fork",
        kind: "static",
        resolve: lucideResolve,
        fontRole: lucideFontRole,
        opticalScale: lucideOpticalScale
    },
    {
        id: "phosphor",
        label: "Phosphor",
        description: "Phosphor Icons — the phosphor-react glyph set",
        kind: "static",
        resolve: phosphorResolve,
        fontRole: phosphorFontRole,
        opticalScale: phosphorOpticalScale
    },
    {
        id: "material",
        label: "Material Symbols",
        description: "Google Material Symbols Rounded — original DMS glyphs",
        kind: "variable",
        resolve: identityResolve,
        fontRole: materialFontRole
    }
];

function list() {
    return PACKS;
}

function labels() {
    var out = [];
    for (var i = 0; i < PACKS.length; i++)
        out.push(PACKS[i].label);
    return out;
}

function getPack(id) {
    for (var i = 0; i < PACKS.length; i++) {
        if (PACKS[i].id === id)
            return PACKS[i];
    }
    return PACKS[0];
}

function idForLabel(label) {
    for (var i = 0; i < PACKS.length; i++) {
        if (PACKS[i].label === label)
            return PACKS[i].id;
    }
    return PACKS[0].id;
}

function labelForId(id) {
    return getPack(id).label;
}

function resolveGlyph(packId, name, filled, weight) {
    var pack = getPack(packId);
    var role = fontRole(packId, filled, weight);
    return pack.resolve(name, role);
}

function opticalScale(packId, name) {
    var pack = getPack(packId);
    if (pack.opticalScale)
        return pack.opticalScale(name);
    return 1;
}

function usesVariableAxes(packId) {
    return getPack(packId).kind === "variable";
}

function fontRole(packId, filled, weight) {
    var pack = getPack(packId);
    if (pack.fontRole)
        return pack.fontRole(filled, weight);
    return "regular";
}

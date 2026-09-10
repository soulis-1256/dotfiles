"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

function loadPragmaJs(filePath) {
    const src = fs.readFileSync(filePath, "utf8").replace(/^\.pragma library\s*/, "");
    const ctx = { console: console, Math: Math, Number: Number, Object: Object, isFinite: isFinite };
    vm.createContext(ctx);
    vm.runInContext(src, ctx);
    return ctx;
}

const lib = loadPragmaJs(path.join(__dirname, "PinGrid.js"));
const libPath = path.join(__dirname, "PinGrid.js");
const originalPath = path.join(__dirname, "../windows-11/plugins/win11Start/PinGrid.js");
const originalIsLib = fs.existsSync(originalPath) && fs.realpathSync(originalPath) === fs.realpathSync(libPath);
const original = (fs.existsSync(originalPath) && !originalIsLib) ? loadPragmaJs(originalPath) : null;

const WIN11 = { cols: 12, uniformMedium: true };
const WIN10 = { cols: 6 };

let failed = 0;
let passed = 0;

function assert(cond, msg, extra) {
    if (cond) {
        passed++;
        return;
    }
    failed++;
    console.error("FAIL:", msg);
    if (extra !== undefined)
        console.error("     ", extra);
}

function deepEq(a, b) {
    return JSON.stringify(a) === JSON.stringify(b);
}

function pin(id, extra) {
    return Object.assign({ id: id, name: id, size: "medium", wide: false, isFolder: false }, extra || {});
}

function folder(id) {
    return { id: id, name: id, size: "medium", wide: false, isFolder: true, tiles: [] };
}

function pack11(list) {
    return lib.pack(list, WIN11);
}

function pack10(list) {
    return lib.pack(list, WIN10);
}

function resolve11(params) {
    return lib.resolveDropTarget(Object.assign({}, WIN11, params));
}

function resolve10(params) {
    return lib.resolveDropTarget(Object.assign({}, WIN10, params));
}

function slotPixel(idx) {
    return { x: (idx % 6) * 98, y: Math.floor(idx / 6) * 98 };
}

// --- pack: Win11 sequential medium slots ---
{
    const packed = pack11([pin("A"), pin("B"), pin("C"), pin("D"), pin("E"), pin("F"), pin("G")]);
    const cols = packed.map(function (t) { return t.col; });
    const rows = packed.map(function (t) { return t.row; });
    assert(deepEq(cols, [0, 2, 4, 6, 8, 10, 0]), "Win11 pack cols", cols);
    assert(deepEq(rows, [0, 0, 0, 0, 0, 0, 2]), "Win11 pack rows", rows);
    packed.forEach(function (t) {
        assert(t.size === "medium" && t.wCells === 2 && t.hCells === 2, "Win11 pack forces medium " + t.id);
    });
}

// pack preserves array order (does not sort by geometry)
{
    const packed = pack11([
        Object.assign(pin("C"), { col: 4, row: 0 }),
        Object.assign(pin("A"), { col: 0, row: 0 }),
        Object.assign(pin("B"), { col: 2, row: 0 })
    ]);
    assert(deepEq(packed.map(function (t) { return t.id; }), ["C", "A", "B"]), "pack keeps array order");
    assert(deepEq(packed.map(function (t) { return t.col; }), [0, 2, 4]), "pack first-fit from order, not saved col");
}

// splice then pack: [B, A, F1, C]
{
    const remaining = pack11([pin("B"), pin("A"), pin("F1"), pin("C")]);
    assert(deepEq(remaining.map(function (t) { return t.id; }), ["B", "A", "F1", "C"]), "splice order");
    assert(remaining[0].col === 0 && remaining[1].col === 2 && remaining[2].col === 4 && remaining[3].col === 6, "splice cells");
}

// --- one-slot-right: only B displaces ---
{
    const model = pack11([pin("A"), pin("B"), pin("C")]);
    const items = lib.otherItems(model, "A", true);
    const d = lib.computeDisplacement(items, 1, true, 0, pin("A"), WIN11);
    assert(!!d.B && d.B.x === 0 && d.B.y === 0, "B slides into A's hole", d);
    assert(!d.C, "C does not move when A inserts after B", d);
}

// --- 29 / 50 / 71% of TILE on neighbor pin ---
{
    const model = pack11([pin("steam"), pin("scrcpy"), pin("F1"), pin("C")]);
    const items = lib.otherItems(model, "steam", true);
    const origin = slotPixel(1); // scrcpy visual after lifting steam (hole at 0)
    const ts = [0.29, 0.50, 0.71];
    const got = ts.map(function (t) {
        return resolve11({
            lx: origin.x + t * lib.TILE,
            ly: origin.y + 40,
            items: items,
            draggedTile: pin("steam"),
            sourceIndex: 0,
            prevInsertIndex: 0,
            prevDropType: "reorder"
        });
    });
    assert(got[0].dropType === "reorder" && got[0].targetIndex === 0, "29% left = reorder 0", got[0]);
    assert(got[1].dropType === "create-folder" && got[1].tileId === "scrcpy" && got[1].targetIndex === 0, "50% = create-folder, hole frozen", got[1]);
    assert(got[2].dropType === "reorder" && got[2].targetIndex === 1, "71% right = reorder 1", got[2]);
}

// gutter of neighbor pin (x=98+95) is insert-after, not a snap-back
{
    const model = pack11([pin("steam"), pin("scrcpy"), pin("F1")]);
    const items = lib.otherItems(model, "steam", true);
    const r = resolve11({
        lx: 98 + 95,
        ly: 40,
        items: items,
        draggedTile: pin("steam"),
        sourceIndex: 0,
        prevInsertIndex: 1,
        prevDropType: "reorder"
    });
    assert(r.dropType === "reorder" && r.targetIndex === 1, "gutter x=95 on scrcpy slot stays insert 1", r);
}

// after shuffle to insert 1, sweeping original scrcpy slot (now the hole) stays reorder 1
{
    const model = pack11([pin("steam"), pin("scrcpy"), pin("F1")]);
    const items = lib.otherItems(model, "steam", true);
    const scrcpy = slotPixel(1);
    const ts = [0.10, 0.50, 0.90];
    ts.forEach(function (t) {
        const r = resolve11({
            lx: scrcpy.x + t * lib.TILE,
            ly: scrcpy.y + 40,
            items: items,
            draggedTile: pin("steam"),
            sourceIndex: 0,
            prevInsertIndex: 1,
            prevDropType: "reorder"
        });
        assert(r.dropType === "reorder" && r.targetIndex === 1, "hole sweep t=" + t + " stays reorder 1", r);
        assert(r.displacedMap.scrcpy && r.displacedMap.scrcpy.x === 0, "scrcpy stays displaced at hole sweep t=" + t, r.displacedMap);
    });
}

// add-to-folder on folder center freezes hole (F1 has slid into slot 0)
{
    const model = pack11([pin("A"), folder("F1"), pin("C")]);
    const items = lib.otherItems(model, "A", true);
    const r = resolve11({
        lx: slotPixel(0).x + 0.5 * lib.TILE,
        ly: 40,
        items: items,
        draggedTile: pin("A"),
        sourceIndex: 0,
        prevInsertIndex: 1,
        prevDropType: "reorder"
    });
    assert(r.dropType === "add-to-folder" && r.folderId === "F1" && r.targetIndex === 1, "add-to-folder freezes hole", r);
}

// follow B after shuffle: create-folder, hole stays 1
{
    const model = pack11([pin("A"), pin("B"), pin("C")]);
    const items = lib.otherItems(model, "A", true);
    const r = resolve11({
        lx: slotPixel(0).x + 0.5 * lib.TILE,
        ly: 40,
        items: items,
        draggedTile: pin("A"),
        sourceIndex: 0,
        prevInsertIndex: 1,
        prevDropType: "reorder"
    });
    assert(r.dropType === "create-folder" && r.tileId === "B" && r.targetIndex === 1, "create-folder on B keeps hole 1", r);
}

// folder-as-dragged is always reorder, never nested folder
{
    const model = pack11([folder("F"), pin("A"), pin("B")]);
    const items = lib.otherItems(model, "F", true);
    const r = resolve11({
        lx: slotPixel(1).x + 0.5 * lib.TILE,
        ly: 40,
        items: items,
        draggedTile: folder("F"),
        sourceIndex: 0,
        prevInsertIndex: 0,
        prevDropType: "reorder"
    });
    assert(r.dropType === "reorder", "folder drag never folders", r);
}

// wrap of F then pointer on old G body stays insert 6
{
    const ids = ["A", "B", "C", "D", "E", "F", "G", "H"];
    const model = pack11(ids.map(function (id) { return pin(id); }));
    const items = lib.otherItems(model, "X-new", false); // dragging in from outside, 8 items stay
    // Use G as dragged from index 6
    const remaining = lib.otherItems(model, "G", true);
    const oldG = slotPixel(6);
    const r = resolve11({
        lx: oldG.x + 40,
        ly: oldG.y + 40,
        items: remaining,
        draggedTile: pin("G"),
        sourceIndex: 6,
        prevInsertIndex: 6,
        prevDropType: "reorder"
    });
    assert(r.dropType === "reorder" && r.targetIndex === 6, "pointer on old G body (hole) stays insert 6", r);
    assert(items.length === 8, "sanity otherItems without exclude");
}

// inFolderBand hysteresis: sticky widens 0.3±0.04
{
    assert(lib.inFolderBand(0.31 * lib.TILE, false, lib.TILE) === true, "0.31 TILE is folder");
    assert(lib.inFolderBand(0.29 * lib.TILE, false, lib.TILE) === false, "0.29 TILE is reorder");
    assert(lib.inFolderBand(0.27 * lib.TILE, true, lib.TILE) === true, "sticky still folder at 0.27");
    assert(lib.inFolderBand(0.25 * lib.TILE, true, lib.TILE) === false, "sticky drops folder below 0.26");
}

// --- Win10 mixed sizes ---
{
    const packed = pack10([
        { id: "zen", size: "wide", wide: true },
        { id: "dolphin", size: "medium" },
        { id: "tiny", size: "small" },
        { id: "store", size: "large", wide: true }
    ]);
    assert(packed[0].id === "zen" && packed[0].wCells === 4 && packed[0].col === 0 && packed[0].row === 0, "wide first row", packed[0]);
    assert(packed[1].id === "dolphin" && packed[1].wCells === 2 && packed[1].col === 4 && packed[1].row === 0, "medium fills remainder of row 0", packed[1]);
    assert(packed[2].id === "tiny" && packed[2].wCells === 1 && packed[2].col === 0 && packed[2].row === 2, "small starts next band", packed[2]);
    assert(packed[3].id === "store" && packed[3].wCells === 4 && packed[3].hCells === 4, "large keeps 4x4", packed[3]);
    assert(packed[3].col === 2 && packed[3].row === 2, "large first-fits beside small", packed[3]);
}

// Win10: 30/40/30 uses each item's visual width (wide = 190)
{
    const model = pack10([
        { id: "zen", size: "wide", wide: true },
        { id: "dolphin", size: "medium" }
    ]);
    const items = lib.otherItems(model, "steam", false);
    const zen = lib.cellToPixel(0, 0);
    const left = resolve10({
        lx: zen.x + 0.29 * 190,
        ly: zen.y + 40,
        items: items,
        draggedTile: pin("steam"),
        sourceIndex: -1,
        prevInsertIndex: 2,
        prevDropType: "reorder"
    });
    const mid = resolve10({
        lx: zen.x + 0.50 * 190,
        ly: zen.y + 40,
        items: items,
        draggedTile: pin("steam"),
        sourceIndex: -1
    });
    const right = resolve10({
        lx: zen.x + 0.71 * 190,
        ly: zen.y + 40,
        items: items,
        draggedTile: pin("steam"),
        sourceIndex: -1
    });
    assert(left.dropType === "reorder" && left.targetIndex === 0, "wide 29% insert before zen", left);
    assert(mid.dropType === "create-folder" && mid.tileId === "zen", "wide 50% create-folder", mid);
    assert(right.dropType === "reorder" && right.targetIndex === 1, "wide 71% insert after zen", right);
}

// Win10: hole is dragged size (wide placeholder)
{
    const model = pack10([pin("A"), pin("B"), pin("C")]);
    const items = lib.otherItems(model, "wideApp", false);
    const vis = lib.layoutWithHole(items, 1, { id: "wideApp", size: "wide", wide: true }, WIN10);
    assert(vis.hole && vis.hole.wCells === 4 && vis.hole.hCells === 2, "hole takes dragged wide size", vis.hole);
    assert(vis.map.A && vis.map.A.col === 0, "A stays first", vis.map.A);
    assert(vis.map.B && vis.map.B.row >= 2, "B wraps because wide hole occupies 4 cells", vis.map.B);
}

// Win10: drop commit is splice + pack, size preserved
{
    const remaining = pack10([
        { id: "dolphin", size: "medium" },
        { id: "tiny", size: "small" }
    ]);
    remaining.splice(1, 0, { id: "zen", size: "wide", wide: true });
    const packed = pack10(remaining);
    assert(deepEq(packed.map(function (t) { return t.id; }), ["dolphin", "zen", "tiny"]), "commit keeps splice order");
    assert(packed[1].size === "wide" && packed[1].wCells === 4, "commit preserves wide");
    assert(packed[2].size === "small" && packed[2].wCells === 1, "commit preserves small");
}

// sortByGeometry then pack compacts saved gaps (Win10 load path)
{
    const saved = [
        Object.assign(pin("A"), { col: 0, row: 0 }),
        Object.assign(pin("B"), { col: 4, row: 2 })
    ];
    const packed = pack10(lib.sortByGeometry(saved, WIN10));
    assert(packed[0].id === "A" && packed[1].id === "B", "geometry order");
    assert(packed[1].col === 2 && packed[1].row === 0, "gap compacted", packed[1]);
}

// Compare lib vs original Win11 engine while the old file still exists
if (original) {
    const model = original.pack([pin("steam"), pin("scrcpy"), pin("F1"), pin("C")]);
    const items = original.otherItems(model, "steam", true);
    const probes = [
        { t: 0.29, ly: 40 },
        { t: 0.50, ly: 40 },
        { t: 0.71, ly: 40 },
        { t: 95 / 92, ly: 40, absX: 98 + 95 },
        { t: 0.10, ly: 40, prev: 1 },
        { t: 0.90, ly: 40, prev: 1 }
    ];
    probes.forEach(function (p) {
        const origin = slotPixel(1);
        const lx = (typeof p.absX === "number") ? p.absX : (origin.x + p.t * 92);
        const params = {
            lx: lx,
            ly: origin.y + p.ly,
            items: items,
            draggedTile: pin("steam"),
            sourceIndex: 0,
            prevInsertIndex: (typeof p.prev === "number") ? p.prev : 0,
            prevDropType: "reorder"
        };
        const a = original.resolveDropTarget(params);
        const b = resolve11(params);
        assert(a.dropType === b.dropType && a.targetIndex === b.targetIndex && a.tileId === b.tileId,
            "lib matches original Win11 " + JSON.stringify({ t: p.t, prev: p.prev, absX: p.absX, a: a.dropType + ":" + a.targetIndex, b: b.dropType + ":" + b.targetIndex }));
    });
}

// --- folder overlay geometry ---
{
    const slot0 = lib.folderSlotToPixel(0);
    const slot4 = lib.folderSlotToPixel(4);
    assert(slot0.x === 0 && slot0.y === 0, "folder slot 0 origin", slot0);
    assert(slot4.x === 98 && slot4.y === 98, "folder slot 4 is col1 row1", slot4);
    assert(lib.folderOverlayHeight(0) === lib.folderOverlayHeight(1), "empty folder still one row");
    assert(lib.folderGridHeight(4) === 2 * lib.PITCH, "4 tiles = 2 folder rows");
    assert(lib.folderSlotFromPoint(6, 36, 5, false) === 0, "top-left is slot 0");
    assert(lib.folderSlotFromPoint(6 + 98 + 10, 36 + 10, 5, false) === 1, "second column is slot 1");
    assert(lib.folderSlotFromPoint(6 + 98 * 2, 36 + 98, 3, true) === 2, "from-folder clamps to last child", lib.folderSlotFromPoint(6 + 98 * 2, 36 + 98, 3, true));
    assert(lib.folderSlotFromPoint(6 + 98 * 2, 36 + 98, 3, false) === 3, "drop-in can use empty slot 3");

    const shiftRight = lib.folderTileDisplacement(1, 0, -1);
    assert(shiftRight.x === 98 && shiftRight.y === 0, "incoming drop shifts later tiles right", shiftRight);
    const noMove = lib.folderTileDisplacement(0, 2, 0);
    assert(noMove.x === 0 && noMove.y === 0, "dragged folder child does not displace itself", noMove);
}

// --- folder overlay placement ---
{
    const centered = lib.folderOverlayPos(0, 0, 300, 142, 640, 500, 0, 0, 16, 12, false);
    assert(centered.x >= 8 && centered.y >= 8, "centered overlay stays on-pane", centered);
    const group = lib.folderOverlayPos(4, 0, 300, 142, 320, 500, 0, 0, 16, 12, true);
    assert(group.x === 10, "alignGroup pins overlay to group column", group);
    const scrolled = lib.folderOverlayPos(0, 2, 300, 142, 320, 500, 0, 98, 16, 12, true);
    assert(scrolled.y === 12, "scrolled row 2 sits at pad-top", scrolled);
}

// --- folder list ops ---
{
    const a = pin("A");
    const b = pin("B");
    const f = lib.makeFolder("Apps", [a], "F1");
    assert(f.isFolder && f.tiles.length === 1 && f.name === "Apps", "makeFolder", f);
    assert(lib.findFolder([[f], []], "F1") === f, "findFolder in first group");
    assert(lib.findFolder([[], [f]], "missing") === null, "findFolder miss");

    const child = lib.toFolderChild(pin("C", { size: "wide", wide: true, icon: "x" }));
    assert(child.size === "medium" && child.wide === false && child.isFolder === false && child.icon === "x", "toFolderChild flattens", child);

    const replaced = lib.replaceTileWithFolder([a, b], a, "Group");
    assert(replaced.replaced && replaced.list[0].isFolder && replaced.list[0].tiles[0].id === "A" && replaced.list[1].id === "B", "replaceTileWithFolder", replaced.list);

    const added = lib.addTileToFolder([f, b], b, "F1");
    assert(added.length === 1 && added[0].tiles.length === 2 && added[0].tiles[1].id === "B", "addTileToFolder moves pin in", added);

    const removed = lib.removeTileFromFolder(added, "A", "F1");
    assert(removed.found && removed.list[0].tiles.length === 1 && removed.list[0].tiles[0].id === "B", "removeTileFromFolder", removed.list);

    const unpacked = lib.ungroupFolder([added[0]], "F1");
    assert(unpacked.length === 2 && unpacked[0].id === "A" && unpacked[1].id === "B", "ungroupFolder splices children", unpacked.map(function (t) { return t.id; }));
}

console.log("passed", passed, "failed", failed);
process.exit(failed ? 1 : 0);
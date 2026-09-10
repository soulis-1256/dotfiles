.pragma library

// Win11 pinned-grid engine. Uniform medium tiles, 6-column packed list.
// Drop targeting copies WinUI GridViewItem::IsDragOver (30/40/30 on X).
// Hit-test uses the on-screen pin after the current hole, not the pre-shuffle slot.

var CELL = 49
var PITCH = 98
var TILE = 92
var TILE_CELLS = 2
var COLS = 12
var TILE_COLS = 6
var FLOW_PAD_TOP = 12
var FLOW_PAD_LEFT = 16
var VISIBLE_ROWS = 5
var CHROME_HEIGHT = 170
var FOLDER_HIT_RATIO = 0.34
var FOLDER_HIT_MIN = 18
var GRIDVIEW_DRAGOVER_OUTSIDE = 0.3
var GRIDVIEW_DRAGOVER_HYST = 0.04

function chromeHeight() {
    return CHROME_HEIGHT
}

function paneHeight(rows) {
    var n = (typeof rows === "number" && rows > 0) ? rows : VISIBLE_ROWS
    return FLOW_PAD_TOP + n * PITCH
}

function homeHeight(rows) {
    return chromeHeight() + paneHeight(rows)
}

function cellNum(v) {
    var n = Number(v)
    return isFinite(n) ? n : 0
}

function cellToPixel(c, r) {
    c = cellNum(c)
    r = cellNum(r)
    return {
        "x": Math.floor(c / 2) * PITCH + (c % 2) * CELL,
        "y": Math.floor(r / 2) * PITCH + (r % 2) * CELL
    }
}

function readingKey(row, col) {
    return cellNum(row) * COLS + cellNum(col)
}

function rectsOverlap(c1, r1, w1, h1, c2, r2, w2, h2) {
    return (c1 < c2 + w2 && c1 + w1 > c2 && r1 < r2 + h2 && r1 + h1 > r2)
}

function slotIndex(col, row) {
    return Math.floor(cellNum(row) / TILE_CELLS) * TILE_COLS + Math.floor(cellNum(col) / TILE_CELLS)
}

function slotPos(idx) {
    idx = Math.max(0, idx)
    return {
        "x": (idx % TILE_COLS) * TILE_CELLS,
        "y": Math.floor(idx / TILE_COLS) * TILE_CELLS
    }
}

function slotPixel(idx) {
    idx = Math.max(0, idx)
    return {
        "x": (idx % TILE_COLS) * PITCH,
        "y": Math.floor(idx / TILE_COLS) * PITCH
    }
}

function contentPixelHeight(model) {
    var maxH = TILE
    var list = model || []
    for (var i = 0; i < list.length; i++) {
        var it = list[i]
        if (!it)
            continue
        var p = cellToPixel(it.col, it.row)
        if (p.y + TILE > maxH)
            maxH = p.y + TILE
    }
    return maxH
}

function flickContentHeight(tileContentH, paneH) {
    var rows = Math.max(1, Math.ceil(Math.max(0, tileContentH) / PITCH))
    var h = FLOW_PAD_TOP + rows * PITCH
    return Math.max(paneH, h)
}

function wheelDelta(pixelY, angleY) {
    if (pixelY)
        return pixelY > 0 ? -PITCH : PITCH
    if (angleY)
        return angleY > 0 ? -PITCH : PITCH
    return 0
}

function snapContentY(y, maxY) {
    var cap = Math.max(0, maxY || 0)
    var snapped = Math.round((y || 0) / PITCH) * PITCH
    if (snapped < 0)
        snapped = 0
    if (snapped > cap)
        snapped = cap
    return snapped
}

function folderOverlayPos(col, row, overlayW, overlayH, paneW, paneH, contentX, contentY, padLeft, padTop) {
    var pad = 8
    var origin = cellToPixel(col, row)
    var tileX = (typeof padLeft === "number" ? padLeft : FLOW_PAD_LEFT) + origin.x - (contentX || 0)
    var tileY = (typeof padTop === "number" ? padTop : FLOW_PAD_TOP) + origin.y - (contentY || 0)
    var x = tileX + (TILE - overlayW) / 2
    var y = tileY
    var maxX = Math.max(pad, paneW - overlayW - pad)
    var maxY = Math.max(pad, paneH - overlayH - pad)
    return {
        "x": Math.max(pad, Math.min(maxX, x)),
        "y": Math.max(pad, Math.min(maxY, y))
    }
}

function folderOverlayHeight(tileCount) {
    var rows = Math.max(1, Math.ceil((tileCount || 0) / 3))
    return 36 + rows * PITCH + 8
}

function folderGridHeight(tileCount) {
    var rows = Math.max(1, Math.ceil((tileCount || 0) / 3))
    return rows * PITCH
}

// Sequential 6-column packing. Preserves array order — the list is the model.
function pack(list) {
    if (!list || list.length === 0)
        return []
    var result = []
    for (var i = 0; i < list.length; i++) {
        if (!list[i])
            continue
        var it = Object.assign({}, list[i])
        it.size = "medium"
        it.wide = false
        it.wCells = TILE_CELLS
        it.hCells = TILE_CELLS
        var p = slotPos(result.length)
        it.col = p.x
        it.row = p.y
        result.push(it)
    }
    return result
}

function sortByGeometry(list) {
    return (list || []).slice().sort(function(a, b) {
        return readingKey(a.row, a.col) - readingKey(b.row, b.col)
    })
}

function otherItems(model, draggedId, excludeDragged) {
    var list = []
    var src = model || []
    for (var i = 0; i < src.length; i++) {
        var it = src[i]
        if (!it)
            continue
        if (excludeDragged && draggedId && it.id === draggedId)
            continue
        list.push(it)
    }
    return list
}

function hasTileAt(items, c, r, w, h) {
    if (!items || items.length === 0)
        return false
    w = w || TILE_CELLS
    h = h || TILE_CELLS
    for (var i = 0; i < items.length; i++) {
        var it = items[i]
        var ic = cellNum(it.col)
        var ir = cellNum(it.row)
        if (rectsOverlap(ic, ir, it.wCells || TILE_CELLS, it.hCells || TILE_CELLS, c, r, w, h))
            return true
    }
    return false
}

function clampInsert(k, n) {
    if (k < 0)
        return 0
    if (k > n)
        return n
    return k
}

// Remaining item i sits at this slot while the hole is at `hole`.
function visualSlot(i, hole) {
    return (i >= hole) ? (i + 1) : i
}

function baseSlot(i, hasSource, sourceIndex) {
    return (hasSource && i >= sourceIndex) ? (i + 1) : i
}

// Range-shift: remaining items packed around `targetIndex` vs the source hole.
function computeDisplacement(items, targetIndex, hasSource, sourceIndex) {
    if (!items || items.length === 0)
        return {}
    var n = items.length
    var hole = clampInsert(targetIndex, n)
    var res = {}
    for (var i = 0; i < n; i++) {
        var it = items[i]
        if (!it || !it.id)
            continue
        var dest = visualSlot(i, hole)
        var base = baseSlot(i, hasSource, sourceIndex)
        if (dest !== base) {
            var p = slotPos(dest)
            res[it.id] = { "x": p.x, "y": p.y }
        }
    }
    return res
}

function inFolderBand(localX, sticky) {
    var lo = GRIDVIEW_DRAGOVER_OUTSIDE
    var hi = 1 - GRIDVIEW_DRAGOVER_OUTSIDE
    if (sticky) {
        lo -= GRIDVIEW_DRAGOVER_HYST
        hi += GRIDVIEW_DRAGOVER_HYST
    }
    // Center 40% of the visible pin (WinUI GridViewItem IsDragOver). Gutter
    // past TILE is outside the pin, so it cannot be a folder hit.
    var t = localX / TILE
    return t > lo && t < hi
}

function finishReorder(result, items, insertIndex, hasSource, sourceIndex, fromFolder) {
    var n = items.length
    insertIndex = clampInsert(insertIndex, n)
    var p = slotPos(insertIndex)
    result.dropType = "reorder"
    result.targetIndex = insertIndex
    result.targetCol = p.x
    result.targetRow = p.y
    result.folderId = ""
    result.tileId = ""
    result.stickyId = ""
    result.badge = fromFolder ? "Move out of folder" : ""
    result.displacedMap = computeDisplacement(items, insertIndex, hasSource, sourceIndex)
    return result
}

function finishFolder(result, hit, insertIndex, items, hasSource, sourceIndex, dropType, badge) {
    var vis = slotPos(visualSlot(hit.index, insertIndex))
    result.dropType = dropType
    result.targetIndex = insertIndex
    result.targetCol = vis.x
    result.targetRow = vis.y
    result.tileId = hit.item.id
    result.folderId = (dropType === "add-to-folder") ? hit.item.id : ""
    result.stickyId = hit.item.id
    result.hoverId = hit.item.id
    result.badge = badge
    result.displacedMap = computeDisplacement(items, insertIndex, hasSource, sourceIndex)
    return result
}

// Pointer over the on-screen pin (after the current hole), then 30/40/30 on X.
// Center band is folder and freezes the hole. Outer bands splice the packed list.
function resolveDropTarget(params) {
    var items = params.items || []
    var n = items.length
    var dragged = params.draggedTile
    var draggingFolder = !!(dragged && dragged.isFolder)
    var lx = cellNum(params.lx)
    var ly = cellNum(params.ly)
    var fromFolder = !!params.fromFolder
    var hasSource = (typeof params.sourceIndex === "number" && params.sourceIndex >= 0)
    var sourceIndex = hasSource ? params.sourceIndex : -1

    var visInsert = hasSource ? sourceIndex : n
    var prevType = params.prevDropType || ""
    if (prevType === "reorder" || prevType === "add-to-folder" || prevType === "create-folder") {
        if (typeof params.prevInsertIndex === "number" && params.prevInsertIndex >= 0)
            visInsert = clampInsert(params.prevInsertIndex, n)
    }

    var result = {
        dropType: "reorder",
        targetIndex: visInsert,
        folderId: "",
        tileId: "",
        targetCol: 0,
        targetRow: 0,
        badge: fromFolder ? "Move out of folder" : "",
        hoverId: "",
        hoverSince: 0,
        stickyId: "",
        displacedMap: {}
    }

    // Hit the on-screen cell (PITCH), not the pre-shuffle model slot. The 6px
    // gutter belongs to that pin so it cannot snap the hole backward.
    var hit = null
    var i
    for (i = 0; i < n; i++) {
        var it = items[i]
        if (!it)
            continue
        var sp = slotPixel(visualSlot(i, visInsert))
        var localX = lx - sp.x
        var localY = ly - sp.y
        if (localX >= 0 && localX < PITCH && localY >= 0 && localY < PITCH) {
            hit = { "index": i, "item": it, "localX": localX, "localY": localY }
            break
        }
    }

    if (hit && !draggingFolder) {
        var sticky = (params.stickyId === hit.item.id)
        if (inFolderBand(hit.localX, sticky)) {
            if (hit.item.isFolder)
                return finishFolder(result, hit, visInsert, items, hasSource, sourceIndex, "add-to-folder", "Add to folder")
            return finishFolder(result, hit, visInsert, items, hasSource, sourceIndex, "create-folder", "Drop to create folder")
        }
        var insertAt = (hit.localX / TILE < 0.5) ? hit.index : (hit.index + 1)
        return finishReorder(result, items, insertAt, hasSource, sourceIndex, fromFolder)
    }

    if (hit && draggingFolder) {
        var folderInsert = (hit.localX / TILE < 0.5) ? hit.index : (hit.index + 1)
        return finishReorder(result, items, folderInsert, hasSource, sourceIndex, fromFolder)
    }

    var holePx = slotPixel(visInsert)
    if (lx >= holePx.x && lx < holePx.x + PITCH && ly >= holePx.y && ly < holePx.y + PITCH)
        return finishReorder(result, items, visInsert, hasSource, sourceIndex, fromFolder)

    var col = Math.max(0, Math.min(TILE_COLS - 1, Math.floor(Math.max(0, lx) / PITCH)))
    var row = Math.max(0, Math.floor(Math.max(0, ly) / PITCH))
    var slot = row * TILE_COLS + col
    return finishReorder(result, items, slot, hasSource, sourceIndex, fromFolder)
}

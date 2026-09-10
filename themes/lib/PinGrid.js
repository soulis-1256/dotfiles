.pragma library

// Packed pin-grid engine. Ordered list is the model; pack() only assigns cells.
// Drop targeting is WinUI GridViewItem::IsDragOver (30/40/30 on X) against the
// on-screen pin after the hole, not the pre-shuffle slot.
//
// Layout numbers (cell size, default 12-col / 6 medium tiles) match the Win11
// pin grid. A theme with a narrower group passes { cols: 6 } and keeps tile
// sizes (small/medium/wide/large). uniformMedium: true forces 2x2 tiles.

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
var HOLE_ID = "__pin_hole__"

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

function gridOpts(params) {
    params = params || {}
    var cols = cellNum(params.cols)
    if (cols <= 0)
        cols = COLS
    return {
        "cols": cols,
        "uniformMedium": !!params.uniformMedium
    }
}

function cellToPixel(c, r) {
    c = cellNum(c)
    r = cellNum(r)
    return {
        "x": Math.floor(c / 2) * PITCH + (c % 2) * CELL,
        "y": Math.floor(r / 2) * PITCH + (r % 2) * CELL
    }
}

function readingKey(row, col, cols) {
    cols = (typeof cols === "number" && cols > 0) ? cols : COLS
    return cellNum(row) * cols + cellNum(col)
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

function tileMetrics(it, opts) {
    opts = opts || {}
    if (opts.uniformMedium || !it)
        return { "size": "medium", "wCells": TILE_CELLS, "hCells": TILE_CELLS, "width": TILE, "height": TILE }
    var size = it.size || (it.wide ? "wide" : "medium")
    if (size === "small")
        return { "size": "small", "wCells": 1, "hCells": 1, "width": 43, "height": 43 }
    if (size === "wide")
        return { "size": "wide", "wCells": 4, "hCells": TILE_CELLS, "width": 190, "height": TILE }
    if (size === "large")
        return { "size": "large", "wCells": 4, "hCells": 4, "width": 190, "height": 190 }
    return { "size": "medium", "wCells": TILE_CELLS, "hCells": TILE_CELLS, "width": TILE, "height": TILE }
}

function contentPixelHeight(model, opts) {
    var maxH = TILE
    var list = model || []
    for (var i = 0; i < list.length; i++) {
        var it = list[i]
        if (!it)
            continue
        var p = cellToPixel(it.col, it.row)
        var m = tileMetrics(it, opts)
        if (p.y + m.height > maxH)
            maxH = p.y + m.height
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

// First-fit occupancy in array order. Does not re-sort.
function pack(list, opts) {
    if (!list || list.length === 0)
        return []
    opts = gridOpts(opts)
    var cols = opts.cols
    var occupied = {}
    var result = []

    function canFit(r, c, w, h) {
        if (c < 0 || r < 0 || c + w > cols)
            return false
        var dr, dc
        for (dr = 0; dr < h; dr++) {
            for (dc = 0; dc < w; dc++) {
                if (occupied[(r + dr) + "," + (c + dc)])
                    return false
            }
        }
        return true
    }

    function occupy(r, c, w, h) {
        var dr, dc
        for (dr = 0; dr < h; dr++) {
            for (dc = 0; dc < w; dc++)
                occupied[(r + dr) + "," + (c + dc)] = true
        }
    }

    var i
    for (i = 0; i < list.length; i++) {
        if (!list[i])
            continue
        var it = Object.assign({}, list[i])
        var m = tileMetrics(it, opts)
        it.size = m.size
        it.wide = (m.size === "wide" || m.size === "large")
        it.wCells = m.wCells
        it.hCells = m.hCells
        var w = m.wCells
        var h = m.hCells
        var stepC = (w === 1) ? 1 : TILE_CELLS
        var stepR = (h === 1) ? 1 : TILE_CELLS
        var placed = false
        var r, c
        for (r = 0; r < 400 && !placed; r += stepR) {
            for (c = 0; c <= cols - w && !placed; c += stepC) {
                if (canFit(r, c, w, h)) {
                    it.col = c
                    it.row = r
                    occupy(r, c, w, h)
                    placed = true
                }
            }
        }
        result.push(it)
    }
    return result
}

function sortByGeometry(list, opts) {
    opts = gridOpts(opts)
    var cols = opts.cols
    return (list || []).slice().sort(function(a, b) {
        return readingKey(a.row, a.col, cols) - readingKey(b.row, b.col, cols)
    })
}

function otherItems(model, draggedId, excludeDragged) {
    var list = []
    var src = model || []
    var i
    for (i = 0; i < src.length; i++) {
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
    var i
    for (i = 0; i < items.length; i++) {
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

function visualSlot(i, hole) {
    return (i >= hole) ? (i + 1) : i
}

function baseSlot(i, hasSource, sourceIndex) {
    return (hasSource && i >= sourceIndex) ? (i + 1) : i
}

function layoutWithHole(items, holeIndex, dragged, opts) {
    opts = gridOpts(opts)
    items = items || []
    var n = items.length
    holeIndex = clampInsert(holeIndex, n)
    var m = tileMetrics(dragged, opts)
    var probe = []
    var i
    for (i = 0; i < n; i++) {
        if (i === holeIndex)
            probe.push({ "id": HOLE_ID, "size": m.size, "wide": (m.size === "wide" || m.size === "large"), "wCells": m.wCells, "hCells": m.hCells })
        if (items[i])
            probe.push(items[i])
    }
    if (holeIndex === n)
        probe.push({ "id": HOLE_ID, "size": m.size, "wide": (m.size === "wide" || m.size === "large"), "wCells": m.wCells, "hCells": m.hCells })
    var packed = pack(probe, opts)
    var map = {}
    var hole = null
    for (i = 0; i < packed.length; i++) {
        var it = packed[i]
        if (!it)
            continue
        if (it.id === HOLE_ID)
            hole = it
        else if (it.id)
            map[it.id] = it
    }
    return { "map": map, "hole": hole }
}

function computeDisplacement(items, targetIndex, hasSource, sourceIndex, dragged, opts) {
    if (!items || items.length === 0)
        return {}
    var vis = layoutWithHole(items, targetIndex, dragged, opts)
    var res = {}
    var i
    for (i = 0; i < items.length; i++) {
        var it = items[i]
        if (!it || !it.id)
            continue
        var dest = vis.map[it.id]
        if (!dest)
            continue
        if (cellNum(dest.col) !== cellNum(it.col) || cellNum(dest.row) !== cellNum(it.row))
            res[it.id] = { "x": dest.col, "y": dest.row }
    }
    return res
}

function inFolderBand(localX, sticky, tileWidth) {
    var lo = GRIDVIEW_DRAGOVER_OUTSIDE
    var hi = 1 - GRIDVIEW_DRAGOVER_OUTSIDE
    if (sticky) {
        lo -= GRIDVIEW_DRAGOVER_HYST
        hi += GRIDVIEW_DRAGOVER_HYST
    }
    var w = (typeof tileWidth === "number" && tileWidth > 0) ? tileWidth : TILE
    var t = localX / w
    return t > lo && t < hi
}

function insertIndexAtPoint(lx, ly, items, vis, opts) {
    opts = gridOpts(opts)
    var cols = opts.cols
    var col = Math.max(0, Math.floor(Math.max(0, lx) / CELL))
    var row = Math.max(0, Math.floor(Math.max(0, ly) / CELL))
    if (col >= cols)
        col = cols - 1
    var pk = readingKey(row, col, cols)
    var i
    for (i = 0; i < items.length; i++) {
        var it = items[i]
        if (!it || !it.id)
            continue
        var p = vis.map[it.id]
        if (!p)
            continue
        if (readingKey(p.row, p.col, cols) >= pk)
            return i
    }
    return items.length
}

function finishReorder(result, items, insertIndex, hasSource, sourceIndex, fromFolder, dragged, opts) {
    insertIndex = clampInsert(insertIndex, items.length)
    var vis = layoutWithHole(items, insertIndex, dragged, opts)
    var hole = vis.hole
    result.dropType = "reorder"
    result.targetIndex = insertIndex
    result.targetCol = hole ? hole.col : 0
    result.targetRow = hole ? hole.row : 0
    result.folderId = ""
    result.tileId = ""
    result.stickyId = ""
    result.badge = fromFolder ? "Move out of folder" : ""
    result.displacedMap = computeDisplacement(items, insertIndex, hasSource, sourceIndex, dragged, opts)
    return result
}

function finishFolder(result, hit, insertIndex, items, hasSource, sourceIndex, dropType, badge, dragged, opts) {
    var vis = layoutWithHole(items, insertIndex, dragged, opts)
    var dest = (hit.item && vis.map[hit.item.id]) ? vis.map[hit.item.id] : null
    result.dropType = dropType
    result.targetIndex = insertIndex
    result.targetCol = dest ? dest.col : 0
    result.targetRow = dest ? dest.row : 0
    result.tileId = hit.item.id
    result.folderId = (dropType === "add-to-folder") ? hit.item.id : ""
    result.stickyId = hit.item.id
    result.hoverId = hit.item.id
    result.badge = badge
    result.displacedMap = computeDisplacement(items, insertIndex, hasSource, sourceIndex, dragged, opts)
    return result
}

function hitRect(origin, metrics) {
    return {
        "x": origin.x,
        "y": origin.y,
        "w": metrics.wCells * CELL,
        "h": metrics.hCells * CELL,
        "tileW": metrics.width
    }
}

function resolveDropTarget(params) {
    params = params || {}
    var opts = gridOpts(params)
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

    var vis = layoutWithHole(items, visInsert, dragged, opts)
    var hit = null
    var i
    for (i = 0; i < n; i++) {
        var it = items[i]
        if (!it || !it.id)
            continue
        var dest = vis.map[it.id]
        if (!dest)
            continue
        var m = tileMetrics(it, opts)
        var origin = cellToPixel(dest.col, dest.row)
        var rect = hitRect(origin, m)
        var localX = lx - rect.x
        var localY = ly - rect.y
        if (localX >= 0 && localX < rect.w && localY >= 0 && localY < rect.h) {
            hit = { "index": i, "item": it, "localX": localX, "localY": localY, "tileW": rect.tileW }
            break
        }
    }

    if (hit && !draggingFolder) {
        var sticky = (params.stickyId === hit.item.id)
        if (inFolderBand(hit.localX, sticky, hit.tileW)) {
            if (hit.item.isFolder)
                return finishFolder(result, hit, visInsert, items, hasSource, sourceIndex, "add-to-folder", "Add to folder", dragged, opts)
            return finishFolder(result, hit, visInsert, items, hasSource, sourceIndex, "create-folder", "Drop to create folder", dragged, opts)
        }
        var insertAt = (hit.localX / hit.tileW < 0.5) ? hit.index : (hit.index + 1)
        return finishReorder(result, items, insertAt, hasSource, sourceIndex, fromFolder, dragged, opts)
    }

    if (hit && draggingFolder) {
        var folderInsert = (hit.localX / hit.tileW < 0.5) ? hit.index : (hit.index + 1)
        return finishReorder(result, items, folderInsert, hasSource, sourceIndex, fromFolder, dragged, opts)
    }

    if (vis.hole) {
        var hm = tileMetrics(dragged, opts)
        var holeOrigin = cellToPixel(vis.hole.col, vis.hole.row)
        var holeRect = hitRect(holeOrigin, hm)
        if (lx >= holeRect.x && lx < holeRect.x + holeRect.w && ly >= holeRect.y && ly < holeRect.y + holeRect.h)
            return finishReorder(result, items, visInsert, hasSource, sourceIndex, fromFolder, dragged, opts)
    }

    var slot = insertIndexAtPoint(lx, ly, items, vis, opts)
    return finishReorder(result, items, slot, hasSource, sourceIndex, fromFolder, dragged, opts)
}

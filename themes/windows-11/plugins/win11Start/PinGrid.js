.pragma library

// Win11 pinned-grid engine. Uniform medium tiles only (2x2 cells).
// Occupancy, packing, range-shift displacement, and viewport math.
// Drag timings live in StartDrag.qml (shared with Win10).

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

function cellToPixel(c, r) {
    c = cellNum(c)
    r = cellNum(r)
    return {
        "x": Math.floor(c / 2) * PITCH + (c % 2) * CELL,
        "y": Math.floor(r / 2) * PITCH + (r % 2) * CELL
    }
}

function cellNum(v) {
    var n = Number(v)
    return isFinite(n) ? n : 0
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

function targetCell(lx, ly, prevCol, prevRow) {
    var majorCol = Math.max(0, Math.min(TILE_COLS - 1, Math.floor(Math.max(0, lx) / PITCH)))
    var majorRow = Math.max(0, Math.floor(Math.max(0, ly) / PITCH))
    var c = majorCol * TILE_CELLS
    var r = majorRow * TILE_CELLS
    if (c + TILE_CELLS > COLS)
        c = COLS - TILE_CELLS

    if (typeof prevCol === "number" && typeof prevRow === "number" && prevCol >= 0 && prevRow >= 0) {
        var pc = Math.floor(prevCol / TILE_CELLS)
        var pr = Math.floor(prevRow / TILE_CELLS)
        var cx = pc * PITCH + PITCH / 2
        var cy = pr * PITCH + PITCH / 2
        // Stay on the current slot until the pointer is clearly in the next one.
        if (Math.abs(lx - cx) < PITCH * 0.62 && Math.abs(ly - cy) < PITCH * 0.62)
            return { "x": prevCol, "y": prevRow }
    }
    return { "x": c, "y": r }
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

function folderHitLimit(w, h) {
    return Math.max(FOLDER_HIT_MIN, Math.min(w, h) * FOLDER_HIT_RATIO)
}

// Win10 sticky is "still on this tile" (tile rect + 10px). Packed 6-across
// tiles have almost no gap, so the analog of leaving the tile is leaving
// the folder-create center.
function stillOnSticky(lx, ly, ghostCx, ghostCy, rect) {
    var cx = rect.x + rect.w / 2
    var cy = rect.y + rect.h / 2
    var limit = folderHitLimit(rect.w, rect.h) + 10
    return Math.hypot(lx - cx, ly - cy) <= limit || Math.hypot(ghostCx - cx, ghostCy - cy) <= limit
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
        list.push({
            "id": it.id,
            "size": "medium",
            "width": TILE,
            "height": TILE,
            "wCells": TILE_CELLS,
            "hCells": TILE_CELLS,
            "col": it.col,
            "row": it.row,
            "modelData": it
        })
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

// Occupied slot: left half inserts at this tile (it moves), right half
// inserts after it (it stays, later pins make the gap). Empty slots
// occupy the hole. probeX is in tileFlowItem pixels (pointer or ghost).
function insertCell(other, targetCol, targetRow, probeX) {
    targetCol = cellNum(targetCol)
    targetRow = cellNum(targetRow)
    if (!other || !hasTileAt(other, targetCol, targetRow))
        return { "x": targetCol, "y": targetRow }
    if (typeof probeX !== "number" || !isFinite(probeX))
        return { "x": targetCol, "y": targetRow }
    var origin = cellToPixel(targetCol, targetRow)
    if (probeX < origin.x + PITCH / 2)
        return { "x": targetCol, "y": targetRow }
    var np = slotPos(slotIndex(targetCol, targetRow) + 1)
    return { "x": np.x, "y": np.y }
}

function pack(list) {
    if (!list || list.length === 0)
        return []
    var occupied = {}
    var result = []

    function canFit(r, c, w, h) {
        if (c + w > COLS)
            return false
        for (var dr = 0; dr < h; dr++) {
            for (var dc = 0; dc < w; dc++) {
                if (occupied[(r + dr) + "," + (c + dc)])
                    return false
            }
        }
        return true
    }

    function occupy(r, c, w, h) {
        for (var dr = 0; dr < h; dr++) {
            for (var dc = 0; dc < w; dc++)
                occupied[(r + dr) + "," + (c + dc)] = true
        }
    }

    var sorted = list.slice().sort(function (a, b) {
        return readingKey(a.row, a.col) - readingKey(b.row, b.col)
    })

    for (var i = 0; i < sorted.length; i++) {
        var it = Object.assign({}, sorted[i])
        it.size = "medium"
        it.wide = false
        it.wCells = TILE_CELLS
        it.hCells = TILE_CELLS
        var w = TILE_CELLS
        var h = TILE_CELLS
        var placed = false
        if (typeof it.col === "number" && typeof it.row === "number" && it.col >= 0 && it.col + w <= COLS && it.row >= 0) {
            if (canFit(it.row, it.col, w, h)) {
                occupy(it.row, it.col, w, h)
                placed = true
            }
        }
        if (!placed) {
            var startR = Math.floor(Math.max(0, it.row || 0) / 2) * 2
            var startC = Math.floor(Math.max(0, it.col || 0) / 2) * 2
            for (var r = startR; r < 200 && !placed; r += 2) {
                var cMin = (r === startR) ? startC : 0
                for (var c = cMin; c <= COLS - w && !placed; c += 2) {
                    if (canFit(r, c, w, h)) {
                        it.col = c
                        it.row = r
                        occupy(r, c, w, h)
                        placed = true
                    }
                }
            }
            if (!placed) {
                for (var r2 = 0; r2 < startR && !placed; r2 += 2) {
                    for (var c2 = 0; c2 <= COLS - w && !placed; c2 += 2) {
                        if (canFit(r2, c2, w, h)) {
                            it.col = c2
                            it.row = r2
                            occupy(r2, c2, w, h)
                            placed = true
                        }
                    }
                }
            }
        }
        result.push(it)
    }

    result.sort(function (a, b) {
        return readingKey(a.row, a.col) - readingKey(b.row, b.col)
    })
    return result
}

function displacedMap(other, targetCol, targetRow, probeX, sourceCol, sourceRow) {
    if (!other || other.length === 0)
        return {}

    var insert = insertCell(other, targetCol, targetRow, probeX)
    targetCol = insert.x
    targetRow = insert.y

    // Empty target occupies that hole. Range-shift is only for inserting
    // into an occupied slot — otherwise a tile dragged into a gap (e.g.
    // left of a folder with empty space) pushes every later pin forward.
    if (!hasTileAt(other, targetCol, targetRow))
        return {}

    var targetIdx = slotIndex(targetCol, targetRow)
    var hasSource = (typeof sourceCol === "number" && typeof sourceRow === "number" && sourceCol >= 0 && sourceRow >= 0)
    var sourceIdx = hasSource ? slotIndex(sourceCol, sourceRow) : -1
    var res = {}
    var i, it, idx, np

    if (hasSource) {
        if (sourceIdx === targetIdx)
            return {}
        var lo, hi, dir
        if (sourceIdx < targetIdx) {
            lo = sourceIdx + 1
            hi = targetIdx
            dir = -1
        } else {
            lo = targetIdx
            hi = sourceIdx - 1
            dir = 1
        }
        for (i = 0; i < other.length; i++) {
            it = other[i]
            idx = slotIndex(it.col, it.row)
            if (idx >= lo && idx <= hi) {
                np = slotPos(idx + dir)
                res[it.id] = np
            }
        }
        return res
    }

    var used = {}
    var occupant = null
    for (i = 0; i < other.length; i++) {
        it = other[i]
        idx = slotIndex(it.col, it.row)
        used[idx] = true
        if (idx === targetIdx)
            occupant = it
    }
    if (!occupant)
        return {}

    var hole = targetIdx + 1
    while (used[hole])
        hole++
    for (i = 0; i < other.length; i++) {
        it = other[i]
        idx = slotIndex(it.col, it.row)
        if (idx >= targetIdx && idx < hole) {
            np = slotPos(idx + 1)
            res[it.id] = np
        }
    }
    return res
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

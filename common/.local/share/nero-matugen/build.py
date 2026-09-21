#!/usr/bin/env python3
"""Build ~/.icons/Nero-Matugen XCursor theme from extracted .ani frames.

Recolors the cyan glow family to the live matugen primary
(cursor-color from ghostty dankcolors, same source as Discord/Zen/Ghostty),
preserving S/V/alpha so glow falloff and AA stay pixel-identical.
Red/amber spinners (Busy/Working/Unavailable) are semantic -> untouched.
"""
import colorsys
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

SRC_HUE_CENTER = 184.0
HUE_LO, HUE_HI = 150.0, 240.0
MIN_SAT = 0.05

WIN_TO_X = {
    'Normal': ('left_ptr', ['arrow', 'default', 'top_left_arrow', 'context-menu',
                            'X_cursor', 'x-cursor', 'wayland-cursor', 'center_ptr',
                            'right_ptr']),
    'Busy': ('wait', ['watch', '0426c50838c15042011045643ac1ed18']),
    'Working': ('progress', ['left_ptr_watch', 'half-busy',
                             '00000000000000020006000e7e9ffc3f',
                             '08e8e1c95fe2fc01f976f1e063a24ccd',
                             '3ecb610c1bf2410f44200f48c40d3599']),
    'Link': ('hand2', ['hand1', 'pointer', 'pointing_hand', 'grab', 'openhand',
                       'link', '9d800788f1b08800ae810202380a0822',
                       'e29285e634086352946a0e7090d73106']),
    'Text': ('text', ['xterm', 'ibeam', 'caret', 'vertical-text',
                      '04080000000000000000000000000000']),
    'Precision': ('crosshair', ['cross', 'cell', 'cross_reverse', 'diamond_cross',
                                'tcross', 'zoom-in', 'zoom-out', 'plus', 'color-picker']),
    'Move': ('move', ['fleur', 'size_all', 'all-scroll', 'all-resize', 'grabbing',
                      'closedhand', 'dnd-move', '4498f0e0c1937ffe01fd06f973665830',
                      '9081237383d90e509aa00f00170e968f', 'fcf21c00b30f7e3f83fe0dfd12e71cff']),
    'HoriRes': ('ew-resize', ['col-resize', 'h_double_arrow',
                              'sb_h_double_arrow', 'split_h', 'size_hor',
                              'w-resize', 'e-resize', 'left_side', 'right_side',
                              'left-arrow', 'right-arrow']),
    'VertRes': ('ns-resize', ['row-resize', 'v_double_arrow',
                              'sb_v_double_arrow', 'split_v', 'size_ver',
                              'n-resize', 's-resize', 'top_side', 'bottom_side',
                              'up-arrow', 'down-arrow', 'base_arrow_up', 'base_arrow_down',
                              '00008160000006810000408080010102',
                              '2870a09082c103050b10ffd50204d508']),
    'Help': ('help', ['question_arrow', 'whats_this', 'left_ptr_help', 'dnd-ask',
                      '5c6cd98b3f3ebcb1f9c7f1c204630408', 'd9ce0ab605698f320427677b458ad60b']),
    'Handwrite': ('pencil', ['draft']),
    'Unavailable': ('not-allowed', ['forbidden', 'no-drop', 'dnd-none', 'dnd-no-drop',
                                    'crossed_circle', 'circle', 'pirate',
                                    '03b6e0fcb3499374a867c041f52298f0']),
    'Alternate': ('copy', ['dnd-copy', 'alias', '1081e37283d90000800003c07f3ef6bf',
                           '6407b0e94181790501fd1e167b474872', 'b66166c04f8c3109214a4fbd64a50fc8',
                           '3085a0e285430894940527032f8b26df', '640fb0e74195791501fd1ed57b41487f',
                           'a2a266d0498c3104214a47bd64ab0fc8']),
    'Location': ('location', ['pin']),
    'Person': ('person', ['user']),
}


def hex_to_hsv(hx):
    hx = hx.strip().lstrip('#')
    r, g, b = (int(hx[i:i + 2], 16) for i in (0, 2, 4))
    return colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)


def live_primary():
    dc = Path.home() / '.config/ghostty/themes/dankcolors'
    if dc.exists():
        for line in dc.read_text().splitlines():
            if line.startswith('cursor-color'):
                return '#' + line.split('#')[1].strip()
    raise RuntimeError('cursor-color not found in dankcolors')


def tip_hotspot(img):
    """Arrow tip (0, 0) or center for symmetric cursors."""
    w, h = img.size
    px = img.load()
    for y in range(min(5, h)):
        for x in range(min(5, w)):
            if px[x, y][3] > 100:
                return 0, 0
    return w // 2, h // 2


def diagonal_kind(png):
    """'\\': backslash (nwse) or '/': slash (nesw), from colored pixels."""
    im = Image.open(png).convert('RGBA')
    w, h = im.size
    px = im.load()
    sx = sy = sxx = syy = sxy = n = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            if mx == 0 or (mx - mn) / mx < 0.2:
                continue
            hh, _, _ = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            deg = hh * 360
            if not (HUE_LO <= deg <= HUE_HI or deg >= 345 or deg <= 15 or 40 <= deg <= 60):
                continue
            n += 1
            sx += x
            sy += y
            sxx += x * x
            syy += y * y
            sxy += x * y
    if n == 0:
        return '?'
    cov = sxy / n - (sx / n) * (sy / n)
    return '\\' if cov > 0 else '/'


def recolor(img, th, ts, tv):
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            if mx == 0:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            deg = hh * 360
            if HUE_LO <= deg <= HUE_HI and ss >= MIN_SAT:
                new_h = th
                new_s = ss * ts
                new_v = vv * tv
                nr, ng, nb = colorsys.hsv_to_rgb(new_h, new_s, new_v)
                px[x, y] = (int(round(nr * 255)), int(round(ng * 255)),
                            int(round(nb * 255)), a)
    return img


def build_cursor(win_name, src_dir, tmp_dir, cursors_dir, th, ts, tv,
                 primary_name=None):
    manifest = json.loads((src_dir / 'manifest.json').read_text())
    jif = manifest['jif'] or 2
    delay = max(1, round(jif * 1000 / 60))
    n_icons = max(f['icon'] for f in manifest['frames']) + 1
    seq = manifest['seq'] or list(range(n_icons))
    by_size = {}
    for f in manifest['frames']:
        by_size.setdefault((f['w'], f['h']), {}).setdefault(
            f['icon'], f['file'])
    name = primary_name or WIN_TO_X[win_name][0]
    # Ensure standard sizes [24, 28, 32, 36, 44, 48] are generated
    target_sizes = [(24, 24), (28, 28), (32, 32), (36, 36), (44, 44), (48, 48)]
    hot = {}
    for sz in target_sizes:
        w, h = sz
        if name in ('crosshair', 'cross') or win_name == 'Precision':
            hot[sz] = (w // 2, h // 2)
        else:
            hot[sz] = (0, 0)
    lines = []
    work = tmp_dir / name
    work.mkdir(parents=True, exist_ok=True)
    for sz in target_sizes:
        w, h = sz
        hx, hy = hot[sz]
        for icon_idx in seq:
            # Pick highest resolution master frame to avoid upscaling artifacts
            if (48, 48) in by_size and icon_idx in by_size[(48, 48)]:
                src = Image.open(src_dir / by_size[(48, 48)][icon_idx]).convert('RGBA')
            elif (32, 32) in by_size and icon_idx in by_size[(32, 32)]:
                src = Image.open(src_dir / by_size[(32, 32)][icon_idx]).convert('RGBA')
            elif sz in by_size and icon_idx in by_size[sz]:
                src = Image.open(src_dir / by_size[sz][icon_idx]).convert('RGBA')
            else:
                continue

            # Recolor master frame BEFORE resizing so ripple and glow are 100% recolored
            # without Lanczos interpolation / sub-pixel color fringing
            if win_name not in ('Busy', 'Unavailable'):
                recolor(src, th, ts, tv)

            if src.size != (w, h):
                src = src.resize((w, h), Image.Resampling.LANCZOS)
            out = work / ('%dx%d_f%03d.png' % (w, h, len(lines)))
            src.save(out)
            lines.append('%d %d %d %s %d' % (w, hx, hy, out, delay))
    conf = tmp_dir / (name + '.in')
    conf.write_text('\n'.join(lines) + '\n')
    subprocess.run(['xcursorgen', str(conf),
                    str(cursors_dir / name)], check=True)
    print('built %-14s %3d images %dx%d delay=%dms hot=%s' % (
        name, len(lines), w, h, delay, hot))
    return name


def main():
    frames_root = Path(sys.argv[1])
    theme_dir = Path(sys.argv[2])
    color = sys.argv[3] if len(sys.argv) > 3 else live_primary()
    th, ts, tv = hex_to_hsv(color)
    if ts < 0.15:
        print('primary %s is near-gray, keeping cyan' % color)
        return
    print('target %s (h=%.1f s=%.2f v=%.2f)' % (color, th * 360, ts, tv))
    cursors_dir = theme_dir / 'cursors'
    if theme_dir.exists():
        shutil.rmtree(theme_dir)
    cursors_dir.mkdir(parents=True)
    tmp_dir = Path('/tmp/nero-build/work')
    if tmp_dir.exists():
        shutil.rmtree(tmp_dir)
    tmp_dir.mkdir(parents=True)

    # orient the two diagonal resizers
    d1 = diagonal_kind(sorted((frames_root / 'DiaRes1').glob('*48x48*'))[0])
    d2 = diagonal_kind(sorted((frames_root / 'DiaRes2').glob('*48x48*'))[0])
    print('DiaRes1=%s DiaRes2=%s' % (d1, d2))
    dia_map = {}
    dia_map['DiaRes1'] = 'nwse-resize' if d1 == '\\' else 'nesw-resize'
    dia_map['DiaRes2'] = 'nesw-resize' if d1 == '\\' else 'nwse-resize'

    built = {}
    for win_name in sorted(p.name for p in frames_root.iterdir()
                           if p.is_dir()):
        src = frames_root / win_name
        if win_name in ('DiaRes1', 'DiaRes2'):
            primary = dia_map[win_name]
            # X11: bd (\) = nwse, fd (/) = nesw
            aliases = (['fd_double_arrow', 'size_bdiag', 'ne-resize', 'sw-resize',
                        'top_right_corner', 'bottom_left_corner', 'ur_angle', 'll_angle',
                        'fcf1c3c7cd4491d801f1e1c78f100000']
                       if 'nesw' in primary else
                       ['bd_double_arrow', 'size_fdiag', 'nw-resize', 'se-resize',
                        'top_left_corner', 'bottom_right_corner', 'ul_angle', 'lr_angle',
                        'c7088f0f3e6c8088236ef8e1e3e70000'])
            name = build_cursor(win_name, src, tmp_dir, cursors_dir,
                                th, ts, tv, primary_name=primary)
            built[name] = [a for a in aliases if a not in built]
        else:
            primary, aliases = WIN_TO_X[win_name]
            name = build_cursor(win_name, src, tmp_dir, cursors_dir,
                                th, ts, tv)
            built[name] = aliases
    for primary, aliases in built.items():
        for a in aliases:
            link = cursors_dir / a
            if link.exists() or link.is_symlink():
                link.unlink()
            link.symlink_to(primary)
            print('alias %-18s -> %s' % (a, primary))
    (theme_dir / 'index.theme').write_text(
        '[Icon Theme]\nName=Nero-Matugen\n'
        'Comment=Nero v2 (BIueGuy/Kimi) recolored to matugen primary %s\n'
        'Inherits=Adwaita\n' % color)
    print('theme at %s' % theme_dir)


if __name__ == '__main__':
    main()

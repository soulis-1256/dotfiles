#!/usr/bin/env python3
"""Extract Windows .ani frames to PNGs + metadata JSON for xcursorgen rebuild."""
import struct
import sys
from pathlib import Path
from PIL import Image


def read_chunks(buf):
    off = 0
    while off + 8 <= len(buf):
        tag = buf[off:off + 4]
        (size,) = struct.unpack('<I', buf[off + 4:off + 8])
        yield tag, buf[off + 8:off + 8 + size]
        off += 8 + size + (size & 1)


def parse_dib(dib):
    (biSize, biW, biH, planes, bpp, comp) = struct.unpack('<IiiHHI', dib[:20])
    doubled = biH > 0 and biH % 2 == 0
    h = biH // 2 if (doubled and bpp <= 24) else abs(biH)
    w = biW
    hdr = 40
    if bpp == 32:
        h = abs(biH)
        if len(dib) - hdr < w * h * 4:
            h //= 2
        px = dib[hdr:hdr + w * h * 4]
        img = Image.frombytes('RGBA', (w, h), px, 'raw', 'BGRA')
        img = img.transpose(Image.FLIP_TOP_BOTTOM)
        # Windows 32-bpp cursors store an 8-bit alpha channel directly in the pixel data.
        has_alpha = any(px[i] > 0 for i in range(3, len(px), 4))
        if has_alpha:
            return img, None
        mask = dib[hdr + w * h * 4:]
        mask_stride = ((w + 31) // 32) * 4
        if len(mask) >= mask_stride * h:
            alpha = Image.new('L', (w, h))
            ap = alpha.load()
            for y in range(h):
                for x in range(w):
                    byte = mask[y * mask_stride + x // 8]
                    if byte & (0x80 >> (x % 8)):
                        ap[x, h - 1 - y] = 0
                    else:
                        ap[x, h - 1 - y] = 255
            img.putalpha(alpha)
        return img, None
    if bpp in (24, 8, 4, 1):
        stride = ((w * bpp + 31) // 32) * 4
        raw = dib[hdr:hdr + stride * h]
        mode = 'RGB' if bpp == 24 else 'P'
        img = Image.frombytes(mode, (w, h), raw, 'raw',
                              ('BGR' if bpp == 24 else mode + ';R'),
                              stride, -1)
        img = img.convert('RGBA')
        mask_off = hdr + stride * h
        mask_stride = ((w + 31) // 32) * 4
        mask = dib[mask_off:mask_off + mask_stride * h]
        if len(mask) >= mask_stride * h:
            alpha = Image.new('L', (w, h))
            ap = alpha.load()
            for y in range(h):
                for x in range(w):
                    byte = mask[y * mask_stride + x // 8]
                    if byte & (0x80 >> (x % 8)):
                        ap[x, h - 1 - y] = 0
                    else:
                        ap[x, h - 1 - y] = 255
            img.putalpha(alpha)
        return img, None
    raise ValueError('unsupported bpp %d' % bpp)


def parse_ani(path):
    d = Path(path).read_bytes()
    assert d[:4] == b'RIFF' and d[8:12] == b'ACON', 'not ANI'
    rate = None
    seq = None
    icons = []
    jif = 2
    for tag, body in read_chunks(d[12:]):
        if tag == b'anih':
            v = struct.unpack('<9I', body[:36])
            jif = v[7] or 2
        elif tag == b'rate':
            n = len(body) // 4
            rate = list(struct.unpack('<%dI' % n, body[:n * 4]))
        elif tag == b'seq ':
            n = len(body) // 4
            seq = list(struct.unpack('<%dI' % n, body[:n * 4]))
        elif tag == b'LIST' and body[:4] == b'fram':
            for stag, sbody in read_chunks(body[4:]):
                if stag != b'icon':
                    continue
                rsv, typ, cnt = struct.unpack('<HHH', sbody[:6])
                entries = []
                o = 6
                for _ in range(cnt):
                    w, h, col, res, hx, hy, sz, fo = struct.unpack(
                        '<BBBBHHII', sbody[o:o + 16])
                    entries.append((w or 256, h or 256, hx, hy,
                                    sbody[fo:fo + sz]))
                    o += 16
                icons.append(entries)
    return {'jif': jif, 'rate': rate, 'seq': seq, 'icons': icons}


def main():
    src = Path(sys.argv[1])
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    meta = parse_ani(src)
    icons = meta['icons']
    print('%s: %d icon frames, jif=%d, seq=%s' % (
        src.name, len(icons), meta['jif'],
        'yes' if meta['seq'] else 'no'))
    manifest = {'jif': meta['jif'], 'rate': meta['rate'],
                'seq': meta['seq'], 'frames': []}
    for i, entries in enumerate(icons):
        for j, (w, h, hx, hy, dib) in enumerate(entries):
            try:
                img, _ = parse_dib(dib)
            except Exception as e:
                print('  frame %d entry %d: SKIP (%s)' % (i, j, e))
                continue
            fn = 'f%02d_%dx%d.png' % (i, img.width, img.height)
            img.save(out / fn)
            manifest['frames'].append(
                {'file': fn, 'icon': i, 'w': img.width,
                 'h': img.height, 'hx': hx, 'hy': hy})
    (out / 'manifest.json').write_text(
        __import__('json').dumps(manifest, indent=1))
    print('  wrote %d pngs' % (len(manifest['frames'])))


if __name__ == '__main__':
    main()

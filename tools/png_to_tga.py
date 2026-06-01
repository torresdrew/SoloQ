#!/usr/bin/env python3
"""Convert an 8-bit RGBA non-interlaced PNG to a 32-bit uncompressed TGA.

Stdlib only. Supports exactly PNG color type 6, bit depth 8, interlace 0 (the
format of assets/hero_rat.png). Raises a clear error on anything else.
"""
import struct
import sys
import zlib

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png_rgba(data):
    if data[:8] != PNG_SIGNATURE:
        raise ValueError("not a PNG file")
    pos = 8
    width = height = None
    idat = bytearray()
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, bit_depth, color_type, _comp, _filt, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
            if bit_depth != 8 or color_type != 6 or interlace != 0:
                raise ValueError(
                    "unsupported PNG: need 8-bit RGBA non-interlaced "
                    "(got bit_depth=%d color_type=%d interlace=%d)"
                    % (bit_depth, color_type, interlace)
                )
        elif ctype == b"IDAT":
            idat += chunk
        elif ctype == b"IEND":
            break
    if width is None:
        raise ValueError("missing IHDR")
    raw = zlib.decompress(bytes(idat))
    channels = 4
    stride = width * channels
    pixels = bytearray(height * stride)
    prev = bytearray(stride)
    rpos = 0
    for y in range(height):
        ftype = raw[rpos]
        rpos += 1
        line = bytearray(raw[rpos:rpos + stride])
        rpos += stride
        if ftype == 0:
            pass
        elif ftype == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif ftype == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ftype == 3:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif ftype == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                c = prev[i - channels] if i >= channels else 0
                line[i] = (line[i] + _paeth(a, prev[i], c)) & 0xFF
        else:
            raise ValueError("bad PNG filter type %d" % ftype)
        pixels[y * stride:(y + 1) * stride] = line
        prev = line
    return width, height, bytes(pixels)


def rgba_to_tga(width, height, rgba):
    # 32-bit uncompressed true-color TGA. Descriptor 0x28 = top-left origin,
    # 8 alpha bits; pixels stored BGRA top-to-bottom to match.
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0, 0, 2,
        0, 0, 0,
        0, 0,
        width, height,
        32, 0x28,
    )
    out = bytearray(header)
    for i in range(0, len(rgba), 4):
        out += bytes((rgba[i + 2], rgba[i + 1], rgba[i], rgba[i + 3]))
    return bytes(out)


def convert(src_path, dst_path):
    with open(src_path, "rb") as fh:
        png = fh.read()
    width, height, rgba = read_png_rgba(png)
    with open(dst_path, "wb") as fh:
        fh.write(rgba_to_tga(width, height, rgba))
    return width, height


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "assets/hero_rat.png"
    dst = sys.argv[2] if len(sys.argv) > 2 else "assets/hero_rat.tga"
    w, h = convert(src, dst)
    print("wrote %s (%dx%d)" % (dst, w, h))

import struct
import zlib

import png_to_tga


def _chunk(ctype, data):
    return struct.pack(">I", len(data)) + ctype + data + struct.pack(
        ">I", zlib.crc32(ctype + data) & 0xFFFFFFFF
    )


def _fixture_png():
    # 2x2 RGBA. Row 0 filter 0 (None); row 1 filter 2 (Up).
    ihdr = struct.pack(">IIBBBBB", 2, 2, 8, 6, 0, 0, 0)
    row0 = bytes([10, 20, 30, 40, 50, 60, 70, 80])
    row1_up = bytes([80] * 8)  # actual row1 - row0, all 80
    raw = b"\x00" + row0 + b"\x02" + row1_up
    idat = zlib.compress(raw)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", idat)
        + _chunk(b"IEND", b"")
    )


def _expect_tga():
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, 2, 2, 32, 0x28)
    # BGRA, top-to-bottom: row0 then row1.
    pixels = bytes([
        30, 20, 10, 40, 70, 60, 50, 80,        # row0
        110, 100, 90, 120, 150, 140, 130, 160,  # row1
    ])
    return header + pixels


def run():
    png = _fixture_png()
    width, height, rgba = png_to_tga.read_png_rgba(png)
    assert (width, height) == (2, 2), (width, height)
    assert rgba == bytes([
        10, 20, 30, 40, 50, 60, 70, 80,
        90, 100, 110, 120, 130, 140, 150, 160,
    ]), rgba
    tga = png_to_tga.rgba_to_tga(width, height, rgba)
    assert tga == _expect_tga(), tga
    print("PASS tools/test_png_to_tga.py")


run()

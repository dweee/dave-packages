"""Emit an inert, deterministic x86-64 ELF for Ghidra to parse on every host."""
import struct
import sys
from pathlib import Path

code = bytes.fromhex("31c0c3")  # xor eax,eax; ret — never executed by this test
base, offset = 0x400000, 64 + 56
ident = b"\x7fELF\x02\x01\x01" + bytes(9)
header = struct.pack("<16sHHIQQQIHHHHHH", ident, 2, 62, 1,
                     base + offset, 64, 0, 0, 64, 56, 1, 64, 0, 0)
program = struct.pack("<IIQQQQQQ", 1, 5, 0, base, base,
                      offset + len(code), offset + len(code), 0x1000)
Path(sys.argv[1]).write_bytes(header + program + code)

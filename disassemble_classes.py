#!/usr/bin/env python3
"""Disassemble all .class files under a directory using javap.
Replaces each .class file with a .class.disasm file containing javap -c -p output.
Exits non-zero only on unexpected errors; per-file failures are recorded in the .disasm file.
"""
import os
import sys
import subprocess
from pathlib import Path


def disassemble_dir(root_dir: Path) -> int:
    root_dir = root_dir.resolve()
    if not root_dir.is_dir():
        print(f"Not a directory: {root_dir}", file=sys.stderr)
        return 2
    for dirpath, _, filenames in os.walk(root_dir):
        for fn in filenames:
            if not fn.endswith('.class'):
                continue
            classfile = Path(dirpath) / fn
            # compute class name relative to root_dir, convert path sep -> dot and strip .class
            rel = classfile.relative_to(root_dir)
            classname = str(rel.with_suffix('')).replace(os.sep, '.')
            outpath = classfile.with_suffix(classfile.suffix + '.disasm')
            # run javap
            try:
                # first try with class name
                proc = subprocess.run(['javap', '-c', '-p', '-classpath', str(root_dir), classname],
                                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False)
                out = proc.stdout
                if proc.returncode != 0:
                    # fallback: try javap on the file path
                    proc2 = subprocess.run(['javap', '-c', '-p', str(classfile)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False)
                    out = proc2.stdout
                if not out:
                    out = f"failed to disassemble {classfile}\n"
            except FileNotFoundError:
                out = "javap not found in PATH\n"
            try:
                outpath.write_text(out)
            except Exception as e:
                print(f"Failed to write disasm for {classfile}: {e}", file=sys.stderr)
                return 3
            try:
                classfile.unlink()
            except Exception as e:
                print(f"Failed to remove class file {classfile}: {e}", file=sys.stderr)
    return 0


def main():
    if len(sys.argv) < 2:
        print("Usage: disassemble_classes.py <dir> [<dir> ...]", file=sys.stderr)
        sys.exit(2)
    rc = 0
    for d in sys.argv[1:]:
        r = disassemble_dir(Path(d))
        if r != 0:
            rc = r
    sys.exit(rc)


if __name__ == '__main__':
    main()

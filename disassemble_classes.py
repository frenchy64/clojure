#!/usr/bin/env python3
"""Disassemble .class files that differ between two directories using javap.
Usage: disassemble_classes.py <dir1> <dir2>
For any relative .class path that either exists in only one dir or whose contents differ,
write a .class.disasm file next to each existing .class and remove the original .class.
"""
import sys
import subprocess
from pathlib import Path
import hashlib


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()


def collect_class_paths(dirpath: Path):
    result = set()
    for p in dirpath.rglob('*.class'):
        result.add(p.relative_to(dirpath))
    return result


def disassemble_file(root_dir: Path, classfile_rel: Path) -> int:
    classfile = (root_dir / classfile_rel).resolve()
    outpath = classfile.with_suffix(classfile.suffix + '.disasm')
    # classname: replace path sep with dot and strip .class
    classname = str(classfile_rel.with_suffix('')).replace('/', '.').replace('\\', '.')
    try:
        print(f"Disassembling {classname}")
        proc = subprocess.run(['javap', '-c', '-p', '-classpath', str(root_dir), classname],
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False)
        out = proc.stdout
        if proc.returncode != 0 or not out:
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
    if len(sys.argv) != 3:
        print("Usage: disassemble_classes.py <dir1> <dir2>", file=sys.stderr)
        sys.exit(2)
    dir1 = Path(sys.argv[1]).resolve()
    dir2 = Path(sys.argv[2]).resolve()
    if not dir1.is_dir() or not dir2.is_dir():
        print("Both arguments must be directories", file=sys.stderr)
        sys.exit(2)

    paths1 = collect_class_paths(dir1)
    paths2 = collect_class_paths(dir2)
    all_paths = paths1.union(paths2)

    exit_code = 0
    for rel in sorted(all_paths):
        p1 = dir1 / rel
        p2 = dir2 / rel
        exists1 = p1.exists()
        exists2 = p2.exists()
        need = False
        if exists1 and exists2:
            try:
                if sha256(p1) != sha256(p2):
                    need = True
            except Exception as e:
                print(f"Failed hashing files {p1} or {p2}: {e}", file=sys.stderr)
                need = True
        else:
            # present only in one dir
            need = True
        if not need:
            continue
        # disassemble whichever exists
        if exists1:
            r = disassemble_file(dir1, rel)
            if r != 0:
                exit_code = r
        if exists2:
            r = disassemble_file(dir2, rel)
            if r != 0:
                exit_code = r
    sys.exit(exit_code)


if __name__ == '__main__':
    main()

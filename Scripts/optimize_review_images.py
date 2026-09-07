#!/usr/bin/env python3
"""Make review screenshots smaller and update local Markdown links (macOS/sips)."""
import argparse
from pathlib import Path
import re
import subprocess
import struct


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--max-edge', type=int, default=1440)
    parser.add_argument('--quality', type=int, default=80)
    args = parser.parse_args()
    if args.max_edge < 640 or not 1 <= args.quality <= 100:
        parser.error('Use a max edge of at least 640 and quality between 1 and 100.')
    root = Path(__file__).resolve().parents[1]
    screenshots = sorted((root / 'Documentation').rglob('*.png'))
    converted = {}
    before = after = 0
    for source in screenshots:
        target = source.with_suffix('.jpg')
        if target.exists():
            raise SystemExit(f'Refusing to overwrite {target}')
        with source.open('rb') as image:
            header = image.read(24)
        if header[:8] != b'\x89PNG\r\n\x1a\n':
            raise SystemExit(f'Not a PNG: {source}')
        width, height = struct.unpack('>II', header[16:24])
        resize = ['--resampleHeightWidthMax', str(args.max_edge)] if max(width, height) > args.max_edge else []
        subprocess.run([
            'sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', str(args.quality),
            *resize, str(source), '--out', str(target)
        ], check=True, stdout=subprocess.DEVNULL)
        original_size, new_size = source.stat().st_size, target.stat().st_size
        if new_size >= original_size:
            target.unlink()
            continue
        before += original_size
        after += new_size
        converted[source.resolve()] = target
    # Only rewrite links to screenshots actually converted; leave external URLs alone.
    for document in root.rglob('*.md'):
        if any(part in {'.git', '.build'} for part in document.relative_to(root).parts):
            continue
        original = document.read_text()
        def replace_link(match):
            value = match.group(1)
            if '://' in value:
                return match.group(0)
            path, separator, fragment = value.partition('#')
            resolved = (document.parent / path).resolve()
            if resolved not in converted:
                return match.group(0)
            return '](' + str(Path(path).with_suffix('.jpg')) + separator + fragment + ')'
        updated = re.sub(r'\]\(([^)]+)\)', replace_link, original)
        for source in converted:
            updated = updated.replace('[' + source.name + '](', '[' + source.with_suffix('.jpg').name + '](')
        if updated != original:
            document.write_text(updated)
    for source in converted:
        source.unlink()
    print(f'{len(converted)} screenshots: {before:,} → {after:,} bytes')


if __name__ == '__main__':
    main()

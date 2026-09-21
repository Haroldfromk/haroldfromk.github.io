#!/usr/bin/env python3
"""
_posts 폴더에서 <img ... width=...> 형태(HTML 태그)로 사이즈가 지정된 곳만
따로 찾아서 파일별로 보여주는 진단용 스크립트. 수정은 하지 않고 조회만 함.

사용법:
  python3 find_html_img_width.py
  python3 find_html_img_width.py --dir _posts
"""
import argparse
import re
from pathlib import Path

IMG_TAG = re.compile(r'<img\b[^>]*/?>')


def iter_md_files(posts_dir: Path):
    for md_file in sorted(posts_dir.rglob("*.md")):
        rel_parts = md_file.relative_to(posts_dir).parts
        if any(part.startswith('.') for part in rel_parts):
            continue
        yield md_file


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default="_posts", help="포스트 폴더 경로 (기본값: _posts)")
    args = parser.parse_args()

    posts_dir = Path(args.dir)
    if not posts_dir.exists():
        print(f"'{posts_dir}' 폴더를 찾을 수 없어요.")
        return

    hits = []
    scanned = 0
    for md_file in iter_md_files(posts_dir):
        scanned += 1
        text = md_file.read_text(encoding="utf-8")
        for mo in IMG_TAG.finditer(text):
            tag = mo.group(0)
            if 'width=' in tag:
                hits.append((md_file, tag.strip()))

    print(f"스캔한 .md 파일 수: {scanned}")
    print(f"<img ... width=...> 형태 발견: {len(hits)}개\n")
    for f, tag in hits:
        print(f"{f}")
        print(f"  {tag}\n")


if __name__ == "__main__":
    main()

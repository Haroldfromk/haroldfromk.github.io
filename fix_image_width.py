#!/usr/bin/env python3
"""
Jekyll 블로그 _posts 폴더에서 이미지 width 스타일 {: width=...} 를 찾아 리포트하고,
--apply 옵션을 주면 실제로 제거해서 원본 사이즈로 되돌리는 스크립트.

기본 동작:
  - .jekyll-cache 등 숨김(.으로 시작하는) 폴더는 스캔 대상에서 제외 (빌드 캐시라 건드리면 안 됨)
  - width 값이 퍼센트(%)이고 --skip-under 값 이상인 것만 제거 대상 (기본 10% 미만은 보존, 인라인 아이콘 보호용)
  - px 등 퍼센트가 아닌 값(예: 720, 700)은 --strip-px 를 줘야 제거 대상에 포함됨

사용법:
  python3 fix_image_width.py                     # 드라이런
  python3 fix_image_width.py --apply              # 실제 적용
  python3 fix_image_width.py --skip-under 5        # 5% 미만만 보존하고 싶을 때
  python3 fix_image_width.py --apply --strip-px    # px 값도 같이 제거
"""
import argparse
import re
from pathlib import Path
from collections import Counter

WIDTH_BLOCK = re.compile(r'\s*\{:\s*[^}]*\bwidth=[^}]*\}')
WIDTH_VALUE = re.compile(r'width=["\'“]?(\d+)(%)?["\'”]?')


def iter_md_files(posts_dir: Path):
    for md_file in sorted(posts_dir.rglob("*.md")):
        rel_parts = md_file.relative_to(posts_dir).parts
        if any(part.startswith('.') for part in rel_parts):
            continue
        yield md_file


def should_strip(match_text: str, skip_under: int, strip_px: bool):
    m = WIDTH_VALUE.search(match_text)
    if not m:
        # 파싱 안 되는 특이 케이스(따옴표 이슈 등)는 그냥 제거 대상으로 취급
        return True, "unparsed"
    value, is_percent = int(m.group(1)), bool(m.group(2))
    if not is_percent:
        return strip_px, "px"
    if value < skip_under:
        return False, f"{value}% (skip-under 대상)"
    return True, f"{value}%"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default="_posts", help="포스트 폴더 경로 (기본값: _posts)")
    parser.add_argument("--apply", action="store_true", help="실제로 파일을 수정 (기본은 드라이런)")
    parser.add_argument("--skip-under", type=int, default=10, help="이 퍼센트 미만은 보존 (기본 10)")
    parser.add_argument("--strip-px", action="store_true", help="퍼센트가 아닌 px 값도 제거 대상에 포함")
    args = parser.parse_args()

    posts_dir = Path(args.dir)
    if not posts_dir.exists():
        print(f"'{posts_dir}' 폴더를 찾을 수 없어요. --dir 옵션으로 실제 경로를 지정하세요.")
        return

    stripped_counter = Counter()
    kept_counter = Counter()
    stripped_files = []
    kept_matches = []

    for md_file in iter_md_files(posts_dir):
        text = md_file.read_text(encoding="utf-8")
        matches = list(WIDTH_BLOCK.finditer(text))
        if not matches:
            continue

        new_text = text
        file_stripped = 0
        for mo in matches:
            match_text = mo.group(0)
            do_strip, label = should_strip(match_text, args.skip_under, args.strip_px)
            if do_strip:
                stripped_counter[label] += 1
                file_stripped += 1
                if args.apply:
                    new_text = new_text.replace(match_text, '', 1)
            else:
                kept_counter[label] += 1
                kept_matches.append((md_file, match_text.strip()))

        if file_stripped:
            stripped_files.append((md_file, file_stripped))
            if args.apply and new_text != text:
                md_file.write_text(new_text, encoding="utf-8")

    total_stripped = sum(stripped_counter.values())
    total_kept = sum(kept_counter.values())

    print(f"제거 대상: {total_stripped}개 ({len(stripped_files)}개 파일)")
    for label, count in stripped_counter.most_common():
        print(f"  {label}: {count}개")

    print(f"\n보존(제외) 대상: {total_kept}개")
    for label, count in kept_counter.most_common():
        print(f"  {label}: {count}개")

    if kept_matches:
        print("\n보존된 항목 상세 (인라인 아이콘 등, 필요하면 직접 확인):")
        for f, m in kept_matches:
            print(f"  {f}: {m}")

    if not args.apply:
        print("\n드라이런 모드입니다. --apply 를 붙이면 실제로 제거합니다.")
    else:
        print("\n적용 완료. git diff 로 변경 내역을 검토한 뒤 커밋하세요.")


if __name__ == "__main__":
    main()

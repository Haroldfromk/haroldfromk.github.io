#!/usr/bin/env python3
"""
Jekyll 블로그 _posts 폴더에서 이미지 width 지정을 찾아 리포트하고,
--apply 옵션을 주면 실제로 제거해서 원본 사이즈로 되돌리는 스크립트.

처리하는 두 가지 패턴:
  1. kramdown 방식: ![]() 뒤에 붙는 {: width="50%" height="50%"} 블록 전체 제거
  2. HTML 방식: <img ... width="50%" height="50%" ... /> 태그에서 width/height 속성만 제거 (태그 자체는 유지)

공통 규칙:
  - .jekyll-cache 등 숨김(.으로 시작하는) 폴더는 스캔 제외 (빌드 캐시)
  - width 값이 퍼센트이고 --skip-under 미만이면 보존 (인라인 아이콘 보호용, 기본 10)
  - px 등 퍼센트가 아닌 값은 --strip-px 를 줘야 제거 대상에 포함

사용법:
  python3 fix_image_width.py                     # 드라이런
  python3 fix_image_width.py --apply               # 실제 적용
  python3 fix_image_width.py --skip-under 5         # 5% 미만만 보존
  python3 fix_image_width.py --apply --strip-px      # px 값도 같이 제거
"""
import argparse
import re
from pathlib import Path
from collections import Counter

KRAMDOWN_BLOCK = re.compile(r'\s*\{:\s*[^}]*\bwidth=[^}]*\}')
IMG_TAG = re.compile(r'<img\b[^>]*/?>')
WIDTH_ATTR = re.compile(r'\s*width=["\'“]?\d+%?["\'”]?')
HEIGHT_ATTR = re.compile(r'\s*height=["\'“]?\d+%?["\'”]?')
WIDTH_VALUE = re.compile(r'width=["\'“]?(\d+)(%)?["\'”]?')


def iter_md_files(posts_dir: Path):
    for md_file in sorted(posts_dir.rglob("*.md")):
        rel_parts = md_file.relative_to(posts_dir).parts
        if any(part.startswith('.') for part in rel_parts):
            continue
        yield md_file


def classify(match_text: str, skip_under: int, strip_px: bool):
    m = WIDTH_VALUE.search(match_text)
    if not m:
        return True, "unparsed"
    value, is_percent = int(m.group(1)), bool(m.group(2))
    if not is_percent:
        return strip_px, "px"
    if value < skip_under:
        return False, f"{value}% (skip-under 대상)"
    return True, f"{value}%"


def process_text(text: str, skip_under: int, strip_px: bool, do_apply: bool):
    stripped = Counter()
    kept = Counter()
    kept_detail = []

    def kramdown_repl(mo):
        match_text = mo.group(0)
        strip, label = classify(match_text, skip_under, strip_px)
        if strip:
            stripped[label] += 1
            return '' if do_apply else match_text
        kept[label] += 1
        kept_detail.append(match_text.strip())
        return match_text

    def img_repl(mo):
        tag = mo.group(0)
        if 'width=' not in tag:
            return tag
        strip, label = classify(tag, skip_under, strip_px)
        if strip:
            stripped[label] += 1
            if do_apply:
                return HEIGHT_ATTR.sub('', WIDTH_ATTR.sub('', tag))
            return tag
        kept[label] += 1
        kept_detail.append(tag.strip())
        return tag

    text = KRAMDOWN_BLOCK.sub(kramdown_repl, text)
    text = IMG_TAG.sub(img_repl, text)
    return text, stripped, kept, kept_detail


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
        original = md_file.read_text(encoding="utf-8")
        new_text, s, k, kd = process_text(original, args.skip_under, args.strip_px, args.apply)

        stripped_counter.update(s)
        kept_counter.update(k)
        if s:
            stripped_files.append((md_file, sum(s.values())))
        for item in kd:
            kept_matches.append((md_file, item))

        if args.apply and new_text != original:
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

#!/usr/bin/env python3
"""
블로그 포스트 작성 규칙 검사기

사용법:
    python3 lint_post.py <post.md> [<post.md> ...]

ERROR 가 하나라도 있으면 exit code 1 로 끝난다.
WARN 은 사람이 판단할 항목이라 exit code 에 영향을 주지 않는다.
"""

import re
import sys
from datetime import datetime
from pathlib import Path

FORBIDDEN_CHARS = {
    "\u2014": "em dash",
    "\u2013": "en dash",
    "\u00b7": "가운뎃점",
}
REQUIRED_KEYS = ["title", "date", "categories", "tags"]
DATE_FORMATS = ["%Y-%m-%d %H:%M:%S %z", "%Y-%m-%d %H:%M %z", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"]

FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
HEADER = re.compile(r"^(#{2,4}) (.*)")
NUMBERED_HEADER = re.compile(r"^\d+(-\d+)*\.\s")
EMOJI = re.compile("[\U0001F000-\U0001FAFF\u2600-\u27BF\u2B50\u2B55]")
INLINE_LINK = re.compile(r"(?<!!)\[([^\]]+)\]\((https?://[^)]+)\)(\{:[^}]*\})?")
REF_LINK_DEF = re.compile(r"^\[([^\]]+)\]:\s*(https?://\S+)")
SOURCE_PREFIX = re.compile(r"^[A-Z]+[- ]?\d+: ")  # [RFC 6762: ...], [WWDC25: ...], [SE-0296: ...]
SOURCE_SUFFIX = re.compile(r" \([^()]+\)$")  # [AppStorage (Apple)] 처럼 끝에 붙인 출처
NEW_TAB = '{:target="_blank"}'
OWN_SITE = "haroldfromk.github.io"
FILENAME_DATE = re.compile(r"^(\d{4}-\d{2}-\d{2})-")


class Report:
    def __init__(self, path):
        self.path = path
        self.errors = 0
        self.warnings = 0

    def error(self, line, rule, message):
        self.errors += 1
        print(f"{self.path}:{line}: ERROR [{rule}] {message}")

    def warn(self, line, rule, message):
        self.warnings += 1
        print(f"{self.path}:{line}: WARN  [{rule}] {message}")


def split_front_matter(lines):
    """front matter 를 dict 로, 본문 시작 줄 index 와 함께 돌려준다."""
    if not lines or lines[0].strip() != "---":
        return None, 0
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            meta = {}
            for raw in lines[1:i]:
                if ":" in raw and not raw.startswith(" "):
                    key, value = raw.split(":", 1)
                    meta[key.strip()] = value.strip()
            return meta, i + 1
    return None, 0


def parse_date(value):
    value = value.strip().strip("\"'")
    for fmt in DATE_FORMATS:
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    return None


def check_front_matter(report, meta, filename):
    if meta is None:
        report.error(1, "front-matter", "front matter 가 없다")
        return

    for key in REQUIRED_KEYS:
        if key not in meta:
            report.error(1, "front-matter", f"'{key}' 가 없다")

    date = parse_date(meta.get("date", ""))
    if "date" in meta and date is None:
        report.error(1, "date", f"date 형식을 읽을 수 없다: {meta['date']}")
    if date is not None:
        now = datetime.now(date.tzinfo) if date.tzinfo else datetime.now()
        if date > now:
            report.error(1, "date", f"미래 날짜라 blogrun 에서 보이지 않는다: {meta['date']}")
        match = FILENAME_DATE.match(filename)
        if match and match.group(1) != date.strftime("%Y-%m-%d"):
            report.warn(1, "date", f"파일명 날짜({match.group(1)})와 front matter 날짜가 다르다")

    tags = meta.get("tags", "").strip("[]")
    for tag in [t.strip() for t in tags.split(",") if t.strip()]:
        if tag[0].isascii() and tag[0].islower():
            report.warn(1, "tags", f"기존 포스트는 대문자로 시작하는 tag 를 쓴다: {tag}")


def check_header_name(report, number, title):
    if "`" in title:
        report.error(number, "header", f"헤더에 백틱을 쓰지 않는다. API 이름은 그대로 쓰고 조사를 붙인다: {title}")
    if EMOJI.search(title):
        report.error(number, "header", f"헤더에 이모지를 쓰지 않는다: {title}")
    if NUMBERED_HEADER.match(title):
        report.warn(number, "header", f"순서가 중요한 단계가 아니면 헤더 앞 번호를 지운다: {title}")
    if title.rstrip("?.!").endswith("다"):
        report.warn(number, "header", f"헤더가 문장으로 끝난다. 명사구로 바꿀지 본다: {title}")


def check_body(report, lines, start):
    fence = None  # 열려있는 code block 의 fence 문자열. 같은 문자로 같거나 긴 fence 가 와야 닫힌다
    prev_text = None  # 바로 앞의 비어있지 않은 줄 (code block 밖)
    pending_h2 = None  # 아직 도입부 문단이 나오지 않은 ## 헤더의 줄 번호
    in_refs = False  # ## 참고자료 섹션 안인지
    refs_headers = {}  # ## 참고자료 헤더 줄 번호 -> 그 섹션의 내용 줄 수
    body_urls = set()  # 참고자료 밖 본문에 건 링크 주소
    ref_links = []  # (줄 번호, 텍스트, 주소) 참고자료 섹션의 링크

    for index in range(start, len(lines)):
        line = lines[index]
        number = index + 1

        for char, name in FORBIDDEN_CHARS.items():
            if char in line:
                report.error(number, "char", f"{name} 를 쓰지 않는다. 하이픈(-)으로 바꾼다")

        match = FENCE.match(line)
        if match:
            marker = match.group(1)
            if fence is None:
                fence = marker
            elif marker[0] == fence[0] and len(marker) >= len(fence) and not line.strip()[len(marker):]:
                fence = None
            pending_h2 = None
            prev_text = line
            continue
        if fence is not None or not line.strip():
            continue

        header = HEADER.match(line)
        if header:
            check_header_name(report, number, header.group(2).strip())
        if header and header.group(1) == "####":
            if prev_text is not None and prev_text.strip() == "---":
                report.error(number, "separator", f"#### 위에는 --- 를 두지 않는다. 바로 위의 --- 를 지운다: {line.strip()}")
            pending_h2 = None
        elif header:
            if prev_text is not None and prev_text.strip() != "---":
                report.error(number, "separator", f"헤더 위에 --- 구분선이 없다: {line.strip()}")
            if header.group(1) == "###" and pending_h2 is not None:
                report.error(number, "intro", f"{pending_h2}번째 줄 ## 헤더 아래에 도입부 문단 없이 ### 가 왔다")
            pending_h2 = number if header.group(1) == "##" else None
            if header.group(1) == "##":
                in_refs = header.group(2).strip() == "참고자료"
                if in_refs:
                    refs_header = number
                    refs_headers[number] = 0
        elif line.strip() != "---":
            pending_h2 = None
            if in_refs:
                refs_headers[refs_header] += 1

        for text, url, attr in INLINE_LINK.findall(line):
            if OWN_SITE in url:
                continue
            if attr != NEW_TAB:
                report.error(number, "new-tab", f"외부 링크 뒤에 {NEW_TAB} 를 붙인다: [{text}]({url})")
            if in_refs:
                ref_links.append((number, text, url))
                if not SOURCE_SUFFIX.search(text) and not SOURCE_PREFIX.match(text):
                    report.error(number, "refs", f"참고자료 링크는 [이름 (출처)] 나 [RFC 6762: 제목] 형식으로 쓴다: [{text}]({url})")
            else:
                body_urls.add(normalize_url(url))
        ref = REF_LINK_DEF.match(line)
        if ref and OWN_SITE not in ref.group(2):
            report.error(number, "new-tab", f"reference 링크는 쓰지 않는다. 본문에서 [{ref.group(1)}]({ref.group(2)}){NEW_TAB} 로 바꾸고 이 줄은 지운다")

        if "/assets/images/upload/" in line:
            report.warn(number, "image", "로컬 이미지 경로가 남아있다. uploadimg 를 아직 안 돌렸다면 실행한다")

        prev_text = line

    for number, count in refs_headers.items():
        if count == 0:
            report.error(number, "refs", "참고자료가 비어 있다. ## 참고자료 헤더와 그 위의 --- 를 지운다")

    for number, text, url in ref_links:
        if normalize_url(url) in body_urls:
            report.warn(number, "refs", f"본문에 이미 링크한 자료다. 참고자료에서 뺄지 본다: [{text}]")


def normalize_url(url):
    return url.split("#")[0].rstrip("/").lower()


def lint(path):
    report = Report(path)
    lines = path.read_text(encoding="utf-8").split("\n")
    meta, start = split_front_matter(lines)
    check_front_matter(report, meta, path.name)
    check_body(report, lines, start)
    return report


def main():
    if len(sys.argv) < 2:
        sys.exit("사용법: python3 lint_post.py <post.md> [<post.md> ...]")

    total_errors = 0
    for arg in sys.argv[1:]:
        report = lint(Path(arg))
        total_errors += report.errors
        print(f"{arg}: ERROR {report.errors}개, WARN {report.warnings}개")

    sys.exit(1 if total_errors else 0)


if __name__ == "__main__":
    main()

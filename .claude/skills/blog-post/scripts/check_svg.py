#!/usr/bin/env python3
"""
SVG 다이어그램 규칙 검사기 + PNG 변환

사용법:
    /opt/homebrew/bin/python3.12 -I check_svg.py <그림.svg> [<그림.svg> ...]
    /opt/homebrew/bin/python3.12 -I check_svg.py --no-png <그림.svg> ...   (검사만)

references/diagrams.md 의 규칙을 검사하고, ERROR 가 0개인 파일만 viewBox 의 2배 크기로
같은 이름의 PNG 를 만든다. 만든 PNG 경로는 그 파일의 마지막 줄에 출력한다.

ERROR 가 하나라도 있으면 exit code 1 로 끝난다.
WARN 은 사람이 판단할 항목이라 exit code 에 영향을 주지 않는다.
이 검사를 통과해도 PNG 를 눈으로 확인하는 일은 그대로 해야 한다.
"""

import re
import sys
import xml.parsers.expat
from pathlib import Path

REQUIRED_FONT = "noto sans cjk kr"
ALLOWED_COLORS = {"#71717a", "#0d9488", "rgba(13,148,136,0.08)", "none"}
FONT_SIZE_MIN = 11.5
FONT_SIZE_MAX = 17
EMOJI = re.compile("[\U0001F000-\U0001FAFF☀-➿⭐⭕]")  # lint_post.py 와 같은 범위
CSS_RULE = re.compile(r"([^{}]+)\{([^{}]*)\}")
CSS_AT_BLOCK = re.compile(r"@[^{]*\{(?:[^{}]*\{[^{}]*\})*[^{}]*\}")  # @media 블록은 통째로 건너뛴다
TRANSLATE = re.compile(r"^\s*translate\(\s*(-?[\d.]+)(?:[\s,]+(-?[\d.]+))?\s*\)\s*$")
INHERITED = ("font-family", "font-size", "text-anchor")
NOT_DRAWN = {"defs", "style", "marker", "clipPath", "mask", "linearGradient", "radialGradient", "pattern", "symbol", "title", "desc"}


class Report:
    def __init__(self, path):
        self.path = path
        self.errors = 0
        self.warnings = 0
        self.counts = {}

    def error(self, line, rule, message):
        self.errors += 1
        self.counts[rule] = self.counts.get(rule, 0) + 1
        print(f"{self.path}:{line}: ERROR [{rule}] {message}")

    def warn(self, line, rule, message):
        self.warnings += 1
        self.counts[rule] = self.counts.get(rule, 0) + 1
        print(f"{self.path}:{line}: WARN  [{rule}] {message}")


class Node:
    def __init__(self, tag, attrs, line, parent):
        self.tag = tag.split(":")[-1]
        self.attrs = attrs
        self.line = line
        self.parent = parent
        self.children = []
        self.parts = []  # 문자열과 자식 Node 가 문서에 나온 순서대로
        self.props = {}  # 이 요소에 직접 적용된 속성 (attribute < <style> 규칙 < style 속성)

    def inherited(self, name):
        node = self
        while node is not None:
            if name in node.props:
                return node.props[name]
            node = node.parent
        return None

    def own_text(self):
        return "".join(part for part in self.parts if isinstance(part, str))


def parse(source):
    root = None
    stack = []
    parser = xml.parsers.expat.ParserCreate()

    def start(tag, attrs):
        nonlocal root
        node = Node(tag, attrs, parser.CurrentLineNumber, stack[-1] if stack else None)
        if stack:
            stack[-1].children.append(node)
            stack[-1].parts.append(node)
        else:
            root = node
        stack.append(node)

    def end(tag):
        stack.pop()

    def chars(data):
        if stack:
            stack[-1].parts.append(data)

    parser.StartElementHandler = start
    parser.EndElementHandler = end
    parser.CharacterDataHandler = chars
    parser.Parse(source, True)
    return root


def walk(node):
    yield node
    for child in node.children:
        yield from walk(child)


def declarations(text):
    result = {}
    for item in text.split(";"):
        if ":" in item:
            key, value = item.split(":", 1)
            result[key.strip().lower()] = value.strip()
    return result


def css_rules(root):
    """<style> 안의 단순한 규칙(태그, .class)만 읽는다. @media 안은 보지 않는다."""
    rules = []
    for node in walk(root):
        if node.tag != "style":
            continue
        css = re.sub(r"/\*.*?\*/", "", node.own_text(), flags=re.S)
        css = CSS_AT_BLOCK.sub("", css)
        for selectors, body in CSS_RULE.findall(css):
            for selector in selectors.split(","):
                rules.append((selector.strip(), declarations(body)))
    return rules


def apply_styles(root):
    rules = css_rules(root)
    for node in walk(root):
        props = {key.lower(): value for key, value in node.attrs.items()}
        classes = node.attrs.get("class", "").split()
        for selector, decls in rules:
            if selector == node.tag or (selector.startswith(".") and selector[1:] in classes):
                props.update(decls)
        props.update(declarations(node.attrs.get("style", "")))
        node.props = props


def number(value, default=None):
    try:
        return float(re.sub(r"px$", "", str(value).strip()))
    except (TypeError, ValueError):
        return default


def is_drawn(node):
    while node is not None:
        if node.tag in NOT_DRAWN:
            return False
        node = node.parent
    return True


def check_text(report, root):
    for node in walk(root):
        if node.tag not in ("text", "tspan") or not is_drawn(node):
            continue
        text = node.own_text().strip()
        if not text:
            continue
        shown = text if len(text) <= 20 else text[:20] + "..."

        family = node.inherited("font-family") or ""
        if REQUIRED_FONT not in family.lower():
            report.error(node.line, "font", f"font-family 에 'Noto Sans CJK KR' 이 없다(지금: {family or '없음'}): {shown}")
        if EMOJI.search(text):
            report.error(node.line, "emoji", f"이모지를 쓰지 않는다: {shown}")

        size = number(node.inherited("font-size"))
        if size is not None and (size < FONT_SIZE_MIN or size > FONT_SIZE_MAX):
            report.warn(node.line, "font-size", f"글자 크기 {size:g} 가 {FONT_SIZE_MIN}~{FONT_SIZE_MAX} 밖이다: {shown}")


def check_background(report, root, view_box):
    if view_box is None:
        return
    _, _, width, height = view_box
    for node in walk(root):
        if node.tag != "rect" or not is_drawn(node):
            continue
        rect_width = node.props.get("width", "")
        rect_height = node.props.get("height", "")
        covers_width = rect_width == "100%" or (number(rect_width, 0) >= width)
        covers_height = rect_height == "100%" or (number(rect_height, 0) >= height)
        at_origin = number(node.props.get("x", 0), 0) <= view_box[0] and number(node.props.get("y", 0), 0) <= view_box[1]
        fill = node.inherited("fill") or "black"
        if covers_width and covers_height and at_origin and fill.lower() not in ("none", "transparent"):
            report.error(node.line, "background", f"그림 전체를 덮는 배경 rect 가 있다(fill: {fill}). 배경은 투명으로 둔다")


def check_css_var(report, source):
    for index, line in enumerate(source.split("\n"), start=1):
        if "var(" in line:
            report.error(index, "css-var", "CSS 변수 var( 를 쓰지 않는다. 색 값을 직접 적는다")


def check_colors(report, root):
    for node in walk(root):
        if node.tag == "style":
            continue
        for name in ("fill", "stroke"):
            value = node.props.get(name)
            if value is None:
                continue
            normalized = re.sub(r"\s+", "", value).lower()
            if normalized.startswith("url("):  # 화살표 marker 참조 같은 것
                continue
            if normalized not in ALLOWED_COLORS:
                report.warn(node.line, "color", f"{name} 색 {value} 는 정해진 두 색(#71717A, #0D9488)이 아니다")


def text_width(text, size):
    width = 0.0
    for char in text:
        if char == " ":
            width += 0.3
        elif ord(char) < 0x2E80:
            width += 0.58
        else:
            width += 1.0
    return width * size


def offset(node):
    """조상의 translate 를 더한다. translate 가 아닌 transform 이 있으면 None (위치를 어림할 수 없다)."""
    dx = dy = 0.0
    while node is not None:
        transform = node.attrs.get("transform")
        if transform:
            match = TRANSLATE.match(transform)
            if not match:
                return None
            dx += float(match.group(1))
            dy += float(match.group(2) or 0)
        node = node.parent
    return dx, dy


def label_boxes(root):
    """[(줄, 글자, x0, y0, x1, y1)] 글자 수로 어림한 라벨 상자."""
    boxes = []
    for node in walk(root):
        if node.tag != "text" or not is_drawn(node):
            continue
        shift = offset(node)
        if shift is None:
            continue
        x = number(node.props.get("x", 0), 0)
        y = number(node.props.get("y", 0), 0)
        segments = [[node, x, y, ""]]  # 줄을 바꾸는 tspan 마다 새 조각
        for part in node.parts:
            if isinstance(part, str):
                segments[-1][3] += part
            elif part.tag == "tspan":
                moved = any(key in part.attrs for key in ("x", "y", "dy"))
                if moved:
                    x = number(part.attrs.get("x"), x)
                    y = number(part.attrs.get("y"), y) + number(part.attrs.get("dy"), 0)
                    segments.append([part, x, y, part.own_text()])
                else:
                    segments[-1][3] += part.own_text()
        for owner, seg_x, seg_y, text in segments:
            text = " ".join(text.split())
            if not text:
                continue
            size = number(owner.inherited("font-size"), 16)
            width = text_width(text, size)
            anchor = owner.inherited("text-anchor") or "start"
            left = seg_x - width / 2 if anchor == "middle" else seg_x - width if anchor == "end" else seg_x
            left += shift[0]
            top = seg_y - size * 0.8 + shift[1]
            boxes.append((owner.line, text, left, top, left + width, top + size))
    return boxes


def check_overlap(report, root):
    boxes = label_boxes(root)
    for first in range(len(boxes)):
        for second in range(first + 1, len(boxes)):
            a, b = boxes[first], boxes[second]
            overlap_x = min(a[4], b[4]) - max(a[2], b[2])
            overlap_y = min(a[5], b[5]) - max(a[3], b[3])
            if overlap_x > 2 and overlap_y > 2:  # 2 이하로 스치는 건 어림 오차로 본다
                report.warn(b[0], "overlap", f"{a[0]}번째 줄 라벨과 겹쳐 보인다(어림값). PNG 에서 확인한다: '{a[1][:16]}' / '{b[1][:16]}'")


def convert(path, view_box):
    import cairosvg

    target = path.with_suffix(".png")
    cairosvg.svg2png(url=str(path), write_to=str(target), output_width=round(view_box[2] * 2), output_height=round(view_box[3] * 2))
    return target


def check(path, make_png):
    report = Report(path)
    source = path.read_text(encoding="utf-8")
    try:
        root = parse(source)
    except xml.parsers.expat.ExpatError as error:
        report.error(error.lineno, "xml", f"SVG 를 읽을 수 없다: {error}")
        return report

    apply_styles(root)
    values = [number(value) for value in re.split(r"[\s,]+", root.attrs.get("viewBox", "").strip())]
    view_box = values if len(values) == 4 and None not in values else None
    if view_box is None:
        report.error(root.line, "viewbox", "viewBox 가 없다. 2배 크기로 변환하려면 필요하다")

    check_text(report, root)
    check_background(report, root, view_box)
    check_css_var(report, source)
    check_colors(report, root)
    check_overlap(report, root)

    by_rule = ", ".join(f"{rule} {count}" for rule, count in sorted(report.counts.items()))
    print(f"{path}: ERROR {report.errors}개, WARN {report.warnings}개" + (f" ({by_rule})" if by_rule else ""))
    if report.errors == 0 and make_png:
        print(convert(path, view_box))
    return report


def main():
    args = sys.argv[1:]
    make_png = "--no-png" not in args
    paths = [arg for arg in args if arg != "--no-png"]
    if not paths:
        sys.exit("사용법: python3.12 -I check_svg.py [--no-png] <그림.svg> [<그림.svg> ...]")

    total_errors = sum(check(Path(arg), make_png).errors for arg in paths)
    sys.exit(1 if total_errors else 0)


if __name__ == "__main__":
    main()

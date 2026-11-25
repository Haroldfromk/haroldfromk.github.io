#!/usr/bin/env python3
"""
블로그 포스트 외부 링크 확인기

사용법:
    python3 check_links.py <post.md | 주소> [<post.md | 주소> ...]

포스트 경로를 주면 본문(code block 밖)의 외부 링크를 모두 뽑아서 확인하고,
http 로 시작하는 주소를 주면 그 주소만 확인한다. 문제 있는 링크만 출력한다.

Apple 문서 링크는 페이지가 아니라 문서 데이터 주소가 200 인지로 판정한다.
404 면 부모 타입의 문서 데이터에서 이름이 같은 주소 후보를 찾아 같이 보여준다.

ERROR 가 하나라도 있으면 exit code 1 로 끝난다.
WARN(자동 접속 차단, 시간 초과 등)은 사람이 직접 열어 볼 항목이라 exit code 에 영향을 주지 않는다.
"""

import json
import re
import subprocess
import sys
import urllib.parse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
# 주소 안의 괄호 한 겹까지 허용한다: .../view/task(priority:_:)
INLINE_LINK = re.compile(r"(?<!!)\[[^\]]+\]\((https?://(?:[^()\s]|\([^()\s]*\))+)\)")
OWN_SITE = "haroldfromk.github.io"
APPLE_DOCS = "https://developer.apple.com/documentation/"
APPLE_DATA = "https://developer.apple.com/tutorials/data/documentation/"
USER_AGENT = "Mozilla/5.0 (link-check)"
TIMEOUT = 15
BLOCKED = {401, 403, 429, 999}  # 자동 접속을 막는 사이트가 돌려주는 코드
MAX_CANDIDATES = 5


def fetch(url):
    """(상태 코드, 본문 bytes) 를 돌려준다. 연결 자체가 실패하면 (None, 이유).

    python 의 urllib 은 설치본에 따라 인증서 묶음이 없어 https 가 실패하므로 curl 을 쓴다.
    """
    quoted = urllib.parse.quote(url, safe=":/?#[]@!$&'()*+,;=%~-._")
    command = ["curl", "-sS", "-g", "-L", "--max-time", str(TIMEOUT), "-A", USER_AGENT, "-w", "\n%{http_code}", quoted]
    done = subprocess.run(command, capture_output=True)
    body, _, code = done.stdout.rpartition(b"\n")
    if done.returncode != 0 or not code.isdigit() or code == b"000":
        return None, done.stderr.decode("utf-8", "replace").strip() or f"curl exit {done.returncode}"
    return int(code), body


def apple_path(url):
    """Apple 문서 주소에서 documentation/ 뒤의 경로를 소문자로 돌려준다."""
    path = url[len(APPLE_DOCS):].split("#")[0].split("?")[0].rstrip("/")
    return urllib.parse.unquote(path).lower()


def apple_candidates(path):
    """부모 타입의 문서 데이터에서 마지막 이름이 같은 주소를 찾는다 (overload 접미사 찾기용)."""
    if "/" not in path:
        return []
    parent, name = path.rsplit("/", 1)
    name = re.sub(r"-[0-9a-z]{4,6}$", "", name)
    status, body = fetch(f"{APPLE_DATA}{parent}.json")
    if status != 200:
        return []
    found = []
    for reference in json.loads(body).get("references", {}).values():
        ref_url = reference.get("url", "") if isinstance(reference, dict) else ""
        last = ref_url.rsplit("/", 1)[-1].lower()
        if ref_url.lower().startswith(f"/documentation/{parent}/") and (last == name or last.startswith(name + "-")):
            found.append("https://developer.apple.com" + ref_url)
    return sorted(set(found))[:MAX_CANDIDATES]


def check(url):
    """(등급, 메시지) 를 돌려준다. 문제가 없으면 (None, None)."""
    if url.startswith(APPLE_DOCS):
        path = apple_path(url)
        status, body = fetch(f"{APPLE_DATA}{path}.json")
        if status == 200:
            return None, None
        if status == 404:
            candidates = apple_candidates(path)
            hint = " 후보: " + ", ".join(candidates) if candidates else " 부모 문서에서도 같은 이름을 못 찾았다"
            return "ERROR", f"Apple 문서가 없다(404): {url}{hint}"
        return "WARN", f"Apple 문서 확인 실패({status if status else body}): {url}"

    status, body = fetch(url)
    if status is not None and 200 <= status < 300:
        return None, None
    if status in (404, 410):
        return "ERROR", f"페이지가 없다({status}): {url}"
    if status in BLOCKED:
        return "WARN", f"자동 접속을 막는 사이트라 확인 못 했다({status}). 직접 열어 본다: {url}"
    return "WARN", f"확인 실패({status if status else body}). 직접 열어 본다: {url}"


def links_in_post(path):
    """[(줄 번호, 주소)] code block 밖의 외부 링크."""
    found = []
    fence = None
    for number, line in enumerate(path.read_text(encoding="utf-8").split("\n"), start=1):
        match = FENCE.match(line)
        if match:
            marker = match.group(1)
            if fence is None:
                fence = marker
            elif marker[0] == fence[0] and len(marker) >= len(fence) and not line.strip()[len(marker):]:
                fence = None
            continue
        if fence is not None:
            continue
        for url in INLINE_LINK.findall(line):
            if OWN_SITE not in url:
                found.append((number, url))
    return found


def main():
    if len(sys.argv) < 2:
        sys.exit("사용법: python3 check_links.py <post.md | 주소> [<post.md | 주소> ...]")

    targets = []  # (출력할 위치, 주소)
    for arg in sys.argv[1:]:
        if arg.startswith(("http://", "https://")):
            targets.append(("주소", arg))
        else:
            targets.extend((f"{arg}:{number}", url) for number, url in links_in_post(Path(arg)))

    urls = sorted({url for _, url in targets})
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = dict(zip(urls, pool.map(check, urls)))

    errors = warnings = 0
    for where, url in targets:
        level, message = results[url]
        if level == "ERROR":
            errors += 1
            print(f"{where}: ERROR [link] {message}")
        elif level == "WARN":
            warnings += 1
            print(f"{where}: WARN  [link] {message}")

    print(f"링크 {len(targets)}개(주소 {len(urls)}종) 확인: ERROR {errors}개, WARN {warnings}개")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()

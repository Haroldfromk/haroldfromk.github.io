#!/usr/bin/env python3
"""
블로그 배포용 커밋 스크립트

posts-lastmod-hook.rb 플러그인이 활성화된 상태에서 jekyll build/serve를 돌리면
git log를 글 개수만큼 fork해서 실행하느라 로컬 빌드가 매우 느려진다.
그래서 평소 작업 중에는 이 플러그인을 .disabled로 꺼두고 작업하다가,
실제로 커밋/푸시할 때만 잠깐 켜서 last_modified_at 값이 정상 반영되게 하고
푸시가 끝나면 다시 꺼서 다음 로컬 작업 속도를 유지한다.

사용법:
    python3 deploy_post.py
"""

import subprocess
import sys
from pathlib import Path

# 이 스크립트가 blog 저장소 루트에 있다고 가정. 다른 위치에 두면 아래 경로를 수정할 것.
REPO_ROOT = Path(__file__).resolve().parent
PLUGIN_ACTIVE = REPO_ROOT / "_plugins" / "posts-lastmod-hook.rb"
PLUGIN_DISABLED = REPO_ROOT / "_plugins" / "posts-lastmod-hook.rb.disabled"

COMMIT_MESSAGE = "post"


def run(cmd: list[str]) -> None:
    print(f"$ {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=REPO_ROOT)
    if result.returncode != 0:
        sys.exit(f"실패: {' '.join(cmd)}")


def main() -> None:
    # 1. 변경사항 있는지 확인
    status = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    ).stdout
    if not status.strip():
        print("커밋할 변경사항 없음")
        return

    # 2. lastmod 훅 활성화 (꺼져있던 경우만)
    reenabled = False
    if PLUGIN_DISABLED.exists() and not PLUGIN_ACTIVE.exists():
        PLUGIN_DISABLED.rename(PLUGIN_ACTIVE)
        reenabled = True
        print("lastmod 훅 활성화됨")
    elif PLUGIN_ACTIVE.exists():
        print("lastmod 훅 이미 활성화 상태")
    else:
        print("경고: posts-lastmod-hook.rb 파일을 찾을 수 없음 (경로 확인 필요)")

    # 3. 커밋 & 푸시
    run(["git", "add", "-A"])
    run(["git", "commit", "-m", COMMIT_MESSAGE])
    run(["git", "push"])

    # 4. 다시 비활성화 (다음 로컬 작업 속도 위해)
    if reenabled:
        PLUGIN_ACTIVE.rename(PLUGIN_DISABLED)
        print("lastmod 훅 다시 비활성화됨 (다음 로컬 작업 속도 위해)")


if __name__ == "__main__":
    main()

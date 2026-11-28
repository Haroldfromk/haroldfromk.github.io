---
title: "여러 Claude를 나눠 부리기: 누가 판정하고 맥락을 어떻게 넘기나"
writer: Harold
date: 2026-11-27 11:50:00 +0900
categories: [Udemy, ClaudeCode]
tags: [ClaudeCode, Subagent, Headless, Orchestration]

toc: true
toc_sticky: true
published: true
---

작업 메모와 코드를 보고 AI로 정리한 글이다. Claude Code Bootcamp에서 subagent, 에이전트 팀, 훅, headless를 들을 때 옆에 두고 비교하는 참고 노트로 쓴다.
{: .prompt-info }

강의에서 subagent와 에이전트 팀(여러 Claude 세션이 일을 나눠 맡고 서로 주고받는 구성)을 배우기 전에, 나는 Claude를 여러 번 불러 일을 시키는 무인 실행기(autorun)를 먼저 만들어 봤다. 만들다 보니 같은 세 질문에 계속 부딪혔다. 여러 Claude를 어떻게 나눠 부리나, 누가 "됐다"고 판정하나, 단계 사이에 맥락을 어떻게 넘기나. 이 글은 그 답을 개념별로 정리한 비교용 노트다. autorun은 예시 하나로만 쓴다.

---

## 예시로 쓸 실행기

autorun은 계획 문서(체크리스트)에서 체크 안 된 task를 하나씩 `implement → 게이트 → 리뷰 → (fix → 게이트 → 리뷰) 최대 3라운드 → 로컬 커밋`으로 처리하는 zsh 스크립트다. 모든 task가 끝나거나 중간에 멈추면 인계 메모를 쓰고, 커밋이 하나라도 있으면 블로그 메모도 쓴다. 단계마다 `claude -p`를 한 번씩 새로 부른다.

만든 이유는 병목 때문이었다. 나는 계획을 세우고, task마다 implementer와 reviewer 루프를 돌리고, 커밋하고, 인계 메모를 남기고, 새 세션을 여는 순서로 일한다. 그런데 세션이 바뀔 때마다 사람이 손으로 다시 시작해야 했다.

![모델(claude -p)은 일하는 칸 네 개뿐이고, 게이트, 지적 판정, 라운드 수, 커밋, 다음 task 고르기는 스크립트가 한다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-27-orchestration-patterns/orchestration-runner-flow.png)

청록색 칸 네 개(implement, review, fix, handoff)가 모델을 부르는 자리이고, 회색 칸(게이트, 지적 판정, 라운드 수, 커밋, 다음 task 고르기)은 전부 스크립트가 한다. fix는 최대 3라운드까지만 돌고, 게이트가 실패하거나 3라운드를 넘기면 멈춘다. 모델은 일하고, 스크립트가 판정해서 다음 칸을 고른다. 게이트 실패나 라운드 초과로 멈춰도 마무리에서 handoff를 부른다. 사용량 한도로 멈출 때만 handoff를 부르지 않고, 인계 메모 맨 위에 멈춤 문단만 덧붙인다.

---

### headless 모드란?

[`claude -p`](https://code.claude.com/docs/en/headless){:target="_blank"}는 대화창 없이 프롬프트 하나를 받아 끝까지 처리하고, 결과를 출력하고, 끝나는 모드다. 대화 대신 쪽지를 넣고 답장을 받는 우편함과 비슷하다. 스크립트가 Claude를 함수처럼 부르려면 이 모드가 필요했다. 프롬프트를 넣으면 결과가 나오고 프로세스가 끝나서, 호출마다 깨끗한 상태로 시작한다.

---

## 판정을 모델 밖에 두는 원칙

실행기를 설계하면서 가장 먼저 정한 원칙은 설계 문서의 이 한 줄이다.

> 판정(테스트 결과, 라운드 수, 커밋, 멈춤)은 셸 스크립트가 직접 한다. 모델의 "통과했다"는 말을 믿지 않는다.

같은 문서의 "실패로 칠 것" 목록도 이 원칙에서 나왔다.

- 테스트가 빨간 상태로 커밋되는 것
- reviewer가 implementer의 대화나 판단을 보고 도장만 찍는 것
- 밤새 돌다가 주간 한도(구독 사용량의 주별 상한)를 다 쓰는 것
- `--dangerously-skip-permissions`나 넓은 `--allowedTools`로 도는 것
- 멈췄는데 왜 멈췄는지 기록이 없는 것

---

### 게이트란?

게이트는 task가 다음 단계로 넘어가기 전에 꼭 통과해야 하는 관문이다. 여기서는 테스트와 빌드 명령 목록이다. 공항 검색대와 같아서, 승객이 "가방에 위험한 건 없어요"라고 말해도 검색대는 자기 기계로 다시 본다. 모델이 테스트를 돌려 "통과했다"고 해도 그 말은 판정에 쓰지 않는다. 실행기가 따로 돌린 결과만 쓴다.

```zsh
# 게이트: AR_GATE 명령을 순서대로, 대상 저장소에서. 첫 실패에서 멈춘다.
gate_run() {
  local repo=$1 log=$2 cmd rc
  for cmd in "${AR_GATE[@]}"; do
    print -r -- "\$ $cmd" >> "$log"
    ( cd "$repo" && exec timeout "${AR_GATE_TIMEOUT:-1800}" zsh -c "$cmd" ) >> "$log" 2>&1 &
    AR_CHILD_PID=$!
    wait $AR_CHILD_PID
    rc=$?
    AR_CHILD_PID=""
    if (( rc != 0 )); then
      print -r -- "→ 실패 (exit $rc)" >> "$log"
      return 1
    fi
  done
  return 0
}
```

#### timeout과 wait로 게이트 명령 돌리기

1. [`timeout`](https://www.gnu.org/software/coreutils/manual/html_node/timeout-invocation.html){:target="_blank"}은 GNU coreutils의 명령으로, 첫 인자(여기서는 `AR_GATE_TIMEOUT`, 기본 1800초)가 지나면 뒤에 오는 명령을 강제로 끝낸다. 게이트가 무한히 도는 것을 막는 안전장치다.
2. 명령 끝의 `&`는 그 줄을 백그라운드로 보낸다. 바로 뒤의 `$!`는 방금 띄운 프로세스의 PID(프로세스 번호)이고, 그걸 `AR_CHILD_PID`에 담아 둔다. 중단 신호가 오면 이 번호로 자식을 끌 수 있다.
3. zsh 내장 명령 `wait`는 그 PID의 프로세스가 끝날 때까지 기다리고, 종료 코드를 `$?`로 남긴다. `rc`가 0이 아니면 로그에 실패를 적고 `return 1`로 첫 실패에서 멈춘다.

`print -r --`는 zsh 내장 출력 명령이다. `-r`은 `\` 같은 문자를 해석하지 않고 그대로 찍고, `--`는 그 뒤를 옵션이 아니라 출력할 내용으로 읽게 한다. 명령 문자열이 `-`로 시작해도 안전하게 로그에 남는다.

종료 코드는 프로세스가 끝날 때 운영체제에 남기는 숫자로, 0이면 성공이고 그 밖의 값이면 실패다. 스크립트는 모델의 말 대신 이 숫자만 본다.

이 원칙이 실제로 지켜 준 일이 있다. implement 프롬프트는 "끝내기 전에 게이트 명령을 직접 돌려 통과를 확인한다"고 시킨다. 그래서 haiku(Claude 모델 등급 중 가장 작은 것. 중간은 sonnet, 가장 큰 것은 opus)가 task마다 한 번쯤 게이트 명령 뒤에 `; echo`를 붙여 부르다가 권한 거절을 당했다. 그래도 판정에는 모델이 돌린 결과가 아니라 실행기가 따로 돌린 게이트만 쓰므로 결과에는 영향이 없었다.

리뷰어에게 주는 프롬프트에도 같은 원칙이 들어 있다. (스테이징은 커밋할 변경을 올려 둔 상태이고, diff는 바뀐 줄을 보여 주는 비교 결과다.)

```text
독립 리뷰어로서, 아래 task 를 위해 스테이징된 변경을 검토한다. 구현자의 설명은 일부러 주지 않는다. 코드와 계획만 보고 판단한다.
...
- 테스트나 게이트를 직접 돌리지 않는다. 실행기가 리뷰 전에 게이트를 돌려 통과시켰다. Bash 는 `git diff`, `git log`, `git show` 만 된다.
```

---

## 여러 Claude를 부리는 세 방식

설계할 때 세 방식을 비교했다. SDD는 subagent-driven development(task마다 새 subagent를 띄워 구현시키고 리뷰시키는 방식)다.

| | 방식 | 장점 | 단점 |
|---|---|---|---|
| A | task 하나를 `claude -p` 한 번에 맡기고 그 안에서 subagent 루프 | 스크립트가 짧고 지금 SDD 방식과 같다 | 테스트 결과와 라운드 수를 모델 보고에 기댐 |
| B | Agent SDK 프로그램 | 가장 엄격, 호출별 도구 제한을 코드로 | 코드와 의존성, 구독 로그인으로 도는지 확인 필요 |
| **C (고름)** | **zsh 스크립트가 심판, 구현/리뷰/수정을 각각 따로 `claude -p`** | B만큼 엄격하고 A만큼 작다. reviewer가 다른 프로세스라 진짜 독립 | 단계 간 정보는 파일과 JSON으로만 넘김 |

Agent SDK는 Claude Code를 코드(Python이나 TypeScript)에서 부르는 라이브러리다.

![A는 판정이 모델 세션 안에 있고, B는 내 코드가, C는 zsh 스크립트가 판정하며 구현과 리뷰와 수정은 각각 독립된 claude -p 호출이다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-27-orchestration-patterns/orchestration-who-judges.png)

세 방식의 차이는 한 가지다. 판정하는 쪽이 모델 안에 있느냐 밖에 있느냐. A는 부모 세션이 자기 subagent의 보고를 받아 스스로 판단한다. B와 C는 판정을 모델 밖으로 뺀다. C는 그 밖을 셸 스크립트로 만들어서 B보다 작게 끝냈다.

---

### subagent란?

[subagent](https://code.claude.com/docs/en/sub-agents){:target="_blank"}는 한 세션(부모) 안에서 부모가 일을 떼어 맡기는 또 하나의 Claude다. 자기 context에서 일하고, 부모에게는 결과 요약만 돌려준다. 팀장이 팀원에게 일을 맡기고 보고만 받는 것과 같다. 위 표에서 A 방식의 기본 단위가 이것이고, 강의 주제이기도 하다.

강의와 비교할 점은 여기다. subagent는 한 세션 안에서 부모가 결과를 받는 구조라 A에 가깝다. autorun은 프로세스 바깥의 스크립트가 조율하는 C다.

---

## 대화가 아니라 파일로 넘기는 맥락

단계마다 새 `claude -p`라서 context가 쌓이지 않는다. 대신 단계 사이의 정보는 프롬프트 파일, `--json-schema`로 받은 JSON, git diff로만 넘어간다.

---

### context window란?

context window는 모델이 한 번에 볼 수 있는 대화 분량이다. 책상 넓이와 같아서, 자료를 계속 쌓으면 책상이 차서 앞쪽 자료를 치워야 한다. Claude Code는 대화가 길어지면 앞부분을 요약(compaction)하는데, 그때 세부 내용이 사라진다. 단계 사이에는 대화가 쌓이지 않으니, 한 단계가 혼자 책상을 채우지 않는 한 compaction이 일어나지 않는다. 이것이 새 프로세스로 나눈 근거였다.

호출 하나를 만드는 인자는 `lib/claude.zsh`의 한 함수에 모여 있다.

```zsh
_ar_claude_args() {
  args=(-p --model "$1" --output-format stream-json --verbose --json-schema "$2")
  local d
  for d in "${AR_CALL_ADD_DIRS[@]}"; do args+=(--add-dir "$d"); done
  args+=(--allowedTools "${AR_CALL_ALLOWED[@]}"
    --disallowedTools "Bash(git push:*)" "Bash(git commit:*)" "Bash(git reset:*)" "Bash(git checkout:*)" "Bash(rm:*)"
    --max-budget-usd "$AR_BUDGET")
}
```

#### claude 호출 인자로 역할 좁히기

같은 종류의 옵션이 나란히 있어서 표로 정리한다. 전체 목록은 [CLI reference](https://code.claude.com/docs/en/cli-reference){:target="_blank"}에 있다.

| 플래그 | 하는 일 |
|---|---|
| `-p` | headless로 실행한다 |
| `--model` | 호출마다 모델을 고른다(sonnet, opus 등) |
| `--output-format stream-json` | 진행 과정을 JSON 한 줄씩 흘려 보낸다. 마지막 줄이 최종 결과다 |
| `--verbose` | `stream-json`을 쓸 때 함께 필요한 옵션이다 |
| `--json-schema` | 최종 답을 이 JSON schema(필드 이름과 값 종류를 정해 둔 틀) 모양으로 받는다 |
| `--add-dir` | 작업 폴더 밖에서 읽거나 쓸 폴더를 추가한다 |
| `--allowedTools` | 묻지 않고 쓸 수 있는 도구 목록이다 |
| `--disallowedTools` | 어떤 경우에도 못 쓰는 도구 목록이다. 여기서는 `git push`, `commit`, `reset`, `checkout`, `rm`을 막았다. `Bash(git push:*)`의 `:*`는 뒤에 무엇이 붙어도 같은 규칙으로 본다는 뜻이다 |
| `--max-budget-usd` | 호출 하나가 쓸 수 있는 비용 상한이다 |

커밋은 스크립트만 하고, push는 아무도 하지 않는다. 그래서 `git commit`과 `git push`를 `--disallowedTools`에 넣었다.

---

### 구조화된 출력이란?

구조화된 출력은 모델의 답을 자유 문장 대신 정해 둔 JSON 모양으로 받는 것이다. 빈칸이 정해진 서식을 채우게 하는 것과 같다. 스크립트가 답을 읽고 분기하려면 문장이 아니라 필드가 필요했다. 리뷰 결과의 schema(`schemas/review.json`)를 줄이면 이렇다.

```json
{
  "verdict": "approve | changes",
  "findings": [
    { "severity": "critical | important | minor", "file": "...", "line": 0, "problem": "...", "fix": "..." }
  ],
  "summary": "..."
}
```

스크립트는 `stream-json` 출력에서 마지막 result를 골라 그 안의 `structured_output`만 꺼낸다.

```zsh
so=$(jq -cs 'map(select(.type == "result")) | last | select(. != null and .is_error != true) | .structured_output | select(. != null)' "$out.jsonl" 2>/dev/null)
```

#### jq로 마지막 result에서 구조화된 출력 꺼내기

[`jq`](https://jqlang.org/manual/){:target="_blank"}는 JSON을 명령줄에서 걸러 내고 바꾸는 도구다. 이 한 줄은 파이프(`|`)로 필터를 이어 붙인 것이다.

1. `-c`는 결과를 한 줄로 내보내고, `-s`(slurp)는 줄마다 따로 있는 JSON 여러 개를 하나의 배열로 모아서 읽는다. `stream-json` 출력이 JSON 줄의 연속이라 필요하다.
2. `map(select(.type == "result"))`는 배열에서 `type`이 `result`인 항목만 남긴다. `select`는 조건이 참인 것만 통과시키는 필터다.
3. `last`는 그중 마지막 항목을 고른다. 이어서 `select(. != null and .is_error != true)`로 비어 있거나 오류로 끝난 결과를 걸러 내고, `.structured_output`을 꺼낸다.

`structured_output`이 없으면 `so`가 비어서 스크립트는 호출 실패로 처리한다. 모델이 모양을 못 맞춘 답을 그냥 믿고 넘어가지 않는다.

reviewer에게는 implementer의 대화와 요약을 주지 않는다. 계획 머리말, task 본문, 설계 문서 경로, 이전 라운드의 minor가 아닌 지적만 프롬프트로 주고, diff는 reviewer가 `git diff --cached`로 직접 본다. reviewer가 다른 프로세스라서 가능한 일이고, C 방식을 고른 이유이기도 하다.

세션 사이의 인계는 인계 메모 다섯 칸으로 한다. 현재 상태, 남은 일, 정한 것, 해봤는데 안 된 것, 핵심 파일이다. session-handoff 스킬(Claude Code가 필요할 때 꺼내 읽는 작업 설명서의 하나로, 세션을 넘길 때 쓸 메모 형식을 정해 둔다)이 이 형식을 정했고 autorun의 handoff 단계도 같은 다섯 칸을 쓴다.

---

## 리뷰 결과로 판정하기

판정을 스크립트가 해도, 무엇을 보고 판정하느냐에서 한 번 틀렸다. reviewer가 minor 지적만 있어도 verdict를 `changes`로 줘서 쓸데없는 fix 라운드가 돌았다. 그래서 verdict는 보지 않고, critical이나 important 지적이 하나라도 있는지로 판정하게 바꿨다.

```zsh
_task_review_changes() {
  jq -e 'any(.findings[]?; .severity == "critical" or .severity == "important")' "$1" >/dev/null
}
```

호출하는 쪽에는 둘이 어긋날 때를 처리하는 줄도 있다.

```zsh
    if ! _task_review_changes "$td/review-$r.json"; then
      [[ $(jq -r .verdict "$td/review-$r.json") == changes ]] &&
        ar_warn "Task $n 리뷰 $r: verdict changes 인데 critical/important 지적이 없어 approve 로 봄"
      break
    fi
```

#### jq로 지적 등급 판정하기

- [`jq -e`](https://jqlang.org/manual/){:target="_blank"}는 마지막 결과가 `false`나 `null`이면 종료 코드를 1로 내보낸다. 그래서 셸의 `if`에서 바로 참과 거짓으로 쓸 수 있다.
- [`any(생성기; 조건)`](https://jqlang.org/manual/){:target="_blank"}은 생성기가 내놓는 값 중 하나라도 조건이 참이면 `true`를 돌려준다. 여기서는 `.findings[]?`의 각 지적이 critical이거나 important인지 본다. `[]?`의 `?`는 `findings`가 없을 때 오류 대신 빈 목록으로 보는 표시다.

- 호출하는 쪽의 `jq -r`은 결과가 문자열이면 따옴표 없이 있는 그대로 내보낸다(raw output). 그래서 `verdict` 값 `changes`를 셸의 `==`로 바로 비교할 수 있다.

경고는 한 방향으로만 난다. verdict가 `changes`인데 critical이나 important 지적이 없으면 경고를 남기고 approve로 본다. 반대로 verdict를 `approve`로 붙였어도 important 지적이 있으면 경고 없이 fix 라운드가 돈다. 판정은 모델이 붙인 라벨이 아니라 지적의 등급으로 한다.

---

## 역할별 모델 고르기

실제 설정은 implement, fix, handoff가 sonnet, review가 opus다(`projects/quickrun.json`).

```json
"models": { "implement": "sonnet", "fix": "sonnet", "review": "opus", "handoff": "sonnet" },
```

동작 확인(smoke)은 전부 haiku로 했다. 장난감 저장소에 task 2개를 돌리는 데 $0.04 정도 들었고, 주간 한도는 그대로였다. 실행기 자체는 가짜 claude 바이너리를 써서 테스트 103개로 검증했다.

executing-plans 스킬은 이렇게 말한다. 계획이 충분히 자세하면 실행은 받아쓰기라서 중간급 모델로 되고, 가장 큰 모델이 값을 하는 곳은 마지막 전체 리뷰 한 번이다. 내 설정은 그 말을 호출 단위로 옮긴 것이다. 받아쓰기에 가까운 implement와 fix는 sonnet, 판단이 필요한 review는 opus를 쓴다.

---

## Subagent-driven과 Native

superpowers 플러그인에는 계획을 실행하는 스킬이 두 갈래 있다.

- Subagent-driven(subagent-driven-development): task마다 새 구현 subagent와 새 리뷰 subagent를 띄우고, 끝에 전체 리뷰를 한다. 가장 꼼꼼하지만 비용이 크다.
- Native(executing-plans): 이 세션에서 Claude가 직접 TDD로 구현하고, 끝에 opus 리뷰어를 한 번 부른다. autorun을 만들 때는 Native를 골랐다.

TDD(test-driven development)는 실패하는 테스트를 먼저 쓰고, 그 테스트를 통과시키는 코드를 쓰는 방식이다.

Native는 subagent가 주던 장점을 다른 장치로 대신 지킨다.

| subagent가 주던 것 | Native에서 대신하는 것 |
|---|---|
| task마다 새 context | 브리프(task 설명서)가 스펙 역할을 한다 |
| 이전 task를 이어받는 기억 | 실행 원장과 git log가 기억을 맡는다 |
| 구현자와 다른 눈의 task별 검사 | TDD가 task마다 관문이 된다 |
| 전체를 보는 독립 리뷰 | 마지막 opus 리뷰어가 두 번째 눈이 된다 |

실행 원장(ledger)은 `progress.md`에 task 완료 줄과 `Ruling:` 줄을 남기는 파일이다. compaction 뒤에도 이미 끝낸 task를 다시 하지 않게 하려는 장치다. 핵심 문장은 이렇다. 대화 기억은 compaction을 못 넘으니 원장과 git log를 믿는다.

마지막 전체 리뷰의 결과를 처리하는 규칙도 executing-plans에 있다. 등급은 리뷰어의 라벨이 아니라 쓰는 사람이 실제로 겪는 영향으로 다시 매긴다. Critical과 Important만 한 번 고치고, 각각 실패하는 테스트를 먼저 쓴다. Minor는 미룬 목록으로 보낸다. 이 규칙을 따르다 보니 리뷰어가 minor로 붙인 지적도 쓰는 사람이 겪는 영향이 크면 important로 올려서 고치게 됐다.

---

## 스킬 체인과 사람의 승인 지점

autorun 같은 실행기를 만들기 전에, 나는 스킬을 이어 붙여 일하는 순서부터 정해 두었다. 그 순서에서 사람이 어디서 승인하는지가 무엇을 무인으로 바꿀 수 있는지를 갈랐다.

---

### 스킬이란?

스킬은 Claude Code가 필요할 때 꺼내 읽는 작업 설명서(`SKILL.md`)다. 업무 매뉴얼 한 장과 비슷하다. 내용을 매번 프롬프트에 붙여 넣는 대신 이름만 불러서 쓴다. 자세한 형식은 [Skills 문서](https://code.claude.com/docs/en/skills){:target="_blank"}에 있다.

---

superpowers의 스킬은 순서대로 이어진다.

1. brainstorming: 무엇을 왜 만드는지, 접근 방식을 무엇으로 할지 정하고 설계 문서를 쓴다
2. writing-plans: 파일, 시그니처, 테스트까지 정한 계획을 쓴다
3. executing-plans 또는 subagent-driven-development: 계획을 실행한다
4. finishing-a-development-branch: 테스트를 확인하고 merge(작업 브랜치를 본 줄기에 합치기), PR(합쳐 달라고 올리는 요청), 보관(브랜치를 그대로 두기) 셋 중 하나를 고른다

각 단계에 사람의 승인 지점이 있다. 설계 승인, 실행 방식 고르기, merge 여부다. autorun은 이 중 실행 부분만 무인으로 바꾼 것이다. push와 merge는 하지 않는다(non-goal).

---

## 권한을 좁게 주는 allowedTools

무인으로 돌리니 "무엇을 할 수 있나"를 단계마다 다르게 좁혀야 했다.

---

### 권한 규칙이란?

[권한 규칙](https://code.claude.com/docs/en/permissions){:target="_blank"}은 Claude Code가 도구(Read, Edit, Bash 등)를 쓰기 전에 허용과 거절을 가르는 목록이다. `Bash(git diff:*)`처럼 도구 이름과 인자 패턴으로 쓰고, `:*`는 뒤에 무엇이 붙어도 허용한다는 뜻이다. 출입증에 적힌 출입 가능 구역과 같다. 목록에 없는 일은 무인 실행에서 거절되고 끝난다. 묻는 사람이 없기 때문이다.

```zsh
_task_impl_tools() {
  AR_CALL_ALLOWED=(Read Edit Write Glob Grep "Bash(git diff:*)" "Bash(git status)")
  local x; for x in "${AR_IMPL_BASH[@]}"; do AR_CALL_ALLOWED+=("Bash($x)"); done
  AR_CALL_ADD_DIRS=()
}
_task_review_tools() {
  AR_CALL_ALLOWED=(Read Glob Grep "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)")
  AR_CALL_ADD_DIRS=()
}
```

handoff 단계는 더 좁다. 읽기와 읽기 전용 git, 그리고 인계 메모 파일 하나와, 커밋이 있을 때만 블로그 메모 폴더를 `Edit`로 쓸 수 있다.

```zsh
# 절대 경로를 권한 규칙 꼴로: Claude Code 규칙에서 절대 경로는 // 로 시작한다.
_run_perm_path() { [[ $1 == /* ]] && print -r -- "/$1" || print -r -- "$1"; }
...
  AR_CALL_ALLOWED=(Read "Bash(git status)" "Bash(git log:*)" "Edit($(_run_perm_path "$AR_HANDOFF"))")
  ...
  if (( commits > 0 )) && [[ -n $AR_BLOG_NOTES ]]; then
    AR_CALL_ALLOWED+=("Edit($(_run_perm_path "$AR_BLOG_NOTES")/**)")
    AR_CALL_ADD_DIRS+=("$AR_BLOG_NOTES")
  fi
```

implement와 fix는 파일을 고치고 정해진 Bash 명령(테스트, 빌드)을 돌린다. review는 읽기와 `git diff`, `git log`, `git show`만 된다. 리뷰어는 파일을 고칠 수 없으니 자기가 본 코드를 슬쩍 바꿔 통과시킬 길이 없다.

진짜 호출(claude 2.1.326)로 부딪히며 알게 된 함정이 네 가지 있다.

| 함정 | 해결 |
|---|---|
| 절대 경로 규칙은 `//`로 시작해야 한다 | `_run_perm_path`가 절대 경로 앞에 `/`를 하나 더 붙인다 |
| `Write(...)` 경로 규칙은 효과가 없다. 블로그 메모 쓰기에 `Write(//dir/**)`를 줬는데 새 파일 쓰기가 거절됐고, `Edit(//dir/**)`가 새 파일 쓰기까지 허용한다 | 쓰기 허용은 `Edit(...)`로 준다 |
| `Bash(cmd)`는 `cmd; echo ...`나 `cd x && cmd`처럼 이어 붙인 명령과 맞지 않는다 | 프롬프트에 "게이트 명령과 허용된 명령은 적힌 그대로 하나씩 실행한다"를 넣고, 게이트도 `swift test --package-path x`처럼 한 줄 한 명령으로 쓴다 |
| handoff가 `git status`를 거절당해 메모에 "작업 트리를 확인 못 함"이라고 썼다 | 읽기 전용 `Bash(git status)`와 `Bash(git log:*)`를 허용한다 |

`Write` 규칙의 함정은 smoke 실행에서 드러났다. 허용 목록을 고치기 전의 1차 실행에서는 블로그 메모 쓰기가 거절됐고, `Edit`로 바꾼 2차 실행에서는 블로그 메모가 써졌다. 둘 다 장난감 저장소의 task 2개를 haiku로 돌린 결과다.

| 실행 | 결과 | 비용 합 (`total_cost_usd`) | claude 시간 합 | 주간 (`seven_day`: 구독 사용량 한도 대비 비율) | 5시간 (같은 비율의 5시간 단위 한도) |
|---|---|---|---|---|---|
| 1차 (허용 목록 고치기 전) | 커밋 2개, 블로그 메모 거절됨 | $0.059 | 104초 | 84% → 84% | 20% → 20% |
| 2차 (고친 뒤) | 커밋 2개, 인계 메모, 블로그 메모, 점검 항목 | $0.041 | 89초 | 84% → 84% | 22% → 23% |

세 번째 줄의 프롬프트 문구는 `prompts/implement.md`에 이렇게 들어 있다.

```text
- 게이트 명령과 허용된 명령은 적힌 그대로 하나씩 실행한다. 앞뒤에 `;`, `&&`, `|`, `cd`, `echo` 를 붙이면 허용 목록에 안 맞아 거절된다. 종료 코드는 도구 결과에 이미 나온다.
```

거절된 도구는 `lib/claude.zsh`에서 `*.denials.json`에 남긴다. 나중에 허용 목록을 늘릴지는 사람이 거절 기록을 보고 판단한다.

```zsh
dn=$(jq -cs 'map(select(.type == "result") | .permission_denials // []) | add // [] | select(length > 0)' "$out.jsonl" 2>/dev/null)
[[ -n $dn ]] && print -r -- "$dn" > "$out.denials.json"
```

#### jq로 거절 기록 모으기

[`add`](https://jqlang.org/manual/){:target="_blank"}는 배열 안의 배열들을 하나로 합치고, [`//`](https://jqlang.org/manual/){:target="_blank"}는 앞의 값이 없을 때 뒤의 값을 대신 쓴다는 뜻이다. 여기서는 result마다 `.permission_denials`를 꺼내 없으면 빈 배열로 두고, 그것들을 합쳐 한 배열로 만든다. 거절이 한 건도 없으면 `select(length > 0)`에서 걸러져 파일이 만들어지지 않는다.

---

## 세션끼리 일 넘기기

실행기 바깥, Claude 데스크톱 앱에서도 세션 자체를 나눠 부렸다. 부모 세션이 side session(부모 세션에서 갈라져 나와 일을 맡아 하는 별도 세션)을 열어 autorun 작업을 맡겼다. 큰 기록은 공유 노트 폴더(`side-session-notes/<부모 id>/`)에 두고, 보고는 끝 메시지의 앞 400자만 부모에게 넘어간다. 그래서 보고 맨 앞에 한 일(커밋)을 쓴다.

대화가 길어지면 훅이 "[대화 크기 알림]"을 넣는다. 그러면 session-handoff 스킬이 인계 메모를 쓰고, 새(fresh) 세션을 열고, 옛 세션과의 묶음을 바로 푼다(detach). 묶음을 안 풀면 새 세션이 답할 때마다 길어진 옛 세션이 깨어나서 한도를 쓴다.

---

### 훅이란?

[훅](https://code.claude.com/docs/en/hooks){:target="_blank"}은 Claude Code의 특정 순간(프롬프트 제출, 도구 호출 전후 등)에 자동으로 실행되는 내 스크립트다. 문을 열 때 울리는 센서와 같다. 대화 크기 알림은 UserPromptSubmit 훅(프롬프트를 보낼 때마다 도는 훅)이 대화 길이를 재서 일정 크기를 넘으면 알림 문구를 넣는 방식이다. 강의의 훅 부분과 이어서 볼 만한 실제 쓰임이다.

---

![옛 세션은 알림을 받고 인계 메모를 쓰며, 새 세션은 메모 파일만 읽고 시작하고, 옛 세션과의 묶음은 해제한다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-27-orchestration-patterns/orchestration-session-handoff.png)

세션 사이의 인계는 대화가 아니라 메모 파일로 하고, 옛 세션은 떼어 낸다. 새 세션은 옛 대화를 하나도 모르고 메모만 읽는다. 파일로 넘기는 구조는 위의 `claude -p` 단계들과 같은 원리다.

---

## 강의와 맞춰 볼 비교 축

강의의 subagent, 에이전트 팀, headless를 이 노트와 맞대면 비교 축은 세 가지다.

- 판정 위치: 에이전트 팀과 A, C가 갈리는 지점은 누가 판정하느냐다. 팀의 판정이 모델 보고에 기대면 A에 가깝고, autorun은 바깥 스크립트가 따로 검사한다.
- 도구 제한: subagent에 도구 제한을 줄 때도 `--allowedTools`와 같은 문제가 생긴다. `Write` 규칙이 안 먹는 것, 이어 붙인 명령이 거절되는 것이 대표적이다.
- 구조화된 출력: headless(`claude -p`)에서 `--json-schema`로 받는 JSON이 스크립트로 Claude를 부리는 핵심 부품이다. 스크립트가 분기하려면 이 모양이 필요하다.

내가 실행기를 만들며 가져간 결론은 두 가지다. 판정은 모델 밖에서 하고, 맥락은 대화가 아니라 파일로 넘긴다.

---

## 참고자료

- [Agent SDK overview (Claude Code Docs)](https://code.claude.com/docs/en/agent-sdk/overview){:target="_blank"}
- [superpowers (GitHub)](https://github.com/obra/superpowers){:target="_blank"}

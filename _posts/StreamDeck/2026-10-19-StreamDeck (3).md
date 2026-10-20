---
title: StreamDeck (3) 버튼 하나로 Alacritty 새 창에서 별칭 명령 실행하기, 그리고 볼륨 키
writer: Harold
date: 2026-10-19 18:20:00 +0900
last_modified_at: 2026-10-20 16:47:00 +0900
categories: [StreamDeck]
tags: [Process, zsh, Alacritty, AppleScript]

toc: true
toc_sticky: true
published: true
---

앱 실행 다음으로 넣고 싶었던 건 터미널 명령이다. 블로그 작업할 때 쓰는 `blogrun`, `postblog`, `uploadimg` 같은 별칭을 `~/.zshrc`에 만들어 두고 쓰는데, 이걸 버튼 하나로 실행하고 싶었다. 메인 터미널이 Alacritty라서 버튼을 누르면 Alacritty 새 창이 열리고 그 안에서 명령이 돌게 했다. 빈 Alacritty 창을 하나 더 여는 버튼과 맥 소리 크기 조절도 이번 글에서 같이 다룬다.

---

## 새 창이 안 생기는 앱 실행

처음엔 Alacritty도 그냥 앱 버튼으로 열면 되지 않나 싶었다. 그런데 Alacritty가 이미 켜져 있으면 앱 실행은 기존 창만 앞으로 가져온다. 터미널에서 `alacritty &`를 치면 새 창이 생기는 것과 다르다.

`open` 명령에는 이미 켜져 있어도 새로 하나 더 띄우는 `-n` 옵션이 있다. 앱 이름은 `-a`로 주고, 앱에 넘길 인자는 `--args` 뒤에 적는다. 그래서 빈 새 창은 이렇게 연다.

```text
open -na /Applications/Alacritty.app --args --working-directory /Users/dongik
```

`--working-directory`는 Alacritty 옵션으로, 새 창이 어느 폴더에서 시작할지 정한다. 명령을 실행하는 버튼은 여기에 `-e`(창 안에서 실행할 프로그램)를 더 붙인다.

```swift
// AlacrittyCommand.swift (DeckKit)
public static func openArguments(command: String?, directory: String?) -> [String] {
    let dir = directory.map(expandTilde) ?? NSHomeDirectory()
    var args = ["-na", appPath, "--args", "--working-directory", dir]
    if let command {
        args += ["-e", "/bin/zsh", "-ic", "\(command); exec zsh"]
    }
    return args
}
```

#### 홈 경로와 Optional map

[`NSHomeDirectory()`](https://developer.apple.com/documentation/foundation/nshomedirectory%28%29){:target="_blank"}는 지금 사용자의 홈 폴더 경로 글자(`/Users/이름`)를 준다. `directory.map(expandTilde)`의 [`map`](https://developer.apple.com/documentation/swift/optional/map%28%5F:%29){:target="_blank"}은 옵셔널에 쓰는 것으로, 값이 있으면 함수를 적용하고 nil이면 그대로 nil을 돌려준다. 폴더가 정해져 있을 때만 물결표를 홈 경로로 바꾸고, 없으면 `??` 뒤의 홈 폴더를 쓴다.

`blogrun`은 `bundle exec jekyll serve`라서 블로그 폴더 안에서 돌아야 한다. 그래서 명령 버튼에는 "실행할 폴더" 칸을 따로 뒀고, 그 값이 `--working-directory`로 들어간다. `~/Documents/...`처럼 물결표로 적어도 되게 앞에서 홈 경로로 바꿔 준다.

---

## 따옴표를 신경 쓰지 않아도 되는 인자 배열

명령 글자에 따옴표나 공백이 들어가면 어떻게 될지가 걱정이었다. 예를 들어 `git commit -m "a b"` 같은 걸 셸 명령 한 줄로 이어 붙이면 따옴표가 어디서 열리고 닫히는지 계속 신경 써야 한다.

---

### 셸과 인자란?

터미널에 명령을 치면 그 글자를 먼저 읽는 프로그램이 있다. 이게 셸이고, 맥의 기본 셸이 zsh다. 셸은 한 줄을 공백으로 잘라 단어로 나누고, 따옴표로 묶인 부분은 한 단어로 본 뒤 따옴표는 떼어 낸다. 그렇게 만든 단어 목록을 실행할 프로그램에 넘기는데, 이 단어 하나하나를 인자라고 부른다.

![셸 한 줄 git commit -m "a b"를 셸이 git, commit, -m, a b 네 인자로 나누고, Process.arguments에 배열로 직접 넘기면 셸 없이 같은 네 인자가 된다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-3/touchdeck-shell-args.png)

프로그램 입장에서는 셸을 거쳤든 아니든 받는 건 같은 인자 목록이다. 그러니 셸에게 한 줄을 읽히는 대신 목록을 직접 만들어 넘기면 따옴표를 맞출 일이 사라진다.

---

### 인자를 배열로 넘기기

여기서는 셸 한 줄로 만들지 않고 `Process`에 인자를 배열로 넘겼다. 배열의 칸 하나가 그대로 인자 하나가 되니, 명령 글자 전체가 zsh `-c`의 인자 하나로 통째로 들어간다. 그 안의 따옴표는 zsh가 평소처럼 읽는다. 테스트로 따옴표가 그대로 남는지 확인했다.

```swift
// AlacrittyCommandTests.swift (DeckKit)
@Test func commandArgumentsKeepQuotesIntact() {
    let args = AlacrittyCommand.openArguments(command: #"git commit -m "a b""#, directory: "/tmp")
    #expect(args == ["-na", "/Applications/Alacritty.app", "--args", "--working-directory", "/tmp",
                     "-e", "/bin/zsh", "-ic", #"git commit -m "a b"; exec zsh"#])
}
```

#### raw string 글자

`#"…"#`는 Swift의 raw string([`String`](https://developer.apple.com/documentation/swift/string){:target="_blank"})이다. 안의 따옴표와 역슬래시를 글자 그대로 두어서, 따옴표가 섞인 명령을 테스트 값으로 쓰기 좋다.

```swift
// ActionRunner.swift (맥)
@discardableResult
func runProcess(_ path: String, _ arguments: [String], output: Pipe? = nil) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(filePath: path)
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = output ?? FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
}
```

#### Process로 프로그램 실행하기

`runProcess`는 프로그램 하나를 이 순서로 실행한다.

1. [`Process`](https://developer.apple.com/documentation/foundation/process){:target="_blank"}를 만든다. 다른 프로그램을 자식 프로세스로 실행하는 도구이고, 셸을 거치지 않고 실행 파일을 바로 띄운다.
2. [`executableURL`](https://developer.apple.com/documentation/foundation/process/executableurl){:target="_blank"}에 실행할 파일 위치(`/usr/bin/open`, `/bin/zsh`)를, [`arguments`](https://developer.apple.com/documentation/foundation/process/arguments){:target="_blank"}에 인자 배열을 넣는다. 배열 칸 하나가 인자 하나다.
3. 입력과 출력을 정한다. [`standardOutput`](https://developer.apple.com/documentation/foundation/process/standardoutput){:target="_blank"}(그리고 `standardInput`, `standardError`)에 `FileHandle.nullDevice`를 넣으면 버리고, [`Pipe`](https://developer.apple.com/documentation/foundation/pipe){:target="_blank"}를 넣으면 한쪽에서 쓴 출력을 다른 쪽에서 읽을 수 있다.
4. [`run()`](https://developer.apple.com/documentation/foundation/process/run%28%29){:target="_blank"}으로 실행한다. 실행 파일이 없으면 오류를 던진다.
5. [`waitUntilExit()`](https://developer.apple.com/documentation/foundation/process/waituntilexit%28%29){:target="_blank"}로 끝날 때까지 기다린다. 그동안 이 스레드는 멈춘다.
6. [`terminationStatus`](https://developer.apple.com/documentation/foundation/process/terminationstatus){:target="_blank"}로 종료 코드를 읽는다. 0이면 성공이다.

`@discardableResult`는 "돌려주는 값을 안 써도 경고하지 말라"는 표시다. 종료 코드가 필요 없는 곳에서도 이 함수를 부를 수 있게 붙였다.

---

## 별칭이 보이는 대화형 zsh 실행

`blogrun`은 프로그램이 아니라 `~/.zshrc`에 적어 둔 별칭이다. zsh는 대화형으로 켜질 때만 `~/.zshrc`를 읽는다. 그래서 `-c`만 주면 `blogrun`을 모르고, `-i`(대화형)를 같이 줘서 `-ic`로 실행해야 터미널에서 직접 칠 때처럼 별칭이 먹는다.

---

### 별칭이란?

별칭은 긴 명령에 붙인 짧은 이름이다. `~/.zshrc`에 `alias blogrun='bundle exec jekyll serve --unpublished --livereload --limit_posts 10'`처럼 적어 두면, 셸이 명령을 읽을 때 `blogrun`을 긴 명령으로 바꿔 끼운다.

![내가 친 blogrun을 셸이 bundle exec jekyll serve 같은 긴 명령으로 바꿔 끼운다. 별칭은 셸이 기억하는 줄임말이라 셸 밖에서는 찾을 수 없다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-3/touchdeck-alias.png)

그래서 별칭은 셸 안에서만 산다. `open` 명령이나 `Process`는 셸을 거치지 않고 프로그램 파일을 바로 찾기 때문에 `blogrun`이라는 이름을 모른다. 버튼이 꼭 zsh를 거쳐야 하는 이유다.

---

### 대화형 셸과 .zshrc란?

대화형 셸은 사람이 한 줄씩 치고 결과를 보는 셸이다. 터미널 창을 열면 뜨는 그 셸이다. zsh는 대화형으로 켜질 때만 `~/.zshrc`를 읽는다. 별칭, 프롬프트 모양, oh-my-zsh 같은 플러그인은 사람이 쓰는 창을 위한 설정이라, 스크립트를 돌릴 때까지 읽으면 느리고 결과가 설정에 따라 달라질 수 있어서다.

![터미널 창과 zsh -ic는 대화형이라 .zshrc를 읽어 blogrun을 알고, zsh -c는 대화형이 아니라 .zshrc를 건너뛰어 blogrun을 모른다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-3/touchdeck-interactive-shell.png)

`zsh -c '명령'`은 명령 한 줄만 실행하는 대화형 아닌 셸이라 `~/.zshrc`를 건너뛴다. 여기에 `-i`를 더하면 대화형으로 켜져서 읽는다.

---

### 창을 남겨 두는 exec zsh

명령 뒤에 붙인 `; exec zsh`는 창을 남겨 두려는 것이다. `exec`는 지금 셸을 다른 프로그램으로 갈아 끼우는 명령이다. 이게 없으면 `uploadimg`처럼 금방 끝나는 명령은 끝나자마자 창이 닫혀서 결과를 못 본다. `exec zsh`로 셸을 이어 두면 명령이 끝난 뒤에도 그 창에서 계속 쓸 수 있고, `blogrun`처럼 계속 도는 건 그 창에서 Ctrl+C로 끄면 된다.

버튼을 눌러 실제로 뜬 프로세스를 확인해 보니 의도한 대로였다.

```text
$ ps -axo pid,args | grep -E "[A]lacritty|[j]ekyll serve"
57908 /Applications/Alacritty.app/Contents/MacOS/alacritty --working-directory /Users/dongik
58222 /Applications/Alacritty.app/Contents/MacOS/alacritty --working-directory /Users/dongik/Documents/Workspace/blog -e /bin/zsh -ic blogrun; exec zsh
58332 /Users/dongik/.gem/bin/jekyll serve --unpublished --livereload --limit_posts 10
```

첫 줄이 "새 터미널" 버튼으로 연 빈 창, 둘째 줄이 `blogrun` 버튼으로 연 창이다. 셋째 줄은 그 창 안에서 별칭이 풀려 실제로 돌고 있는 jekyll 서버다.

---

## 명령 끝 주석과 안 닫힌 따옴표

`; exec zsh`를 명령 뒤에 그냥 이어 붙이면, 명령 모양에 따라 이 부분이 사라진다. `blogrun # 블로그 서버`처럼 명령 끝에 주석을 달면 `; exec zsh`까지 주석이 된다. `echo "abc`처럼 따옴표를 닫지 않으면 zsh가 문법 오류를 내고 아무것도 실행하지 않는다. 어느 쪽이든 창이 바로 닫혀서 무슨 일이 있었는지 볼 수 없다.

줄바꿈으로 이으면 주석은 해결된다. 주석은 줄 끝에서 끝나기 때문이다. 하지만 따옴표는 줄을 넘어서도 계속 열려 있다. `exec zsh` 대신 `exec echo AFTER`를 넣어 확인했다.

```text
$ zsh -c $'echo "abc\nexec echo AFTER'
zsh:2: unmatched "
```

그래서 명령을 작은따옴표로 감싸 `eval`에 넘겼다. 바깥 스크립트는 명령이 어떻게 생겼든 늘 `eval '명령'; exec zsh` 모양이라 문법이 깨지지 않는다. 주석이나 따옴표 문제는 `eval` 안에서만 오류가 되고, 그다음 `exec zsh`는 그대로 실행된다. 별칭은 `eval`이 명령을 읽는 순간에 풀려서 전처럼 먹는다.

```text
$ zsh -c "eval 'echo \"abc'; exec echo AFTER"
(eval):1: unmatched "
AFTER
```

---

### eval이란?

`eval`은 글자를 받아서 그 자리에서 셸 명령으로 읽고 실행한다. 바깥 스크립트 입장에서 사용자 명령은 작은따옴표 안의 글자 하나일 뿐이라, 그 안에 주석 기호나 안 닫힌 따옴표가 있어도 바깥 문법은 멀쩡하다. 문제가 있으면 `eval`이 그 글자를 실행할 때 안에서만 오류가 난다.

![바깥 스크립트는 eval '사용자 명령'; exec zsh 모양이 늘 같다. 사용자 명령의 오류는 eval 안에서만 나고, 뒤의 exec zsh는 그래도 실행된다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-3/touchdeck-eval.png)

작은따옴표 안에서는 셸이 아무 글자도 특별하게 보지 않는다. 그래서 명령 안의 작은따옴표 하나만 따로 처리하면 된다.

```swift
// AlacrittyCommand.swift (DeckKit)
if let command {
    args += ["-e", "/bin/zsh", "-ic", "eval \(singleQuoted(command)); exec zsh"]
}

private static func singleQuoted(_ text: String) -> String {
    "'\(text.replacingOccurrences(of: "'", with: #"'\''"#))'"
}
```

#### replacingOccurrences로 글자 바꾸기

[`replacingOccurrences(of:with:)`](https://developer.apple.com/documentation/foundation/nsstring/replacingoccurrences%28of:with:%29){:target="_blank"}는 글자 안의 어떤 글자를 전부 다른 글자로 바꾼 새 글자를 돌려준다. 여기서는 `'`를 `'\''`로 바꿨다.

작은따옴표로 감싸는 방법은 뒤에서 다룰 `whence` 확인 스크립트와 같다. 테스트는 만든 스크립트를 실제 zsh로 돌려서 명령 다음 줄까지 실행되는지 본다.

```swift
// AlacrittyCommandTests.swift (DeckKit)
@Test(arguments: ["echo hi # 주석", #"echo "abc"#, "echo 'it"])
func shellStillContinuesAfterBrokenCommand(_ command: String) throws {
    let script = try #require(AlacrittyCommand.openArguments(command: command, directory: "/tmp").last)
    let process = Process()
    process.executableURL = URL(filePath: "/bin/zsh")
    process.arguments = ["-fc", script.replacingOccurrences(of: "exec zsh", with: "echo AFTER")]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    #expect(output.hasSuffix("AFTER\n"))
}
```

#### 값을 바꿔 도는 테스트와 Pipe 출력 읽기

테스트는 이렇게 돈다.

1. [`@Test(arguments:)`](https://developer.apple.com/documentation/testing/test%28%5F:%5F:arguments:%29-8kn7a){:target="_blank"}는 같은 테스트를 값만 바꿔 여러 번 돌린다. 배열의 명령 하나마다 테스트가 한 번씩 돈다.
2. [`#require(_:_:)`](https://developer.apple.com/documentation/testing/require%28%5F:%5F:sourcelocation:%29-6w9oo){:target="_blank"}로 스크립트를 꺼낸다. nil이면 그 자리에서 테스트를 실패로 끝내고, 아니면 꺼낸 값을 돌려준다.
3. zsh를 `Process`로 돌리고, 출력은 `Pipe`의 읽는 쪽 끝([`fileHandleForReading`](https://developer.apple.com/documentation/foundation/pipe/filehandleforreading){:target="_blank"})에서 [`readDataToEndOfFile()`](https://developer.apple.com/documentation/foundation/filehandle/readdatatoendoffile%28%29){:target="_blank"}로 끝까지 읽는다.
4. [`String(decoding:as:)`](https://developer.apple.com/documentation/swift/string/init%28decoding:as:%29){:target="_blank"}로 바이트를 UTF-8 글자로 바꾸고 `AFTER`로 끝나는지 본다. 틀린 바이트가 있으면 대체 글자로 바꿔 주니 여기서 멈추지 않는다.

---

### 명령이 끝나면 창 닫기

그런데 창이 늘 남는 게 맞는 건 아니었다. `npm run dev`나 `bundle exec jekyll serve`처럼 서버를 띄우는 명령은 창이 켜져 있어야 하지만, `uploadimg`처럼 금방 끝나는 명령은 끝난 창이 계속 쌓인다. 그래서 명령어 편집 화면에 "명령이 끝나면 창 닫기" 토글을 두고 버튼마다 고르게 했다. 켜면 뒤의 `exec zsh`를 붙이지 않아서 명령이 끝날 때 창도 닫힌다. 대신 오류가 나도 창이 바로 닫히니, 결과를 봐야 하는 명령은 꺼 둔다.

```swift
// AlacrittyCommand.swift (DeckKit)
/// keepOpen == false면 명령이 끝날 때 창도 닫힌다 (뒤에 exec zsh를 붙이지 않는다)
public static func openArguments(command: String?, directory: String?, keepOpen: Bool = true) -> [String] {
    let dir = directory.map(expandTilde) ?? NSHomeDirectory()
    var args = ["-na", appPath, "--args", "--working-directory", dir]
    if let command {
        let script = "eval \(singleQuoted(command))"
        args += ["-e", "/bin/zsh", "-ic", keepOpen ? "\(script); exec zsh" : script]
    }
    return args
}
```

기본은 지금처럼 창 유지다. 이 값이 생기기 전에 만든 버튼은 설정 파일에 값이 없으니 창 유지로 읽고, 저장할 때도 "닫기"일 때만 `"keepOpen": false`를 적어서 기존 버튼의 저장 모양이 바뀌지 않게 했다.

---

## 있는 별칭을 없다고 하던 문제

버튼을 눌렀을 때 맥 앱은 Alacritty 창 안을 볼 수 없다. 창 안에서 명령이 성공했는지는 알 방법이 없다. 그렇다고 무조건 "실행했음"이라고 하면, 오타 난 명령도 성공했다고 하고 창만 열린 채 "command not found"가 찍히게 된다. 그래서 실행 전에 확인할 수 있는 것만 확인하기로 했다. 폴더가 정말 있는지, 명령의 첫 단어를 zsh가 찾을 수 있는지(별칭, 함수, 프로그램 전부)다.

zsh의 `whence`가 이름을 찾으면 0, 못 찾으면 1로 끝나서 이걸 썼다.

---

### 종료 코드란?

프로그램은 끝날 때 운영체제에 숫자 하나를 남긴다. 이걸 종료 코드라고 하고, 0이면 성공, 0이 아니면 실패라는 약속이다. 셸에서는 `echo $?`로 바로 앞 명령의 종료 코드를 볼 수 있고, 맥 앱은 `Process`의 `terminationStatus`로 읽는다.

![whence blogrun은 0으로 끝나 찾음, Alacritty 창을 연다. whence blogrn은 1로 끝나 못 찾음, 아이패드에 이유를 보낸다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-3/touchdeck-exit-code.png)

---

### 이름을 뒤에 넘기면 스크립트가 안 돌던 문제

처음엔 이름을 스크립트 뒤에 따로 넘겼다. 이렇게 하면 이름이 스크립트 안에서 `$1`로 들어가서, 이름에 이상한 글자가 있어도 셸이 명령으로 해석할 일이 없다.

```text
$ /bin/zsh -ic 'whence -- "$1" >/dev/null' zsh blogrun; echo $?
1
```

`blogrun`이 분명히 있는데 1이 나왔다. 하나씩 확인해 봤다.

```text
$ /bin/zsh -ic 'alias blogrun; echo "status=$?"'
blogrun='bundle exec jekyll serve --unpublished --livereload --limit_posts 10'
status=0

$ /bin/zsh -ic 'whence -w -- "$1"; echo "1=[$1] 0=[$0]"' zsh blogrun
(아무것도 안 찍힘)
```

뒤에 아무것도 안 붙이면 별칭이 잘 보이는데, 뒤에 이름을 붙이자 `echo`조차 실행되지 않았다. 스크립트 자체가 안 돈 것이다. 내 `~/.zshrc`(oh-my-zsh, gitstatus 등)가 켜지는 과정에서 뭔가가 이 경우를 막는 것으로 보이는데, 정확히 어느 줄인지는 아직 못 찾았다.

그래서 이름을 뒤에 넘기지 않고 작은따옴표로 감싸 스크립트 안에 직접 넣었다. 이름 안에 작은따옴표가 있으면 `'\''`로 바꿔서, 따옴표를 닫고 따옴표 글자 하나를 넣고 다시 여는 식으로 처리한다.

```swift
// AlacrittyCommand.swift (DeckKit)
public static func lookupScript(for name: String) -> String {
    "whence -- '\(name.replacingOccurrences(of: "'", with: #"'\''"#))' >/dev/null"
}
```

```text
$ /bin/zsh -ic "whence -- 'blogrun' >/dev/null"; echo $?
0
$ /bin/zsh -ic "whence -- 'blogrn' >/dev/null"; echo $?
1
```

이제 오타 난 명령 버튼을 누르면 Alacritty 창은 아예 안 열리고, 아이패드에 이유가 뜬다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-3/touchdeck-failure.png)

이 확인을 할 때마다 대화형 zsh가 한 번 켜지는데, 내 `~/.zshrc` 기준으로 약 0.85초가 걸렸다. 버튼을 누르고 창이 뜨기까지 그만큼 늦어진다. 화면 없이 켜서 `can't change option: zle`, `gitstatus failed to initialize` 같은 경고도 찍히는데 결과에는 영향이 없었다.

---

## 환경 변수와 경로까지 보는 사전 확인

처음 확인은 공백으로 자른 첫 단어만 zsh에 물었다. 그래서 실제로는 되는 명령을 못 찾는다고 막는 경우가 있었다. `FOO=1 npm start`는 `FOO=1`을 찾았고, `./deploy.sh`는 실행할 폴더가 아니라 맥 앱이 떠 있는 폴더 기준으로 찾았고, `"my tool" --x`처럼 따옴표로 시작하면 따옴표까지 이름으로 봤다.

`FOO=1` 같은 `이름=값`은 환경 변수다. 프로그램에 넘기는 설정값으로, 명령 앞에 붙이면 그 명령 하나에만 적용된다. `./`는 "지금 있는 폴더"라는 뜻이라 어느 폴더에서 실행하느냐에 따라 가리키는 파일이 달라진다.

그래서 명령 모양을 보고 무엇을 확인할지부터 정했다.

- 앞에 붙은 `이름=값`은 건너뛰고 그다음 단어를 본다
- 단어에 `/`가 있으면 경로로 보고, 실행할 폴더 기준으로 그 자리에 실행 파일이 있는지 확인한다
- 따옴표, `$`, 괄호처럼 공백으로 자른 단어가 zsh가 읽는 단어와 달라질 수 있는 글자가 섞이면 확인하지 않고 그냥 실행한다

```swift
// AlacrittyCommand.swift (DeckKit)
private static let unparsable = Set(#""'`$\(){};|&<>*?"#)

public static func preflight(command: String, directory: String?) -> Preflight {
    let words = command.split(whereSeparator: \.isWhitespace).map(String.init)
    guard !words.isEmpty else { return .empty }
    let assignments = words.prefix { $0.wholeMatch(of: /[A-Za-z_][A-Za-z0-9_]*=.*/) != nil }
    guard let word = words.dropFirst(assignments.count).first,
          !(assignments + [word]).contains(where: { $0.contains(where: unparsable.contains) }) else { return .skip }
    guard word.contains("/") else { return .lookup(word) }
    let path = expandTilde(word)
    let base = URL(filePath: directory.map(expandTilde) ?? NSHomeDirectory())
    return .executable((path.hasPrefix("/") ? URL(filePath: path) : base.appending(path: path)).standardized.path)
}
```

#### 명령을 단어로 자르고 정규식으로 보기

[`split(whereSeparator:)`](https://developer.apple.com/documentation/swift/sequence/split%28maxsplits:omittingemptysubsequences:whereseparator:%29){:target="_blank"}는 조건에 맞는 글자(여기서는 공백)마다 잘라 조각 배열을 만든다. 빈 조각은 뺀다. 조각이 `이름=값`인지는 [`wholeMatch(of:)`](https://developer.apple.com/documentation/swift/bidirectionalcollection/wholematch%28of:%29-7741n){:target="_blank"}로 본다. 글자 전체가 정규식에 맞으면 결과가 있고, `/[A-Za-z_][A-Za-z0-9_]*=.*/`는 Swift의 정규식 글자(Regex literal)다. 경로는 마지막에 [`standardized`](https://developer.apple.com/documentation/foundation/url/standardized){:target="_blank"}로 `.`과 `..`를 정리한다. `./a/../b`는 `./b`가 된다.

마지막 경우는 잘못 막는 것보다 그냥 실행하는 쪽을 골랐다. 틀린 명령이면 Alacritty 창에서 zsh가 오류를 보여 준다. 경로 모양인데 실행 파일이 없으면 "실행 파일 없음: /Users/.../deploy.sh"처럼 찾아본 자리를 그대로 알려 준다. 파일은 있는데 실행 권한(`chmod +x`)이 없는 경우도 여기에 걸린다. 맥의 파일에는 "실행해도 되는지" 표시가 따로 있고, `chmod +x`가 그 표시를 켠다.

`zsh -ic`로 묻는 확인에는 시간 제한도 없었다. `~/.zshrc`에서 무언가 멈추면 버튼 누름도 같이 멈춘다. 그래서 3초를 넘기면 확인을 건너뛰고 실행하게 했다. 대화형 zsh는 보통의 종료 신호(SIGTERM)를 무시해서, 시간이 넘으면 SIGKILL로 끝낸다.

---

### 시그널이란?

시그널은 운영체제가 실행 중인 프로그램(프로세스)에 보내는 짧은 알림이다. SIGTERM은 "이제 끝내 줘"라는 부탁이라, 받은 프로그램이 하던 일을 정리하고 끝낼 수도 있고 무시할 수도 있다. SIGKILL은 운영체제가 그 프로그램을 바로 끝내 버리는 것이라 무시할 수 없다. 대화형 zsh는 실수로 창이 꺼지지 않게 SIGTERM을 무시한다.

![맥 앱이 보낸 SIGTERM은 대화형 zsh가 무시하고 계속 돌고, SIGKILL은 운영체제가 강제로 끝내서 zsh가 바로 끝난다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-3/touchdeck-signals.png)

```text
$ zsh -fic 'kill -TERM $$; echo survived'
survived
```

```swift
// ActionRunner.swift (맥)
func runProcess(_ path: String, _ arguments: [String], timeout: Duration) throws -> Int32? {
    let process = Process()
    process.executableURL = URL(filePath: path)
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    let finished = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in finished.signal() }
    try process.run()
    let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
    if finished.wait(timeout: .now() + seconds) == .timedOut {
        kill(process.processIdentifier, SIGKILL)
        return nil
    }
    return process.terminationStatus
}
```

#### DispatchSemaphore로 시간 제한 걸기

시간 제한은 이렇게 건다.

1. [`DispatchSemaphore`](https://developer.apple.com/documentation/dispatch/dispatchsemaphore){:target="_blank"}`(value: 0)`을 만든다. 누가 `signal()`을 부를 때까지 `wait`에서 멈춰 있게 하는 신호다.
2. 프로그램이 끝나면 불리는 [`terminationHandler`](https://developer.apple.com/documentation/foundation/process/terminationhandler){:target="_blank"}에서 `signal()`을 부른다.
3. `run()` 뒤 `wait(timeout:)`으로 정한 시간까지만 기다린다. [`Duration`](https://developer.apple.com/documentation/swift/duration){:target="_blank"}(`.seconds(3)`)은 `components`로 초와 그 아래 단위(아토초)를 꺼내 초 수로 바꿨다.
4. 시간이 다 되면(`.timedOut`) [`processIdentifier`](https://developer.apple.com/documentation/foundation/process/processidentifier){:target="_blank"}(프로그램 번호)로 [`kill(2)`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages%5FiPhoneOS/man2/kill.2.html){:target="_blank"}을 불러 `SIGKILL`을 보낸다. 운영체제가 그 프로그램을 강제로 끝낸다.

`nil`(시간 초과)이 오면 명령이 있다고 보고 그대로 창을 연다.

---

## 경로를 치지 않는 폴더 고르기

명령어 버튼의 "실행할 폴더"와 새 터미널 버튼의 "시작 폴더"는 처음엔 맥 폴더 경로를 글자로 치는 칸이었다. 막상 아이패드로 `~/Documents/Workspace/blog` 같은 긴 경로를 치기는 번거롭고, 칸에 "시작 폴더 (선택)"라고만 적혀 있으니 뭘 넣어야 하는지도 알기 어려웠다. 그래서 두 칸 옆에 "맥에서 폴더 고르기"를 두고, 맥 홈 폴더부터 하위 폴더를 눌러 가며 고르게 했다. 직접 치는 칸도 그대로 남겼다.

아이패드가 경로를 보내면 맥이 그 폴더의 하위 폴더 이름 목록을 돌려준다.

```json
{ "type": "listFolder", "path": "~/Documents" }
{ "type": "folder", "path": "~/Documents", "children": ["Workspace", "블로그"], "ok": true }
```

경로는 홈 폴더를 `~`로 줄여서 주고받는다. 버튼에도 이 모양 그대로 저장되고, 실행할 때 맥이 홈 경로로 바꾼다. 폴더 고르기는 홈 폴더 안에서만 다니게 했다. `~`에서는 더 위로 못 올라가고, `..`이 들어간 경로나 홈 밖 경로는 맥이 거절한다. `~`는 내 홈 폴더(`/Users/dongik`)를 줄인 표시이고, `..`는 한 칸 위 폴더라는 뜻이다. `~/../..`처럼 쓰면 홈 밖으로 나갈 수 있어서 막는다. 이 규칙은 공용 코드에 두고 테스트로 정했다.

```swift
// FolderPath.swift (DeckKit)
/// 한 칸 위. 홈("~")에서는 더 올라가지 않는다
public static func parent(_ path: String) -> String? {
    guard path != "~", let slash = path.lastIndex(of: "/") else { return nil }
    return String(path[..<slash])
}

public static func isInsideHome(_ path: String) -> Bool {
    guard path == "~" || path.hasPrefix("~/") else { return false }
    return !path.split(separator: "/").contains("..")
}
```

#### lastIndex와 Substring

[`lastIndex(of:)`](https://developer.apple.com/documentation/swift/bidirectionalcollection/lastindex%28of:%29){:target="_blank"}는 그 글자가 마지막으로 나오는 위치를 준다. 없으면 nil이다. `path[..<slash]`처럼 글자 일부를 자른 값은 [`Substring`](https://developer.apple.com/documentation/swift/substring){:target="_blank"}인데, 원래 글자 메모리를 같이 쓰니 오래 들고 있을 거면 `String(...)`으로 바꿔 둔다.

맥 쪽은 하위 항목 중에 폴더만 남긴다. `.git` 같은 숨김 폴더와 파일은 빼고, `Safari.app`처럼 폴더지만 Finder에서 하나의 파일로 보이는 패키지(2편의 번들)도 뺀다.

```swift
// FolderLister.swift (맥)
static func children(atPath path: String) -> [String]? {
    let url = URL(filePath: path)
    guard let urls = try? FileManager.default.contentsOfDirectory(
        at: url, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey], options: [.skipsHiddenFiles]) else { return nil }
    return urls
        .filter { item in
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            return values?.isDirectory == true && values?.isPackage != true
        }
        .map(\.lastPathComponent)
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
}
```

#### URLResourceKey로 폴더만 고르기

폴더 목록을 받을 때 [`URLResourceKey`](https://developer.apple.com/documentation/foundation/urlresourcekey){:target="_blank"}로 미리 읽어 둘 속성을 고른다. `.isDirectoryKey`는 폴더인지, `.isPackageKey`는 Finder에서 파일 하나로 보이는 번들인지다. [`skipsHiddenFiles`](https://developer.apple.com/documentation/foundation/filemanager/directoryenumerationoptions/skipshiddenfiles){:target="_blank"}는 `.git`처럼 숨긴 항목을 뺀다. 항목마다 [`resourceValues(forKeys:)`](https://developer.apple.com/documentation/foundation/url/resourcevalues%28forkeys:%29){:target="_blank"}로 그 속성을 읽고(미리 골라 둬서 디스크를 다시 읽지 않는다), 이름은 [`lastPathComponent`](https://developer.apple.com/documentation/foundation/url/lastpathcomponent){:target="_blank"}(경로 맨 끝 이름)로 꺼낸다.

임시 폴더에 `b`, `a`, `.git`, `Safari.app`, `블로그` 폴더와 `note.txt` 파일을 만들고 `["a", "b", "블로그"]`가 나오는지 테스트했더니 실패했다. 실제로는 `["블로그", "a", "b"]`가 나왔다. 맥 언어가 한국어라 Finder처럼 한글 이름이 영어보다 앞에 온 것이다. 앱 목록도 같은 방식으로 정렬하고 있어서 코드가 아니라 테스트를 고쳤다. 어떤 이름이 들어 있는지와 영어 이름끼리의 순서만 보고, 한글과 영어 중 뭐가 먼저인지는 보지 않게 했다.

맥 앱이 문서, 데스크탑, 다운로드 폴더 안을 처음 읽을 때는 macOS가 "TouchDeck이 문서 폴더에 접근하려고 합니다" 창을 띄울 수 있다. 앱 샌드박스를 꺼도 이 폴더들은 따로 허락을 받는다.

---

## 소리 크기와 missing value 응답

소리 크기는 AppleScript로 바꿨다. 맥에 기본으로 있는 명령이라 따로 권한도 필요 없다.

```text
$ osascript -e "set volume output volume 50"
$ osascript -e "get volume settings"
```

그런데 이 맥에서 현재 값을 읽었더니 숫자가 아니라 `missing value`가 나왔다.

```text
output volume:missing value, input volume:36, alert volume:100, output muted:missing value
```

소리가 어디로 나가는지 봤더니 맥북 스피커가 아니라 모니터였다.

```text
$ system_profiler SPAudioDataType
        LG ULTRAWIDE:
          Default Output Device: Yes
          Transport: DisplayPort
```

DisplayPort나 HDMI로 연결된 모니터 스피커는 macOS가 소리 크기를 조절하지 못한다. 키보드의 볼륨 키를 눌러도 안 먹는 그 상황이다. 그래서 맥이 보내는 소리 크기 메시지에 "지금 조절할 수 있는지"를 하나 더 넣었다.

```swift
// VolumeController.swift (맥)
static func parse(_ text: String) -> (value: Int, muted: Bool, available: Bool) {
    var value: Int?
    var muted = false
    for part in text.split(separator: ",") {
        let pair = part.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
        guard pair.count == 2 else { continue }
        if pair[0] == "output volume" { value = Int(pair[1]) }
        if pair[0] == "output muted" { muted = pair[1] == "true" }
    }
    // 모니터(DisplayPort/HDMI)처럼 소리 크기가 없는 장치는 "missing value"
    return (value ?? 0, muted, value != nil)
}
```

#### split과 trimmingCharacters로 응답 읽기

[`split(separator:)`](https://developer.apple.com/documentation/swift/sequence/split%28separator:maxsplits:omittingemptysubsequences:%29){:target="_blank"}는 정한 글자(쉼표, 콜론)마다 잘라 조각 배열을 만들고, [`trimmingCharacters(in:)`](https://developer.apple.com/documentation/foundation/nsstring/trimmingcharacters%28in:%29){:target="_blank"}는 앞뒤의 정한 글자들(`.whitespaces`면 공백)을 떼어 낸다.

처음엔 조절할 수 없으면 아이패드 오른쪽 볼륨 슬라이더를 끄고 "지금 출력 장치는 맥에서 소리 크기를 바꿀 수 없어요"를 띄웠다. 그런데 실제로 써 보니 이상했다. 해피해킹 키보드의 볼륨 키로는 같은 모니터 소리가 잘 바뀌었다.

혹시 AppleScript만 모르는 건가 싶어서 CoreAudio로 출력 장치를 직접 읽어 봤다. 소리 크기(`kAudioDevicePropertyVolumeScalar`), 가상 전체 볼륨(`kAudioHardwareServiceDeviceProperty_VirtualMainVolume`), 음소거 항목이 전부 없었다.

```text
device 85 LG ULTRAWIDE
VolumeScalar main has: false settable: false value: -1.0 status: -1
VolumeScalar ch1  has: false settable: false value: -1.0 status: -1
VirtualMainVolume has: false settable: false value: -1.0 status: -1
Mute has: false
```

macOS는 정말로 이 모니터 소리를 못 바꾼다. 그럼 키보드 키는 누가 처리하나 찾아보니 BetterDisplay가 켜져 있었다. BetterDisplay는 볼륨 키를 가로채서, 모니터에 화면 설정을 바꾸는 명령(DDC)으로 직접 "소리 키워"를 보낸다. 설정 파일에도 모니터별 소리 값이 따로 저장돼 있었다.

```text
"value@volume-DDCController@Display:3" = "0.0625";
"value@mute-DDCController@Display:3" = 0;
```

---

### DDC란?

모니터 케이블(DisplayPort, HDMI) 안에는 화면 신호 말고도, 컴퓨터와 모니터가 설정을 주고받는 작은 통로가 따로 있다. 이 통로를 DDC(Display Data Channel)라고 부른다. 원래는 모니터가 "나는 이런 해상도를 지원해"라고 알려 주는 데 쓰였고, 지금은 컴퓨터가 밝기, 소리 크기, 입력 전환 같은 명령도 보낸다. 모니터 아래쪽 버튼으로 바꾸는 설정을 컴퓨터가 대신 눌러 주는 셈이다.

![맥과 LG 모니터 사이 DisplayPort 케이블 안에 화면 신호와 따로, BetterDisplay가 보내는 소리 키워 같은 설정 명령이 다니는 DDC 통로가 있다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-3/touchdeck-ddc.png)

macOS는 외부 모니터 스피커의 소리 크기를 이 통로로 바꾸지 않아서 값을 모르고, BetterDisplay는 이 통로로 모니터에 직접 명령을 보낸다.

---

### 볼륨 키와 똑같은 신호 보내기

그래서 TouchDeck도 같은 길로 가기로 했다. 맥 앱이 소리 크기를 직접 정하는 대신, 키보드의 볼륨 키를 누른 것과 똑같은 시스템 이벤트를 낸다. 소리가 맥북 스피커로 나갈 땐 macOS가 이 신호를 받아 소리를 바꾸고, 모니터로 나갈 땐 BetterDisplay가 받아서 모니터에 명령을 보낸다. 해피해킹 키와 완전히 같은 경로다.

```swift
// MediaKey.swift (맥)
/// macOS의 NX_KEYTYPE 값 (IOKit hidsystem/ev_keymap.h)
static func code(for key: VolumeKey) -> Int32 {
    switch key {
    case .up: 0     // NX_KEYTYPE_SOUND_UP
    case .down: 1   // NX_KEYTYPE_SOUND_DOWN
    case .mute: 7   // NX_KEYTYPE_MUTE
    }
}

/// 시스템 이벤트의 data1: 위 16비트는 키 코드, 아래는 누름(0xA00) / 뗌(0xB00)
static func data1(code: Int32, down: Bool) -> Int {
    Int((code << 16) | (down ? 0xA00 : 0xB00))
}

/// 누르고 떼기를 한 번. 권한이 없으면 false
static func press(_ key: VolumeKey) -> Bool {
    guard allowed else { return false }
    let code = code(for: key)
    for down in [true, false] {
        let event = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                                       modifierFlags: NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00),
                                       timestamp: 0, windowNumber: 0, context: nil,
                                       subtype: 8, data1: data1(code: code, down: down), data2: -1)
        event?.cgEvent?.post(tap: .cghidEventTap)
    }
    return true
}
```

#### NSEvent로 볼륨 키 보내기

볼륨 키 하나는 이렇게 보낸다.

1. [`NSEvent.otherEvent(with:…)`](https://developer.apple.com/documentation/appkit/nsevent/otherevent%28with:location:modifierflags:timestamp:windownumber:context:subtype:data1:data2:%29){:target="_blank"}로 키보드도 마우스도 아닌 이벤트를 만든다. `.systemDefined`에 subtype 8을 주면 볼륨, 밝기 같은 미디어 키가 되고, 어떤 키인지와 누름/뗌은 `data1`에 담는다.
2. [`cgEvent`](https://developer.apple.com/documentation/appkit/nsevent/cgevent){:target="_blank"}로 같은 이벤트를 CoreGraphics의 `CGEvent`로 바꾼다.
3. [`CGEvent.post(tap:)`](https://developer.apple.com/documentation/coregraphics/cgevent/post%28tap:%29){:target="_blank"}로 시스템에 넣는다. `.cghidEventTap`은 진짜 키보드에서 온 것과 같은 자리라, 맥이 실제로 키를 누른 것처럼 처리한다.

다른 앱으로 이벤트를 보내려면 손쉬운 사용 권한이 있어야 하고, 있는지는 [`AXIsProcessTrusted()`](https://developer.apple.com/documentation/applicationservices/1460720-axisprocesstrusted){:target="_blank"}로 확인한다.

볼륨 키는 일반 글자 키와 다르게 "시스템 정의 이벤트"(종류 8)로 오고, 어떤 키인지와 누름/뗌이 `data1` 숫자 하나에 같이 들어 있다. 키 하나를 누르는 건 누름과 뗌 두 이벤트를 연달아 보내는 것이다.

다른 앱에 키 이벤트를 보내는 건 맥에서 손쉬운 사용 권한이 있어야 한다. 그래서 맥 앱이 켜질 때 권한이 없으면 시스템이 설정으로 안내하는 창을 한 번 띄우게 했다. 아이패드에는 권한이 없다는 걸 알려서, 화면 아래에 "맥의 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 TouchDeck을 켜 주세요"를 띄운다.

---

### 손쉬운 사용 권한이란?

손쉬운 사용은 원래 화면 읽기 프로그램이나 음성 제어처럼, 몸이 불편한 사람을 위해 다른 앱을 대신 조작해 주는 기능이다. 그래서 이 권한을 받은 앱은 다른 앱에 키를 누르고 마우스를 움직일 수 있다. 나쁜 앱이 받으면 비밀번호를 대신 칠 수도 있는 힘이라, macOS는 사용자가 시스템 설정에서 직접 켜야만 준다.

![TouchDeck이 다른 앱에 키를 입력하려면 사용자가 켠 손쉬운 사용 권한을 지나야 한다. 권한은 앱 서명에 묶여서 임시 서명으로 다시 빌드하면 풀리고, 팀 서명을 고정하면 남는다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-3/touchdeck-accessibility.png)

서명은 "누가 만든 이 앱인지"를 증명하는 도장이다. macOS는 권한을 앱 이름이 아니라 이 도장에 붙여 둔다.

이 권한은 앱 서명에 묶여 있다. 처음엔 앱을 임시 서명으로 빌드했는데, 이러면 빌드할 때마다 macOS가 다른 앱으로 보고 권한을 다시 켜야 한다. 그래서 프로젝트 설정 파일에 팀 서명을 고정했다.

---

### 끈 거리만큼 키를 누르는 띠

아이패드 쪽은 처음에 슬라이더를 키보드처럼 올림, 음소거, 내림 키캡 세 개로 바꿨다. 실제로 볼륨이 바뀌는 건 확인했는데, 써 보니 버튼을 여러 번 누르는 것보다 끌어서 조절하고 싶었다. 문제는 키 신호가 "지금 몇 %"를 정하지 못하고 한 칸씩 올리고 내리기만 한다는 것이다. 그래서 슬라이더처럼 값을 정하는 대신, 끈 거리만큼 볼륨 키를 대신 눌러 주는 띠로 만들었다. Stream Deck+의 터치 띠나 다이얼처럼 "얼마나 움직였나"만 보는 방식이다.

끈 거리를 몇 칸인지로 바꾸는 규칙은 공용 코드에 두고 테스트로 먼저 정했다. 16pt 움직일 때마다 한 칸이고, 손을 떼지 않고 되돌아오면 그만큼 내린다.

```swift
// VolumeDrag.swift (DeckKit)
public struct VolumeDrag: Sendable {
    /// 몇 pt를 움직이면 한 칸인지
    public let step: Double
    private var sentSteps = 0

    public init(step: Double) {
        self.step = step
    }

    /// 손가락이 처음 닿은 곳에서 얼마나 움직였는지(올림 쪽이 +). 새로 넘은 칸만큼 키를 돌려준다.
    public mutating func update(distance: Double) -> [VolumeKey] {
        let steps = Int(distance / step)
        let diff = steps - sentSteps
        sentSteps = steps
        return Array(repeating: diff > 0 ? .up : .down, count: abs(diff))
    }

    /// 손을 떼면 다음 끌기는 처음부터 다시 센다
    public mutating func end() {
        sentSteps = 0
    }
}
```

#### Sendable 표시

[`Sendable`](https://developer.apple.com/documentation/swift/sendable){:target="_blank"}은 여러 작업이 동시에 들고 다녀도 안전한 값이라는 표시다. 숫자만 들고 있는 구조체라 붙일 수 있다.

`mutating`은 구조체가 자기 값을 바꾸는 함수라는 표시다. `VolumeDrag`는 보낸 칸 수를 스스로 기억해야 해서 `update`와 `end`에 붙였다.

```swift
// VolumeDragTests.swift (DeckKit)
@Test func goingBackSendsDown() {
    // 위로 3칸 갔다가 손을 떼지 않고 아래로 내려오면 그만큼 내림
    var drag = VolumeDrag(step: 16)
    _ = drag.update(distance: 48)
    #expect(drag.update(distance: 16) == [.down, .down])
    #expect(drag.update(distance: -20) == [.down, .down])
}
```

화면에서는 손잡이가 손가락을 따라 움직이고, 한 칸을 넘을 때마다 짧게 진동한다. 손을 떼면 손잡이는 가운데로 돌아온다. 값을 정하는 슬라이더가 아니라서, 손잡이 위치가 지금 소리 크기를 뜻하지 않게 하려는 것이다. 맥북 스피커처럼 macOS가 값을 아는 장치일 때만 띠 안에 지금 값이 보라색으로 차 있다. 음소거는 띠 아래 키캡으로 남겼다.

```swift
// VolumeStrip.swift (iOS)
.gesture(DragGesture(minimumDistance: 0)
    .onChanged { value in
        // 올림 쪽이 +: 세로는 위로, 가로는 오른쪽으로
        let distance = vertical ? -value.translation.height : value.translation.width
        offset = min(max(distance, -travel), travel)
        for key in drag.update(distance: distance) {
            onKey(key)
            haptic.impactOccurred()
        }
    }
    .onEnded { _ in
        drag.end()
        withAnimation(.spring(duration: 0.25)) { offset = 0 }
    })
```

#### DragGesture로 끄는 동안 키 보내기

끄는 동안 일어나는 일을 순서대로 보면 이렇다.

1. [`DragGesture(minimumDistance:)`](https://developer.apple.com/documentation/swiftui/draggesture){:target="_blank"}는 손가락 끌기 제스처다. `minimumDistance: 0`이라 닿자마자 시작한다.
2. 끄는 동안 [`onChanged(_:)`](https://developer.apple.com/documentation/swiftui/gesture/onchanged%28%5F:%29){:target="_blank"}가 계속 불린다. `value.translation`이 처음 닿은 곳에서 움직인 거리다. 한 칸을 넘을 때마다 [`UIImpactFeedbackGenerator`](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator){:target="_blank"}의 `impactOccurred()`로 짧게 진동한다. 진동 모터가 없는 아이패드에서는 아무 일도 없다.
3. 손을 떼면 [`onEnded(_:)`](https://developer.apple.com/documentation/swiftui/gesture/onended%28%5F:%29){:target="_blank"}가 한 번 불린다. [`withAnimation(_:_:)`](https://developer.apple.com/documentation/swiftui/withanimation%28%5F:%5F:%29){:target="_blank"}으로 손잡이를 `.spring(duration:)`(튕기듯 돌아오는 움직임)으로 가운데에 되돌린다.

맥이 키 신호를 보낸 뒤에는 0.15초 기다렸다가 소리 크기를 다시 읽어서 붙어 있는 모든 기기에 알려 준다. 키 신호가 바로 반영되지 않을 수 있어서다.

아이패드 버튼으로 직접 눌러 보니 LG 모니터 소리가 해피해킹 볼륨 키와 똑같이 바뀌었다.

---

### BetterDisplay에게 값을 물어 게이지 만들기

그런데 끄는 띠도 써 보니 아쉬웠다. 지금 소리가 몇인지 안 보이니, 끄는 손이 어디쯤에서 멈춰야 할지 모른다. 실제 값만큼 차오르는 게이지가 낫다. 그러려면 맥이 모니터 소리 값을 알아야 하는데, macOS는 모르지만 BetterDisplay는 안다. BetterDisplay 설명서를 보니 다른 프로그램이 값을 읽고 정할 수 있는 방법(CLI, URL, HTTP, 알림)이 있었고, 그중 CLI는 기본으로 켜져 있었다. 앱 안의 실행 파일이 그대로 CLI 역할을 해서, 이렇게 부르면 켜져 있는 BetterDisplay가 답한다.

```text
$ /Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay get -name="LG ULTRAWIDE" -volume
0.063
$ /Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay get -name="LG ULTRAWIDE" -mute
off
$ /Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay get -name="MacBook" -volume
Failed.
```

값은 0~1 사이로 오고(0.063은 약 6%), `set -volume=0.55`처럼 정할 수도 있다. 한 번 부르는 데 0.2초쯤 걸렸다. 디스플레이 이름은 CoreAudio가 알려 주는 지금 출력 장치 이름("LG ULTRAWIDE")과 같아서, 그 이름을 그대로 넘기면 된다.

그래서 맥 앱이 소리 값을 읽고 정하는 길을 두 개로 나눴다. macOS가 아는 장치면 AppleScript로, 아니면서 BetterDisplay가 켜져 있으면 BetterDisplay로, 둘 다 아니면 값 없이 끄는 띠로 돌아간다.

```swift
// VolumeController.swift (맥)
static func chooseSource(systemAvailable: Bool, outputName: String?, betterDisplayRunning: Bool) -> Source {
    if systemAvailable { return .system }
    if let outputName, betterDisplayRunning { return .betterDisplay(name: outputName) }
    return .none
}

/// BetterDisplay는 0~1 값을 돌려준다. "Failed." 같은 건 nil
static func parseBetterDisplayVolume(_ text: String) -> Int? {
    guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
    return Int((min(max(value, 0), 1) * 100).rounded())
}
```

이 맥에서 읽어 보니 `output: LG ULTRAWIDE`, `(value: 6, muted: false, available: true)`가 나왔다. AppleScript 한 번, BetterDisplay 두 번(볼륨, 음소거)을 부르느라 한 번 읽는 데 약 1.1초가 걸린다.

아이패드 오른쪽은 실제 값만큼 보라색이 차오르는 게이지가 됐다. 누르거나 끈 위치가 곧 값이고, 위에 숫자가 보인다. 10% 눈금을 넘을 때마다 짧게 진동한다. 끄는 동안에는 0.1초에 한 번만 맥에 보낸다. 맥 쪽은 BetterDisplay에 쓰는 데 0.2초쯤 걸리니, 쓰는 동안 새로 온 값은 마지막 것만 남겨 두었다가 이어서 쓴다.

```swift
// TouchDeckMacApp.swift (맥)
func setVolume(_ value: Int) async {
    pendingVolume = value
    guard !settingVolume else { return }
    settingVolume = true
    while let next = pendingVolume {
        pendingVolume = nil
        await Task.detached { VolumeController.set(next) }.value
    }
    settingVolume = false
}
```

#### Task.detached로 BetterDisplay 부르기

[`Task.detached`](https://developer.apple.com/documentation/swift/task/detached%28name:priority:operation:%29-9xki7){:target="_blank"}는 메인 스레드 밖에서 도는 별도 작업이다. BetterDisplay를 부르는 0.2초 동안 메뉴바가 멈추지 않게 했고, `.value`로 끝날 때까지 기다린다.

해피해킹 키로 소리를 바꿔도 게이지가 따라오게, 맥이 붙어 있는 기기가 있을 때만 3초마다 값을 다시 읽어서 바뀌었으면 알려 준다. 읽는 데 1초가 넘게 걸려서 더 자주 하지는 않았다. 반대로 아이패드에서 막 끈 직후에 맥이 읽어 둔 옛 값이 도착하면 게이지가 뒤로 튈 수 있어서, 아이패드는 마지막으로 만진 뒤 2초 동안은 맥이 보낸 값을 무시한다.

BetterDisplay가 꺼져 있거나 다른 모니터로 바뀌어서 값을 알 수 없을 때는 위의 끄는 띠가 나온다. 실제로 써 보니 출력을 모니터에서 맥북 스피커로 바꾸면 게이지가 바로 그쪽 값으로 바뀌었고, 해피해킹 키로 바꾼 소리도 따라왔다.

---

### 가끔 끄는 띠로 바뀌던 게이지

그런데 가끔 게이지가 끄는 띠로 바뀌었다가 곧 돌아오는 일이 있었다. 맥이 3초마다 값을 읽다가 한 번 실패하면 바로 "값 모름"을 보내고, 아이패드는 그걸 받자마자 화면을 바꾸기 때문이다. 셸에서 BetterDisplay에게 40번 물어도, 값을 바꾸는 쓰기와 읽기를 20번 겹쳐도 실패는 한 번도 없었다. 종료 코드도 60번 모두 0이었다. 맥 앱 안에서만 가끔 생기는 일이라 정확히 어느 단계인지는 아직 못 찾았다.

원인을 찾는 것과 별개로, 한 번의 실패로 화면이 바뀌지는 않게 했다. 같은 출력 장치에서 10초 안에 읽은 값이 있으면 첫 실패는 그 값으로 덮고, 두 번 연달아 실패하거나 출력 장치가 바뀌었을 때만 "값 모름"을 알린다. 실패할 때는 어느 단계(BetterDisplay 실행 실패인지, 이상한 출력인지, 출력 장치를 못 찾았는지)였는지 로그에 남기게 했다.

```swift
// VolumeStabilizer.swift (맥)
mutating func stabilize(_ reading: Reading, output: String?, now: Date) -> Reading {
    if reading.available {
        lastGood = (reading, output, now)
        failures = 0
        return reading
    }
    failures += 1
    if failures == 1, let lastGood, lastGood.output == output, now.timeIntervalSince(lastGood.at) <= Self.window {
        return lastGood.reading
    }
    return reading
}
```

#### Date로 지난 시간 재기

[`Date`](https://developer.apple.com/documentation/foundation/date){:target="_blank"}는 한 순간의 시각이다. `now.timeIntervalSince(lastGood.at)`은 두 시각 사이가 몇 초인지 준다.

---

## 참고자료

- [Alacritty 명령줄 옵션 (--working-directory, -e)](https://alacritty.org/cmd-alacritty.html){:target="_blank"}
- [open 명령 (-n, -a, --args)](https://ss64.com/mac/open.html){:target="_blank"}
- [zsh 내장 명령 (whence)](https://zsh.sourceforge.io/Doc/Release/Shell-Builtin-Commands.html){:target="_blank"}
- [zsh 시작 파일 (.zshrc를 언제 읽는지)](https://zsh.sourceforge.io/Doc/Release/Files.html){:target="_blank"}
- [AppleScript Language Guide: Commands Reference (set volume, get volume settings)](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_cmds.html){:target="_blank"}
- [AXIsProcessTrustedWithOptions (Apple)](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions){:target="_blank"}
- [BetterDisplay (외부 모니터 DDC 조절)](https://github.com/waydabber/BetterDisplay){:target="_blank"}
- [BetterDisplay 연동 기능과 CLI (get, set, volume)](https://github.com/waydabber/BetterDisplay/wiki/Integration-features,-CLI){:target="_blank"}

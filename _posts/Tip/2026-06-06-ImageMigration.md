---
title: 블로그 이미지 로컬 마이그레이션 & Cloudflare R2 이전기
writer: Harold
date: 2026-06-06 08:33:00 +0800
last_modified_at: 2026-06-06 18:00
categories: []
tags: []

toc: true
toc_sticky: true
published: true
---

블로그를 오래 운영하다 보면 이미지가 깨지기 시작한다. 
처음에 깃블로그 이전에 만들었던 velog에서 가져온 이미지, esdrop 이미지, 그리고 GitHub issue에 드래그해서 올렸던 이미지 등..
이 이미지들은 호스팅하는 쪽이 운영 중단하거나 사라질 가능성이 항상 존재해왔다.

오늘 하루를 통째로 써서 정리했다.
python 안쓴지 오래라 자동화 코드는 AI를 통해 작성되었다.

---

## 문제 파악

450개 이상의 포스트에 흩어진 이미지 소스들:

- `github.com/user-attachments/assets/` - GitHub 이슈 첨부
- `velog.velcdn.com` - velog에서 마이그레이션한 글
- `i.esdrop.com` - 예전에 쓰던 이미지 호스팅
- `i.ibb.co` - imgBB
- 기타 외부 링크들 (Medium, Apple 공식 문서 등)

GitHub user-attachments URL은 S3 서명 URL로 리다이렉트되는데 5분마다 만료된다. 
그래서 스크립트로 직접 받으면 404가 뜨는 경우가 생겼다.

---

## 1단계: 로컬 다운로드

`download_images_v4.py`로 3개 소스 이미지를 한번에 처리했다.

velog랑 esdrop은 URL 자체에 파일명이 있으면 중복 가능성이 있어서 UUID 기반으로 통일했다.
(실제 뒤에 image.png로 된게 여럿있어서 링크 주소는 다르지만 뒤의 파일명이 같아 동일한 이미지로 인식하는 문제가 있었다.)

폴더명 규칙도 이번에 손봤다. 괄호가 URL에서 인코딩 문제를 일으킨다는 걸 뒤늦게 발견했다. `GitExplorer(1)` 폴더로 이미지를 올리면 Jekyll에서 URL이 제대로 인코딩되지 않아서 이미지가 안 보였다.

이걸 깨닫기까지 `git checkout .`을 두 번 했다.

---

## 2단계: 외부 이미지 백업

GitHub/velog/esdrop 외에도 외부 링크가 59개 남아있었다. `download_external.py`로 다운로드만 하고 md 교체는 주석처리했다.
사이트가 살아있는 동안은 외부 링크로 두고, 깨지면 그때 교체하려고.

실패한 것들:

- `aglowiditsolutions.com` - 디자인 패턴 이미지 4개, 사이트 자체 없어짐
- Firebase Storage - 402 Payment Required (코드블럭에 있는 이미지 링크라 패스)
- Notion 만료 링크 - 400 Bad Request (현재 블로그에서는 정상적으로 보여서 별도 저장 후 링크 교체)
- Vimeo - 영상 링크라 이미지가 아님

복구 불가능한 것들은 따로 `failed_images.md`로 정리해뒀다.

---

## 3단계: 용량 문제

로컬에 다 받고 나니 `assets/images/` 폴더가 1.2GB였다. GitHub에 올리려니 500MB 제한에 걸렸다.

pngquant로 압축하니 826MB로 줄었지만 여전히 많았다. GitHub Pages로 서빙하는 블로그라 이미지를 레포에 넣지 않으면 배포된 사이트에서 이미지가 안 보인다. 결국 외부 호스팅이 필요했다.

---

## 4단계: Cloudflare R2 설정

Cloudflare R2를 선택한 이유:
- 무료 10GB
- egress 무료 (읽기 트래픽 과금 없음)
- S3 호환 API

Token 생성은

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-06-ImageMigration/CleanShot%202026-06-06%20at%2019.03.50%402x.png){: width="50%" height="50%"}

여기서 하면 된다.

버킷 생성하고 Public Development URL 활성화하면 `pub-xxxxx.r2.dev` 형태의 공개 URL이 생긴다.

`upload_to_r2.py`로 2342개 파일을 올렸다. boto3 S3 API를 사용했는데 R2가 S3 호환이라 endpoint만 바꿔주면 됐다.

---

## 5단계: md 경로 교체

`upload_to_r2.py` 2단계에서 md 파일의 `/assets/images/폴더명/파일명` 경로를 R2 URL로 일괄 교체했다.

714개 파일 중 483개에서 교체가 일어났다.

---

## 6단계: ibb.co 처리

`i.ibb.co` 링크가 별도로 남아있었다. `<img src="...">` 태그 형식이라 앞의 스크립트에서 빠진 것들이었다. `download_ibb_upload_r2.py`로 따로 처리했다.

---

## 새 이미지 워크플로우

앞으로 새 글 쓸 때는:

1. `assets/images/upload/` 에 이미지 저장
2. md에 `/assets/images/upload/파일명` 으로 작성
3. `upload_new_images.py` 실행 → R2 업로드 + md 경로 자동 교체 + upload 폴더 비우기
4. git push (images 폴더는 .gitignore)

---

## 결과

- 이미지 2342개 R2 업로드 완료
- md 파일 경로 R2 URL로 교체 완료
- 레포 용량: 이미지 제외하고 md + 설정파일만
- 복구 불가 이미지: `failed_images.md` 에 정리

하루 종일 걸렸지만 이제 이미지 걱정은 없다.

---

## CleanShot 이미지 명 설정 및 Espanso 재설정

보통 스크린샷을 찍을 때 CleanShot을 쓰는데, 기본 파일명에 공백이 있어서 이미지 업로드할 때 문제가 생긴다. 설정에서 파일명 포맷을 바꿔줬다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-06-ImageMigration/CleanShot_06-19.22@2x.png){: width="50%" height="50%"}

Edit을 눌러서 포맷을 수정하면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-06-ImageMigration/CleanShottest.png){: width="50%" height="50%"}

이렇게 공백 없는 파일명으로 저장된다.

이미지 업로드 방식도 R2로 바뀌었으니 Espanso도 맞춰서 수정했다. 기존 `;img`는 GitHub issue 첨부 `<img>` 태그용이었는데, 이제 로컬 upload 경로로 바꿨다.

````yaml
- trigger: ";img"
    vars:
      - name: filename
        type: clipboard
    replace: "![](/assets/images/upload/{{filename}}){: width=\"50%\" height=\"50%\"}"
````

파일명만 복사하고 `;img` 치면 전체 경로가 완성된다.

---

## 업로드 전 이미지 압축

아까 이미지 마이그레이션 하면서 pngquant로 압축했을 때 1.2GB → 826MB로 줄었던 게 생각났다. 어차피 PNG는 업로드 전에 한번 돌리는 게 맞다 싶어서 `upload_new_images.py`에 압축 단계를 추가했다.

gif, webp는 그대로 올라가고 PNG만 압축된다.
---
title: WhatFlower (1)
writer: Harold
date: 2024-04-17 14:13
#last_modified_at: 2024-04-15 09:11
categories: [Udemy, CoreML]
tags: []

toc: true
toc_sticky: true
---

## PIP 설치확인

> PIP?
>> 파이썬으로 작성된 패키지 라이브러리를 관리해주는 시스템

우선 설치되어있는지 확인하기위해 Terminal에서 버전체크를 해보자

맥에서는 기본적으로 python이 설치가 되어있다.

하지만 python -V를 하니 인식이 안되어서 환경변수를 확인해볼까 하다가. `brew install python`을 사용해서 파이썬 재설치를 하기로 결정



## pip를 통해 가상환경 설치

인스톨을 하려 하니 문제가 발생.

![CleanShot 2024-04-17 at 15 25 34@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/f3c08c6f-a6ae-4d4c-aa55-e56312fe7989)

[사이트](https://velog.io/@mystic/%EB%A7%A5%EB%B6%81-Homebrew-python%EC%84%A4%EC%B9%98%EC%8B%9C-pip-%EB%AC%B8%EC%A0%9C)를 참고하여 값을 변경해주었다.

`pip3 install virtualenv` 를 통해 설치 완료.

생각보다 이것저것 검색하다가 시간을 날린것같다.

## 가상환경 설정

```shell
cd ~ // Home Directory
mkdir Environments // Environments Directory 생성
virtualenv --python=/usr/bin/python2.7 python27 // 강의 내용과 다름.
```

`virtualenv --python=/usr/bin/python2.7 python27` 이부분이 강의와 다르기에 별도로 적는다.

[사이트](https://www.python.org/downloads/release/python-2718/)를 통해 python2.7 수동 설치.

`virtualenv py2.7-env`로 생성 하지만 버전이 3.12.3 이다.

에러 코드에 대해 검색해보니 `pip install --upgrade pip`를 사용하여 버전업을 하라고 해서 버전업을 하고

virtualenv 버전도 지정을 해주었다.

`pip install virtualenv==20.15.1`

`python -m virtualenv venv` 를 실행하니

![CleanShot 2024-04-17 at 16 56 28@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/52f5ebbf-7a9f-4a13-a204-2cc8c556fbd1)

2.7버전으로 뭔가 만들어진 스멜이다. 확인해보자.

다시 순서 정리

```shell
cd ~ // Home Directory
mkdir Environments // Environments Directory 생성
python -m virtualenv venv // 2.7 버전으로 가상환경 생성
source venv/bin/activate // 파이썬 버전 적용.
python --version // 버전확인
deactivate // 버전 해제
```

## coremltools 설치

coremltools 설치

`pip install -U coremltools`

설치중 에러 발생

[사이트](https://packaging.python.org/en/latest/tutorials/installing-packages/) 참고하여

```shell
python3 -m ensurepip --default-pip
python3 -m pip install --upgrade pip setuptools wheel
```

진행하니 에러코드가 달라졌다.

파이썬 3.12 최신버전에 대한 문제도 있어 3.11로 새로 설치한다.

다운그레이드하고 해보니 일단 설치는 된것같다.

힘들었다.

.py file에 import를 해봤으나 실패...

`Defaulting to user installation because normal site-packages is not writeable`

어느순간 바뀌어버린 에러메세지.

파이썬에대한 환경변수가 문제인건가 생각이 들기 시작한다.

현재 설치된 파이썬의 경로를 찾아보기 시작한다.

```shell
❯ where python
/Library/Frameworks/Python.framework/Versions/2.7/bin/python
/usr/local/bin/python
❯ where python3
/usr/bin/python3
```

python 디폴트가 2.7로 되어있다. 우선 이녀석을 3.12버전만 아닌 다른 녀석으로 설치를 해줘야할 듯 하다.

현재 라이브러리 들어가서 확인 해본결과 2.7하나만 있다.

brew list를 확인해보니 3.10, 3.11 버전은 설치가 되어있다.

파이썬 공식사이트를 통해 설치를 해보기로 했다.

버전은 3.11.9

python3 명령어를 치고 import coremltools를 하니 먹힌다.

어느부분에서 인식이 된건지 모호하다.

![CleanShot 2024-04-18 at 00 03 46@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/0db8dd15-b1e8-4fe8-b75e-02a1d78a2419)

터미널을 4개나 켜면서 확인을 해야했던 작업.

터미널 진짜 사용해보면 재미있는데.....

python 3.9 버전에서 coremltools import 확인.

![CleanShot 2024-04-18 at 00 02 32@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/da30d1a9-8f2f-4c28-9abd-cac63e825c1e)

vscode에서 python3 version을 3.9로 체인지.

이건 조만간 맥미니로 테스트를 하면서 과정을 다시 적어보도록 하겠다.

## python 코드 작성

새로운 폴더를 하나 만들고 model과 관련된 파일들을 넣어준다.

그리고 파이썬을 사용하여 swift에서 사용할 수 있는 모델로 바꾸기 위한 작업을 시작해보겠다.

file명은 convert-script.py로 해두었다.

간만에 머신러닝, 딥러닝 모델을 접하니 설렌다. 딥하게 아는건 아니지만 그래도 찍먹을 해보아서 그럴까? 설렌다.

관련 [Docs](https://apple.github.io/coremltools/docs-guides/source/target-conversion-formats.html)는 여기를 참고.

caffe model내용은 [여기](https://www.wwt.com/article/convert-a-caffe-model-to-core-ml-format)를 참고.

[자세한정보는여기](https://docs.openvino.ai/2023.3/openvino_docs_MO_DG_prepare_model_convert_model_Convert_Model_From_Caffe.html)

```python
import coremltools

caffe_model = ('oxford102.caffemodel', 'deploy.prototxt')

labels = 'flower-labels.txt'

coreml_model = coremltools.converters.caffe.convert(
    caffe_model,
    class_labels=labels,
    image_input_names='data'
)


coreml_model.save('FlowerClassifier.mlmodel')
```

- parameter 정보 (convert)
    - 첫번째 : model의 경로 (String)
        - 현재는 python file과 같은 경로이기에 파일명을 그대로 쓰면됨.
        - caffe_model(모델, 모델정보txt) → 같은 디렉토리일때.
    - 두번째 : class_label (String)
        - 모든 클래스들이 명명된 문서의 파일경로.
        - 여기선 클래스들은 꽃의 이름들.
    - 세번째 : image_input_names (String|[String])
        - ![CleanShot 2024-04-18 at 01 33 34@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/cb1971ba-73d5-4e66-b897-a5187f3d67b5)


문제 발생. 현재 버전에서는 converter에 caffe_model를 다루지 않음.....

실제로 실행할땐 `python3 convert-script.py`를 사용하면 될 것이다.

![CleanShot 2024-04-18 at 01 02 10@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/19e02a6f-0df0-4454-b5e1-81be9d406b63)

기껏 설치했더니 현재는 지원하지 않는 버전.

개빡.

하긴 이미 vscode에서 작성하면서 미리 인지를 해두긴 했음.

그래서 강제로 버전 다운그레이드. 

재부팅을 해서 그런가 아까 설치한 python3.11.9 버전이 디폴트가 되었다.

`pip3 install coremltools` 재시도

![CleanShot 2024-04-18 at 01 05 02@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/de058a78-c6fb-4661-a0d1-f079e71db5e2)

`pip3 install coremltools==4.0` 버전 다운그레이드 설치

![CleanShot 2024-04-18 at 01 06 00@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/fbea4255-cae7-4753-a3ad-b8e9ca47afce)

완료.

Vscode python interpreter 다시 교체.

![CleanShot 2024-04-18 at 01 07 07@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/6a998d46-4870-4d1a-ae15-16581d5ba749)

인터프리터가 같은버전으로 2개가 있는데 

![CleanShot 2024-04-18 at 01 07 41@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/1190bc5d-ffa0-4fa3-9e65-78b13421516e)

이렇게 확인해주면 된다.

그랬더니 다시 coremltools 인식.

다시 터미널에서 해당 파일 파이썬으로 돌려보면.

![CleanShot 2024-04-18 at 01 12 09@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/768961f4-0f79-4713-9d1d-f58e84710955)

에러발생.

찾아보니 4.0 버전도 안됨.

3.4에서 된다는 글을 보아서 다운그레이드 재시도.

하지만 현재 파이썬 버전에서는 불가능.

다시 가상환경에서 2.7 버전의 파이썬을 재호출.

coremltools 3.4 버전 설치.

그리고 가상환경에서 2.7의 파이썬에서 

`convert-script.py` 파일이 있는 디렉토리로 이동

다시 재호출

![CleanShot 2024-04-18 at 01 18 56@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/d0c2fc46-003a-4d39-8b06-4f2572de268c)

드디어 성공.

사양이 좋아서 그런가. model생성이 1분도 안걸렸다.

역시 가끔은 낮에 하는 것 보다 밤에하는게 잘된다.

## 그동안의 여정을 정리.

coremltools 설치 이후.

1. 우선 coremltools가 현재 어떤 파이썬의 버전을 지원하는지 체크를 하지않고 무작정 설치하려다 호환성 문제로 설치가 안됨.
- 그걸 깨닫는시점이 너무 오래걸림.
2. 문제점 인지하고 파이썬 버전을 downgrade 
- 3.12 -> 3.11
3. coremltools 설치 성공.
4. 코드 작성중 coremltools가 caffe model을 지원하지 않는다는것을 인지.
5. Coremltools Downgrade (4.0)
6. 4.0에서도 안됨. 코드내부의 문제가 아닌 coremltools의 호환성 문제.
7. 다운그레이드 재시도 (3.4)
8. 현재 파이썬 버전에서는 안됨.
9. 이전에 만들어둔 가상환경이 2.7버전인걸 확인.
10. 해당가상환경 로드 후 pip install coremltools==3.4로 특정 버전으로 설치 시도.
11. 설치 성공후 VScode에서 해보려고 했으나, 할필요가 없음을 깨달음
- terminal에서 가상환경으로 2.7을 불러두고 convert-script.py 실행하면됨.
12. 해당 파일 실행.
13. 성공.

![CleanShot 2024-04-18 at 01 24 20@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/2e3ac108-ba23-4912-ad1c-8525aab9be91)

몇시간동안 노력의 결과.

확실한건. 가상환경으로 파이썬 구버전을 잘 쟁여둬야겠다는 생각이 든다.

언제 또 쓸지 모르니까.


---
title: Create Model (1)
writer: Harold
date: 2024-04-19 15:13
#last_modified_at: 2024-04-15 09:11
categories: [Udemy, CoreML]
tags: []

toc: true
toc_sticky: true
---

## CreateML

이제는 모델을 직접 만드는 과정이다.

[Docs](https://developer.apple.com/kr/machine-learning/create-ml/) 참고.

## 학습을 위한 DataSet을 만들고 이미지 가져오기.

이전에 파이썬으로 모델을 만드는것과 동일하게, Directory의 이름이 곧 Label이 된다.

TrainingData라는 Directory를 만들고 거기에 새롭게 Dog라는 디렉토리를 만든다.

Dataset이 많을 수록 더 정확도가 올라간다.

그리고 학습시킨 이미지를 테스트할 TestingData라는 폴더를 만들고 그 하위에 똑같이 Dog를 만든다.

이때 중요한건, 학습과, 테스트의 Image는 달라야 한다.

그래야 더 객관적으로 정확도를 판단할 수 있기 때문이다.

강의에선 구글의 이미지를 가지고 오는데 이럴땐 [Kaggle](https://www.kaggle.com/datasets?search=dog)에서 데이터셋을 찾으면 더 편하다.

캐글 오래간만에 들어가네, 이전에 프로젝트하면서 견종 인식 딥러닝 모델 정확도 올린다고 2주를 고생했던 기억이 떠오른다.

![CleanShot 2024-04-19 at 22 28 24@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/ccede6fe-95db-4750-8d7f-79220ae47195){: width="75%" height="75%"}

사진은 모델링 하면서 했던 과정중의 하나를 가져와봤다.

과거의 나와 조우.

CreateML로도 할 수 있어서 나중에 한번 이걸로 아이디어를 만들어볼까? 생각을 해본다.

다시 본론으로 돌아가서.

이미지를 저장하게 되면 이미지의 확장자, 사이즈가 중요해진다.

하지만 Createml은 그런 걱정에서 해방시켜준다.

즉 **JPEG, PNG**같은 이미지 표준 형식을 사용하는 한 아무런 문제가 없다.

## ImageSet을 Train/Test로 분류하기.

우리가 직접 이미지를 저장하고 폴더를 분류 하지않는 이상.

ImageSet을 구하게 되면 label로만 나눠져있는 경우가 많다.

강의와 다르게 [Kaggle](https://www.kaggle.com/datasets/iamsouravbanerjee/animal-image-dataset-90-different-animals/code)에서 구한 ImageSet은 90종의 동물 label이 있고, 이미지의 개수는 총 5400장이 있다.

이것을 하나하나 Train/Test로 나눈다는건 멍청한 짓이다.

Train/Test 이미지를 나눌때 비율은 8:2가 이상적이라고 한다.

하지만 이렇게 분류하고서 끝이나는게 아니고, 원래는 Validation이라고 하여 학습을하고 그걸 통해 Test가 된 모델을 검증해야 하기에 Validation용 이미지를 또 별도로 분류를 하곤 한다.

하지만 지금은 뭐 굳이 그렇게 까지 할 필요는 없기에... split만 하는걸로 하려고한다.

우선 Python을 사용해야하고, split-folders라는 라이브러리가 필요하다.

```shell
pip install split-folders
```

![CleanShot 2024-04-20 at 16 48 42@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/7877649f-7bad-46b4-89aa-6d9601aee586){: width="50%" height="50%"}

위에 pip했을때 reject된 이유는 2.7버전이 더이상 업뎃이나 이런 유지보수를 안하기 때문.

그래고 pip3 -V를 한 이유는 version check를 해야 vscode에서 python interpreter를 해당 버전에 맞추기 때문이다.

설치가 끝났으니 해당 라이브러리를 사용한다.

vscode에서 F1을 눌러 인터프리터를 설정을 다시 해준다. (그래야 설치한 라이브러리가 적용이된다.)

![CleanShot 2024-04-20 at 16 55 57@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/4a48b3a7-6e5e-40b1-afe9-9ce65222ffe8){: width="50%" height="50%"}

vscode로 바로 터미널로 해당 파일 실행을 하면 이렇게 분류가 된다.

```python
import splitfolders

splitfolders.ratio("animals", output="output", seed=1337, ratio=(.8, .2))
```

이때 주의할점은 디렉토리의 구조가 파이썬파일과 animals라는 상위 폴더와 같이있고, animals를 들어갔을때 label 폴더가 있어야 한다는 점이다.

![CleanShot 2024-04-20 at 16 57 49@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/bfed98c9-c209-4f55-b0d2-dc9001945bd8){: width="50%" height="50%"}

이런식.

그러면 위의 사진과 같이 output이라는 새로운 디렉토리가 생성되었고 train/val로 나뉘어진걸 알 수 있다.

그래서 위에는 TrainingData라는 디렉토리를 만들고 그다음에 Dog를 만들었지만, 더 많은 종류의 학습을 위해 새롭게 구성했다.

train / val 의 디렉토리로 나누어졌다.

## CreateML을 통해 머신러닝모델 만들기.

이전과 CreateML을 사용하는 방식이 바뀌었다.

Xcode → ToolBar → Open Developer Tools → Create ML → Choose New Document → Choose an Image Classification → Give it the Training and Testing Data

![CleanShot 2024-04-20 at 17 16 31@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/fab96bf9-55fc-48d9-8760-a1680eeb1a21){: width="50%" height="50%"}

이렇게 된다.

![CleanShot 2024-04-20 at 17 20 07@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/706bc52f-5cdb-4aad-91ef-7b1ffbf6999c)

그리고 Training and Testing Data에 디렉토리를 추가해준다.

Iteration은 반복 횟수를 의미한다.

우선 아무런 Augumentations를 하지않고 학습을 시작해본다.

![CleanShot 2024-04-20 at 17 24 22@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/5caeac50-120a-4528-bca0-d2edb6c42ead)

이런식으로 진행과정이 보인다.

![CleanShot 2024-04-20 at 17 26 24@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/7c1bdfdc-7ef7-488c-96f9-b349b8bbe2a0)

1차 결과

antelope가 0퍼센트의 정답률을 보인다.

사실 이럴땐 이미지를 더 보강해줘야 하긴하지만, 지금은 그냥 테스트니까 넘어가자...

우선 trainmore를 통해 35회의 반복 횟수를 더 주기로 했다.

이렇게 결과가 나오면 어떤 부분이 제일 학습하면서 혼란스러워 했는지 알 수 있는데,

![CleanShot 2024-04-20 at 17 28 37@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/b6d83f12-2126-484b-9127-66f4cba77c32)

영양과 사슴을 헷갈려했다.

위에도 언급했지만 이건 영양과 사슴에 대해 이미지를 더 많이 주고 학습시키는것 밖에는 답이 없다.

일단 모델만드는것에 포커스를 두고 패스하자.

get을 누르면 해당 모델을 저장 할 수 있다.

정확도를 올리는 [Article](https://developer.apple.com/documentation/createml/improving-your-model-s-accuracy)이 애플 개발자 문서에 있으니 참고해도 좋을 듯 하다.

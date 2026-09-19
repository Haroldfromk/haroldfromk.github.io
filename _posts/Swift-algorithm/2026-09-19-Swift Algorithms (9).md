---
title: Swift Algorithms (9) - Doubly Linked Lists
writer: Harold
date: 2026-09-19 04:06
categories: []
tags: []

toc: true
toc_sticky: true
---

## Doubly Linked List — class가 필요한 진짜 이유

새 프로젝트(멀티플랫폼 앱, landscape 고정)로 시작해서, 제네릭 doubly linked list를 구현한다.

---

### 왜 struct가 아니라 class인가

```swift
class DoublyLinkedListNode<T> {
    var value: T
    var prev: DoublyLinkedListNode<T>?
    var next: DoublyLinkedListNode<T>?

    init(value: T) {
        self.value = value
    }
}
```

여기서 `class`를 쓴 이유가 이 섹션 전체의 핵심이다. `DoublyLinkedListNode`는 `prev`, `next`로 **자기 자신과 같은 타입**을 참조한다. struct는 자기 자신을 프로퍼티로 담을 수 없다. struct는 값 타입이라 인스턴스 하나의 메모리 크기가 고정되어야 하는데, "내 프로퍼티가 나 자신과 같은 타입"이라면 그 크기를 무한히 재귀적으로 계산해야 해서 애초에 정의가 불가능하기 때문이다(컴파일러가 "struct 'DoublyLinkedListNode' has infinite size" 같은 에러를 낸다). class는 참조 타입이라 프로퍼티가 실제 값을 담는 대신 "다른 인스턴스를 가리키는 참조"만 담으면 되므로, 이런 자기 참조 구조가 자연스럽게 가능하다.

`prev`, `next`는 리스트의 양 끝에서는 가리킬 대상이 없을 수 있으니 optional로 선언한다.

---

### DoublyLinkedList: head, tail, append

```swift
class DoublyLinkedList<T> {
    var head: DoublyLinkedListNode<T>?
    var tail: DoublyLinkedListNode<T>?

    init(head: DoublyLinkedListNode<T>? = nil, tail: DoublyLinkedListNode<T>? = nil) {
        self.head = head
        self.tail = tail
    }

    init(values: [T]) {
        self.head = nil
        self.tail = nil
        for value in values {
            self.append(value: value)
        }
    }

    func append(value: T) {
        let newNode = DoublyLinkedListNode(value: value)
        if head == nil {
            head = newNode
            tail = newNode
        } else {
            tail?.next = newNode
            newNode.prev = tail
            tail = newNode
        }
    }
}
```

두 개의 초기화 함수를 만들었다. 하나는 `head`/`tail`을 직접 받는 기본형이고, 다른 하나는 값 배열(`values: [T]`)을 받아서 `append(value:)`를 반복 호출해 한 번에 리스트를 구성하는 편의 생성자다.

`append(value:)`의 로직은 이렇다. 리스트가 비어있으면(`head == nil`) 새 노드가 `head`이자 `tail`이 된다. 비어있지 않으면, 기존 `tail`의 `next`를 새 노드로 연결하고(`tail?.next = newNode`), 새 노드의 `prev`를 기존 `tail`로 연결한 뒤(`newNode.prev = tail`), `tail` 자체를 새 노드로 갱신한다.

---

### UI에서 기록할 만한 것: 화살표로 리스트를 시각화하기

```swift
struct DoublyLinkedListView<T>: View {
    let doublyLinkedList: DoublyLinkedList<T>
    let arrow = "arrow.left.arrow.right"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                NullView()
                HStack(spacing: -5.0) {
                    Image(systemName: arrow).font(.largeTitle).fontWeight(.thin)
                    ForEach(doublyLinkedList.getNodeValues()) { node in
                        NodeView(value: node.value)
                        Image(systemName: arrow).font(.largeTitle).fontWeight(.thin)
                    }
                }
                NullView()
            }
        }.padding()
    }
}
```

`getNodeValues()`로 linked list를 순회하면서 `DoublyLinkedListNode` 배열을 뽑아내고, 각 노드 사이사이에 양방향 화살표 아이콘(`arrow.left.arrow.right`)을 끼워넣는다. 리스트 맨 앞과 맨 뒤에는 `NullView()`(아마도 nil을 시각적으로 표현하는 placeholder)를 둬서 "여기서 리스트가 끝난다"는 걸 보여준다. `ScrollView(.horizontal)`로 감싸서, 노드가 아무리 많아도 가로로 스크롤하며 전체를 확인할 수 있게 했다. 자료구조를 텍스트가 아니라 실제 화살표로 이어진 시각적 형태로 보여주는, 이 강의에서 처음 나온 방식이다.

---

### delete: `===`로 노드 자체를 식별하기

값으로 노드를 찾아 삭제하는 함수를 구현한다. 값이 같은 노드를 찾은 뒤, 그 노드의 양옆(`prev`, `next`)을 서로 직접 연결해서 삭제된 노드를 건너뛰게 만드는 방식이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-19-Swift-Algorithms-9/dll_delete_relink_fixed.png){: width="90%" height="90%"}

```swift
func delete(value: T) {
    var current = head

    while let node = current {
        if node.value == value {
            let prevNode = node.prev
            let nextNode = node.next

            prevNode?.next = nextNode
            nextNode?.prev = prevNode

            if node === head {
                head = nextNode
            }

            if node === tail {
                tail = prevNode
            }

            return
        }

        current = node.next
    }
}
```

여기서 두 가지를 짚을 만하다.

- **`node === head`, `node === tail`**: `==`이 아니라 `===`를 썼다. `==`은 "값이 같은가"(`Equatable`)를 비교하는 연산자고, `===`는 "같은 인스턴스를 가리키는가"(참조 비교, identity)를 확인하는 연산자다. 지금 하려는 건 "지금 삭제하려는 이 노드가, 리스트의 head/tail로 저장해둔 바로 그 인스턴스와 같은 객체인가"를 확인하는 것이라 `===`가 정확히 맞는 연산자다. **이 연산자 자체가 class(참조 타입)에서만 의미를 가진다** — struct 같은 값 타입에는 `===`가 아예 적용되지 않는다. 이 섹션이 바로 "class가 아니면 이 코드 자체가 성립하지 않는" 지점이다
- **`prevNode?.next = nextNode`, `nextNode?.prev = prevNode`**: `prevNode`나 `nextNode`가 `nil`일 수 있으니(삭제 대상이 head나 tail인 경우) optional chaining으로 안전하게 연결한다. 만약 `prevNode`가 `nil`이면(즉 삭제 대상이 head라면) 이 줄은 그냥 아무 일도 하지 않고 넘어가고, 대신 뒤이어 나오는 `if node === head { head = nextNode }`가 head 자체를 갱신해준다

값이 일치하는 노드를 못 찾으면 `current = node.next`로 계속 다음 노드로 넘어가고, 끝까지 못 찾으면 아무 일 없이 함수가 종료된다.

---

### 정리: 왜 이 섹션이 진짜 "class 활용 사례"인가

앞서 `MiniBar`, `Hotel` 예제에서는 class를 썼지만 struct로 바꿔도 겉보기엔 큰 문제가 없어 보였다. 이번 doubly linked list는 다르다.(MiniBar, Hotel쪽은 별도로 기록할게 없어보여서 Pass)

1. **자기 참조 자체가 struct로는 불가능**하다(무한 크기 문제)
2. **`===`(참조 identity 비교)가 알고리즘의 정확성에 직접 관여**한다 — "이 노드가 바로 그 head 인스턴스인가"라는 질문 자체가, 참조 타입이 아니면 성립하지 않는 질문이다

이 두 가지가, class를 "그냥 문법적으로 쓸 수 있는 선택지" 정도가 아니라 "이 자료구조를 구현하는 데 반드시 필요한 도구"로 만드는 지점이다. `Stack` 예제가 "class를 쓰면 이런 부작용이 생긴다"는 주의사항이었다면, 이번 섹션은 "이런 상황에서는 class가 아니면 애초에 안 된다"는 쪽의 사례다.
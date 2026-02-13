---
title: (Deep Dive) Protocols and Delegates
writer: Harold
date: 2024-03-06
categories: [Deep Dive]
tags: []

toc: true
toc_sticky: true
---

Protocol과 Delegate를 응급 구조 상황에 빗대어 코드를 작성하였다.

```swift
protocol AdvancedLifeSupport {
    func performCPR() // cpr을 할 수 있는 응급 구조 인증서(프로토콜)
}

class EmergencyCallHandler { // 응급실 콜센터 직원
    var delegate : AdvancedLifeSupport? // 그 대리인은 응급 구조 인증서가 있는가? 있을수도 있고 ~ 없을수도 있고.
    
    func assessSituation() { // 상황 파악
        print("Can you tell me what happened?")
    }
    
    func medicalEmergency(){ // 응급 상황 발생, 대리인이 cpr수행.
        delegate?.performCPR()
    }
}

struct Paramedic: AdvancedLifeSupport { // 응급구조사 구조체 생성.
   
    init(handler: EmergencyCallHandler){ // 담당자가 누구인지
        handler.delegate = self // 담당자의 대리인을 자신으로 설정.
    }
    
    func performCPR() {
        print("The paramedic does chest compressions, 30 per second.")
    }
    
}

class Doctor : AdvancedLifeSupport {
    
    init(handler: EmergencyCallHandler){
        handler.delegate = self
    }
    
    func performCPR() {
        print("The doctor does chest compresssions, 30 per second.")
    }
    
    func useStethescope() {
        print("Listening for heart sounds")
    }
}

class Surgeon : Doctor {
    override func performCPR() {
        super.performCPR()
        print("Sings staying alive by the BeeGees")
    }
    
    func useElectricDrill() {
        print("Whirr...")
    }
    
}

let emilio = EmergencyCallHandler() // 오늘의 읍급 콜 센터 직원은 emilio
//let pete = Paramedic(handler: emilio) // emilio가 통지를 해준다.
let angela = Surgeon(handler: emilio)


emilio.assessSituation() // 뭔가 상황이 발생하면 전화가 에밀리오에가 가고 에밀리오는 상황 파악을 한다.
emilio.medicalEmergency() // 상황 파악 후 비상사태 선언
// Doctor, Surgeon이 없을때의 출력, 비상상태 선언을 하니 pete가 위임받고 대신 하고 있다.
// Can you tell me what happened? from emilio (EmergencyCallHandler)
// The paramedic does chest compressions, 30 per second. from pete (Paramedic)

// Doctor, Surgeon이 있고, angela를 통해서 선언시.
// Can you tell me what happened? from emilio (EmergencyCallHandler)
// The doctor does chest compresssions, 30 per second. from Doctor
// Sings staying alive by the BeeGees from Surgeon

```

얼추 감은 오지만 그래도 완벽하다고는 할 수 없다.

조만간 한번더 강의를 듣고, 자료를 찾아보면서 보완을 해야 할 것 같다.
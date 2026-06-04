//
//  TouchdownView.swift
//  RunWay
//

import SwiftUI

struct TouchdownView: View {
    @State private var navigateToSummary = false
    @State private var planeOffset: CGFloat = 80    // 양수 = 아래쪽 시작
    @State private var planeScale: CGFloat = 3    // 클수록 크게 시작
    @State private var planeOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleScale: CGFloat = 0.7
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Runway + 비행기 애니메이션
                ZStack {
                    RunwayView()
                        .frame(height: 280)
                    
                    // 착륙하는 비행기 — 아래서 위로 올라가며 작아짐
                    Image(systemName: "airplane")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.rwGreen)
                        .shadow(color: Color.rwGreen.opacity(0.6), radius: 12)
                        .rotationEffect(.degrees(-90)) // 위 방향
                        .scaleEffect(planeScale)
                        .offset(y: planeOffset)
                        .opacity(planeOpacity)
                    // rotationEffect 없으면 기본 방향 (오른쪽)
                    // .rotationEffect(.degrees(90))  // 아래 방향
                    // .rotationEffect(.degrees(180)) // 왼쪽 방향
                }
                .frame(height: 280)
                
                // TOUCHDOWN title
                Text("TOUCHDOWN")
                    .font(.orbitron(28, weight: .black))
                    .foregroundColor(.rwGreen)
                    .shadow(color: Color.rwGreen.opacity(0.5), radius: 20)
                    .padding(.top, 8)
                    .opacity(titleOpacity)
                    .scaleEffect(titleScale)
                
                // Great flight badge
                HStack(spacing: 8) {
                    Image(systemName: "airplane.arrival")
                        .foregroundColor(.rwGreen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("GREAT FLIGHT!")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.rwGreen)
                        Text("Safe landing")
                            .font(.system(size: 10))
                            .foregroundColor(.rwMuted)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.rwGreen)
                        .font(.system(size: 20))
                }
                .padding(12)
                .background(Color.rwGreen.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rwGreen.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                
                // Stats
                HStack(spacing: 0) {
                    TDStatView(label: "DISTANCE", value: "8.42", unit: "km")
                    Divider().frame(height: 40).background(Color.rwBorder)
                    TDStatView(label: "TIME", value: "48:12", unit: "")
                    Divider().frame(height: 40).background(Color.rwBorder)
                    TDStatView(label: "AVG PACE", value: "5'42\"", unit: "/km")
                    Divider().frame(height: 40).background(Color.rwBorder)
                    TDStatView(label: "AVG HR", value: "153", unit: "bpm")
                    Divider().frame(height: 40).background(Color.rwBorder)
                    TDStatView(label: "CADENCE", value: "172", unit: "spm")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                
                Spacer()
                
                // View Summary button
                Button { navigateToSummary = true } label: {
                    Text("VIEW SUMMARY")
                        .font(.orbitron(14, weight: .bold))
                        .foregroundColor(.rwBg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.rwGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
                
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToSummary) {
            FlightSummaryView()
        }
        .onAppear {
            playTouchdownSequence()
        }
    }
    
    func playTouchdownSequence() {
        // 1. 비행기 등장 (멀리서 가까이 + 위에서 아래로)
        withAnimation(.easeIn(duration: 0.3)) {
            planeOpacity = 1
        }
        
        withAnimation(.easeOut(duration: 1.2)) {
            planeOffset = -60   // 음수 = 위쪽으로 이동
            planeScale = 0.2    // 작아지며 소실점으로
        }
        
        // 2. 착륙 순간 햅틱
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            // 살짝 텀 두고 한 번 더 (착륙 느낌)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let impact2 = UIImpactFeedbackGenerator(style: .medium)
                impact2.impactOccurred()
            }
        }
        
        // 3. 비행기 사라지고 TOUCHDOWN 텍스트 등장
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                planeOpacity = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                titleOpacity = 1
                titleScale = 1.0
            }
        }

    }
}

struct TDStatView: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.rwMuted)
                .kerning(0.5)
                .multilineTextAlignment(.center)
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value)
                    .font(.orbitron(13, weight: .bold))
                    .foregroundColor(.rwText)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 7))
                        .foregroundColor(.rwMuted)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Runway Illustration
struct RunwayView: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black)
            )

            // 소실점 (위쪽)
            let vanishX = w / 2
            let vanishY = h * 0.15

            // 활주로 왼쪽 엣지
            var leftPath = Path()
            leftPath.move(to: CGPoint(x: w * 0.05, y: h))
            leftPath.addLine(to: CGPoint(x: vanishX - 8, y: vanishY))
            context.stroke(leftPath, with: .color(Color.rwGreen.opacity(0.5)), lineWidth: 1.5)

            // 활주로 오른쪽 엣지
            var rightPath = Path()
            rightPath.move(to: CGPoint(x: w * 0.95, y: h))
            rightPath.addLine(to: CGPoint(x: vanishX + 8, y: vanishY))
            context.stroke(rightPath, with: .color(Color.rwGreen.opacity(0.5)), lineWidth: 1.5)

            // 중앙 점선 — 아래(가까이)에서 크고, 위(멀리)에서 작아짐
            let dashPositions: [CGFloat] = [0.92, 0.78, 0.65, 0.52, 0.40, 0.28]
            for pos in dashPositions {
                let y = h * pos
                // pos 클수록(아래) 크게, 작을수록(위) 작게
                let perspRatio = pos - 0.15
                let dashW: CGFloat = max(2, 14 * perspRatio)
                let dashH: CGFloat = max(3, 26 * perspRatio)
                let rect = CGRect(
                    x: vanishX - dashW / 2,
                    y: y - dashH / 2,
                    width: dashW,
                    height: dashH
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 2),
                    with: .color(Color.white.opacity(max(0.15, 0.7 * perspRatio)))
                )
            }

            // 활주로 라이트 — 엣지 선 위에 정확히 배치
            let lightCount = 6
            for i in 0..<lightCount {
                let t = CGFloat(i) / CGFloat(lightCount - 1)
                let yPos = h * (1.0 - t * 0.85)

                // 왼쪽 엣지 위 x 좌표 (선형 보간)
                let leftX = w * 0.05 + t * (vanishX - 8 - w * 0.05)
                let rightX = w * 0.95 - t * (w * 0.95 - (vanishX + 8))

                // 아래쪽(t=0)이 크고, 위쪽(t=1)이 작아짐
                let radius: CGFloat = max(1.5, 5.0 * (1 - t * 0.75))
                let opacity = max(0.25, 0.9 * (1 - t * 0.55))

                // 가까운 건 흰색, 멀수록 앰버
                let lightColor = Color.rwAmber.opacity(opacity)

                // 왼쪽 라이트
                context.fill(
                    Path(ellipseIn: CGRect(x: leftX - radius, y: yPos - radius, width: radius * 2, height: radius * 2)),
                    with: .color(lightColor)
                )

                // 오른쪽 라이트
                context.fill(
                    Path(ellipseIn: CGRect(x: rightX - radius, y: yPos - radius, width: radius * 2, height: radius * 2)),
                    with: .color(lightColor)
                )
            }
        }
    }
}

#Preview {
    NavigationStack { TouchdownView() }
}

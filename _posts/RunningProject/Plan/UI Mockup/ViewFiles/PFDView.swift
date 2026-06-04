//
//  PFDView.swift
//  RunWay
//

import SwiftUI
import AudioToolbox

enum GPWSState {
    case normal, sinkRate, overspeed, minimums
}

struct PFDView: View {
    @Environment(\.dismiss) var dismiss
    @State private var navigateToTouchdown = false
    @State private var gpwsState: GPWSState = .normal
    @State private var overlayOpacity: Double = 0
    @State private var flashOn = false

    var overlayColor: Color {
        switch gpwsState {
        case .normal: return .clear
        case .sinkRate, .overspeed: return .rwRed
        case .minimums: return .rwAmber
        }
    }

    var body: some View {
        ZStack {
            Color.rwBg.ignoresSafeArea()

            // GPWS/MINIMUMS 배경 점멸 오버레이
            if gpwsState != .normal {
                overlayColor
                    .opacity(flashOn ? 0.2 : 0)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    HStack(spacing: 5) {
                        BlinkingDot(color: .rwRed, size: 7)
                        Text("REC")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.rwRed)
                    }
                    Spacer()
                    Text("48:12")
                        .font(.orbitron(18, weight: .bold))
                        .foregroundColor(.rwText)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.rwMuted)
                            .font(.system(size: 15))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.rwPanel)
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(.rwBorder), alignment: .bottom)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {

                        // Header label
                        HStack {
                            Text("RUNWAY")
                                .font(.orbitron(13, weight: .black))
                                .foregroundColor(.rwGreen)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Speed tape + ADI + Alt tape
                        HStack(spacing: 0) {
                            // Speed tape
                            SpeedTapeView()
                                .frame(width: 56)

                            // ADI
                            ADIView()
                                .frame(maxWidth: .infinity)

                            // Alt tape
                            AltTapeView()
                                .frame(width: 56)
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rwBorder, lineWidth: 1))
                        .padding(.horizontal, 16)

                        // N1% Dual Gauges
                        HStack(spacing: 8) {
                            N1GaugeView(label: "HR N1%", value: 84, color: .rwRed, zone: "ZONE 4")
                            N1GaugeView(label: "CAD N1%", value: 91, color: .rwGreen, zone: "ZONE 4")
                        }
                        .padding(.horizontal, 16)

                        // Dist + Flight Time
                        HStack(spacing: 8) {
                            VStack(spacing: 2) {
                                Text("DIST")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.rwMuted)
                                    .kerning(1.5)
                                HStack(alignment: .lastTextBaseline, spacing: 2) {
                                    Text("8.42")
                                        .font(.orbitron(20, weight: .bold))
                                        .foregroundColor(.rwText)
                                    Text("km")
                                        .font(.system(size: 10))
                                        .foregroundColor(.rwMuted)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.rwPanel)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rwBorder, lineWidth: 1))

                            VStack(spacing: 2) {
                                Text("FLIGHT TIME")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.rwMuted)
                                    .kerning(1.5)
                                Text("48:12")
                                    .font(.orbitron(20, weight: .bold))
                                    .foregroundColor(.rwText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.rwPanel)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rwBorder, lineWidth: 1))
                        }
                        .padding(.horizontal, 16)

                        // GPWS status
                        HStack(spacing: 8) {
                            switch gpwsState {
                            case .normal:
                                BlinkingDot(color: .rwGreen, size: 7)
                                Text("NORMAL OPERATION")
                                    .font(.orbitron(10, weight: .semibold))
                                    .foregroundColor(.rwGreen)
                                    .kerning(2)
                                Spacer()
                                Text("GPWS ●")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.rwGreen)
                            case .sinkRate:
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.rwRed)
                                Text("SINK RATE")
                                    .font(.orbitron(11, weight: .bold))
                                    .foregroundColor(.rwRed)
                                    .kerning(2)
                                Spacer()
                                Text("PULL UP")
                                    .font(.orbitron(10, weight: .bold))
                                    .foregroundColor(.rwRed)
                            case .overspeed:
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.rwAmber)
                                Text("OVERSPEED")
                                    .font(.orbitron(11, weight: .bold))
                                    .foregroundColor(.rwAmber)
                                    .kerning(2)
                                Spacer()
                                Text("SLOW DOWN")
                                    .font(.orbitron(10, weight: .bold))
                                    .foregroundColor(.rwAmber)
                            case .minimums:
                                Image(systemName: "flag.fill")
                                    .foregroundColor(.rwAmber)
                                Text("MINIMUMS")
                                    .font(.orbitron(11, weight: .bold))
                                    .foregroundColor(.rwAmber)
                                    .kerning(2)
                                Spacer()
                                Text("50m REMAINING")
                                    .font(.orbitron(9, weight: .bold))
                                    .foregroundColor(.rwAmber)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(gpwsState == .normal ? Color.rwGreen.opacity(0.06) : gpwsState == .minimums ? Color.rwAmber.opacity(0.1) : Color.rwRed.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(gpwsState == .normal ? Color.rwGreen.opacity(0.2) : gpwsState == .minimums ? Color.rwAmber.opacity(0.3) : Color.rwRed.opacity(0.3), lineWidth: 1))
                        .opacity(gpwsState == .normal ? 1 : (flashOn ? 1 : 0.25)) // 경고 시 깜빡임
                        .padding(.horizontal, 16)

                        // 테스트 버튼 3개
                        HStack(spacing: 6) {
                            Button { triggerGPWS(.sinkRate) } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(.rwRed)
                                    Text("SINK RATE")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.rwRed)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.rwRed.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rwRed.opacity(0.3), lineWidth: 1))
                            }
                            Button { triggerGPWS(.minimums) } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: "flag.fill")
                                        .foregroundColor(.rwAmber)
                                    Text("MINIMUMS")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.rwAmber)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.rwAmber.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rwAmber.opacity(0.3), lineWidth: 1))
                            }
                            Button { triggerGPWS(.normal) } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.rwGreen)
                                    Text("NORMAL")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.rwGreen)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.rwGreen.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rwGreen.opacity(0.3), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 16)

                        // Touchdown
                        Button { navigateToTouchdown = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "airplane.arrival")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("TOUCHDOWN ■")
                                    .font(.orbitron(15, weight: .bold))
                                    .kerning(1)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.rwRed)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
                .scrollDisabled(true)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToTouchdown) {
            TouchdownView()
        }
    }

    func triggerGPWS(_ state: GPWSState) {
        // 기존 애니메이션 초기화
        flashOn = false
        gpwsState = state

        if state == .normal { return }

        // 깜빡임 시작
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            flashOn = true
        }

        // 햅틱
        let style: UIImpactFeedbackGenerator.FeedbackStyle = state == .minimums ? .medium : .heavy
        let impact = UIImpactFeedbackGenerator(style: style)
        impact.impactOccurred()

        // 경고음
        if state == .sinkRate || state == .overspeed {
            AudioServicesPlaySystemSound(1005)
        } else if state == .minimums {
            AudioServicesPlaySystemSound(1013)
        }
    }
}

// MARK: - Speed Tape
struct SpeedTapeView: View {
    let paces = ["6'00", "5'45", "5'30", "5'15", "5'00"]
    let currentPace = "5'32\""
    let avgPace = "AVG 5'28\""

    var body: some View {
        ZStack {
            Color.rwPanel.opacity(0.9)
            VStack(spacing: 0) {
                Text("SPD")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.rwMuted)
                    .kerning(1)
                    .padding(.top, 6)

                Spacer()

                ForEach(paces, id: \.self) { pace in
                    HStack {
                        Spacer()
                        if pace == "5'30" {
                            Text(currentPace)
                                .font(.orbitron(11, weight: .bold))
                                .foregroundColor(.rwGreen)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.rwPanel2)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.rwGreen, lineWidth: 1))
                        } else {
                            Text(pace)
                                .font(.system(size: 8))
                                .foregroundColor(.rwMuted)
                        }
                        Rectangle()
                            .fill(Color.rwBorder)
                            .frame(width: 6, height: 1)
                    }
                    if pace != paces.last { Spacer() }
                }

                Spacer()

                Text(avgPace)
                    .font(.system(size: 6))
                    .foregroundColor(.rwMuted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 6)
            }
            .padding(.trailing, 4)
        }
        .overlay(
            Rectangle()
                .fill(Color.rwBorder)
                .frame(width: 1),
            alignment: .trailing
        )
    }
}

// MARK: - ADI (Attitude Director Indicator)
struct ADIView: View {
    var body: some View {
        ZStack {
            // Sky
            LinearGradient(
                colors: [Color(hex: "#0a3a5c"), Color(hex: "#0055aa")],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .offset(y: -50)

            // Ground
            LinearGradient(
                colors: [Color(hex: "#3a2010"), Color(hex: "#1a0e06")],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .offset(y: 50)

            // Horizon line
            Rectangle()
                .fill(Color.rwGreen.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 1.5)

            // Pitch lines
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 80, height: 1)
                .offset(y: -28)
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 60, height: 1)
                .offset(y: 28)

            // Aircraft symbol
            Path { path in
                path.move(to: CGPoint(x: -35, y: 0))
                path.addLine(to: CGPoint(x: 0, y: -8))
                path.addLine(to: CGPoint(x: 35, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 4))
                path.closeSubpath()
            }
            .stroke(Color.rwAmber, lineWidth: 2)

            // Center dot
            Circle()
                .fill(Color.rwAmber)
                .frame(width: 4, height: 4)

            // Vertical center line
            Rectangle()
                .fill(Color.rwAmber.opacity(0.5))
                .frame(width: 1.5, height: 30)

            // Heading tape at top
            VStack {
                ZStack {
                    Color.black.opacity(0.55)
                    HStack {
                        Text("270")
                            .font(.system(size: 8))
                            .foregroundColor(.rwMuted)
                        Spacer()
                        Text("N  180°")
                            .font(.orbitron(9, weight: .bold))
                            .foregroundColor(.rwAmber)
                        Spacer()
                        Text("90")
                            .font(.system(size: 8))
                            .foregroundColor(.rwMuted)
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 20)
                Spacer()

                // GLIDE PATH label
                HStack {
                    Spacer()
                    VStack(spacing: 1) {
                        Text("GLIDE PATH")
                            .font(.system(size: 6, weight: .medium))
                            .foregroundColor(.rwGreen)
                        Text("-1.2%")
                            .font(.orbitron(10, weight: .bold))
                            .foregroundColor(.rwGreen)

                        // VS
                        Text("VS  -0.6 m/s")
                            .font(.system(size: 7))
                            .foregroundColor(.rwMuted)
                    }
                    .padding(5)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
        }
        .background(Color.rwBg)
    }
}

// MARK: - Alt Tape
struct AltTapeView: View {
    let alts = ["100", "80", "60", "42", "20", "0"]
    let currentAlt = "0.42"

    var body: some View {
        ZStack {
            Color.rwPanel.opacity(0.9)
            VStack(spacing: 0) {
                Text("ALT")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.rwMuted)
                    .kerning(1)
                    .padding(.top, 6)

                Spacer()

                ForEach(alts, id: \.self) { alt in
                    HStack {
                        Rectangle()
                            .fill(Color.rwBorder)
                            .frame(width: 6, height: 1)
                        if alt == "42" {
                            Text(currentAlt)
                                .font(.orbitron(11, weight: .bold))
                                .foregroundColor(.rwGreen)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.rwPanel2)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.rwGreen, lineWidth: 1))
                        } else {
                            Text(alt)
                                .font(.system(size: 8))
                                .foregroundColor(.rwMuted)
                        }
                        Spacer()
                    }
                    if alt != alts.last { Spacer() }
                }

                Spacer()
                Text("km")
                    .font(.system(size: 6))
                    .foregroundColor(.rwMuted)
                    .padding(.bottom, 6)
            }
            .padding(.leading, 4)
        }
        .overlay(
            Rectangle()
                .fill(Color.rwBorder)
                .frame(width: 1),
            alignment: .leading
        )
    }
}

#Preview {
    NavigationStack { PFDView() }
}

//
//  RunWayTheme.swift
//  RunWay
//

import SwiftUI

// MARK: - Colors
extension Color {
    static let rwBg       = Color(hex: "#0B0E14")
    static let rwPanel    = Color(hex: "#161A22")
    static let rwPanel2   = Color(hex: "#1E2430")
    static let rwBorder   = Color(hex: "#252D3A")
    static let rwGreen    = Color(hex: "#64FFDA")
    static let rwGreen2   = Color(hex: "#00C896")
    static let rwAmber    = Color(hex: "#FFB020")
    static let rwRed      = Color(hex: "#FF453A")
    static let rwBlue     = Color(hex: "#0A84FF")
    static let rwMuted    = Color(hex: "#88949E")
    static let rwText     = Color(hex: "#E6EDF3")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography
extension Font {
    static func orbitron(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Orbitron", size: size).weight(weight)
    }
}

// MARK: - Reusable Components

struct RWPanel<Content: View>: View {
    let content: Content
    var padding: CGFloat = 14
    var cornerRadius: CGFloat = 14

    init(padding: CGFloat = 14, cornerRadius: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.rwPanel)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.rwBorder, lineWidth: 1)
            )
    }
}

struct RWLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.rwMuted)
            .kerning(1.5)
            .textCase(.uppercase)
    }
}

struct BlinkingDot: View {
    let color: Color
    var size: CGFloat = 7
    @State private var on = true

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(on ? 1 : 0.15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                    on.toggle()
                }
            }
    }
}

struct N1GaugeView: View {
    let label: String
    let value: Int
    let color: Color
    let zone: String

    var progress: Double { Double(value) / 100.0 }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.rwMuted)
                Spacer()
                Text("\(value)%")
                    .font(.orbitron(13, weight: .bold))
                    .foregroundColor(color)
            }

            ZStack {
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(Color.rwPanel2, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(90))

                Circle()
                    .trim(from: 0.15, to: 0.15 + 0.70 * progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .animation(.easeOut(duration: 0.5), value: value)

                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.orbitron(16, weight: .bold))
                        .foregroundColor(color)
                    Text(zone)
                        .font(.system(size: 7))
                        .foregroundColor(.rwMuted)
                }
            }
            .frame(height: 64)
        }
        .padding(10)
        .background(Color.rwPanel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rwBorder, lineWidth: 1))
    }
}

struct TabBarView: View {
    let selected: Int

    var body: some View {
        HStack {
            ForEach(tabs.indices, id: \.self) { i in
                let tab = tabs[i]
                VStack(spacing: 3) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 20))
                        .foregroundColor(selected == i ? .rwGreen : .rwMuted)
                    Text(tab.label)
                        .font(.system(size: 9))
                        .foregroundColor(selected == i ? .rwGreen : .rwMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(.rwBorder), alignment: .top)
    }

    let tabs = [
        (icon: "house.fill", label: "Deck"),
        (icon: "list.bullet.clipboard", label: "Logbook"),
        (icon: "airplane", label: "Aircraft"),
        (icon: "bell", label: "Alerts"),
        (icon: "person.circle", label: "Profile"),
    ]
}

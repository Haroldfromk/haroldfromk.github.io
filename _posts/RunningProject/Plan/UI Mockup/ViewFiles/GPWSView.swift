//
//  GPWSView.swift
//  RunWay
//

import SwiftUI

struct GPWSView: View {
    @Environment(\.dismiss) var dismiss
    @State private var flashRed = false

    var body: some View {
        ZStack {
            Color(hex: "#130506").ignoresSafeArea()

            VStack(spacing: 0) {
                // Alert bar
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                    Text("GPWS")
                        .font(.orbitron(11, weight: .bold))
                        .foregroundColor(.white)
                        .kerning(2)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.rwRed)

                // Stripe
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .rwRed, location: 0),
                                .init(color: .rwRed, location: 0.5),
                                .init(color: .clear, location: 0.5),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 16)
                    .opacity(0.6)

                Spacer()

                VStack(spacing: 16) {
                    // Main warning
                    VStack(spacing: 8) {
                        Text("SINK RATE")
                            .font(.orbitron(32, weight: .black))
                            .foregroundColor(.rwRed)
                            .shadow(color: Color.rwRed.opacity(0.6), radius: 20)
                        Text("TOO HIGH")
                            .font(.orbitron(32, weight: .black))
                            .foregroundColor(.rwRed)
                            .shadow(color: Color.rwRed.opacity(0.6), radius: 20)
                    }
                    .opacity(flashRed ? 1 : 0.5)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                            flashRed.toggle()
                        }
                    }

                    // Sink rate value
                    VStack(spacing: 4) {
                        Text("SINK RATE")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.rwMuted)
                            .kerning(2)
                        Text("-3.2 m/s")
                            .font(.orbitron(36, weight: .bold))
                            .foregroundColor(.rwRed)
                    }

                    // SPD + ALT mini tapes
                    HStack(spacing: 12) {
                        MiniTapeView(label: "SPD", values: ["6'00", "5'45", "5'30\"", "5'15", "5'00"], current: "5'30\"")
                        MiniTapeView(label: "ALT", values: ["100", "80", "60", "42", "20"], current: "42")
                    }
                    .padding(.horizontal, 16)

                    // PULL UP button
                    Text("PULL UP")
                        .font(.orbitron(20, weight: .black))
                        .foregroundColor(.rwAmber)
                        .kerning(3)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.rwAmber, lineWidth: 2)
                        )

                    // N1% gauges
                    HStack(spacing: 10) {
                        N1GaugeView(label: "HR N1%", value: 87, color: .rwRed, zone: "ZONE 4")
                        N1GaugeView(label: "CAD N1%", value: 92, color: .rwRed, zone: "ZONE 4")
                    }
                    .padding(.horizontal, 16)
                }

                Spacer()

                // Bottom stripe
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .rwRed, location: 0),
                                .init(color: .rwRed, location: 0.5),
                                .init(color: .clear, location: 0.5),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 20)
                    .opacity(0.6)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Mini Tape
struct MiniTapeView: View {
    let label: String
    let values: [String]
    let current: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.rwMuted)
                .kerning(1.5)
            ForEach(values, id: \.self) { val in
                if val == current {
                    Text(val)
                        .font(.orbitron(10, weight: .bold))
                        .foregroundColor(.rwRed)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.rwPanel2)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.rwRed, lineWidth: 1))
                } else {
                    Text(val)
                        .font(.system(size: 8))
                        .foregroundColor(.rwMuted.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.rwPanel.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.rwRed.opacity(0.3), lineWidth: 1))
    }
}

#Preview {
    NavigationStack { GPWSView() }
}

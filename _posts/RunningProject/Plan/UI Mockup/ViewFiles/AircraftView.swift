//
//  AircraftView.swift
//  RunWay
//

import SwiftUI

struct AircraftView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.rwBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    // Header
                    Text("AIRCRAFT")
                        .font(.orbitron(20, weight: .bold))
                        .foregroundColor(.rwText)
                        .kerning(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // Aircraft model name
                    Text("A320-200")
                        .font(.orbitron(28, weight: .black))
                        .foregroundColor(.rwGreen)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)

                    // Plane illustration
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.rwPanel)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rwBorder, lineWidth: 1))

                        Image(systemName: "airplane")
                            .font(.system(size: 80))
                            .foregroundColor(.rwGreen.opacity(0.2))
                            .rotationEffect(.degrees(-45))

                        // Glow effect
                        Image(systemName: "airplane")
                            .font(.system(size: 80))
                            .foregroundColor(.rwGreen)
                            .rotationEffect(.degrees(-45))
                            .blur(radius: 0)
                            .opacity(0.15)
                    }
                    .frame(height: 160)
                    .padding(.horizontal, 16)

                    // Aircraft info
                    VStack(spacing: 0) {
                        Text("AIRCRAFT INFO")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.rwMuted)
                            .kerning(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        AircraftInfoRow(label: "REGISTRATION", value: "HL-BHXI")
                        AircraftInfoRow(label: "ENGINES", value: "CFM56-5B")
                        AircraftInfoRow(label: "MTOW", value: "77,000 kg")
                        AircraftInfoRow(label: "TOTAL FLIGHT TIME", value: "327 h")
                    }
                    .background(Color.rwPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rwBorder, lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }


        }
        .navigationBarHidden(true)
    }
}

struct AircraftInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.rwMuted)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.rwText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(.rwBorder), alignment: .bottom)
    }
}

#Preview {
    NavigationStack { AircraftView() }
}

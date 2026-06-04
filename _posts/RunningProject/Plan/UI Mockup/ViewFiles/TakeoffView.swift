//
//  TakeoffView.swift
//  RunWay
//

import SwiftUI

struct TakeoffView: View {
    @Environment(\.dismiss) var dismiss
    @State private var countdownActive = false
    @State private var countdownValue = 3
    @State private var navigateToPFD = false
    
    let checkItems: [(icon: String, name: String, value: String, ok: Bool)] = [
        ("wifi", "GPS SIGNAL", "STRONG", true),
        ("heart.fill", "HEART RATE", "87%", true),
        ("waveform.path.ecg", "CADENCE SENSOR", "CONNECTED", true),
        ("battery.75", "BATTERY", "92%", true),
        ("cloud.sun", "WEATHER", "GOOD", true),
    ]
    
    var body: some View {
        ZStack {
            Color.rwBg.ignoresSafeArea()
            
            
            VStack(spacing: 10) {
                
                // Ready badge
                HStack(spacing: 8) {
                    BlinkingDot(color: .rwGreen, size: 8)
                    Text("READY FOR TAKEOFF")
                        .font(.orbitron(13, weight: .bold))
                        .foregroundColor(.rwGreen)
                        .kerning(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.rwGreen.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rwGreen.opacity(0.3), lineWidth: 1.5))
                .padding(.horizontal, 16)
                .padding(.top, 14)
                
                // Checklist
                VStack(spacing: 6) {
                    ForEach(checkItems, id: \.name) { item in
                        HStack {
                            Image(systemName: item.icon)
                                .foregroundColor(.rwMuted)
                                .frame(width: 20)
                            Text(item.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.rwText)
                            Spacer()
                            if item.ok {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.rwGreen)
                                    .font(.system(size: 14))
                            }
                            Text(item.value)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(item.ok ? .rwGreen : .rwRed)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color.rwPanel)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rwBorder, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                
                // Throttle + Status
                HStack(spacing: 10) {
                    VStack(spacing: 4) {
                        Text("THRUST")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.rwMuted)
                            .kerning(1.5)
                        Text("100%")
                            .font(.orbitron(22, weight: .bold))
                            .foregroundColor(.rwGreen)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.rwPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rwBorder, lineWidth: 1))
                    
                    VStack(spacing: 4) {
                        Text("STATUS")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.rwMuted)
                            .kerning(1.5)
                        Text("READY")
                            .font(.orbitron(22, weight: .bold))
                            .foregroundColor(.rwAmber)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.rwPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rwBorder, lineWidth: 1))
                }
                .padding(.horizontal, 16)
                
                // ROTATE Button
                Button { startCountdown() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 16, weight: .semibold))
                        Text("ROTATE")
                            .font(.orbitron(18, weight: .bold))
                            .kerning(3)
                    }
                    .foregroundColor(.rwBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.rwGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                
                // Countdown hint
                HStack(spacing: 20) {
                    ForEach([(3, "weak"), (2, "medium"), (1, "strong"), (0, "max")], id: \.0) { val, label in
                        VStack(spacing: 3) {
                            Text(val == 0 ? "R!" : "\(val)")
                                .font(.orbitron(16, weight: .bold))
                                .foregroundColor(val == 0 ? .rwRed : val == 1 ? .rwAmber : val == 2 ? .rwGreen : .rwMuted)
                            Text(label)
                                .font(.system(size: 8))
                                .foregroundColor(.rwMuted)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                
                // Cancel
                Text("3 ... 2 ... 1 ...")
                    .font(.orbitron(13))
                    .foregroundColor(.rwMuted.opacity(0.6))
                    .kerning(2)
                    .padding(.bottom, 24)
                
                Spacer()
            }
            
            
            // Countdown Overlay
            if countdownActive {
                ZStack {
                    Color.rwBg.opacity(0.96).ignoresSafeArea()
                    VStack(spacing: 12) {
                        Text(countdownValue > 0 ? "\(countdownValue)" : "ROTATE!")
                            .font(.orbitron(countdownValue > 0 ? 120 : 48, weight: .black))
                            .foregroundColor(countdownValue > 0 ? .rwGreen : .rwAmber)
                            .shadow(color: (countdownValue > 0 ? Color.rwGreen : Color.rwAmber).opacity(0.5), radius: 30)
                            .animation(.easeInOut(duration: 0.2), value: countdownValue)
                        if countdownValue == 0 {
                            Image(systemName: "airplane.departure")
                                .font(.system(size: 40))
                                .foregroundColor(.rwGreen)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("TAKEOFF")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.rwPanel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToPFD) {
            PFDView()
        }
    }
    
    func startCountdown() {
        countdownActive = true
        countdownValue = 3
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i)) {
                if i < 3 { countdownValue = 3 - i }
                else if i == 3 { countdownValue = 0 }
                else {
                    countdownActive = false
                    navigateToPFD = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack { TakeoffView() }
}

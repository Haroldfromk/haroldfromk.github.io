//
//  ModeAView.swift
//  RunWay
//

import SwiftUI

struct ModeAView: View {
    @State private var targetPaceMin: Int = 5
    @State private var targetPaceSec: Int = 30
    @State private var paceDeviation: Int = 10
    @State private var targetDistance: Double = 5.0

    var body: some View {
        ZStack {
            Color.rwBg.ignoresSafeArea()

            VStack(spacing: 10) {

                Color.clear.frame(height: 4) // 상단 여백

                // TARGET PACE
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .foregroundColor(.rwGreen)
                            .font(.system(size: 10))
                        Text("TARGET PACE")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.rwMuted)
                            .kerning(1.5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Button { if targetPaceMin < 15 { targetPaceMin += 1 } } label: {
                                Image(systemName: "chevron.up").foregroundColor(.rwGreen).font(.system(size: 12, weight: .semibold))
                            }
                            Text("\(targetPaceMin)")
                                .font(.orbitron(34, weight: .bold))
                                .foregroundColor(.rwGreen)
                                .frame(width: 50)
                            Button { if targetPaceMin > 3 { targetPaceMin -= 1 } } label: {
                                Image(systemName: "chevron.down").foregroundColor(.rwGreen).font(.system(size: 12, weight: .semibold))
                            }
                        }
                        Text("'")
                            .font(.orbitron(34, weight: .bold))
                            .foregroundColor(.rwGreen)
                            .padding(.bottom, 4)
                        VStack(spacing: 2) {
                            Button {
                                if targetPaceSec < 55 { targetPaceSec += 5 } else { targetPaceSec = 0 }
                            } label: {
                                Image(systemName: "chevron.up").foregroundColor(.rwGreen).font(.system(size: 12, weight: .semibold))
                            }
                            Text(String(format: "%02d", targetPaceSec))
                                .font(.orbitron(34, weight: .bold))
                                .foregroundColor(.rwGreen)
                                .frame(width: 50)
                            Button {
                                if targetPaceSec > 0 { targetPaceSec -= 5 } else { targetPaceSec = 55 }
                            } label: {
                                Image(systemName: "chevron.down").foregroundColor(.rwGreen).font(.system(size: 12, weight: .semibold))
                            }
                        }
                        Text("\"")
                            .font(.orbitron(34, weight: .bold))
                            .foregroundColor(.rwGreen)
                            .padding(.bottom, 4)
                        Text("/km")
                            .font(.system(size: 10))
                            .foregroundColor(.rwMuted)
                            .padding(.leading, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.rwPanel)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rwGreen.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 16)

                // PACE DEVIATION
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "plusminus")
                            .foregroundColor(.rwAmber)
                            .font(.system(size: 10))
                        Text("PACE DEVIATION")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.rwMuted)
                            .kerning(1.5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 16) {
                        Button { if paceDeviation > 5 { paceDeviation -= 5 } } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.rwAmber)
                                .font(.system(size: 26))
                        }
                        VStack(spacing: 1) {
                            Text("±\(paceDeviation)s")
                                .font(.orbitron(28, weight: .bold))
                                .foregroundColor(.rwAmber)
                            Text("허용 오차")
                                .font(.system(size: 8))
                                .foregroundColor(.rwMuted)
                        }
                        .frame(maxWidth: .infinity)
                        Button { if paceDeviation < 60 { paceDeviation += 5 } } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.rwAmber)
                                .font(.system(size: 26))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.rwPanel)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rwAmber.opacity(0.25), lineWidth: 1))
                .padding(.horizontal, 16)

                // TARGET DISTANCE
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.checkered")
                            .foregroundColor(.rwBlue)
                            .font(.system(size: 10))
                        Text("TARGET DISTANCE")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.rwMuted)
                            .kerning(1.5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 16) {
                        Button { if targetDistance > 1.0 { targetDistance -= 0.5 } } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.rwBlue)
                                .font(.system(size: 26))
                        }
                        VStack(spacing: 1) {
                            Text(String(format: "%.1f km", targetDistance))
                                .font(.orbitron(28, weight: .bold))
                                .foregroundColor(.rwBlue)
                            Text("MINIMUMS 50m 전 경고")
                                .font(.system(size: 8))
                                .foregroundColor(.rwMuted)
                        }
                        .frame(maxWidth: .infinity)
                        Button { if targetDistance < 42.0 { targetDistance += 0.5 } } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.rwBlue)
                                .font(.system(size: 26))
                        }
                    }

                    HStack(spacing: 6) {
                        ForEach([3.0, 5.0, 10.0, 21.1, 42.2], id: \.self) { dist in
                            Button { targetDistance = dist } label: {
                                Text(dist == 21.1 ? "하프" : dist == 42.2 ? "풀" : "\(Int(dist))km")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(targetDistance == dist ? .rwBg : .rwBlue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                                    .background(targetDistance == dist ? Color.rwBlue : Color.rwBlue.opacity(0.1))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.rwBlue.opacity(0.3), lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.rwPanel)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rwBlue.opacity(0.25), lineWidth: 1))
                .padding(.horizontal, 16)

                // MISSION BRIEF
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MISSION BRIEF")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.rwMuted)
                            .kerning(2)
                        HStack(spacing: 4) {
                            Text("Target")
                                .font(.system(size: 9))
                                .foregroundColor(.rwMuted)
                            Text("\(targetPaceMin)'\(String(format: "%02d", targetPaceSec))\"/km")
                                .font(.orbitron(10, weight: .bold))
                                .foregroundColor(.rwGreen)
                        }
                        HStack(spacing: 4) {
                            Text("Deviation")
                                .font(.system(size: 9))
                                .foregroundColor(.rwMuted)
                            Text("±\(paceDeviation)s")
                                .font(.orbitron(10, weight: .bold))
                                .foregroundColor(.rwAmber)
                        }
                        HStack(spacing: 4) {
                            Text("Distance")
                                .font(.system(size: 9))
                                .foregroundColor(.rwMuted)
                            Text(String(format: "%.1f km", targetDistance))
                                .font(.orbitron(10, weight: .bold))
                                .foregroundColor(.rwBlue)
                        }
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("SINK RATE")
                            .font(.system(size: 7))
                            .foregroundColor(.rwRed)
                        Text("> \(targetPaceMin)'\(String(format: "%02d", min(59, targetPaceSec + paceDeviation)))\"")
                            .font(.orbitron(9, weight: .bold))
                            .foregroundColor(.rwRed)
                        Divider().background(Color.rwBorder)
                        Text("GLIDE PATH")
                            .font(.system(size: 7))
                            .foregroundColor(.rwGreen)
                        Divider().background(Color.rwBorder)
                        Text("OVERSPEED")
                            .font(.system(size: 7))
                            .foregroundColor(.rwAmber)
                        Text("< \(targetPaceMin)'\(String(format: "%02d", max(0, targetPaceSec - paceDeviation)))\"")
                            .font(.orbitron(9, weight: .bold))
                            .foregroundColor(.rwAmber)
                    }
                    .padding(8)
                    .background(Color.rwPanel2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.rwPanel)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rwBorder, lineWidth: 1))
                .padding(.horizontal, 16)

                // PRE-FLIGHT CHECK
                NavigationLink(destination: TakeoffView()) {
                    HStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .font(.system(size: 13, weight: .semibold))
                        Text("PRE-FLIGHT CHECK")
                            .font(.orbitron(13, weight: .bold))
                            .kerning(1)
                    }
                    .foregroundColor(.rwBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.rwGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)

                Spacer()
            }
        }
        .navigationTitle("MISSION FLIGHT")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.rwPanel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { ModeAView() }
}

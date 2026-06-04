//
//  AlertsView.swift
//  RunWay
//

import SwiftUI

enum AlertType {
    case sinkRate, overspeed, glidePath, minimums

    var icon: String {
        switch self {
        case .sinkRate: return "arrow.down.circle.fill"
        case .overspeed: return "exclamationmark.triangle.fill"
        case .glidePath: return "checkmark.circle.fill"
        case .minimums: return "flag.fill"
        }
    }

    var title: String {
        switch self {
        case .sinkRate: return "SINK RATE"
        case .overspeed: return "OVERSPEED"
        case .glidePath: return "GLIDE PATH"
        case .minimums: return "MINIMUMS"
        }
    }

    var color: Color {
        switch self {
        case .sinkRate: return .rwRed
        case .overspeed: return .rwAmber
        case .glidePath: return .rwGreen
        case .minimums: return .rwAmber
        }
    }
}

struct FlightAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let description: String
    let pace: String
    let km: String
    let date: String
}

struct AlertsView: View {
    let alerts: [FlightAlert] = [
        FlightAlert(type: .sinkRate,   description: "페이스 목표 초과 +0:12s", pace: "5'42\"/km", km: "3.2 km", date: "2024.05.24  18:22"),
        FlightAlert(type: .minimums,   description: "목표 거리 500m 전 도달",  pace: "5'27\"/km", km: "7.9 km", date: "2024.05.24  18:48"),
        FlightAlert(type: .glidePath,  description: "목표 페이스 범위 복귀",   pace: "5'29\"/km", km: "3.8 km", date: "2024.05.24  18:27"),
        FlightAlert(type: .overspeed,  description: "페이스 목표 초과 -0:15s", pace: "5'15\"/km", km: "1.2 km", date: "2024.05.21  07:14"),
        FlightAlert(type: .sinkRate,   description: "페이스 목표 초과 +0:08s", pace: "5'38\"/km", km: "5.1 km", date: "2024.05.21  07:38"),
        FlightAlert(type: .glidePath,  description: "목표 페이스 범위 복귀",   pace: "5'31\"/km", km: "5.5 km", date: "2024.05.21  07:41"),
    ]

    var sinkRateCount: Int { alerts.filter { $0.type == .sinkRate }.count }
    var overspeedCount: Int { alerts.filter { $0.type == .overspeed }.count }

    var body: some View {
        ZStack {
            Color.rwBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {

                    // Summary cards
                    HStack(spacing: 8) {
                        AlertSummaryCard(
                            label: "SINK RATE",
                            count: sinkRateCount,
                            color: .rwRed,
                            icon: "arrow.down.circle.fill"
                        )
                        AlertSummaryCard(
                            label: "OVERSPEED",
                            count: overspeedCount,
                            color: .rwAmber,
                            icon: "exclamationmark.triangle.fill"
                        )
                        AlertSummaryCard(
                            label: "GLIDE PATH",
                            count: alerts.filter { $0.type == .glidePath }.count,
                            color: .rwGreen,
                            icon: "checkmark.circle.fill"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Alert list
                    VStack(spacing: 6) {
                        ForEach(alerts) { alert in
                            AlertRow(alert: alert)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

// MARK: - Summary Card
struct AlertSummaryCard: View {
    let label: String
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 18))
            Text("\(count)")
                .font(.orbitron(22, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.rwMuted)
                .kerning(0.5)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Alert Row
struct AlertRow: View {
    let alert: FlightAlert

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: alert.type.icon)
                .foregroundColor(alert.type.color)
                .font(.system(size: 20))
                .frame(width: 28)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(alert.type.title)
                        .font(.orbitron(11, weight: .bold))
                        .foregroundColor(alert.type.color)
                    Text(alert.km)
                        .font(.system(size: 9))
                        .foregroundColor(.rwMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.rwPanel2)
                        .clipShape(Capsule())
                }
                Text(alert.description)
                    .font(.system(size: 11))
                    .foregroundColor(.rwText)
                HStack(spacing: 8) {
                    Text(alert.date)
                        .font(.system(size: 9))
                        .foregroundColor(.rwMuted)
                    Text(alert.pace)
                        .font(.orbitron(9, weight: .semibold))
                        .foregroundColor(.rwMuted)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.rwPanel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(alert.type.color.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack { AlertsView() }
}

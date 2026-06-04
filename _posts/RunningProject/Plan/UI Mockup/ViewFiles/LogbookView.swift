//
//  LogbookView.swift
//  RunWay
//

import SwiftUI

struct LogEntry: Identifiable {
    let id = UUID()
    let date: String
    let mode: String
    let distance: String
    let pace: String
    let isTarget: Bool
}

struct LogbookView: View {
    @State private var selectedFilter = 0
    let filters = ["ALL", "MISSION", "FREE"]

    let entries: [LogEntry] = [
        LogEntry(date: "2024.06.24", mode: "MISSION FLIGHT", distance: "8.42 km", pace: "5'42\"/km", isTarget: true),
        LogEntry(date: "2024.05.21", mode: "MISSION FLIGHT", distance: "6.21 km", pace: "5'55\"/km", isTarget: false),
        LogEntry(date: "2024.05.18", mode: "FREE FLIGHT", distance: "5.02 km", pace: "6'02\"/km", isTarget: false),
        LogEntry(date: "2024.05.15", mode: "MISSION FLIGHT", distance: "7.31 km", pace: "5'48\"/km", isTarget: false),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.rwBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("LOGBOOK")
                        .font(.orbitron(20, weight: .bold))
                        .foregroundColor(.rwText)
                        .kerning(2)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Filter tabs
                HStack(spacing: 6) {
                    ForEach(filters.indices, id: \.self) { i in
                        Button {
                            selectedFilter = i
                        } label: {
                            Text(filters[i])
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(selectedFilter == i ? .rwGreen : .rwMuted)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(selectedFilter == i ? Color.rwGreen.opacity(0.1) : Color.rwPanel2)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedFilter == i ? Color.rwGreen.opacity(0.3) : Color.rwBorder, lineWidth: 1)
                                )
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(entries) { entry in
                            NavigationLink(destination: FlightSummaryView()) {
                                LogEntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }


        }
        .navigationBarHidden(true)
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.date)
                    .font(.system(size: 9))
                    .foregroundColor(.rwMuted)
                HStack(spacing: 5) {
                    Text(entry.mode)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.rwText)
                    if entry.isTarget {
                        Text("TARGET HIT")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.rwGreen)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.rwGreen.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.distance)
                    .font(.orbitron(14, weight: .bold))
                    .foregroundColor(.rwText)
                Text(entry.pace)
                    .font(.system(size: 10))
                    .foregroundColor(.rwMuted)
            }
            Image(systemName: "chevron.right")
                .foregroundColor(.rwMuted)
                .font(.system(size: 11))
                .padding(.leading, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.rwPanel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rwBorder, lineWidth: 1))
    }
}

#Preview {
    NavigationStack { LogbookView() }
}
